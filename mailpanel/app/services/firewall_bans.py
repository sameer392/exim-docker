"""Manual IP blocks + fail2ban status for mail-panel."""

from __future__ import annotations

import ipaddress
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

from ..config import FIREWALL_DIR, FIREWALL_STORE, FIREWALL_STATUS, FIREWALL_SYNC_REQUEST, FIREWALL_UNBAN_QUEUE


def format_remaining(seconds: int | None, *, permanent: bool = False) -> str:
    if permanent:
        return "Permanent"
    if seconds is None:
        return "—"
    seconds = max(0, int(seconds))
    if seconds <= 0:
        return "Expired"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    if minutes or not parts:
        parts.append(f"{minutes}m")
    if not days and not hours and secs and minutes == 0:
        parts = [f"{secs}s"]
    return " ".join(parts)


def _default_store() -> dict:
    return {
        "whitelist": [
            "127.0.0.1",
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
        ],
        "blocked": [],
    }


def _validate_ip(ip: str) -> str:
    ip = ip.strip()
    try:
        if "/" in ip:
            net = ipaddress.ip_network(ip, strict=False)
            if net.version != 4:
                raise ValueError("Only IPv4 is supported")
            return str(net)
        addr = ipaddress.ip_address(ip)
        if addr.version != 4:
            raise ValueError("Only IPv4 is supported")
        return str(addr)
    except ValueError as exc:
        raise ValueError(f"Invalid IP or CIDR: {ip}") from exc


def _read_store() -> dict:
    FIREWALL_DIR.mkdir(parents=True, exist_ok=True)
    if not FIREWALL_STORE.exists():
        store = _default_store()
        _write_store(store)
        return store
    try:
        data = json.loads(FIREWALL_STORE.read_text())
    except json.JSONDecodeError:
        return _default_store()
    if not isinstance(data, dict):
        return _default_store()
    data.setdefault("whitelist", [])
    data.setdefault("blocked", [])
    return data


def _write_store(store: dict) -> None:
    FIREWALL_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "whitelist": store.get("whitelist", []),
        "blocked": store.get("blocked", []),
    }
    FIREWALL_STORE.write_text(json.dumps(payload, indent=2) + "\n")
    os.chmod(FIREWALL_STORE, 0o644)


def request_sync() -> None:
    """Ask the host agent to apply iptables/fail2ban changes."""
    FIREWALL_DIR.mkdir(parents=True, exist_ok=True)
    FIREWALL_SYNC_REQUEST.write_text(datetime.now(timezone.utc).isoformat() + "\n")
    # Also nudge by touching the store mtime (path unit watches both)
    try:
        FIREWALL_STORE.touch()
    except OSError:
        pass


def read_status() -> dict:
    if not FIREWALL_STATUS.exists():
        return {
            "updated_at": None,
            "fail2ban_ok": False,
            "fail2ban_banned": [],
            "manual_banned": [],
            "whitelist": _read_store().get("whitelist", []),
            "agent_missing": True,
        }
    try:
        data = json.loads(FIREWALL_STATUS.read_text())
    except json.JSONDecodeError:
        data = {}
    data["agent_missing"] = False
    return data


def list_blocked_page() -> dict:
    store = _read_store()
    status = read_status()
    manual = []
    for entry in store.get("blocked", []):
        if isinstance(entry, dict):
            row = dict(entry)
        else:
            row = {"ip": str(entry), "reason": "", "added_at": ""}
        row["remaining"] = format_remaining(None, permanent=True)
        manual.append(row)
    manual_ips = {m["ip"] for m in manual}

    # Prefer detailed list; fall back to plain IP list
    f2b_source = status.get("fail2ban_bans") or [
        {"ip": ip} for ip in status.get("fail2ban_banned", [])
    ]
    f2b = []
    now = int(time.time())
    for item in f2b_source:
        if isinstance(item, str):
            item = {"ip": item}
        ip = item.get("ip")
        if not ip or ip in manual_ips:
            continue
        remaining = item.get("remaining_seconds")
        # Only recompute if sync did not provide remaining_seconds
        if remaining is None:
            exp = item.get("expires_at")
            if exp:
                try:
                    exp_ts = datetime.strptime(
                        exp.replace("Z", ""), "%Y-%m-%dT%H:%M:%S"
                    ).replace(tzinfo=timezone.utc).timestamp()
                    remaining = max(0, int(exp_ts - now))
                except ValueError:
                    pass
        f2b.append(
            {
                "ip": ip,
                "source": "fail2ban",
                "reason": "Auto-ban (AUTH abuse)",
                "banned_at": item.get("banned_at") or "—",
                "expires_at": item.get("expires_at") or "—",
                "remaining": format_remaining(remaining),
                "remaining_seconds": remaining,
            }
        )
    return {
        "manual": manual,
        "fail2ban": f2b,
        "whitelist": store.get("whitelist", []),
        "status": status,
    }


def add_block(ip: str, reason: str = "") -> None:
    ip = _validate_ip(ip)
    store = _read_store()
    for entry in store["blocked"]:
        existing = entry.get("ip") if isinstance(entry, dict) else str(entry)
        if existing == ip:
            raise ValueError(f"IP already blocked: {ip}")
    for w in store.get("whitelist", []):
        if _ip_in_whitelist(ip, str(w)):
            raise ValueError(f"IP is whitelisted and cannot be blocked: {ip}")
    store["blocked"].append(
        {
            "ip": ip,
            "reason": (reason or "manual").strip()[:200],
            "added_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
    )
    _write_store(store)
    request_sync()


def remove_block(ip: str) -> None:
    ip = ip.strip()
    store = _read_store()
    before = len(store["blocked"])
    store["blocked"] = [
        e
        for e in store["blocked"]
        if (e.get("ip") if isinstance(e, dict) else str(e)) != ip
    ]
    changed = len(store["blocked"]) != before
    if changed:
        _write_store(store)
    # Always queue fail2ban unban + iptables cleanup
    FIREWALL_DIR.mkdir(parents=True, exist_ok=True)
    with FIREWALL_UNBAN_QUEUE.open("a") as f:
        f.write(ip + "\n")
    request_sync()
    if not changed and ip not in read_status().get("fail2ban_banned", []):
        # Allow remove of fail2ban-only entries without error
        pass


def add_whitelist(ip: str) -> None:
    ip = _validate_ip(ip)
    store = _read_store()
    if ip in store["whitelist"]:
        raise ValueError(f"Already whitelisted: {ip}")
    store["whitelist"].append(ip)
    # Drop from blocked if present
    store["blocked"] = [
        e
        for e in store["blocked"]
        if (e.get("ip") if isinstance(e, dict) else str(e)) != ip
    ]
    _write_store(store)
    with FIREWALL_UNBAN_QUEUE.open("a") as f:
        f.write(ip + "\n")
    request_sync()


def remove_whitelist(ip: str) -> None:
    ip = ip.strip()
    store = _read_store()
    if ip not in store["whitelist"]:
        raise ValueError("Not in whitelist")
    # Protect private defaults
    protected = {"127.0.0.1", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"}
    if ip in protected:
        raise ValueError("Cannot remove built-in private network whitelist entry")
    store["whitelist"] = [w for w in store["whitelist"] if w != ip]
    _write_store(store)
    request_sync()


def _ip_in_whitelist(ip: str, entry: str) -> bool:
    try:
        addr = ipaddress.ip_address(ip.split("/")[0])
        if "/" in entry:
            return addr in ipaddress.ip_network(entry, strict=False)
        return str(addr) == str(ipaddress.ip_address(entry))
    except ValueError:
        return False


def ensure_defaults() -> None:
    _read_store()

"""Per-domain SMTP submission IP allowlists + global restriction mode."""

from __future__ import annotations

import ipaddress
import json
import os
from pathlib import Path

from ..config import SMTP_ALLOW_FILE, SMTP_ALLOW_JSON
from .mail import DOMAIN_RE, list_domains

MODE_ANY = "any"
MODE_ALLOWLIST_ONLY = "allowlist_only"
VALID_MODES = {MODE_ANY, MODE_ALLOWLIST_ONLY}


def _default_store() -> dict:
    return {"mode": MODE_ANY, "domains": {}}


def _read_store() -> dict:
    """Return {mode, domains: {domain: [ips]}} with migration from legacy flat JSON."""
    if not SMTP_ALLOW_JSON.exists():
        return _default_store()
    try:
        data = json.loads(SMTP_ALLOW_JSON.read_text())
    except json.JSONDecodeError:
        return _default_store()
    if not isinstance(data, dict):
        return _default_store()

    # New format
    if "domains" in data and isinstance(data.get("domains"), dict):
        mode = data.get("mode", MODE_ANY)
        if mode not in VALID_MODES:
            mode = MODE_ANY
        domains: dict[str, list[str]] = {}
        for domain, ips in data["domains"].items():
            if isinstance(ips, list):
                domains[str(domain).lower()] = [
                    str(ip).strip() for ip in ips if str(ip).strip()
                ]
        return {"mode": mode, "domains": domains}

    # Legacy flat {domain: [ips]}
    domains = {}
    for domain, ips in data.items():
        if domain.startswith("_"):
            continue
        if isinstance(ips, list):
            domains[str(domain).lower()] = [
                str(ip).strip() for ip in ips if str(ip).strip()
            ]
    return {"mode": MODE_ANY, "domains": domains}


def _write_store(store: dict) -> None:
    SMTP_ALLOW_JSON.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "mode": store.get("mode", MODE_ANY),
        "domains": {
            k: sorted(v)
            for k, v in sorted(store.get("domains", {}).items())
            if v
        },
    }
    SMTP_ALLOW_JSON.write_text(json.dumps(payload, indent=2) + "\n")
    os.chmod(SMTP_ALLOW_JSON, 0o644)


def _validate_ip(ip: str) -> str:
    ip = ip.strip()
    try:
        if "/" in ip:
            net = ipaddress.ip_network(ip, strict=False)
            if net.version != 4:
                raise ValueError("Only IPv4 addresses/CIDR are supported")
            return str(net)
        addr = ipaddress.ip_address(ip)
        if addr.version != 4:
            raise ValueError("Only IPv4 addresses are supported")
        return str(addr)
    except ValueError as exc:
        raise ValueError(f"Invalid IP or CIDR: {ip}") from exc


def sync_lsearch_file() -> None:
    """Write Exim lsearch file used by ACLs.

    Format:
      _mode: any | allowlist_only
      domain.tld: 1.2.3.4 : 5.6.7.8
      _all: 1.2.3.4 : 5.6.7.8
    """
    store = _read_store()
    mode = store.get("mode", MODE_ANY)
    domains = store.get("domains", {})
    lines: list[str] = [f"_mode: {mode}"]
    all_ips: list[str] = []
    seen: set[str] = set()
    for domain, ips in sorted(domains.items()):
        if not ips:
            continue
        lines.append(f"{domain}: {' : '.join(ips)}")
        for ip in ips:
            if ip not in seen:
                seen.add(ip)
                all_ips.append(ip)
    if all_ips:
        lines.append(f"_all: {' : '.join(all_ips)}")
    else:
        # Placeholder so lookup never returns empty in a way that matches "any host"
        lines.append("_all: 127.0.0.1")
    SMTP_ALLOW_FILE.parent.mkdir(parents=True, exist_ok=True)
    SMTP_ALLOW_FILE.write_text("\n".join(lines) + "\n")
    os.chmod(SMTP_ALLOW_FILE, 0o644)


def get_mode() -> str:
    return _read_store().get("mode", MODE_ANY)


def set_mode(mode: str) -> None:
    mode = mode.strip().lower()
    if mode not in VALID_MODES:
        raise ValueError("Mode must be 'any' or 'allowlist_only'")
    store = _read_store()
    store["mode"] = mode
    _write_store(store)
    sync_lsearch_file()


def list_allow_ips() -> dict[str, list[str]]:
    store = _read_store()
    data = dict(store.get("domains", {}))
    for domain in list_domains():
        data.setdefault(domain, [])
    return {k: sorted(v) for k, v in sorted(data.items())}


def add_ip(domain: str, ip: str) -> None:
    domain = domain.strip().lower()
    if not DOMAIN_RE.match(domain):
        raise ValueError("Invalid domain")
    if domain not in list_domains():
        raise ValueError(f"Domain not configured: {domain}")
    ip = _validate_ip(ip)
    store = _read_store()
    domains = store.setdefault("domains", {})
    ips = domains.get(domain, [])
    if ip in ips:
        raise ValueError(f"IP already allowed for {domain}: {ip}")
    ips.append(ip)
    domains[domain] = ips
    _write_store(store)
    sync_lsearch_file()


def remove_ip(domain: str, ip: str) -> None:
    domain = domain.strip().lower()
    ip = ip.strip()
    store = _read_store()
    domains = store.get("domains", {})
    ips = domains.get(domain, [])
    if ip not in ips:
        raise ValueError("IP not found for this domain")
    domains[domain] = [x for x in ips if x != ip]
    if not domains[domain]:
        del domains[domain]
    store["domains"] = domains
    _write_store(store)
    sync_lsearch_file()


def remove_domain(domain: str) -> None:
    domain = domain.strip().lower()
    store = _read_store()
    domains = store.get("domains", {})
    if domain in domains:
        del domains[domain]
        store["domains"] = domains
        _write_store(store)
        sync_lsearch_file()


def ensure_defaults() -> None:
    if not SMTP_ALLOW_JSON.exists():
        _write_store(_default_store())
    else:
        # Migrate legacy flat file on read/write cycle
        store = _read_store()
        _write_store(store)
    sync_lsearch_file()

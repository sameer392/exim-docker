"""Per-domain SMTP submission IP allowlists for Exim."""

from __future__ import annotations

import ipaddress
import json
import os
import re
from pathlib import Path

from ..config import SMTP_ALLOW_FILE, SMTP_ALLOW_JSON
from .mail import DOMAIN_RE, list_domains

IP_RE = re.compile(
    r"^("
    r"(\d{1,3}\.){3}\d{1,3}"  # IPv4
    r"|(\d{1,3}\.){3}\d{1,3}/\d{1,2}"  # IPv4 CIDR
    r")$"
)


def _read_json() -> dict[str, list[str]]:
    if not SMTP_ALLOW_JSON.exists():
        return {}
    try:
        data = json.loads(SMTP_ALLOW_JSON.read_text())
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    out: dict[str, list[str]] = {}
    for domain, ips in data.items():
        if isinstance(ips, list):
            out[str(domain).lower()] = [str(ip).strip() for ip in ips if str(ip).strip()]
    return out


def _write_json(data: dict[str, list[str]]) -> None:
    SMTP_ALLOW_JSON.parent.mkdir(parents=True, exist_ok=True)
    SMTP_ALLOW_JSON.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
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
      domain.tld: 1.2.3.4 : 5.6.7.8
      _all: 1.2.3.4 : 5.6.7.8
      _restricted: yes
    """
    data = _read_json()
    lines: list[str] = []
    all_ips: list[str] = []
    seen: set[str] = set()
    for domain, ips in sorted(data.items()):
        if not ips:
            continue
        lines.append(f"{domain}: {' : '.join(ips)}")
        for ip in ips:
            if ip not in seen:
                seen.add(ip)
                all_ips.append(ip)
    if all_ips:
        lines.append(f"_all: {' : '.join(all_ips)}")
        lines.append("_restricted: yes")
    SMTP_ALLOW_FILE.parent.mkdir(parents=True, exist_ok=True)
    SMTP_ALLOW_FILE.write_text("\n".join(lines) + ("\n" if lines else ""))
    os.chmod(SMTP_ALLOW_FILE, 0o644)


def list_allow_ips() -> dict[str, list[str]]:
    data = _read_json()
    # Ensure every configured domain appears (possibly empty)
    for domain in list_domains():
        data.setdefault(domain, [])
    return {k: sorted(v) for k, v in sorted(data.items())}


def get_domain_ips(domain: str) -> list[str]:
    domain = domain.strip().lower()
    return list(_read_json().get(domain, []))


def add_ip(domain: str, ip: str) -> None:
    domain = domain.strip().lower()
    if not DOMAIN_RE.match(domain):
        raise ValueError("Invalid domain")
    if domain not in list_domains():
        raise ValueError(f"Domain not configured: {domain}")
    ip = _validate_ip(ip)
    data = _read_json()
    ips = data.get(domain, [])
    if ip in ips:
        raise ValueError(f"IP already allowed for {domain}: {ip}")
    ips.append(ip)
    data[domain] = ips
    _write_json(data)
    sync_lsearch_file()


def remove_ip(domain: str, ip: str) -> None:
    domain = domain.strip().lower()
    ip = ip.strip()
    data = _read_json()
    ips = data.get(domain, [])
    if ip not in ips:
        raise ValueError("IP not found for this domain")
    data[domain] = [x for x in ips if x != ip]
    if not data[domain]:
        del data[domain]
    _write_json(data)
    sync_lsearch_file()


def remove_domain(domain: str) -> None:
    domain = domain.strip().lower()
    data = _read_json()
    if domain in data:
        del data[domain]
        _write_json(data)
        sync_lsearch_file()


def ensure_defaults() -> None:
    if not SMTP_ALLOW_JSON.exists():
        _write_json({})
    sync_lsearch_file()

import os
import re
import subprocess
from pathlib import Path

from ..config import (
    DKIM_SELECTOR_FILE,
    DOMAINS_FILE,
    MAIL_DIR,
    MAIL_GID,
    MAIL_UID,
    PASSWD_FILE,
    PRIMARY_HOSTNAME_FILE,
    QUALIFY_DOMAIN_FILE,
)

EMAIL_RE = re.compile(
    r"^[a-zA-Z0-9]([a-zA-Z0-9._+-]*[a-zA-Z0-9])?@[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$"
)
DOMAIN_RE = re.compile(
    r"^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$"
)


def _read_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    lines = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            lines.append(line)
    return lines


def _write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + ("\n" if lines else ""))
    os.chmod(path, 0o644)


def read_text_file(path: Path, default: str = "") -> str:
    if not path.exists():
        return default
    return path.read_text().strip()


def list_domains() -> list[str]:
    return _read_lines(DOMAINS_FILE)


def add_domain(domain: str) -> None:
    domain = domain.strip().lower()
    if not DOMAIN_RE.match(domain):
        raise ValueError("Invalid domain format")
    domains = list_domains()
    if domain in domains:
        return
    domains.append(domain)
    _write_lines(DOMAINS_FILE, domains)
    if not read_text_file(QUALIFY_DOMAIN_FILE):
        QUALIFY_DOMAIN_FILE.parent.mkdir(parents=True, exist_ok=True)
        QUALIFY_DOMAIN_FILE.write_text(domain + "\n")
        os.chmod(QUALIFY_DOMAIN_FILE, 0o644)


def remove_domain(domain: str) -> None:
    domain = domain.strip().lower()
    users = list_users()
    if any(u["domain"] == domain for u in users):
        raise ValueError(f"Cannot remove domain with existing users: {domain}")
    domains = [d for d in list_domains() if d != domain]
    _write_lines(DOMAINS_FILE, domains)
    if read_text_file(QUALIFY_DOMAIN_FILE) == domain:
        if domains:
            QUALIFY_DOMAIN_FILE.write_text(domains[0] + "\n")
            os.chmod(QUALIFY_DOMAIN_FILE, 0o644)
        elif QUALIFY_DOMAIN_FILE.exists():
            QUALIFY_DOMAIN_FILE.write_text("")


def parse_passwd() -> list[dict]:
    users = []
    if not PASSWD_FILE.exists():
        return users
    for line in PASSWD_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        email, _hash = line.split(":", 1)
        if "@" not in email:
            continue
        local, domain = email.split("@", 1)
        maildir = MAIL_DIR / domain / local
        users.append(
            {
                "email": email,
                "local": local,
                "domain": domain,
                "has_maildir": maildir.exists(),
            }
        )
    return sorted(users, key=lambda u: u["email"])


def list_users() -> list[dict]:
    return parse_passwd()


def hash_password(password: str) -> str:
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    result = subprocess.run(
        ["openssl", "passwd", "-1", password],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError("Failed to generate password hash")
    return result.stdout.strip()


def _write_passwd(entries: dict[str, str]) -> None:
    PASSWD_FILE.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{email}:{pwd_hash}" for email, pwd_hash in sorted(entries.items())]
    PASSWD_FILE.write_text("\n".join(lines) + ("\n" if lines else ""))
    os.chmod(PASSWD_FILE, 0o644)


def _ensure_maildir(domain: str, local: str) -> Path:
    maildir = MAIL_DIR / domain / local
    maildir.mkdir(parents=True, exist_ok=True)
    os.chown(maildir, MAIL_UID, MAIL_GID)
    os.chmod(maildir, 0o700)
    return maildir


def upsert_user(email: str, password: str) -> None:
    email = email.strip().lower()
    if not EMAIL_RE.match(email):
        raise ValueError("Invalid email address")
    local, domain = email.split("@", 1)
    domains = list_domains()
    if domain not in domains:
        raise ValueError(f"Domain not configured: {domain}. Add the domain first.")

    pwd_hash = hash_password(password)
    entries = {}
    if PASSWD_FILE.exists():
        for line in PASSWD_FILE.read_text().splitlines():
            if ":" in line:
                e, h = line.split(":", 1)
                entries[e.strip()] = h.strip()
    entries[email] = pwd_hash
    _write_passwd(entries)
    _ensure_maildir(domain, local)


def delete_user(email: str) -> None:
    email = email.strip().lower()
    entries = {}
    if PASSWD_FILE.exists():
        for line in PASSWD_FILE.read_text().splitlines():
            if ":" in line:
                e, h = line.split(":", 1)
                if e.strip() != email:
                    entries[e.strip()] = h.strip()
    if email not in {u["email"] for u in parse_passwd()}:
        raise ValueError("User not found")
    _write_passwd(entries)


def get_server_info() -> dict:
    selector = read_text_file(DKIM_SELECTOR_FILE, "unknown")
    return {
        "primary_hostname": read_text_file(PRIMARY_HOSTNAME_FILE, "—"),
        "qualify_domain": read_text_file(QUALIFY_DOMAIN_FILE, "—"),
        "dkim_selector": selector,
        "domain_count": len(list_domains()),
        "user_count": len(list_users()),
    }

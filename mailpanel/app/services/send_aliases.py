import json
import os
from pathlib import Path

from ..config import SEND_ALIASES_FILE, SEND_ALIASES_JSON
from .mail import EMAIL_RE, list_domains, list_users


def _read_json() -> list[dict]:
    if not SEND_ALIASES_JSON.exists():
        return []
    try:
        data = json.loads(SEND_ALIASES_JSON.read_text())
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    return data


def _write_json(entries: list[dict]) -> None:
    SEND_ALIASES_JSON.parent.mkdir(parents=True, exist_ok=True)
    SEND_ALIASES_JSON.write_text(json.dumps(entries, indent=2) + "\n")
    os.chmod(SEND_ALIASES_JSON, 0o644)


def sync_lsearch_file() -> None:
    """Write Exim lsearch file: alias_address -> auth_user (lowercase keys)."""
    lines = []
    for entry in _read_json():
        alias = entry.get("alias", "").strip().lower()
        auth_user = entry.get("auth_user", "").strip().lower()
        if alias and auth_user:
            lines.append(f"{alias}: {auth_user}")
    SEND_ALIASES_FILE.parent.mkdir(parents=True, exist_ok=True)
    SEND_ALIASES_FILE.write_text("\n".join(sorted(lines)) + ("\n" if lines else ""))
    os.chmod(SEND_ALIASES_FILE, 0o644)


def list_aliases() -> list[dict]:
    return sorted(_read_json(), key=lambda e: (e.get("alias", ""), e.get("auth_user", "")))


def add_alias(alias: str, auth_user: str) -> None:
    alias = alias.strip().lower()
    auth_user = auth_user.strip().lower()

    if not EMAIL_RE.match(alias):
        raise ValueError("Invalid alias email address")
    if not EMAIL_RE.match(auth_user):
        raise ValueError("Invalid authenticated account email")

    alias_domain = alias.split("@", 1)[1]
    if alias_domain not in list_domains():
        raise ValueError(f"Alias domain not configured: {alias_domain}")

    user_emails = {u["email"] for u in list_users()}
    if auth_user not in user_emails:
        raise ValueError(f"Authenticated account does not exist: {auth_user}")
    if alias == auth_user:
        raise ValueError("Alias cannot be the same as the authenticated account")

    entries = _read_json()
    for entry in entries:
        if entry.get("alias", "").lower() == alias:
            raise ValueError(f"Send alias already exists: {alias}")

    entries.append({"alias": alias, "auth_user": auth_user})
    _write_json(entries)
    sync_lsearch_file()


def remove_alias(alias: str) -> None:
    alias = alias.strip().lower()
    entries = _read_json()
    new_entries = [e for e in entries if e.get("alias", "").lower() != alias]
    if len(new_entries) == len(entries):
        raise ValueError("Send alias not found")
    _write_json(new_entries)
    sync_lsearch_file()


def remove_for_user(email: str) -> None:
    """Drop aliases when a mailbox is deleted (as alias or auth user)."""
    email = email.strip().lower()
    entries = _read_json()
    new_entries = [
        e
        for e in entries
        if e.get("alias", "").lower() != email and e.get("auth_user", "").lower() != email
    ]
    if len(new_entries) != len(entries):
        _write_json(new_entries)
        sync_lsearch_file()


def ensure_defaults() -> None:
    if not SEND_ALIASES_JSON.exists():
        _write_json([])
    sync_lsearch_file()

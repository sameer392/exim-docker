import json
import os
from pathlib import Path

from ..config import (
    RATE_10M_FILE,
    RATE_1D_FILE,
    RATE_1H_FILE,
    RATE_ASSIGNMENTS_FILE,
    RATE_TIERS_FILE,
)
from .mail import PASSWD_FILE, list_users

DEFAULT_TIER_ID = "level2"

DEFAULT_TIERS = {
    "level1": {
        "name": "Level 1 — Low",
        "per_10m": 20,
        "per_1h": 80,
        "per_1d": 400,
    },
    "level2": {
        "name": "Level 2 — Medium",
        "per_10m": 50,
        "per_1h": 200,
        "per_1d": 1000,
    },
    "level3": {
        "name": "Level 3 — High",
        "per_10m": 150,
        "per_1h": 750,
        "per_1d": 5000,
    },
}

TIER_ORDER = ["level1", "level2", "level3"]


def _read_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return default.copy()
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return default.copy()


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")
    os.chmod(path, 0o644)


def _write_lsearch(path: Path, lines: dict[str, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join(f"{email}: {limit}" for email, limit in sorted(lines.items()))
    path.write_text(content + ("\n" if content else ""))
    os.chmod(path, 0o644)


def ensure_defaults() -> None:
    if not RATE_TIERS_FILE.exists():
        _write_json(RATE_TIERS_FILE, DEFAULT_TIERS)
    if not RATE_ASSIGNMENTS_FILE.exists():
        _write_json(RATE_ASSIGNMENTS_FILE, {})


def list_tiers() -> list[dict]:
    ensure_defaults()
    tiers = _read_json(RATE_TIERS_FILE, DEFAULT_TIERS)
    result = []
    for tier_id in TIER_ORDER:
        tier = tiers.get(tier_id, DEFAULT_TIERS[tier_id])
        result.append(
            {
                "id": tier_id,
                "name": tier.get("name", tier_id),
                "per_10m": int(tier.get("per_10m", 0)),
                "per_1h": int(tier.get("per_1h", 0)),
                "per_1d": int(tier.get("per_1d", 0)),
            }
        )
    return result


def get_tier_map() -> dict[str, dict]:
    tiers = _read_json(RATE_TIERS_FILE, DEFAULT_TIERS)
    return {tier_id: tiers.get(tier_id, DEFAULT_TIERS[tier_id]) for tier_id in TIER_ORDER}


def save_tiers(levels: list[dict]) -> None:
    tiers = {}
    for item in levels:
        tier_id = item["id"]
        if tier_id not in TIER_ORDER:
            continue
        per_10m = int(item["per_10m"])
        per_1h = int(item["per_1h"])
        per_1d = int(item["per_1d"])
        if min(per_10m, per_1h, per_1d) < 1:
            raise ValueError("Rate limits must be at least 1")
        if not (per_10m <= per_1h <= per_1d):
            raise ValueError("Limits must increase: 10 min ≤ 1 hour ≤ 1 day")
        tiers[tier_id] = {
            "name": item.get("name", tier_id).strip() or tier_id,
            "per_10m": per_10m,
            "per_1h": per_1h,
            "per_1d": per_1d,
        }
    _write_json(RATE_TIERS_FILE, tiers)
    sync_lookup_files()


def list_assignments() -> dict[str, str]:
    assignments = _read_json(RATE_ASSIGNMENTS_FILE, {})
    return {email: tier for email, tier in assignments.items() if tier in TIER_ORDER}


def get_user_tier(email: str) -> str:
    assignments = list_assignments()
    return assignments.get(email.strip().lower(), DEFAULT_TIER_ID)


def set_user_tier(email: str, tier_id: str) -> None:
    email = email.strip().lower()
    if tier_id not in TIER_ORDER:
        raise ValueError("Invalid rate limit level")
    users = {u["email"] for u in list_users()}
    if email not in users:
        raise ValueError("User not found")
    assignments = list_assignments()
    assignments[email] = tier_id
    _write_json(RATE_ASSIGNMENTS_FILE, assignments)
    sync_lookup_files()


def remove_user_assignment(email: str) -> None:
    assignments = list_assignments()
    assignments.pop(email.strip().lower(), None)
    _write_json(RATE_ASSIGNMENTS_FILE, assignments)
    sync_lookup_files()


def sync_lookup_files() -> None:
    tiers = get_tier_map()
    assignments = list_assignments()
    limits_10m: dict[str, int] = {}
    limits_1h: dict[str, int] = {}
    limits_1d: dict[str, int] = {}

    emails = set()
    if PASSWD_FILE.exists():
        for line in PASSWD_FILE.read_text().splitlines():
            if ":" in line:
                emails.add(line.split(":", 1)[0].strip().lower())

    for email in sorted(emails):
        tier_id = assignments.get(email, DEFAULT_TIER_ID)
        tier = tiers.get(tier_id, DEFAULT_TIERS[DEFAULT_TIER_ID])
        limits_10m[email] = int(tier["per_10m"])
        limits_1h[email] = int(tier["per_1h"])
        limits_1d[email] = int(tier["per_1d"])

    _write_lsearch(RATE_10M_FILE, limits_10m)
    _write_lsearch(RATE_1H_FILE, limits_1h)
    _write_lsearch(RATE_1D_FILE, limits_1d)


def users_with_tiers() -> list[dict]:
    ensure_defaults()
    sync_lookup_files()
    tier_map = get_tier_map()
    assignments = list_assignments()
    users = []
    for user in list_users():
        tier_id = assignments.get(user["email"], DEFAULT_TIER_ID)
        tier = tier_map.get(tier_id, DEFAULT_TIERS[DEFAULT_TIER_ID])
        users.append(
            {
                **user,
                "tier_id": tier_id,
                "tier_name": tier.get("name", tier_id),
                "limits": {
                    "per_10m": tier.get("per_10m"),
                    "per_1h": tier.get("per_1h"),
                    "per_1d": tier.get("per_1d"),
                },
            }
        )
    return users

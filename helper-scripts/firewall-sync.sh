#!/bin/bash
# Sync mail-panel firewall state to the host (DOCKER-USER + fail2ban).
# Invoked by systemd path/timer. Safe to run repeatedly.
set -euo pipefail

ROOT="${EXIM_DOCKER_ROOT:-/root/exim-docker}"
FW_DIR="${ROOT}/data/firewall"
STORE="${FW_DIR}/blocked_ips.json"
STATUS="${FW_DIR}/status.json"
UNBAN_QUEUE="${FW_DIR}/unban.queue"
SYNC_REQ="${FW_DIR}/sync.request"
IGNORE_LOCAL="/etc/fail2ban/jail.d/exim-docker-ignore.local"
MANUAL_COMMENT="exim-docker-manual"
F2B_JAIL="exim-docker-auth"

mkdir -p "$FW_DIR"

if [ ! -f "$STORE" ]; then
  cat > "$STORE" <<'EOF'
{
  "whitelist": [
    "127.0.0.1",
    "::1",
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ],
  "blocked": []
}
EOF
fi

python3 - "$STORE" "$STATUS" "$UNBAN_QUEUE" "$IGNORE_LOCAL" "$F2B_JAIL" "$MANUAL_COMMENT" <<'PY'
import ipaddress
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

store_path, status_path, unban_queue, ignore_local, f2b_jail, manual_comment = sys.argv[1:7]

def run(cmd, check=False):
    return subprocess.run(cmd, capture_output=True, text=True, check=check)

def load_store():
    with open(store_path) as f:
        data = json.load(f)
    data.setdefault("whitelist", [])
    data.setdefault("blocked", [])
    return data

def valid_v4(ip: str) -> bool:
    try:
        if "/" in ip:
            return ipaddress.ip_network(ip, strict=False).version == 4
        return ipaddress.ip_address(ip).version == 4
    except ValueError:
        return False

def list_manual_rules():
    out = run(["iptables", "-S", "DOCKER-USER"]).stdout.splitlines()
    ips = []
    for line in out:
        if manual_comment not in line or "-j DROP" not in line:
            continue
        m = re.search(r"-s\s+(\d+\.\d+\.\d+\.\d+)(?:/\d+)?", line)
        if m:
            ips.append(m.group(1))
    return ips

def add_manual(ip: str):
    # Avoid duplicates
    if ip in list_manual_rules():
        return
    run([
        "iptables", "-I", "DOCKER-USER",
        "-s", ip, "-j", "DROP",
        "-m", "comment", "--comment", manual_comment,
    ], check=False)

def del_manual(ip: str):
    # Delete until gone (handles duplicates)
    for _ in range(5):
        r = run([
            "iptables", "-D", "DOCKER-USER",
            "-s", ip, "-j", "DROP",
            "-m", "comment", "--comment", manual_comment,
        ])
        if r.returncode != 0:
            break

store = load_store()
wanted = []
for entry in store.get("blocked", []):
    ip = (entry.get("ip") if isinstance(entry, dict) else str(entry)).strip()
    if ip and valid_v4(ip):
        wanted.append(ip)
wanted = sorted(set(wanted))

current = set(list_manual_rules())
for ip in wanted:
    if ip not in current:
        add_manual(ip)
for ip in current - set(wanted):
    del_manual(ip)

# Whitelist → fail2ban ignoreip
whitelist = []
for w in store.get("whitelist", []):
    w = str(w).strip()
    if w and (valid_v4(w) or w == "::1"):
        whitelist.append(w)
# Always keep RFC1918 + localhost for fail2ban ignoreip
for extra in ("127.0.0.1/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"):
    if extra not in whitelist:
        whitelist.append(extra)

ignore_body = (
    "# Managed by exim-docker firewall-sync — do not edit by hand\n"
    "[DEFAULT]\n"
    f"ignoreip = {' '.join(whitelist)}\n"
)
old = ""
if os.path.exists(ignore_local):
    with open(ignore_local) as f:
        old = f.read()
if ignore_body != old:
    with open(ignore_local, "w") as f:
        f.write(ignore_body)
    run(["fail2ban-client", "reload"], check=False)

# Process unban queue (panel-requested)
if os.path.exists(unban_queue):
    with open(unban_queue) as f:
        ips = [ln.strip() for ln in f if ln.strip()]
    os.remove(unban_queue)
    for ip in ips:
        if not valid_v4(ip) or "/" in ip:
            # Allow exact CIDR unban for manual rules
            if not valid_v4(ip):
                continue
        del_manual(ip)
        run(["fail2ban-client", "set", f2b_jail, "unbanip", ip], check=False)

# Collect fail2ban bans (with remaining time)
f2b_banned = []
f2b_details = []
f2b_ok = False
r = run(["fail2ban-client", "status", f2b_jail])
if r.returncode == 0:
    f2b_ok = True
    m = re.search(r"Banned IP list:\s*(.*)$", r.stdout, re.M)
    if m and m.group(1).strip():
        f2b_banned = m.group(1).split()

now = int(time.time())
rt = run(["fail2ban-client", "get", f2b_jail, "banip", "--with-time"])
if rt.returncode == 0 and rt.stdout.strip():
    # Example: 203.0.113.50 \t2026-08-09 08:41:11 + 43200 = 2026-08-09 20:41:11
    for line in rt.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(
            r"^(\d+\.\d+\.\d+\.\d+)\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+\+\s+(\d+)\s+=\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})",
            line,
        )
        if not m:
            ip = line.split()[0]
            f2b_details.append({
                "ip": ip,
                "bantime": None,
                "banned_at": None,
                "expires_at": None,
                "remaining_seconds": None,
            })
            continue
        ip, banned_at, bantime_s, expires_at = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        try:
            exp_ts = int(datetime.strptime(expires_at, "%Y-%m-%d %H:%M:%S").timestamp())
            remaining = max(0, exp_ts - now)
        except ValueError:
            remaining = bantime_s
            exp_ts = None
        f2b_details.append({
            "ip": ip,
            "bantime": bantime_s,
            "banned_at": banned_at.replace(" ", "T") + "Z",
            "expires_at": expires_at.replace(" ", "T") + "Z",
            "remaining_seconds": remaining,
        })
elif f2b_banned:
    # Fallback: sqlite
    try:
        import sqlite3
        db = "/var/lib/fail2ban/fail2ban.sqlite3"
        if os.path.exists(db):
            conn = sqlite3.connect(db)
            for ip, tob, bt in conn.execute(
                "SELECT ip, timeofban, bantime FROM bips WHERE jail=?",
                (f2b_jail,),
            ):
                remaining = max(0, int(tob) + int(bt) - now) if tob and bt else None
                f2b_details.append({
                    "ip": ip,
                    "bantime": bt,
                    "banned_at": datetime.fromtimestamp(tob, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if tob else None,
                    "expires_at": datetime.fromtimestamp(tob + bt, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if tob and bt else None,
                    "remaining_seconds": remaining,
                })
            conn.close()
    except Exception:
        f2b_details = [{"ip": ip, "remaining_seconds": None} for ip in f2b_banned]

if not f2b_details and f2b_banned:
    f2b_details = [{"ip": ip, "remaining_seconds": None} for ip in f2b_banned]

status = {
    "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "fail2ban_ok": f2b_ok,
    "fail2ban_jail": f2b_jail,
    "fail2ban_banned": sorted(f2b_banned),
    "fail2ban_bans": f2b_details,
    "manual_banned": sorted(wanted),
    "whitelist": whitelist,
    "docker_user_rules": list_manual_rules(),
}
with open(status_path, "w") as f:
    json.dump(status, f, indent=2)
    f.write("\n")
print(f"firewall-sync: manual={len(wanted)} fail2ban={len(f2b_banned)}")
PY

rm -f "$SYNC_REQ"
exit 0

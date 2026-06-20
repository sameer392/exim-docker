#!/bin/bash
# Ensure passwd file exists. All mail accounts are created via the admin panel.
set -e

PASSWD_FILE=/etc/exim4/passwd

if [ ! -f "$PASSWD_FILE" ]; then
    touch "$PASSWD_FILE"
    echo "Created empty passwd file — add accounts via admin panel (port 8090)"
fi

chmod 644 "$PASSWD_FILE"
chown root:root "$PASSWD_FILE" 2>/dev/null || true

if [ -s "$PASSWD_FILE" ]; then
    echo "Passwd file has $(wc -l < "$PASSWD_FILE" | tr -d ' ') account(s)"
else
    echo "No mail accounts yet — create them in the admin panel"
fi

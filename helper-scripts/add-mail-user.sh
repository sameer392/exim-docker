#!/bin/bash
# Add a mail user with mailbox on any configured domain.
# Usage: ./helper-scripts/add-mail-user.sh <email@domain.com> <password>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <email@domain.com> <password>"
    echo "Example: $0 sales@hemochrom.com SecurePass123!"
    exit 1
fi

EMAIL_ADDRESS="$1"
NEW_PASSWORD="$2"
DOMAIN=$(echo "$EMAIL_ADDRESS" | cut -d'@' -f2)
USER=$(echo "$EMAIL_ADDRESS" | cut -d'@' -f1)

if [ -z "$DOMAIN" ] || [ -z "$USER" ]; then
    echo "Error: Invalid email address format"
    exit 1
fi

DOMAINS_FILE="./data/exim/domains"
if [ -f "$DOMAINS_FILE" ] && ! grep -qxF "$DOMAIN" "$DOMAINS_FILE" 2>/dev/null; then
    echo "Warning: $DOMAIN is not in $DOMAINS_FILE"
    echo "Add it first: ./helper-scripts/add-domain.sh $DOMAIN"
fi

echo "Adding mail user: $EMAIL_ADDRESS"

# Reuse password change logic (updates passwd + maildir)
"$(dirname "$0")/change-password.sh" "$EMAIL_ADDRESS" "$NEW_PASSWORD"

# Ensure maildir exists with correct ownership (mail:mail = 8:8)
MAILDIR="./data/mail/${DOMAIN}/${USER}"
mkdir -p "$MAILDIR"
chown -R 8:8 "$MAILDIR" 2>/dev/null || chown -R mail:mail "$MAILDIR" 2>/dev/null || true
chmod 700 "$MAILDIR"

echo ""
echo "User $EMAIL_ADDRESS is ready for SMTP, IMAP, and Roundcube."

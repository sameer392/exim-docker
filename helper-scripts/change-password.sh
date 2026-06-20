#!/bin/bash
# Script to change email account password
# Usage: ./change-password.sh <email@domain.com> <new_password>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <email@domain.com> <new_password>"
    echo "Example: $0 info@hemochrom.com MyNewPassword123!"
    exit 1
fi

EMAIL_ADDRESS="$1"
NEW_PASSWORD="$2"

# Extract domain from email
DOMAIN=$(echo "$EMAIL_ADDRESS" | cut -d'@' -f2)
USER=$(echo "$EMAIL_ADDRESS" | cut -d'@' -f1)

if [ -z "$DOMAIN" ] || [ -z "$USER" ]; then
    echo "Error: Invalid email address format"
    exit 1
fi

echo "Changing password for: $EMAIL_ADDRESS"
echo "Domain: $DOMAIN"
echo "User: $USER"
echo ""

# Generate password hash
echo "Generating password hash..."
PASS_HASH=$(docker exec exim-mailserver openssl passwd -1 "$NEW_PASSWORD" 2>&1)

if [ -z "$PASS_HASH" ] || [[ "$PASS_HASH" == *"error"* ]]; then
    echo "Error: Failed to generate password hash"
    exit 1
fi

echo "Password hash generated successfully"
echo ""

# Update Exim password file (both in container and mounted volume if it exists)
echo "Updating Exim password file..."
docker exec exim-mailserver sh -c "
    # Check if user exists, update or append
    if grep -q '^${EMAIL_ADDRESS}:' /etc/exim4/passwd 2>/dev/null; then
        # Update existing entry
        sed -i 's|^${EMAIL_ADDRESS}:.*|${EMAIL_ADDRESS}:${PASS_HASH}|' /etc/exim4/passwd
        echo 'Updated existing password for ${EMAIL_ADDRESS}'
    else
        # Add new entry
        echo '${EMAIL_ADDRESS}:${PASS_HASH}' >> /etc/exim4/passwd
        echo 'Added new password entry for ${EMAIL_ADDRESS}'
    fi
    chmod 640 /etc/exim4/passwd
    chown root:Debian-exim /etc/exim4/passwd
"

# Also update the mounted password file if it exists
if [ -f ./data/passwd ]; then
    echo "Updating mounted password file (./data/passwd)..."
    if grep -q "^${EMAIL_ADDRESS}:" ./data/passwd 2>/dev/null; then
        sed -i "s|^${EMAIL_ADDRESS}:.*|${EMAIL_ADDRESS}:${PASS_HASH}|" ./data/passwd
        echo "Updated mounted password file"
    else
        echo "${EMAIL_ADDRESS}:${PASS_HASH}" >> ./data/passwd
        echo "Added to mounted password file"
    fi
    chmod 640 ./data/passwd
fi

# Create maildir for new users
MAILDIR="./data/mail/${DOMAIN}/${USER}"
if [ ! -d "$MAILDIR" ]; then
    echo "Creating maildir: $MAILDIR"
    mkdir -p "$MAILDIR"
    chown -R 8:8 "$MAILDIR" 2>/dev/null || chown -R mail:mail "$MAILDIR" 2>/dev/null || true
    chmod 700 "$MAILDIR"
fi

# Update docker-compose bootstrap password for default user only
echo ""
echo "Updating docker-compose.yml bootstrap password (default user only)..."
if grep -q "EMAIL_PASS=" docker-compose.yml; then
    if [ "$USER" = "info" ] && grep -qxF "$DOMAIN" ./data/exim/domains 2>/dev/null; then
        sed -i "s|EMAIL_PASS=.*|EMAIL_PASS=${NEW_PASSWORD}|" docker-compose.yml
        echo "Updated EMAIL_PASS in docker-compose.yml"
    fi
else
    echo "Note: EMAIL_PASS not found in docker-compose.yml"
fi

# Restart services
echo ""
echo "Restarting mail services..."
docker compose restart mailserver dovecot

echo ""
echo "========================================="
echo "✅ Password changed successfully!"
echo ""
echo "Email: $EMAIL_ADDRESS"
echo "New password: $NEW_PASSWORD"
echo ""
echo "The password is now active for:"
echo "- SMTP authentication (Exim)"
echo "- IMAP authentication (Dovecot — shared passwd file)"
echo "- Roundcube webmail login"
echo ""
echo "You may need to update your email client"
echo "with the new password."
echo "========================================="

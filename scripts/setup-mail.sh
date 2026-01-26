#!/bin/bash
set -e

DOMAIN=${DOMAIN:-hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

# CRITICAL: Check if password file exists and has content FIRST
# If it exists and has the user, exit immediately - do not modify
if [ -f /etc/exim4/passwd ] && [ -s /etc/exim4/passwd ]; then
    if grep -q "^${EMAIL_USER}@${DOMAIN}:" /etc/exim4/passwd; then
        echo "Password file exists with entry for ${EMAIL_USER}@${DOMAIN}, preserving existing password"
        exit 0
    fi
fi

# Create password hash for Exim using openssl (MD5 crypt format)
# Exim's crypteq function supports MD5, SHA256, SHA512, and traditional crypt
PASS_HASH=$(openssl passwd -1 "$EMAIL_PASS" 2>&1)

# Verify hash was generated
if [ -z "$PASS_HASH" ] || [[ "$PASS_HASH" == *"error"* ]]; then
    echo "Error: Failed to generate password hash"
    exit 1
fi

# Create or update Exim password file (format: user@domain:hash)
# IMPORTANT: Only create if file doesn't exist - NEVER overwrite existing passwords
# This prevents overwriting manually changed passwords on container restart
if [ ! -f /etc/exim4/passwd ]; then
    # Create new file only if it doesn't exist
    echo "${EMAIL_USER}@${DOMAIN}:${PASS_HASH}" > /etc/exim4/passwd
    chmod 640 /etc/exim4/passwd
    chown root:Debian-exim /etc/exim4/passwd
    echo "Created password file for ${EMAIL_USER}@${DOMAIN}"
elif [ "${FORCE_PASSWORD_UPDATE:-0}" = "1" ]; then
    # Only update if FORCE_PASSWORD_UPDATE=1 is explicitly set
    if grep -q "^${EMAIL_USER}@${DOMAIN}:" /etc/exim4/passwd; then
        # Update existing entry
        sed -i "s|^${EMAIL_USER}@${DOMAIN}:.*|${EMAIL_USER}@${DOMAIN}:${PASS_HASH}|" /etc/exim4/passwd
        echo "Updated password for ${EMAIL_USER}@${DOMAIN} (forced update)"
    else
        # Append new entry (user doesn't exist yet)
        echo "${EMAIL_USER}@${DOMAIN}:${PASS_HASH}" >> /etc/exim4/passwd
        echo "Added password entry for ${EMAIL_USER}@${DOMAIN}"
    fi
    chmod 640 /etc/exim4/passwd
    chown root:Debian-exim /etc/exim4/passwd
else
    # Password file exists - DO NOT UPDATE (preserve manually changed passwords)
    if grep -q "^${EMAIL_USER}@${DOMAIN}:" /etc/exim4/passwd; then
        echo "Password file exists with entry for ${EMAIL_USER}@${DOMAIN}, preserving existing password"
        # Exit immediately - do not modify existing password
        exit 0
    else
        # User doesn't exist, add them
        echo "${EMAIL_USER}@${DOMAIN}:${PASS_HASH}" >> /etc/exim4/passwd
        chmod 640 /etc/exim4/passwd
        chown root:Debian-exim /etc/exim4/passwd
        echo "Added new password entry for ${EMAIL_USER}@${DOMAIN}"
    fi
fi

# Verify file was created correctly
if [ ! -s /etc/exim4/passwd ]; then
    echo "Error: Password file is empty"
    exit 1
fi

# Create mail directory
mkdir -p /var/mail/vhosts/${DOMAIN}/${EMAIL_USER}
chown -R mail:mail /var/mail/vhosts/${DOMAIN}/${EMAIL_USER}
chmod 700 /var/mail/vhosts/${DOMAIN}/${EMAIL_USER}

echo "Mail user ${EMAIL_USER}@${DOMAIN} configured"

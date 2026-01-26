#!/bin/bash
set -e

DOMAIN=${DOMAIN:-hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

# Create password hash for Exim using openssl (MD5 crypt format)
# Exim's crypteq function supports MD5, SHA256, SHA512, and traditional crypt
PASS_HASH=$(openssl passwd -1 "$EMAIL_PASS" 2>&1)

# Verify hash was generated
if [ -z "$PASS_HASH" ] || [[ "$PASS_HASH" == *"error"* ]]; then
    echo "Error: Failed to generate password hash"
    exit 1
fi

# Create Exim password file (format: user@domain:hash)
echo "${EMAIL_USER}@${DOMAIN}:${PASS_HASH}" > /etc/exim4/passwd
chmod 640 /etc/exim4/passwd
chown root:Debian-exim /etc/exim4/passwd

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

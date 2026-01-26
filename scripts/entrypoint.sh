#!/bin/bash
set -e

DOMAIN=${DOMAIN:-hemochrom.com}
HOSTNAME=${HOSTNAME:-smtp0.hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

echo "Starting mail server setup for domain: $DOMAIN"

# Create mail directory structure
mkdir -p /var/mail/vhosts/${DOMAIN}/${EMAIL_USER}
chown -R mail:mail /var/mail/vhosts

# Setup mail user password (for Exim)
/scripts/setup-mail.sh

# Setup SQL authentication for Dovecot
/scripts/setup-sql-auth.sh

# Setup DKIM
/scripts/setup-dkim.sh

# Generate self-signed certificates if they don't exist
if [ ! -f /etc/exim4/exim.crt ]; then
    echo "Generating Exim SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/exim4/exim.key \
        -out /etc/exim4/exim.crt \
        -subj "/CN=${HOSTNAME}/O=Hemochrom/C=US"
    chmod 600 /etc/exim4/exim.key
    chmod 644 /etc/exim4/exim.crt
fi

if [ ! -f /etc/dovecot/dovecot.pem ]; then
    echo "Generating Dovecot SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/dovecot/dovecot.key \
        -out /etc/dovecot/dovecot.pem \
        -subj "/CN=${HOSTNAME}/O=Hemochrom/C=US"
    chmod 600 /etc/dovecot/dovecot.key
    chmod 644 /etc/dovecot/dovecot.pem
fi

# Update Exim configuration from template
update-exim4.conf

echo "Mail server is running!"
echo "Domain: $DOMAIN"
echo "Hostname: $HOSTNAME"
echo "Email: ${EMAIL_USER}@${DOMAIN}"

# Start supervisor to manage services
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

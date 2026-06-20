#!/bin/bash
set -e

DOMAIN=${DOMAIN:-hemochrom.com}
HOSTNAME=${HOSTNAME:-smtp0.hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

echo "Starting Exim mail server setup for domain: $DOMAIN"

# Seed dynamic config files (domains, hostname, qualify_domain)
/scripts/setup-exim-config.sh

# Create mail directory structure
mkdir -p /var/mail/vhosts/${DOMAIN}/${EMAIL_USER}
chown -R mail:mail /var/mail/vhosts

# Ensure log directory and files exist
mkdir -p /var/log/exim4
touch /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog
chown Debian-exim:adm /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog
chmod 640 /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog

# Setup mail user password (for Exim)
/scripts/setup-mail.sh || echo "Warning: setup-mail.sh failed, continuing..."

# Setup DKIM (generates random selector if not set)
/scripts/setup-dkim.sh

# Read the DKIM selector that was generated
DKIM_SELECTOR=$(cat /etc/exim4/dynamic/dkim_selector 2>/dev/null || echo "mail")

# Ensure OpenDKIM key directories exist for all configured domains
if [ -f /etc/exim4/dynamic/domains ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        domain="${line#"${line%%[![:space:]]*}"}"
        domain="${domain%"${domain##*[![:space:]]}"}"
        [ -z "$domain" ] && continue
        [[ "$domain" == \#* ]] && continue
        mkdir -p "/etc/opendkim/keys/${domain}"
        chown opendkim:opendkim "/etc/opendkim/keys/${domain}" 2>/dev/null || true
    done < /etc/exim4/dynamic/domains
fi

# Ensure OpenDKIM configuration files exist
chmod 644 /etc/opendkim/KeyTable /etc/opendkim/SigningTable /etc/opendkim/TrustedHosts

# Set ownership for OpenDKIM directories (but preserve key file permissions)
chown opendkim:opendkim /etc/opendkim
chown opendkim:opendkim /etc/opendkim/keys
chown opendkim:opendkim /etc/opendkim/keys/${DOMAIN}

# Set permissions for DKIM private keys so Exim can read them
if [ -f /etc/exim4/dynamic/domains ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        domain="${line#"${line%%[![:space:]]*}"}"
        domain="${domain%"${domain##*[![:space:]]}"}"
        [ -z "$domain" ] && continue
        [[ "$domain" == \#* ]] && continue
        if [ -f "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private" ]; then
            chmod 644 "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private"
            chown root:Debian-exim "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private"
            echo "DKIM key permissions set for ${domain} (selector: ${DKIM_SELECTOR})"
        else
            echo "Warning: DKIM private key missing for ${domain} — run setup-dkim.sh"
        fi
    done < /etc/exim4/dynamic/domains
fi

# Install Let's Encrypt or self-signed TLS certificate
/scripts/setup-ssl.sh

# Render Exim config with resolved hostname/domain values
/scripts/render-exim-config.sh

# Re-apply DKIM key permissions after render (volume-mounted keys)
if [ -f /etc/exim4/dynamic/domains ]; then
    DKIM_SELECTOR=$(cat /etc/exim4/dynamic/dkim_selector 2>/dev/null || echo "mail")
    while IFS= read -r line || [ -n "$line" ]; do
        domain="${line#"${line%%[![:space:]]*}"}"
        domain="${domain%"${domain##*[![:space:]]}"}"
        [ -z "$domain" ] && continue
        [[ "$domain" == \#* ]] && continue
        [ -f "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private" ] && \
            chmod 644 "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private" && \
            chown root:Debian-exim "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private"
    done < /etc/exim4/dynamic/domains
fi

echo "Exim mail server is running!"
echo "Domain: $DOMAIN"
echo "Hostname: $HOSTNAME"
echo "Email: ${EMAIL_USER}@${DOMAIN}"

# Start supervisor to manage Exim
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

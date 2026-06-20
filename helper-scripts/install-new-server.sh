#!/bin/bash
# Bootstrap exim-docker on a new server with custom domain/hostname.
#
# Usage:
#   ./helper-scripts/install-new-server.sh
#   ./helper-scripts/install-new-server.sh --domain example.com --hostname smtp0.example.com \
#       --email-user info --email-pass 'SecurePass123!' --admin-pass 'AdminPass123!'
#
# Prerequisites: Docker, git, ports 25/80/587/465/8080/8090 open, DNS A record for HOSTNAME.

set -e

cd "$(dirname "$0")/.."

DOMAIN=""
HOSTNAME=""
EMAIL_USER="info"
EMAIL_PASS=""
ADMIN_PASS=""
CERTBOT_EMAIL=""
SERVER_IP=""

usage() {
    sed -n '3,8p' "$0"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --domain) DOMAIN="$2"; shift 2 ;;
        --hostname) HOSTNAME="$2"; shift 2 ;;
        --email-user) EMAIL_USER="$2"; shift 2 ;;
        --email-pass) EMAIL_PASS="$2"; shift 2 ;;
        --admin-pass) ADMIN_PASS="$2"; shift 2 ;;
        --certbot-email) CERTBOT_EMAIL="$2"; shift 2 ;;
        --server-ip) SERVER_IP="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default="$3"
    local value=""
    if [ -n "$default" ]; then
        read -r -p "${prompt_text} [${default}]: " value
        value="${value:-$default}"
    else
        read -r -p "${prompt_text}: " value
    fi
    printf -v "$var_name" '%s' "$value"
}

if [ -z "$DOMAIN" ]; then
    prompt DOMAIN "Primary mail domain (e.g. example.com)" ""
fi
if [ -z "$HOSTNAME" ]; then
    prompt HOSTNAME "SMTP hostname (e.g. smtp0.example.com)" "smtp0.${DOMAIN}"
fi
if [ -z "$EMAIL_PASS" ]; then
    prompt EMAIL_PASS "Password for ${EMAIL_USER}@${DOMAIN}" ""
fi
if [ -z "$ADMIN_PASS" ]; then
    prompt ADMIN_PASS "Admin panel password (port 8090)" "ChangeAdminPass!"
fi
if [ -z "$CERTBOT_EMAIL" ]; then
    CERTBOT_EMAIL="${EMAIL_USER}@${DOMAIN}"
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || true)
    prompt SERVER_IP "Server public IP (for DNS checklist)" "$SERVER_IP"
fi

if [ -z "$DOMAIN" ] || [ -z "$HOSTNAME" ] || [ -z "$EMAIL_PASS" ]; then
    echo "Error: domain, hostname, and email password are required."
    exit 1
fi

if [ ${#EMAIL_PASS} -lt 8 ]; then
    echo "Error: email password must be at least 8 characters."
    exit 1
fi

echo ""
echo "=== Installing mail server ==="
echo "  Domain:     ${DOMAIN}"
echo "  Hostname:   ${HOSTNAME}"
echo "  First user: ${EMAIL_USER}@${DOMAIN}"
echo "  Server IP:  ${SERVER_IP}"
echo ""

# Write .env
cat > .env <<EOF
DOMAIN=${DOMAIN}
HOSTNAME=${HOSTNAME}
EMAIL_USER=${EMAIL_USER}
EMAIL_PASS=${EMAIL_PASS}
TZ=Asia/Kolkata
ADMIN_PASSWORD=${ADMIN_PASS}
ADMIN_SECRET=$(openssl rand -hex 16)
CERTBOT_EMAIL=${CERTBOT_EMAIL}
CERTBOT_DOMAIN=${HOSTNAME}
EOF
chmod 600 .env
echo "Created .env"

# Fresh data directory (do not copy from another server)
if [ -d data/passwd ] || [ -f data/passwd ]; then
    read -r -p "data/ already exists. Wipe and start fresh? [y/N]: " wipe
    if [[ "$wipe" =~ ^[Yy]$ ]]; then
        rm -rf data
        echo "Removed existing data/"
    else
        echo "Keeping existing data/ — hostname/domain in .env may not match stored config."
        echo "Edit data/exim/ manually or wipe data/ for a clean install."
    fi
fi

mkdir -p data/exim data/log data/mail data/ssl data/opendkim data/certbot/www data/letsencrypt

# Seed exim dynamic config for first boot
echo "$DOMAIN" > data/exim/domains
echo "$HOSTNAME" > data/exim/primary_hostname
echo "$DOMAIN" > data/exim/qualify_domain
chmod 644 data/exim/domains data/exim/primary_hostname data/exim/qualify_domain

echo "Building and starting services..."
docker compose up -d --build

echo "Waiting for mailserver..."
sleep 8

echo "Obtaining Let's Encrypt certificate for ${HOSTNAME}..."
CERTBOT_DOMAIN="${HOSTNAME}" CERTBOT_EMAIL="${CERTBOT_EMAIL}" ./helper-scripts/obtain-letsencrypt-cert.sh || {
    echo "Warning: Let's Encrypt failed. Ensure DNS A record for ${HOSTNAME} -> ${SERVER_IP}"
    echo "Retry later: CERTBOT_DOMAIN=${HOSTNAME} ./helper-scripts/obtain-letsencrypt-cert.sh"
}

SELECTOR=$(docker exec exim-mailserver cat /etc/exim4/dynamic/dkim_selector 2>/dev/null || echo "unknown")

echo ""
echo "============================================"
echo "  Installation complete"
echo "============================================"
echo ""
echo "Admin panel:  http://${SERVER_IP}:8090"
echo "Webmail:      http://${SERVER_IP}:8080"
echo "Login:        ${EMAIL_USER}@${DOMAIN}"
echo ""
echo "DNS records required (DNS only, not proxied):"
echo ""
echo "  1. A record"
echo "     Name:    $(echo "$HOSTNAME" | sed "s/.${DOMAIN}//")"
echo "     Value:   ${SERVER_IP}"
echo ""
echo "  2. MX record for ${DOMAIN}"
echo "     Priority 10 -> ${HOSTNAME}"
echo ""
echo "  3. SPF TXT for ${DOMAIN}"
echo "     v=spf1 mx a:${HOSTNAME} ~all"
echo ""
echo "  4. DKIM TXT"
echo "     Name: ${SELECTOR}._domainkey"
echo "     Value: run:"
echo "       docker exec exim-mailserver cat /etc/opendkim/keys/${DOMAIN}/${SELECTOR}.txt"
echo ""
echo "  5. DMARC TXT"
echo "     Name: _dmarc"
echo "     Value: v=DMARC1; p=none; rua=mailto:${EMAIL_USER}@${DOMAIN}"
echo ""
echo "Add more domains/users via admin panel or:"
echo "  ./helper-scripts/add-domain.sh otherdomain.com"
echo "  ./helper-scripts/add-mail-user.sh user@otherdomain.com 'password'"
echo ""

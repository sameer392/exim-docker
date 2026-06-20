#!/bin/bash
# Bootstrap exim-docker on a new server with custom hostname.
#
# Usage:
#   ./helper-scripts/install-new-server.sh
#   ./helper-scripts/install-new-server.sh --hostname smtp0.example.com \
#       --admin-pass 'AdminPass123!' --certbot-email admin@example.com
#
# Prerequisites: Docker, git, ports 25/80/587/465/8080/8090 open, DNS A record for HOSTNAME.
# Domains & mail accounts: create via admin panel after install (http://<server-ip>:8090).

set -e

cd "$(dirname "$0")/.."

HOSTNAME=""
ADMIN_PASS=""
CERTBOT_EMAIL=""
SERVER_IP=""

usage() {
    sed -n '3,10p' "$0"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --hostname) HOSTNAME="$2"; shift 2 ;;
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

if [ -z "$HOSTNAME" ]; then
    prompt HOSTNAME "SMTP hostname (e.g. smtp0.example.com)" ""
fi
if [ -z "$ADMIN_PASS" ]; then
    prompt ADMIN_PASS "Admin panel password (port 8090)" "ChangeAdminPass!"
fi
if [ -z "$CERTBOT_EMAIL" ]; then
    prompt CERTBOT_EMAIL "Let's Encrypt contact email" "postmaster@example.com"
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || true)
    prompt SERVER_IP "Server public IP (for DNS checklist)" "$SERVER_IP"
fi

if [ -z "$HOSTNAME" ]; then
    echo "Error: hostname is required."
    exit 1
fi

echo ""
echo "=== Installing mail server ==="
echo "  Hostname:  ${HOSTNAME}"
echo "  Server IP: ${SERVER_IP}"
echo "  Domains:   add via admin panel after install"
echo ""

# Write .env
cat > .env <<EOF
HOSTNAME=${HOSTNAME}
TZ=Asia/Kolkata
ADMIN_PASSWORD=${ADMIN_PASS}
ADMIN_SECRET=$(openssl rand -hex 16)
CERTBOT_EMAIL=${CERTBOT_EMAIL}
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
        echo "Keeping existing data/ — hostname in .env may not match stored config."
    fi
fi

mkdir -p data/exim data/log data/mail data/ssl data/opendkim data/certbot/www data/letsencrypt
touch data/passwd
chmod 644 data/passwd

# Seed hostname only; domains added via admin panel
echo "# Local mail domains — add via admin panel" > data/exim/domains
echo "$HOSTNAME" > data/exim/primary_hostname
chmod 644 data/exim/domains data/exim/primary_hostname

echo "Building and starting services..."
docker compose up -d --build

echo "Waiting for mailserver..."
sleep 8

echo "Obtaining Let's Encrypt certificate for ${HOSTNAME}..."
HOSTNAME="${HOSTNAME}" CERTBOT_EMAIL="${CERTBOT_EMAIL}" ./helper-scripts/obtain-letsencrypt-cert.sh || {
    echo "Warning: Let's Encrypt failed. Ensure DNS A record for ${HOSTNAME} -> ${SERVER_IP}"
    echo "Retry later: HOSTNAME=${HOSTNAME} ./helper-scripts/obtain-letsencrypt-cert.sh"
}

echo ""
echo "============================================"
echo "  Installation complete"
echo "============================================"
echo ""
echo "Admin panel:  http://${SERVER_IP}:8090"
echo "  1. Log in"
echo "  2. Domains → add your mail domain(s)"
echo "  3. Users → create mail accounts"
echo ""
echo "Webmail:      http://${SERVER_IP}"
echo ""
echo "DNS checklist (after adding domain in admin panel):"
echo ""
echo "  1. A record for ${HOSTNAME} → ${SERVER_IP}"
echo "  2. MX record for your domain → ${HOSTNAME}"
echo "  3. SPF TXT: v=spf1 mx a:${HOSTNAME} ~all"
echo "  4. DKIM TXT: shown in admin panel → Domains"
echo "  5. DMARC TXT: v=DMARC1; p=none; rua=mailto:postmaster@yourdomain.com"
echo ""

#!/bin/bash
# Obtain or renew a Let's Encrypt certificate for the mail server hostname.

set -e

cd "$(dirname "$0")/.."

# Prefer .env over the shell's HOSTNAME (bash always sets HOSTNAME to the OS name).
if [ -f .env ]; then
    ENV_HOSTNAME=$(grep -E '^(MAIL_HOSTNAME|HOSTNAME)=' .env | head -1 | cut -d= -f2- | tr -d "'\"" | tr -d '\r')
    # Prefer MAIL_HOSTNAME if present
    ENV_MAIL=$(grep -E '^MAIL_HOSTNAME=' .env | cut -d= -f2- | tr -d "'\"" | tr -d '\r')
    ENV_EMAIL=$(grep -E '^CERTBOT_EMAIL=' .env | cut -d= -f2- | tr -d "'\"" | tr -d '\r')
    [ -n "$ENV_MAIL" ] && HOSTNAME="$ENV_MAIL"
    [ -z "$ENV_MAIL" ] && [ -n "$ENV_HOSTNAME" ] && HOSTNAME="$ENV_HOSTNAME"
    [ -n "$ENV_EMAIL" ] && CERTBOT_EMAIL="$ENV_EMAIL"
fi

DOMAIN="${HOSTNAME:-smtp0.example.com}"
EMAIL="${CERTBOT_EMAIL:-admin@example.com}"

echo "Obtaining Let's Encrypt certificate for ${DOMAIN}"
echo "Email: ${EMAIL}"
echo ""

mkdir -p data/certbot/www data/letsencrypt data/ssl

echo "Starting ACME web server on port 80..."
docker compose up -d nginx-acme

echo "Requesting certificate from Let's Encrypt..."
docker compose run --rm --entrypoint certbot certbot certonly \
    --webroot \
    -w /var/www/certbot \
    -d "${DOMAIN}" \
    --email "${EMAIL}" \
    --agree-tos \
    --non-interactive

echo ""
echo "Installing certificate into mail services..."
docker compose up -d mailserver dovecot
docker exec exim-mailserver /scripts/setup-ssl.sh
docker compose restart mailserver dovecot

echo ""
echo "Certificate installed. Verify with:"
echo "  openssl s_client -connect ${DOMAIN}:587 -starttls smtp </dev/null 2>/dev/null | openssl x509 -noout -issuer -dates"

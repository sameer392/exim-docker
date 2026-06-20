#!/bin/bash
# Obtain or renew a Let's Encrypt certificate for the mail server hostname.

set -e

cd "$(dirname "$0")/.."

DOMAIN="${CERTBOT_DOMAIN:-smtp0.hemochrom.com}"
EMAIL="${CERTBOT_EMAIL:-info@hemochrom.com}"

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

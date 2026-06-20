#!/bin/bash
# Install TLS certificates for Exim (and shared Dovecot volume).
# Uses Let's Encrypt when available, otherwise generates a self-signed cert.

set -e

SSL_DIR="${SSL_DIR:-/etc/exim4/ssl}"
HOSTNAME="${HOSTNAME:-smtp0.hemochrom.com}"
LE_DIR="/etc/letsencrypt/live/${HOSTNAME}"

mkdir -p "$SSL_DIR"

install_self_signed() {
    echo "Generating self-signed certificate for ${HOSTNAME}..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${SSL_DIR}/privkey.pem" \
        -out "${SSL_DIR}/fullchain.pem" \
        -subj "/CN=${HOSTNAME}/O=Mail/C=US"
}

if [ -f "${LE_DIR}/fullchain.pem" ] && [ -f "${LE_DIR}/privkey.pem" ]; then
    echo "Using Let's Encrypt certificate for ${HOSTNAME}"
    rm -f "${SSL_DIR}/fullchain.pem" "${SSL_DIR}/privkey.pem" "${SSL_DIR}/exim.crt" "${SSL_DIR}/exim.key"
    cp -L "${LE_DIR}/fullchain.pem" "${SSL_DIR}/fullchain.pem"
    cp -L "${LE_DIR}/privkey.pem" "${SSL_DIR}/privkey.pem"
elif [ ! -f "${SSL_DIR}/fullchain.pem" ] || [ ! -f "${SSL_DIR}/privkey.pem" ]; then
    install_self_signed
else
    echo "Keeping existing certificate in ${SSL_DIR}"
fi

ln -sf "${SSL_DIR}/fullchain.pem" "${SSL_DIR}/exim.crt"
ln -sf "${SSL_DIR}/privkey.pem" "${SSL_DIR}/exim.key"

chmod 644 "${SSL_DIR}/fullchain.pem" "${SSL_DIR}/exim.crt" 2>/dev/null || true
chmod 640 "${SSL_DIR}/privkey.pem" "${SSL_DIR}/exim.key" 2>/dev/null || true
chown root:Debian-exim "${SSL_DIR}/privkey.pem" "${SSL_DIR}/exim.key" 2>/dev/null || true
chown root:root "${SSL_DIR}/fullchain.pem" "${SSL_DIR}/exim.crt" 2>/dev/null || true

echo "TLS certificate ready: ${SSL_DIR}/fullchain.pem"

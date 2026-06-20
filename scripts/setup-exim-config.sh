#!/bin/bash
# Seed runtime Exim config files from environment on first boot.
# Files live in /etc/exim4/dynamic (mounted from ./data/exim).

set -e

CONFIG_DIR=/etc/exim4/dynamic
DOMAIN=${DOMAIN:-hemochrom.com}
HOSTNAME=${HOSTNAME:-smtp0.hemochrom.com}

mkdir -p "$CONFIG_DIR"

# Domains list — one domain per line; comments start with #
if [ ! -s "$CONFIG_DIR/domains" ]; then
    echo "$DOMAIN" > "$CONFIG_DIR/domains"
    echo "Created domains file with $DOMAIN"
elif ! grep -qxF "$DOMAIN" "$CONFIG_DIR/domains" 2>/dev/null; then
    echo "$DOMAIN" >> "$CONFIG_DIR/domains"
    echo "Added bootstrap domain $DOMAIN to domains file"
fi

# SMTP primary hostname (PTR/MX hostname, e.g. smtp0.example.com)
if [ ! -s "$CONFIG_DIR/primary_hostname" ]; then
    echo "$HOSTNAME" > "$CONFIG_DIR/primary_hostname"
    echo "Created primary_hostname: $HOSTNAME"
fi

# Default domain for unqualified local addresses
if [ ! -s "$CONFIG_DIR/qualify_domain" ]; then
    echo "$DOMAIN" > "$CONFIG_DIR/qualify_domain"
    echo "Created qualify_domain: $DOMAIN"
fi

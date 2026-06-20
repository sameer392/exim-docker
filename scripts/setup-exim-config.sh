#!/bin/bash
# Seed runtime Exim config files from environment on first boot.
# Domains and qualify_domain are managed via the admin panel.

set -e

CONFIG_DIR=/etc/exim4/dynamic
HOSTNAME=${HOSTNAME:-smtp0.example.com}

mkdir -p "$CONFIG_DIR"

# Domains list — one domain per line; add via admin panel
if [ ! -f "$CONFIG_DIR/domains" ]; then
    echo "# Local mail domains — one per line (add via admin panel)" > "$CONFIG_DIR/domains"
    echo "Created empty domains file"
fi

# SMTP primary hostname (PTR/MX hostname, e.g. smtp0.example.com)
if [ ! -s "$CONFIG_DIR/primary_hostname" ]; then
    echo "$HOSTNAME" > "$CONFIG_DIR/primary_hostname"
    echo "Created primary_hostname: $HOSTNAME"
fi

# qualify_domain is set when the first domain is added via admin panel

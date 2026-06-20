#!/bin/bash
# Add a local mail domain to the dynamic domains file and generate DKIM keys.
# Usage: ./helper-scripts/add-domain.sh <domain.com>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <domain.com>"
    echo "Example: $0 anotherdomain.com"
    exit 1
fi

DOMAIN="$1"
DOMAINS_FILE="./data/exim/domains"

# Basic domain format check
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$ ]]; then
    echo "Error: Invalid domain format: $DOMAIN"
    exit 1
fi

mkdir -p ./data/exim

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "# Local mail domains — one per line" > "$DOMAINS_FILE"
fi

if grep -qxF "$DOMAIN" "$DOMAINS_FILE" 2>/dev/null; then
    echo "Domain already configured: $DOMAIN"
else
    echo "$DOMAIN" >> "$DOMAINS_FILE"
    echo "Added domain: $DOMAIN"
fi

# Generate DKIM keys for the new domain inside the container
if docker ps --format '{{.Names}}' | grep -q '^exim-mailserver$'; then
    echo "Generating DKIM keys..."
    docker exec exim-mailserver /scripts/setup-dkim.sh
    echo "Restarting mailserver..."
    docker compose restart mailserver
else
    echo "Container not running. Start with: docker compose up -d"
    echo "DKIM keys will be generated automatically on next start."
fi

echo ""
echo "Next steps for $DOMAIN:"
echo "  1. Add MX record pointing to your mail server"
echo "  2. Add SPF record: v=spf1 mx a:<your-smtp-host> ~all"
echo "  3. Add DKIM TXT record (see setup-dkim output above)"
echo "  4. Add mail users: ./helper-scripts/change-password.sh user@${DOMAIN} <password>"

#!/bin/bash
# Quick start script for Exim + Dovecot + Roundcube mail server

set -e

echo "=========================================="
echo "Exim + Dovecot + Roundcube Mail Server"
echo "Domain: hemochrom.com"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed (plugin or standalone)
if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "ERROR: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Determine which compose command to use
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Create data directories if they don't exist
mkdir -p data/mail data/spool data/log

# Build and start containers
echo "Building and starting containers..."
$COMPOSE_CMD up -d --build

echo ""
echo "Waiting for services to start..."
sleep 10

# Check container status
echo ""
echo "Container status:"
$COMPOSE_CMD ps

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - SMTP:     smtp0.hemochrom.com:25,587,465"
echo "  - IMAP:     smtp0.hemochrom.com:143,993"
echo "  - POP3:     smtp0.hemochrom.com:110,995"
echo "  - Webmail:  http://localhost:8080"
echo ""
echo "Default credentials:"
echo "  Email:    info@hemochrom.com"
echo "  Password: ChangeMe123!"
echo ""
echo "IMPORTANT: Change the default password!"
echo ""
echo "To view logs:"
echo "  $COMPOSE_CMD logs -f"
echo ""
echo "To get DKIM key for Cloudflare DNS:"
echo "  docker exec exim-dovecot-mailserver cat /etc/opendkim/keys/hemochrom.com/mail.txt"
echo ""
echo "See README.md for DNS configuration instructions (SPF, DKIM, MX records)."
echo ""

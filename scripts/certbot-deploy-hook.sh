#!/bin/sh
# Reload mail services after Let's Encrypt certificate renewal.

set -e

echo "Certificate renewed — reloading mail services..."

docker exec exim-mailserver /scripts/setup-ssl.sh
docker exec exim-mailserver pkill -HUP -f 'exim4 -bd' 2>/dev/null \
    || docker restart exim-mailserver

docker exec dovecot-mailserver doveadm reload 2>/dev/null \
    || docker restart dovecot-mailserver

echo "Mail services reloaded."

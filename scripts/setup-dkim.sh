#!/bin/bash

DOMAIN=${DOMAIN:-hemochrom.com}
HOSTNAME=${HOSTNAME:-smtp0.hemochrom.com}

# Generate random DKIM selector if not set or if selector file doesn't exist
if [ -z "$DKIM_SELECTOR" ] || [ ! -f /etc/exim4/dkim_selector ]; then
    if [ -z "$DKIM_SELECTOR" ]; then
        DKIM_SELECTOR=$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')
        echo "Generated random DKIM selector: $DKIM_SELECTOR"
    fi
    # Save selector to file for Exim to read
    echo "$DKIM_SELECTOR" > /etc/exim4/dkim_selector
else
    # Read existing selector from file
    DKIM_SELECTOR=$(cat /etc/exim4/dkim_selector)
    echo "Using existing DKIM selector: $DKIM_SELECTOR"
fi

# Generate DKIM keys if they don't exist
if [ ! -f /etc/opendkim/keys/${DOMAIN}/${DKIM_SELECTOR}.private ]; then
    echo "Generating DKIM keys for ${DOMAIN} with selector: ${DKIM_SELECTOR}..."
    mkdir -p /etc/opendkim/keys/${DOMAIN}
    
    opendkim-genkey -D /etc/opendkim/keys/${DOMAIN}/ -d ${DOMAIN} -s ${DKIM_SELECTOR}
    chown -R opendkim:opendkim /etc/opendkim/keys/${DOMAIN}
    # Set permissions so Exim can read the private key
    chmod 644 /etc/opendkim/keys/${DOMAIN}/${DKIM_SELECTOR}.private
    chown root:Debian-exim /etc/opendkim/keys/${DOMAIN}/${DKIM_SELECTOR}.private
    chmod 644 /etc/opendkim/keys/${DOMAIN}/${DKIM_SELECTOR}.txt
    
    # Update OpenDKIM tables with the correct selector
    sed -i "s/mail\._domainkey\.hemochrom\.com/${DKIM_SELECTOR}._domainkey.hemochrom.com/g" /etc/opendkim/KeyTable
    sed -i "s/:mail:/:${DKIM_SELECTOR}:/g" /etc/opendkim/KeyTable
    sed -i "s/mail\.private/${DKIM_SELECTOR}.private/g" /etc/opendkim/KeyTable
    sed -i "s/mail\._domainkey\.hemochrom\.com/${DKIM_SELECTOR}._domainkey.hemochrom.com/g" /etc/opendkim/SigningTable
    
    echo "DKIM keys generated!"
    echo ""
    echo "=== DKIM Public Key (add to Cloudflare DNS) ==="
    cat /etc/opendkim/keys/${DOMAIN}/${DKIM_SELECTOR}.txt
    echo ""
    echo "Add this TXT record to Cloudflare DNS:"
    echo "Name: ${DKIM_SELECTOR}._domainkey.${DOMAIN}"
    echo "Content: (from ${DKIM_SELECTOR}.txt above)"
fi

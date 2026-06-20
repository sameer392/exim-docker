#!/bin/bash
# Generate DKIM keys for every domain listed in /etc/exim4/dynamic/domains

CONFIG_DIR=/etc/exim4/dynamic
DOMAINS_FILE="$CONFIG_DIR/domains"

mkdir -p "$CONFIG_DIR"

# Generate or reuse DKIM selector
if [ ! -f "$CONFIG_DIR/dkim_selector" ]; then
    DKIM_SELECTOR=$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')
    echo "$DKIM_SELECTOR" > "$CONFIG_DIR/dkim_selector"
    echo "Generated random DKIM selector: $DKIM_SELECTOR"
else
    DKIM_SELECTOR=$(cat "$CONFIG_DIR/dkim_selector")
    echo "Using existing DKIM selector: $DKIM_SELECTOR"
fi

if [ ! -s "$DOMAINS_FILE" ] || ! grep -qvE '^[[:space:]]*(#|$)' "$DOMAINS_FILE" 2>/dev/null; then
    echo "No mail domains configured — add domains via admin panel"
    exit 0
fi

generate_dkim_for_domain() {
    local domain="$1"

    if [ -f "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private" ]; then
        echo "DKIM keys already exist for ${domain}"
        return 0
    fi

    echo "Generating DKIM keys for ${domain} with selector: ${DKIM_SELECTOR}..."
    mkdir -p "/etc/opendkim/keys/${domain}"

    opendkim-genkey -D "/etc/opendkim/keys/${domain}/" -d "${domain}" -s "${DKIM_SELECTOR}"
    chown -R opendkim:opendkim "/etc/opendkim/keys/${domain}"
    chmod 644 "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private"
    chown root:Debian-exim "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.private"
    chmod 644 "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.txt"

    echo ""
    echo "=== DKIM Public Key for ${domain} ==="
    cat "/etc/opendkim/keys/${domain}/${DKIM_SELECTOR}.txt"
    echo ""
    echo "DNS TXT record:"
    echo "  Name: ${DKIM_SELECTOR}._domainkey.${domain}"
    echo "  Content: (from ${DKIM_SELECTOR}.txt above)"
    echo ""
}

while IFS= read -r line || [ -n "$line" ]; do
    domain="${line#"${line%%[![:space:]]*}"}"
    domain="${domain%"${domain##*[![:space:]]}"}"

    [ -z "$domain" ] && continue
    [[ "$domain" == \#* ]] && continue

    generate_dkim_for_domain "$domain"
done < "$DOMAINS_FILE"

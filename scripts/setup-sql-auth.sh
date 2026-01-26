#!/bin/bash
# Setup SQL authentication database for Dovecot

set -e

DB_HOST=${DB_HOST:-db}
DB_ROOT_PASS=${DB_ROOT_PASS:-roundcube_root_pass}
DB_USER=${DB_USER:-roundcube}
DB_PASS=${DB_PASS:-roundcube_pass}
DOMAIN=${DOMAIN:-hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

echo "Setting up Dovecot SQL authentication..."

# Wait for database to be ready
until mysql -h${DB_HOST} -uroot -p${DB_ROOT_PASS} -e "SELECT 1" &>/dev/null; do
    echo "Waiting for database..."
    sleep 2
done

#!/bin/bash
# Setup SQL authentication database for Dovecot

set -e

DB_HOST=${DB_HOST:-db}
DB_ROOT_PASS=${DB_ROOT_PASS:-roundcube_root_pass}
DB_USER=${DB_USER:-roundcube}
DB_PASS=${DB_PASS:-roundcube_pass}
DOMAIN=${DOMAIN:-hemochrom.com}
EMAIL_USER=${EMAIL_USER:-info}
EMAIL_PASS=${EMAIL_PASS:-ChangeMe123!}

echo "Setting up Dovecot SQL authentication..."

# Wait for database to be ready (max 30 seconds)
for i in {1..30}; do
    if mysql -h${DB_HOST} -uroot -p${DB_ROOT_PASS} -e "SELECT 1" &>/dev/null; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "WARNING: Database not available, skipping SQL auth setup. Will use passwd-file instead."
        exit 0
    fi
    sleep 1
done

# Create database and table
mysql -h${DB_HOST} -uroot -p${DB_ROOT_PASS} <<EOF
CREATE DATABASE IF NOT EXISTS dovecot_auth;
USE dovecot_auth;

CREATE TABLE IF NOT EXISTS users (
    username VARCHAR(128) NOT NULL,
    domain VARCHAR(128) NOT NULL,
    password VARCHAR(255) NOT NULL,
    PRIMARY KEY (username, domain)
);

-- Insert or update user
INSERT INTO dovecot_auth.users (username, domain, password)
VALUES ('${EMAIL_USER}', '${DOMAIN}', '$(doveadm pw -s CRYPT -p "${EMAIL_PASS}")')
ON DUPLICATE KEY UPDATE password=VALUES(password);

-- Grant permissions
GRANT SELECT ON dovecot_auth.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "SQL authentication database configured!"

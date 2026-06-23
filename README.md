# Exim + Dovecot + Roundcube Docker Mail Server

A complete, production-ready Docker mail server setup with Exim4, Dovecot, and Roundcube webmail.

## 📦 Repository Information

- **GitHub Repository**: [sameer392/exim-docker](https://github.com/sameer392/exim-docker)
- **Clone Command**: 
  ```bash
  git clone https://github.com/sameer392/exim-docker.git
  cd exim-docker
  ```

## 📚 Documentation

Extended guides for production, scaling, ports, security, and webmail options:

**[docs/](docs/README.md)** — production roadmap, port reference, OX App Suite vs Roundcube, backups, security checklist

## 🚀 Features

- **Exim4** - SMTP server with DKIM signing (ports 25, 587, 465)
- **Dovecot** - IMAP/POP3 server (ports 143, 993, 110, 995)
- **Roundcube** - Webmail via HTTPS (port 443; see [docs/ports-and-services.md](docs/ports-and-services.md))
- **Mail Admin Panel** - Web UI for domains, users, rate limits, and logs (port 8090)
- **Let's Encrypt** - Automatic TLS for SMTP/IMAP via Certbot (port 80 for renewal)
- **Per-account rate limits** - 3 configurable tiers (10 min / 1 hour / 1 day)
- **DKIM Signing** - Automatic email authentication with random selector
- **TLS/SSL Support** - Secure connections on all ports
- **External SMTP Relay** - Support for authenticated relay from external services (WHMCS, apps, etc.)
- **Multi-server ready** - Each server configured via `.env` (hostname, domain, credentials)

## 📋 Configuration Overview

Each server is configured with a `.env` file (copy from `.env.example`):

| Variable | Description | Example |
|----------|-------------|---------|
| `HOSTNAME` | SMTP hostname (PTR/MX) and Let's Encrypt TLS cert | `smtp0.example.com` |
| `ADMIN_PASSWORD` | Mail admin panel login | `ChangeAdminPass!` |
| `CERTBOT_EMAIL` | Let's Encrypt contact email | `admin@example.com` |

Domains and mail accounts are **not** in `.env`. Add domains and users in the admin panel (`:8090`).

## 🏃 Quick Start

### Prerequisites

- Docker and Docker Compose installed
  - If Docker is not installed, use: `./helper-scripts/install-docker.sh` (for AlmaLinux/RHEL 9)
- Server with ports **25, 80, 587, 465, 8080, 8090** open (plus 143/993 for external IMAP)
- Domain DNS access (Cloudflare or any DNS provider)
- **DNS A record** for your SMTP hostname pointing to the server IP (before Let's Encrypt)

### Option A: Automated install (recommended for new servers)

```bash
git clone https://github.com/sameer392/exim-docker.git
cd exim-docker
./helper-scripts/install-new-server.sh
```

The script will prompt for domain, hostname, passwords, and server IP, then:

1. Create `.env` with your settings
2. Seed `data/exim/` with hostname and domain
3. Build and start all Docker services
4. Obtain a Let's Encrypt certificate
5. Print a DNS checklist for your domain

**Non-interactive example** (second server, different domain):

```bash
./helper-scripts/install-new-server.sh \
  --hostname smtp0.cubewebtech.com \
  --admin-pass 'YourAdminPass123!' \
  --certbot-email admin@cubewebtech.com \
  --server-ip 203.0.113.50
```

### Option B: Manual install

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sameer392/exim-docker.git
   cd exim-docker
   ```

2. **Create and edit `.env`:**
   ```bash
   cp .env.example .env
   nano .env
   ```

3. **Seed hostname** (first install only; domains via admin panel):
   ```bash
   mkdir -p data/exim data/log data/mail data/ssl data/opendkim data/certbot/www data/letsencrypt
   echo "# Add domains via admin panel" > data/exim/domains
   echo "smtp0.example.com" > data/exim/primary_hostname
   touch data/passwd && chmod 644 data/passwd data/exim/domains data/exim/primary_hostname
   ```

4. **Build and start all services:**
   ```bash
   docker compose up -d --build
   ```

5. **Obtain Let's Encrypt certificate** (after DNS A record is live):
   ```bash
   HOSTNAME=smtp0.example.com CERTBOT_EMAIL=info@example.com \
     ./helper-scripts/obtain-letsencrypt-cert.sh
   ```

6. **Check service status:**
   ```bash
   docker compose ps
   docker compose logs -f
   ```

7. **Access services:**
   - **Admin panel**: `http://your-server-ip:8090` — log in, then create domains and mail accounts
   - **Roundcube webmail**: `http://your-server-ip:8080` — use accounts created in the admin panel

## 🖥️ Installing on Additional Servers

Each physical or virtual server is a **separate, independent** mail installation. Use the same Git repo, but **never copy the `data/` folder** from another server.

### Per-server checklist

| Step | Action |
|------|--------|
| 1 | New VPS with Docker installed |
| 2 | Clone repo: `git clone https://github.com/sameer392/exim-docker.git` |
| 3 | Run `./helper-scripts/install-new-server.sh` **or** create a unique `.env` |
| 4 | Use a **fresh** `data/` directory (installer creates this automatically) |
| 5 | Point DNS A record: `smtp0.yourdomain.com` → new server IP |
| 6 | Add MX, SPF, DKIM, DMARC for each domain on that server |
| 7 | Configure apps (WHMCS, etc.) with the **new** hostname and credentials |

### Two-server example

| | Server 1 | Server 2 |
|---|---|---|
| IP | `155.138.231.235` | `203.0.113.50` |
| Hostname | `smtp0.hemochrom.com` | `smtp0.cubewebtech.com` |
| Domains | `hemochrom.com`, `cubehostindia.com` | `cubewebtech.com` |
| Admin panel | `http://155.138.231.235:8090` | `http://203.0.113.50:8090` |
| Webmail | `http://155.138.231.235:8080` | `http://203.0.113.50:8080` |

### Do NOT copy between servers

| Path | Reason |
|------|--------|
| `data/opendkim/` | DKIM private keys are unique per server |
| `data/letsencrypt/` | TLS certs are tied to hostname and server |
| `data/passwd` | Mailbox passwords |
| `data/exim/dkim_selector` | Random selector per installation |
| `data/ssl/` | Active TLS certificate copies |

**Safe to copy:** the Git repository, `docker-compose.yml`, scripts, and templates. Configure each server with its own `.env`.

### Adding domains and users on a new server

**Via admin panel** (`http://server-ip:8090`):

- **Domains** — add domains, view DKIM DNS records
- **Users** — create mailboxes, assign rate limit levels
- **Rate Limits** — edit 3 tiers (per 10 min / 1 hour / 1 day)
- **Logs** — view live Exim logs

**Via CLI:**

```bash
./helper-scripts/add-domain.sh anotherdomain.com
./helper-scripts/add-mail-user.sh noreply@anotherdomain.com 'Password123!'
./helper-scripts/change-password.sh user@domain.com 'NewPassword123!'
```

### WHMCS / external app SMTP settings

| Setting | Value |
|---------|-------|
| SMTP Host | `smtp0.example.com` (your `HOSTNAME`) |
| SMTP Port | `587` |
| Encryption | **TLS** (STARTTLS) — not SSL on port 587 |
| Authentication | Required (LOGIN or PLAIN) |
| Username | Full email, e.g. `noreply@example.com` |
| Password | Mailbox password from admin panel |

Alternative: port **465** with encryption **SSL**.

## ⏱️ Rate Limits

Per-account outbound sending limits are enforced at SMTP time (each recipient counts as 1).

Three tiers are configurable in the admin panel (**Rate Limits**):

| Level | Default limits |
|-------|----------------|
| Level 1 — Low | 20 / 10 min · 80 / hour · 400 / day |
| Level 2 — Medium | 50 / 10 min · 200 / hour · 1000 / day |
| Level 3 — High | 150 / 10 min · 750 / hour · 5000 / day |

Assign a level per user under **Users**. When a limit is exceeded, the client receives `Rate limit exceeded` and the message is rejected (not queued).

## 🌐 DNS Configuration in Cloudflare

### 1. A Record for SMTP Server
- **Type**: A
- **Name**: smtp0
- **Content**: Your server's public IP address
- **Proxy**: DNS only (grey cloud) ⚠️ **Important for mail**

### 2. MX Record
- **Type**: MX
- **Name**: @ (or example.com)
- **Priority**: 10
- **Target**: smtp0.example.com
- **Proxy**: DNS only (grey cloud)

### 3. SPF Record
- **Type**: TXT
- **Name**: @ (or example.com)
- **Content**: `v=spf1 mx a:smtp0.example.com ~all`
- **Proxy**: DNS only (grey cloud)

### 4. DKIM Record (Random Selector)

The DKIM selector is randomly generated for security. To get the current selector and public key:

```bash
docker exec exim-mailserver sh -c 'SELECTOR=$(cat /etc/exim4/dynamic/dkim_selector) && echo "DKIM Selector: $SELECTOR" && echo "DNS Record Name: $SELECTOR._domainkey" && echo "" && cat /etc/opendkim/keys/example.com/$SELECTOR.txt'
```

Or check the selector file:
```bash
docker exec exim-mailserver cat /etc/exim4/dynamic/dkim_selector
```

Then add the TXT record in Cloudflare:
- **Type**: TXT
- **Name**: `<SELECTOR>._domainkey` (e.g., `8F5A8E47615B7165._domainkey`)
- **Content**: Copy the full DKIM record from the command above (starts with `v=DKIM1;`)
- **Proxy**: DNS only (grey cloud)

**Note**: The selector is randomly generated on first setup and stored in `data/exim/dkim_selector`. It persists across container restarts unless you delete `data/opendkim/`.

### 5. DMARC Record (Recommended)
- **Type**: TXT
- **Name**: _dmarc
- **Content**: `v=DMARC1; p=none; rua=mailto:info@example.com; ruf=mailto:info@example.com; sp=none; aspf=r;`
- **Proxy**: DNS only (grey cloud)

**Policy Options:**
- `p=none` - Monitor only (start here)
- `p=quarantine` - Mark failing emails as spam
- `p=reject` - Reject failing emails (use after testing)

## 🔌 Port Configuration

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 25 | SMTP | STARTTLS | Mail Transfer Agent |
| 80 | nginx-acme | HTTP | Let's Encrypt ACME challenges |
| 587 | SMTP | STARTTLS | Submission (authenticated) |
| 465 | SMTPS | Implicit TLS | Secure SMTP |
| 143 | IMAP | STARTTLS | Mail retrieval |
| 993 | IMAPS | Implicit TLS | Secure IMAP |
| 110 | POP3 | STARTTLS | Mail retrieval |
| 995 | POP3S | Implicit TLS | Secure POP3 |
| 8080 | Roundcube | HTTP | Webmail interface |
| 8090 | Mail Admin | HTTP | Domains, users, rate limits, logs |

## 📧 Email Client Configuration

### SMTP Settings (Outgoing)
- **Server**: smtp0.example.com (or your server IP)
- **Port**: 
  - 587 (STARTTLS) - Recommended
  - 465 (SSL/TLS) - Alternative
- **Security**: STARTTLS or SSL/TLS
- **Authentication**: Required
- **Username**: info@example.com
- **Password**: (your password)

### IMAP Settings (Incoming)
- **Server**: smtp0.example.com (or your server IP)
- **Port**: 
  - 993 (SSL/TLS) - Recommended
  - 143 (STARTTLS) - Alternative
- **Security**: SSL/TLS or STARTTLS
- **Authentication**: Required
- **Username**: info@example.com
- **Password**: (your password)

## 🔐 Changing Email Account Password

### Method 1: Using Helper Script (Easiest) ⭐

Use the provided script to change any email account password:

```bash
./helper-scripts/change-password.sh <email@domain.com> <new_password>
```

**Example:**
```bash
./helper-scripts/change-password.sh info@example.com MyNewSecurePassword123!
```

This script will:
- Generate the password hash
- Update `data/passwd`
- Create the maildir if needed
- Restart mail services automatically

**All accounts** (including the first) should be created via the admin panel or helper scripts — not via `.env`.

### Method 2: Manual Update (Advanced)

1. **Generate password hash:**
   ```bash
   docker exec exim-mailserver openssl passwd -1 "YourNewPassword"
   ```
   Copy the generated hash (starts with `$1$`).

2. **Update password file:**
   ```bash
   # For existing user (replace the hash)
   docker exec exim-mailserver sh -c "sed -i 's|^info@example.com:.*|info@example.com:NEW_HASH|' /etc/exim4/passwd && chmod 640 /etc/exim4/passwd && chown root:Debian-exim /etc/exim4/passwd"
   
   # Or for new user (add new entry)
   docker exec exim-mailserver sh -c "echo 'user@example.com:NEW_HASH' >> /etc/exim4/passwd && chmod 640 /etc/exim4/passwd && chown root:Debian-exim /etc/exim4/passwd"
   ```

3. **Restart containers:**
   ```bash
   docker compose restart mailserver dovecot
   ```

### Method 3: Using Roundcube Webmail (If Enabled)
1. Login to Roundcube webmail
2. Go to Settings → Password
3. Enter old password and new password
4. Save changes

**Note:** This requires Roundcube password plugin to be configured.

## 👥 Adding More Email Accounts

### Via admin panel (recommended)

1. Open `http://your-server-ip:8090`
2. Go to **Domains** — add the domain if needed
3. Go to **Users** — create account and assign a rate limit level

### Via helper script

```bash
./helper-scripts/add-domain.sh anotherdomain.com
./helper-scripts/add-mail-user.sh sales@anotherdomain.com 'SecurePass123!'
```

### Via CLI inside container (advanced)

```bash
docker exec exim-mailserver bash
NEW_USER="newuser"
NEW_PASS="password123"
PASS_HASH=$(openssl passwd -1 "$NEW_PASS")
echo "${NEW_USER}@example.com:${PASS_HASH}" >> /etc/exim4/passwd
mkdir -p /var/mail/vhosts/example.com/${NEW_USER}
chown -R mail:mail /var/mail/vhosts/example.com/${NEW_USER}
chmod 700 /var/mail/vhosts/example.com/${NEW_USER}
```

## 🔄 External SMTP Relay Support

The server is configured to allow relay from:
- Authenticated users (PLAIN/LOGIN authentication)
- Senders from your domain who are in the password file

This allows external SMTP services (like smtp24x7.com) to relay emails through your server.

**Configuration:**
- External services can authenticate and relay
- Sender address must be from your domain
- Sender must exist in `/etc/exim4/passwd` file

## 🛠️ Troubleshooting

### Check Service Status

**Quick status check:**
```bash
./helper-scripts/check-exim-status.sh
```

**Manual checks:**
```bash
docker compose ps
docker compose logs mailserver --tail 50
docker compose logs dovecot --tail 50
docker compose logs roundcube --tail 50
```

### View Exim Logs
```bash
# Real-time logs
docker exec exim-mailserver tail -f /var/log/exim4/mainlog

# Recent errors
docker exec exim-mailserver tail -50 /var/log/exim4/mainlog | grep -i error

# Check DKIM signing
docker exec exim-mailserver tail -50 /var/log/exim4/mainlog | grep -i dkim
```

### Test SMTP Connection
```bash
# Test port 25
telnet localhost 25

# Test port 587
telnet localhost 587

# Test with openssl (port 465)
openssl s_client -connect localhost:465 -starttls smtp
```

### Test IMAP Connection
```bash
# Test port 143
telnet localhost 143

# Test with openssl (port 993)
openssl s_client -connect localhost:993
```

### Get Current DKIM Selector and Public Key
```bash
docker exec exim-mailserver sh -c 'SELECTOR=$(cat /etc/exim4/dynamic/dkim_selector) && echo "Selector: $SELECTOR" && echo "DNS Name: $SELECTOR._domainkey" && cat /etc/opendkim/keys/example.com/$SELECTOR.txt'
```

### Check DKIM Key Permissions
```bash
docker exec exim-mailserver ls -la /etc/opendkim/keys/example.com/
```

### Verify Configuration
```bash
# Test Exim configuration
docker exec exim-mailserver exim4 -bV

# Check if Exim is running
docker exec exim-mailserver ps aux | grep exim4
```

### Common Issues

#### "relay not permitted" Error
- Ensure sender is authenticated or sender address is in `/etc/exim4/passwd`
- Check ACL configuration in `exim/exim4.conf`

#### "DKIM signature not valid"
- Verify DKIM DNS record matches the current selector
- Check that DNS record is properly formatted (no line breaks in `p=` value)
- Wait 5-10 minutes after DNS changes for propagation

#### "Rate limit exceeded"
- Per-account sending limits are enforced (10 min / 1 hour / 1 day)
- Adjust tiers in admin panel → **Rate Limits**, or assign a higher level per user → **Users**
- Each `RCPT TO` (recipient) counts as one message toward the limit

#### "TLS connection was non-properly terminated"
- This is often harmless - Gmail may close connections abruptly after accepting email
- Check if emails are actually being delivered (look for "250 2.0.0 OK" in logs)

#### Port 465 Syntax Errors
- Port 465 is configured for implicit TLS (SMTPS)
- Ensure clients connect with SSL/TLS from the start, not plain SMTP

## 📁 Data Persistence

Data is stored in mounted volumes under `./data/`:

| Path | Contents |
|------|----------|
| `data/mail` | Email messages (Maildir format) |
| `data/spool` | Exim spool directory |
| `data/log` | Exim mainlog, rejectlog, paniclog |
| `data/db` | Roundcube MariaDB database |
| `data/exim` | Domains, hostname, DKIM selector, rate limits |
| `data/opendkim` | DKIM private keys (per domain) |
| `data/ssl` | Active TLS certificate for Exim/Dovecot |
| `data/letsencrypt` | Let's Encrypt certificates |
| `data/passwd` | Mailbox credentials (shared by Exim and Dovecot) |

### Fresh install on a new server

Docker creates empty `data/` subdirectories on first run. For a clean install:

```bash
# Do not copy data/ from another server
./helper-scripts/install-new-server.sh
```

Or manually seed `data/exim/` before `docker compose up` (see Option B in Quick Start).

The `data/` folder is in `.gitignore` (runtime data, secrets, large files). **Back up `data/`** before major updates or server migration.

## 🔒 Security Notes

1. **Change default passwords** immediately after setup
2. **Use strong passwords** (minimum 12 characters, mixed case, numbers, symbols)
3. **Keep Docker images updated** regularly
4. **Configure firewall** to only allow necessary ports from trusted sources
5. **Monitor logs** for suspicious activity
6. **Use Let's Encrypt TLS** (included; renews automatically via Certbot)
7. **Enable fail2ban** or similar for brute-force protection
8. **Regular backups** of `data/` (mail, passwd, opendkim, letsencrypt)

## 🛑 Stopping the Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (⚠️ deletes all mail data)
docker compose down -v
```

## 📝 Configuration Files

Key configuration files:
- `.env` / `.env.example` - Per-server domain, hostname, passwords (not committed to Git)
- `docker-compose.yml` - Docker services orchestration
- `exim/exim4.conf` - Exim configuration template (rendered at startup)
- `data/exim/` - Runtime hostname, domains, DKIM paths, rate limits
- `roundcube/config.inc.php` - Roundcube configuration
- `mailpanel/` - Admin panel (FastAPI) source
- `scripts/entrypoint-exim.sh` - Exim startup script
- `scripts/setup-ssl.sh` - Let's Encrypt / self-signed TLS setup
- `scripts/render-exim-config.sh` - Renders Exim config from dynamic files
- `helper-scripts/install-new-server.sh` - Automated new-server installer
- `helper-scripts/obtain-letsencrypt-cert.sh` - Manual SSL certificate obtain

## 🛠️ Helper Scripts

Helper scripts are located in `helper-scripts/`:

- **`install-new-server.sh`** - Automated install on a new server (creates `.env`, starts services, obtains SSL)
  ```bash
  ./helper-scripts/install-new-server.sh
  # Or with arguments:
  ./helper-scripts/install-new-server.sh --hostname smtp0.example.com \
    --admin-pass 'AdminPass!' --certbot-email admin@example.com
  ```

- **`obtain-letsencrypt-cert.sh`** - Obtain or refresh Let's Encrypt certificate
  ```bash
  HOSTNAME=smtp0.example.com CERTBOT_EMAIL=info@example.com \
    ./helper-scripts/obtain-letsencrypt-cert.sh
  ```

- **`add-domain.sh`** - Add a mail domain and generate DKIM keys
  ```bash
  ./helper-scripts/add-domain.sh anotherdomain.com
  ```

- **`add-mail-user.sh`** - Create a mailbox on any configured domain
  ```bash
  ./helper-scripts/add-mail-user.sh user@domain.com 'Password123!'
  ```

- **`install-docker.sh`** - Install Docker and Docker Compose on AlmaLinux/RHEL 9
  ```bash
  ./helper-scripts/install-docker.sh
  ```

- **`change-password.sh`** - Change email account password
  ```bash
  ./helper-scripts/change-password.sh <email@domain.com> <new_password>
  ```

- **`check-exim-status.sh`** - Check Exim mail server status
  ```bash
  ./helper-scripts/check-exim-status.sh
  ```

## 🔄 Updating

1. **Pull latest changes:**
   ```bash
   git pull origin main
   ```

2. **Rebuild containers:**
   ```bash
   docker compose down
   docker compose up -d --build
   ```

3. **Check logs for issues:**
   ```bash
   docker compose logs -f
   ```

## 📚 Additional Resources

- [Exim Documentation](https://www.exim.org/docs.html)
- [Dovecot Documentation](https://doc.dovecot.org/)
- [Roundcube Documentation](https://github.com/roundcube/roundcubemail/wiki)
- [DKIM Guide](https://www.dkim.org/)
- [SPF Record Syntax](https://www.openspf.org/SPF_Record_Syntax)
- [DMARC Guide](https://dmarc.org/wiki/FAQ)

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This setup is provided as-is for configuring a mail server with Docker.

## ⚠️ Important Notes

- **Default passwords must be changed** before production use
- **DNS records must be configured** for proper email delivery
- **Firewall rules** should be configured to protect the server
- **Regular backups** are essential for mail data
- **Monitor logs** regularly for security and performance issues

## 🆘 Support

For issues and questions:
- Open an issue on [GitHub](https://github.com/sameer392/exim-docker/issues)
- Check the troubleshooting section above
- Review Exim, Dovecot, and Roundcube documentation

---

**Repository**: [sameer392/exim-docker](https://github.com/sameer392/exim-docker)  
**Last Updated**: June 2026

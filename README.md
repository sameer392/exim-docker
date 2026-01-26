# Exim + Dovecot + Roundcube Docker Mail Server

A complete, production-ready Docker mail server setup with Exim4, Dovecot, and Roundcube webmail.

## 📦 Repository Information

- **GitHub Repository**: [sameer392/exim-docker](https://github.com/sameer392/exim-docker)
- **Clone Command**: 
  ```bash
  git clone https://github.com/sameer392/exim-docker.git
  cd exim-docker
  ```

## 🚀 Features

- **Exim4** - SMTP server with DKIM signing (ports 25, 587, 465)
- **Dovecot** - IMAP/POP3 server (ports 143, 993, 110, 995)
- **Roundcube** - Modern webmail interface (port 8080)
- **DKIM Signing** - Automatic email authentication with random selector
- **TLS/SSL Support** - Secure connections on all ports
- **External SMTP Relay** - Support for authenticated relay from external services

## 📋 Domain Configuration

- **Domain**: example.com (replace with your domain)
- **Hostname**: smtp0.example.com (replace with your hostname)
- **Default Email**: info@example.com (replace with your email)
- **Default Password**: ChangeMe123! (⚠️ **CHANGE THIS IMMEDIATELY!**)

## 🏃 Quick Start

### Prerequisites

- Docker and Docker Compose installed
  - If Docker is not installed, use: `./helper-scripts/install-docker.sh` (for AlmaLinux/RHEL 9)
- Server with ports 25, 587, 465, 143, 993, 110, 995, 8080 open
- Domain DNS access (Cloudflare recommended)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sameer392/exim-docker.git
   cd exim-docker
   ```

2. **Build and start all services:**
   ```bash
   docker compose up -d --build
   ```

3. **Check service status:**
   ```bash
   docker compose ps
   docker compose logs -f
   ```

4. **Access Roundcube webmail:**
   - Open browser: `http://localhost:8080` (or `http://your-server-ip:8080`)
   - Login with: `info@example.com`
   - Password: `ChangeMe123!` (change this immediately!)

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
docker exec exim-mailserver sh -c "DKIM_SELECTOR=\$(cat /etc/exim4/dkim_selector) && echo \"DKIM Selector: \$DKIM_SELECTOR\" && echo \"DNS Record Name: \$DKIM_SELECTOR._domainkey\" && echo \"\" && cat /etc/opendkim/keys/example.com/\$DKIM_SELECTOR.txt"
```

Or check the selector file:
```bash
docker exec exim-mailserver cat /etc/exim4/dkim_selector
```

Then add the TXT record in Cloudflare:
- **Type**: TXT
- **Name**: `<SELECTOR>._domainkey` (e.g., `8F5A8E47615B7165._domainkey`)
- **Content**: Copy the full DKIM record from the command above (starts with `v=DKIM1;`)
- **Proxy**: DNS only (grey cloud)

**Note**: The selector is randomly generated on first setup and stored in `/etc/exim4/dkim_selector`. It persists across container restarts unless you delete the keys directory.

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
| 587 | SMTP | STARTTLS | Submission (authenticated) |
| 465 | SMTPS | Implicit TLS | Secure SMTP |
| 143 | IMAP | STARTTLS | Mail retrieval |
| 993 | IMAPS | Implicit TLS | Secure IMAP |
| 110 | POP3 | STARTTLS | Mail retrieval |
| 995 | POP3S | Implicit TLS | Secure POP3 |
| 8080 | Roundcube | HTTP | Webmail interface |

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
- Update Exim password file
- Update Dovecot configuration
- Restart mail services automatically

### Method 2: Using Environment Variable (For Initial Setup)

1. **Edit `docker-compose.yml`:**
   ```yaml
   environment:
     - EMAIL_PASS=YourNewSecurePassword123!
   ```

2. **Rebuild and restart:**
   ```bash
   docker compose down
   docker compose up -d --build
   ```

**Note:** This method only works for the default user set in `EMAIL_USER`. For existing accounts, use Method 1 or 3.

### Method 3: Manual Update (Advanced)

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

### Method 4: Using Roundcube Webmail (If Enabled)

If password change is enabled in Roundcube:
1. Login to Roundcube webmail
2. Go to Settings → Password
3. Enter old password and new password
4. Save changes

**Note:** This requires Roundcube password plugin to be configured.

## 👥 Adding More Email Accounts

1. **Edit `docker-compose.yml`** to add new user:
   ```yaml
   environment:
     - EMAIL_USER=newuser
     - EMAIL_PASS=NewUserPassword123!
   ```

2. **Or manually add user:**
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
docker exec exim-mailserver sh -c "DKIM_SELECTOR=\$(cat /etc/exim4/dkim_selector) && echo \"Selector: \$DKIM_SELECTOR\" && echo \"DNS Name: \$DKIM_SELECTOR._domainkey\" && cat /etc/opendkim/keys/example.com/\$DKIM_SELECTOR.txt"
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

#### "TLS connection was non-properly terminated"
- This is often harmless - Gmail may close connections abruptly after accepting email
- Check if emails are actually being delivered (look for "250 2.0.0 OK" in logs)

#### Port 465 Syntax Errors
- Port 465 is configured for implicit TLS (SMTPS)
- Ensure clients connect with SSL/TLS from the start, not plain SMTP

## 📁 Data Persistence

Data is stored in mounted volumes:
- `./data/mail` - Email messages (Maildir format)
- `./data/spool` - Exim spool directory
- `./data/log` - Log files
- `./data/db` - Roundcube database

### Automatic Creation

**Yes, the `data/` folder is created automatically!** When you clone from Git and run `docker compose up`, Docker will automatically create the `data/` directory structure when mounting volumes. You don't need to create it manually.

The `data/` folder is excluded from Git (in `.gitignore`) because it contains:
- Runtime data (emails, logs, database)
- Large files that shouldn't be in version control
- Privacy-sensitive information

**On a new server:**
1. Clone the repository
2. Run `docker compose up -d --build`
3. Docker automatically creates `data/` with proper permissions
4. Services start and populate the directories

**Backup these directories** before major updates or container removal.

## 🔒 Security Notes

1. **Change default passwords** immediately after setup
2. **Use strong passwords** (minimum 12 characters, mixed case, numbers, symbols)
3. **Keep Docker images updated** regularly
4. **Configure firewall** to only allow necessary ports from trusted sources
5. **Monitor logs** for suspicious activity
6. **Use proper SSL certificates** in production (replace self-signed certs)
7. **Enable fail2ban** or similar for brute-force protection
8. **Regular backups** of mail data and configuration

## 🛑 Stopping the Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (⚠️ deletes all mail data)
docker compose down -v
```

## 📝 Configuration Files

Key configuration files:
- `exim/exim4.conf` - Main Exim configuration
- `roundcube/config.inc.php` - Roundcube configuration
- `docker-compose.yml` - Docker services orchestration
- `Dockerfile` - Exim container build instructions
- `scripts/entrypoint-exim.sh` - Exim startup script
- `scripts/setup-mail.sh` - Mail user setup script
- `scripts/setup-dkim.sh` - DKIM key generation script
- `opendkim/` - OpenDKIM configuration files
- `supervisord/` - Supervisord configuration files

## 🛠️ Helper Scripts

Helper scripts are located in `helper-scripts/`:

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
**Last Updated**: January 2026

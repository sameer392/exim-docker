# Backup and Monitoring

What to protect, how to watch the stack, and when to alert.

## What to back up

| Path | Contents | Priority |
|------|----------|----------|
| `data/mail/` | All mailboxes (Maildir) | **Critical** |
| `data/passwd` | Account passwords (hashed) | **Critical** |
| `data/opendkim/` | DKIM private keys | **Critical** |
| `data/letsencrypt/` + `data/ssl/` | TLS certificates | High |
| `data/exim/` | Domains, hostname, rate limits, DKIM selector | High |
| `data/db/` | Roundcube MariaDB data | Medium |
| `data/spool/` | Exim queue (in-flight mail) | Medium |
| `.env` | Admin secrets, hostname | High |

**Do not rely on** `data/log/` for recovery — logs are diagnostic only.

### Minimum backup script outline

```bash
#!/bin/bash
# helper-scripts/backup-mail.sh (example — implement and schedule via cron)
BACKUP_DIR=/backups/exim-docker/$(date +%Y%m%d)
mkdir -p "$BACKUP_DIR"
tar czf "$BACKUP_DIR/mail.tar.gz"    -C /path/to/exim-docker data/mail
tar czf "$BACKUP_DIR/config.tar.gz"  -C /path/to/exim-docker data/passwd data/exim data/opendkim data/ssl data/letsencrypt .env
# Copy off-site: rsync, S3, scp to another server
```

### Restore order

1. Stop stack: `docker compose down`
2. Restore `data/mail/`, `data/passwd`, `data/exim/`, DKIM, certs
3. Restore `.env`
4. Start: `docker compose up -d`
5. Verify IMAP login and send test mail

---

## Monitoring signals

### Container health

```bash
docker compose ps
docker stats --no-stream
```

Add Docker healthchecks (see [production-roadmap.md](production-roadmap.md)) for automated restarts.

### Mail queue

```bash
docker exec exim-mailserver exim -bpc          # message count
docker exec exim-mailserver exim -bp | head    # queue listing
```

**Alert if:** queue count stays high for > 1 hour or grows continuously.

### Disk space

```bash
df -h /path/to/exim-docker/data/mail
du -sh data/mail/*
```

**Alert if:** disk usage > 80%.

### TLS certificate expiry

```bash
openssl x509 -enddate -noout -in data/ssl/fullchain.pem
```

Certbot renews automatically; alert if cert expires in < 14 days.

### Exim panic log

```bash
tail -5 data/log/paniclog
```

**Alert on any new line** after initial deploy.

### SMTP / IMAP connectivity (external)

From another machine:

```bash
nc -zv smtp0.example.com 25
nc -zv smtp0.example.com 587
nc -zv smtp0.example.com 993
curl -sI https://smtp0.example.com
```

---

## Suggested tooling

| Tool | Use case | Complexity |
|------|----------|------------|
| **cron + backup script** | Daily tar + rsync | Low |
| **Uptime Kuma** | HTTP/TCP uptime checks | Low |
| **Netdata** | Host + container metrics | Low |
| **Prometheus + Grafana** | Fleet metrics; Dovecot exporter | Medium |
| **fail2ban** | Brute-force blocking | Low |

Dovecot includes `dovecot/conf.d/metrics.conf` — can expose stats for Prometheus when you are ready.

---

## Admin panel monitoring (today)

The mail admin panel (`:8090`) provides:

- Docker service status (running/stopped)
- Log tail for Exim mainlog and rejectlog
- Manual service restart

This is **operator convenience**, not a replacement for external alerting. Use Uptime Kuma or similar to page you when the server or port 25/443 is down.

---

## Fleet monitoring (multiple servers)

Maintain a simple registry:

| Server | IP | Hostname | Last backup | Cert expiry | Queue |
|--------|-----|----------|-------------|-------------|-------|
| mail-01 | 155.x.x.x | smtp0.a.com | 2026-06-23 | 2026-08-15 | 0 |

Automate checks with a small script SSHing to each host or using a monitoring SaaS with multiple TCP checks.

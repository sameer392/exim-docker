# Security Checklist

Pre-production and ongoing security tasks for exim-docker deployments.

## Before going live

### Server and SSH

- [ ] Disable password SSH login; use key-only (`PasswordAuthentication no` in `sshd_config`)
- [ ] Install **fail2ban** for SSH, Exim auth, and admin panel
- [ ] Keep OS and Docker updated
- [ ] Firewall: only required ports open (see [ports-and-services.md](ports-and-services.md))

### Secrets

- [ ] Change `ADMIN_PASSWORD` and `ADMIN_SECRET` in `.env` from defaults
- [ ] Move MariaDB passwords out of `docker-compose.yml` into `.env`
- [ ] Never commit `.env` or `data/passwd` to Git
- [ ] Rotate credentials after any suspected compromise

### Admin panel (port 8090)

- [ ] Put mailpanel behind **HTTPS** (nginx reverse proxy)
- [ ] Restrict port 8090 to admin IPs in firewall, or remove public exposure
- [ ] Use a long random `ADMIN_SECRET` (session signing)

### Mail authentication

- [ ] Strong mailbox passwords for all accounts
- [ ] Plan migration from MD5-CRYPT to bcrypt (see production roadmap)
- [ ] Exim requires auth for submission (587) — already configured

### TLS and DNS

- [ ] Let's Encrypt cert obtained and auto-renewing
- [ ] **PTR/rDNS** matches `HOSTNAME`
- [ ] SPF, DKIM, DMARC published for each domain
- [ ] Start DMARC at `p=none`, move to `quarantine` when stable

### Docker

- [ ] Pin image versions (avoid `:latest` in production)
- [ ] Review `docker.sock` mounts on `mailpanel` and `certbot` — compromise = host control
- [ ] Run `docker compose ps` after deploy; all services healthy

---

## Known risks in current stack

| Risk | Severity | Mitigation |
|------|----------|------------|
| Admin panel on HTTP | High | HTTPS reverse proxy |
| Hardcoded DB passwords in compose | Medium | Move to `.env` |
| `docker.sock` in mailpanel | High | Limit panel access; future: remove socket |
| MD5-CRYPT passwords | Medium | Upgrade to bcrypt |
| No inbound spam filter | Medium | Add Rspamd |
| Dovecot runs as root in container | Low–Medium | Required for Maildir ownership today |
| DKIM keys `chmod 644` in container | Low | Container filesystem only |
| Brute-force on SMTP/IMAP | Medium | fail2ban + rate limits |

---

## Ongoing operations

### Daily / automated

- Monitor `data/log/paniclog` — any new line means Exim config or startup failure
- Check queue size: `docker exec exim-mailserver exim -bpc`
- Verify backups completed (see [backup-and-monitoring.md](backup-and-monitoring.md))

### Weekly

- Review `rejectlog` for auth failures and rejected mail patterns
- Check disk usage on `data/mail/`
- Confirm Certbot renewal (certbot container logs)

### After config changes

- Test SMTP auth and IMAP login
- Send test mail; verify DKIM in headers
- Watch `paniclog` for 24 hours after Exim config edits

---

## Log files reference

| File | Meaning |
|------|---------|
| `data/log/mainlog` | Normal mail traffic, deliveries, connections |
| `data/log/rejectlog` | Rejected mail and ACL denials |
| `data/log/paniclog` | **Fatal** Exim errors — config broken, daemon failed |

If `paniclog` has new entries, treat as urgent — mail may not be sending or receiving correctly.

---

## Incident response (short)

1. Check `docker compose ps` — all containers up?
2. Read `paniclog` — config error?
3. Read recent `mainlog` — delivery deferrals?
4. Verify DNS (MX, PTR, SPF) unchanged
5. Restore from backup if `data/` corrupted

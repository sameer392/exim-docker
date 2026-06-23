# Production Roadmap

A phased plan to take exim-docker from a working single-server setup to a production-grade, scalable mail platform.

## Where the project stands today

| Layer | Status |
|-------|--------|
| SMTP / IMAP | Exim + Dovecot, TLS, DKIM, sent-folder copy |
| Webmail | Roundcube behind nginx HTTPS |
| Operations | Admin panel (domains, users, rate limits, logs) |
| Bootstrap | `install-new-server.sh`, DNS checklist, Certbot auto-renew |
| Abuse control | Per-account outbound rate limits, auth-required relay |

## What “scale” means for this project

This stack is **not** designed as one mailbox cluster across many nodes (like Gmail). Scaling means:

1. **Vertical** — more domains and users reliably on one server
2. **Horizontal fleet** — many independent mail servers from the same Git repo
3. **Production hardening** — security, backups, monitoring, repeatable deploys

```
Fleet model (supported today):

  smtp0.domain-a.com  ──►  VPS 1  (own data/, DKIM, TLS)
  smtp0.domain-b.com  ──►  VPS 2  (own data/, DKIM, TLS)
  smtp0.domain-c.com  ──►  VPS 3  (own data/, DKIM, TLS)
```

Never copy `data/` between servers — each node has its own keys, passwords, and mail storage.

---

## Phase 1 — Production hardening (do first)

Highest-risk gaps before onboarding more customers or servers.

### 1. Secure the admin panel

- Put **mailpanel behind HTTPS** (subdomain e.g. `mailadmin.example.com` or path on nginx)
- Add **fail2ban** for SSH, admin panel, and SMTP auth failures
- Enforce strong `ADMIN_PASSWORD` and `ADMIN_SECRET` in `.env` on every server
- Add login rate limiting and CSRF protection on destructive form actions

### 2. Remove hardcoded secrets

- Move MariaDB / Roundcube passwords from `docker-compose.yml` into `.env`
- Rotate credentials after migration

### 3. Pin Docker images

Replace `:latest` with fixed versions (e.g. `mariadb:11.4`, `roundcube/roundcubemail:1.6.x`) so `docker compose pull` does not cause surprise upgrades.

### 4. Add healthchecks

Example for Exim:

```yaml
healthcheck:
  test: ["CMD", "exim", "-bP", "version"]
  interval: 30s
  retries: 3
```

Add similar checks for Dovecot, MariaDB, and nginx. Use `depends_on` with `condition: service_healthy` where supported.

### 5. Automated backups

Daily off-site backup of:

- `data/mail/` — mailboxes
- `data/passwd` — account credentials
- `data/opendkim/` and `data/letsencrypt/` — DKIM keys and TLS certs
- `data/exim/` — domains, rate limits, hostname

Document and test restore procedure.

---

## Phase 2 — Deliverability and abuse resistance

Important when adding transactional mail (WHMCS, apps, `noreply@` addresses).

### Inbound protection

- **Rspamd** or **SpamAssassin** container
- Exim connection limits per IP (`smtp_accept_max`, `smtp_accept_max_per_host`)
- Optional greylisting on port 25

### Outbound reputation

- **PTR/rDNS** must match `HOSTNAME` on every VPS
- Move **DMARC** from `p=none` → `quarantine` once confident
- Monitor `mainlog` / `rejectlog` for deferrals and blocks
- Consider a **dedicated IP per high-volume domain** in a fleet

### Stronger passwords

Move from MD5-CRYPT (`openssl passwd -1`) to **bcrypt** or **BLF-CRYPT** in Dovecot and Exim auth.

### Queue and throughput

For high send volume:

- Tune Exim queue runners (`queue_run_max`, `remote_max_parallel`)
- Monitor frozen queue messages
- Separate monitoring for submission (587) vs inbound (25)

---

## Phase 3 — Fleet operations

### Server registry

Track per server: IP, `HOSTNAME`, domains, cert expiry, last backup date.

### Standardize provisioning

Extend `install-new-server.sh` to:

- Configure firewall (25, 80, 443, 587, 465, 993, 8090)
- Install fail2ban with Exim jails
- Generate random DB passwords in `.env`
- Print post-install checklist

### GitOps-style releases

- Tag releases (`v1.2.0`) when configs change
- Upgrade path: `git pull && docker compose up -d --build`
- Maintain a CHANGELOG for breaking changes (DKIM rotation, etc.)

### Observability

| Signal | Approach |
|--------|----------|
| Containers up | Docker healthchecks + Uptime Kuma |
| Queue depth | Cron: `exim -bpc` → alert if above threshold |
| Disk usage | Alert when `data/mail` exceeds 80% |
| Cert expiry | Alert 14 days before renewal |
| SMTP errors | Watch `paniclog` and deferral rates |

Dovecot `metrics.conf` can feed **Prometheus + Grafana** for a multi-server fleet.

### Reduce docker.sock exposure

`mailpanel` and `certbot` mount `docker.sock`. Long-term: replace with a minimal reload API or host-side helper scripts for destructive operations.

---

## Phase 4 — Product polish

For open-source visibility or commercial hosting:

1. **Fix doc drift** — README ports must match actual compose (443 webmail, not 8080)
2. **CI pipeline** — build on PR, Exim config syntax check, Python lint for mailpanel
3. **Integration tests** — SMTP auth → send → IMAP fetch → DKIM present
4. **Compose profiles** — `core`, `webmail`, `admin`, `monitoring` for send-only relays
5. **Optional features** — mailpanel REST API, mailbox quotas, alias management, Cloudflare DNS automation

---

## What not to chase early

| Idea | Why wait |
|------|----------|
| Shared Maildir across servers (NFS) | Complex; breaks per-IP reputation model |
| Kubernetes | Overkill; Compose per VPS is appropriate |
| Multi-master Exim cluster | Very hard; industry uses independent MX per node |
| Roundcube multi-account plugins | Poor UX; use mail clients or separate logins |

---

## 90-day suggested plan

| Month | Focus | Outcome |
|-------|--------|---------|
| **1** | HTTPS admin, secrets in `.env`, backups, fail2ban, image pinning | Safe for real customers |
| **2** | Rspamd, connection limits, bcrypt, healthchecks, monitoring | Handles more volume and abuse |
| **3** | CI/tests, mailpanel API, provisioning v2, docs refresh | Repeatable fleet deploys |

---

## Quick wins (this week)

1. Put admin panel behind nginx TLS
2. Add `helper-scripts/backup-mail.sh` + cron
3. Pin `mariadb` and `roundcube` image tags in `docker-compose.yml`
4. Add fail2ban jail for Exim auth failures
5. Update README port documentation

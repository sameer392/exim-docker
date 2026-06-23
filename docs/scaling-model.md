# Scaling Model

How exim-docker scales — and what it does not attempt to do.

## Single server (vertical scale)

One VPS runs the full stack:

```
┌─────────────────────────────────────────┐
│  VPS (smtp0.example.com)                │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐ │
│  │  Exim   │  │ Dovecot │  │Roundcube │ │
│  └────┬────┘  └────┬────┘  └────┬─────┘ │
│       └────────────┴──────────────┘       │
│              data/mail/ (Maildir)         │
└─────────────────────────────────────────┘
```

**Scales by:**

- More CPU/RAM/disk on the VPS
- Per-account rate limits (already in admin panel)
- Exim queue tuning for outbound volume
- Rspamd / connection limits for inbound abuse

**Practical limits:**

- Disk I/O on Maildir for many concurrent IMAP users
- Single IP reputation for all domains on that server
- No automatic failover if the VPS dies

---

## Fleet of servers (horizontal scale)

The supported multi-server model: **one independent installation per VPS**.

```
Repo: github.com/sameer392/exim-docker
         │
         ├──► VPS 1  HOSTNAME=smtp0.client-a.com   data/ (unique)
         ├──► VPS 2  HOSTNAME=smtp0.client-b.com   data/ (unique)
         └──► VPS 3  HOSTNAME=smtp0.client-c.com   data/ (unique)
```

Each server:

- Has its own `.env`, `HOSTNAME`, TLS cert, DKIM keys
- Has its own `data/` directory — **never copy between servers**
- Can host one or many domains via the admin panel
- Is provisioned with `helper-scripts/install-new-server.sh`

### When to add another server

| Scenario | Action |
|----------|--------|
| New customer wants isolated IP/reputation | New VPS + new install |
| Disk or CPU maxed on current VPS | New VPS or upgrade hardware |
| Geographic delivery (EU vs US) | Regional VPS with local `HOSTNAME` |
| Blast radius isolation | Separate transactional vs marketing mail |

### DNS per server

Each server needs:

- **A record** — `smtp0.example.com` → server IP
- **PTR** — IP → `smtp0.example.com` (set at VPS provider)
- **MX** — `example.com` → `smtp0.example.com` (or priority MX)
- **SPF, DKIM, DMARC** — per domain, per server IP

---

## What this project does NOT scale

| Pattern | Why not |
|---------|---------|
| **Shared storage** (NFS/Gluster for Maildir) | Locking, latency, single point of failure; breaks simple backup model |
| **Active-active Exim cluster** | Queue coordination and DKIM/IP binding are complex |
| **One hostname across many IPs** | Mail reputation and TLS certs are per-server |
| **Kubernetes mail stack** | Operational overhead; Compose per VPS is simpler and proven |

Industry pattern for hosting providers: **many independent mail nodes**, not one giant cluster.

---

## Multi-domain on one server

You already support multiple domains on a single VPS (e.g. `hemochrom.com` + `cubehostindia.com`):

- All domains share one IP and one `HOSTNAME` (SMTP banner / TLS cert)
- Separate DKIM selectors per domain in `data/opendkim/`
- Separate maildirs under `data/mail/<domain>/<user>/`

**Trade-off:** All domains share the same IP reputation. For a problematic sender on one domain, others on the same IP can be affected.

---

## Future architecture options (advanced)

Only consider these at significant scale:

1. **Outbound relay service** — Exim on app servers → dedicated smtp relay VPS
2. **Inbound MX backup** — Secondary MX queues to primary (Exim secondary MX config)
3. **Object storage archive** — Old mail offloaded to S3; Dovecot optional plugin
4. **Central LDAP/SQL auth** — Single user DB for many nodes (Dovecot SQL auth already partially supported)

None of these are implemented today; they require custom development.

---

## Upgrade path summary

| Stage | Users / domains | Architecture |
|-------|-----------------|--------------|
| **Starter** | 1–5 domains, low volume | One VPS, this repo |
| **Growth** | 10+ domains, moderate volume | Tune Exim, add Rspamd, backups, monitoring |
| **Hosting** | Many customers | Fleet of VPSes, server registry, scripted provision |
| **Enterprise** | National scale | OX App Suite or commercial groupware; not this stack as-is |

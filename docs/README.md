# exim-docker Documentation

Guides for operating, scaling, and hardening this mail server stack in production.

## Contents

| Document | Description |
|----------|-------------|
| [Production roadmap](production-roadmap.md) | Phased plan: hardening, deliverability, fleet ops, product polish |
| [Ports and services](ports-and-services.md) | SMTP, IMAP, POP3, webmail, and admin panel port reference |
| [Scaling model](scaling-model.md) | Single server vs fleet of independent mail nodes |
| [Security checklist](security-checklist.md) | Pre-production security tasks and ongoing practices |
| [Backup and monitoring](backup-and-monitoring.md) | What to back up, monitoring signals, alerting |
| [OX App Suite vs Roundcube](ox-app-suite-vs-roundcube.md) | Whether to replace Roundcube with OX App Suite |
| [Webmail tech stacks](webmail-tech-stacks.md) | PHP, Java, Python, React stacks for Roundcube, OX, SOGo, SnappyMail, and more |

## Quick links

- Main project README: [../README.md](../README.md)
- Admin panel: `http://YOUR_SERVER_IP:8090` (use HTTPS in production — see security checklist)
- Webmail: `https://YOUR_HOSTNAME` (port 443 via nginx)
- Helper scripts: [../helper-scripts/](../helper-scripts/)

## Current stack

```
Internet
   │
   ├── :25, :587, :465  → Exim (SMTP)
   ├── :143, :993       → Dovecot (IMAP)
   ├── :110, :995       → Dovecot (POP3)
   ├── :80, :443        → nginx → Roundcube (webmail)
   └── :8090            → Mail admin panel
```

All services run via Docker Compose. Mail is stored as Maildir under `data/mail/`.

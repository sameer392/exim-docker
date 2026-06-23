# Webmail & Groupware — Technology Stacks

What each open-source webmail / groupware product is built with (backend, frontend, database, runtime) and how that affects deployment with **exim-docker** (Exim + Dovecot + Maildir).

## Quick comparison table

| Product | Type | Backend | Frontend | Database | License | Fits exim-docker |
|---------|------|---------|----------|----------|---------|------------------|
| **Roundcube** *(current)* | IMAP webmail | **PHP** | JavaScript (Elastic UI) | MariaDB/MySQL/PostgreSQL/SQLite | GPL-3.0 | ✅ Native fit |
| **SnappyMail** | IMAP webmail | **PHP** | JavaScript (Knockout.js) | None required* | AGPL-3.0 | ✅ Easy swap |
| **RainLoop** | IMAP webmail | **PHP** | JavaScript | None required | AGPL-3.0 | ⚠️ Unmaintained; use SnappyMail |
| **Cypht** | IMAP aggregator | **PHP** | JavaScript | MySQL/MariaDB/PostgreSQL/SQLite | LGPL-2.1 | ✅ Good fit |
| **SOGo 5** *(stable)* | Groupware | **Objective-C** (GNUstep) | **AngularJS** | MariaDB/PostgreSQL | GPL-2.0 | ⚠️ Complex integration |
| **SOGo 6** *(in development)* | Groupware | **Python** (Flask, gunicorn) | **React** | PostgreSQL + **Redis** | GPL-2.0 | ⚠️ Future replatform |
| **OX App Suite** | Groupware platform | **Java** | **JavaScript** (SPA) | MySQL/MariaDB | GPL + **CC BY-NC** UI | ❌ Major replatform |
| **Horde** | Groupware suite | **PHP** | JavaScript | Any SQL via Horde DB layer | LGPL-2.1 | ⚠️ Heavy, older stack |
| **Mailpile** | Mail client + search | **Python** | JavaScript | Local index (not typical IMAP cache) | AGPL-3.0 | ❌ Different model |
| **WildDuck** | Full mail server | **Node.js** | Separate web UIs | MongoDB + Redis | EUPL-1.2 | ❌ Replaces Exim/Dovecot |

\* SnappyMail stores config in files; optional DB only for contacts plugin.

---

## Architecture patterns

Most products fall into one of three models:

```
Model A — Thin IMAP client (best for exim-docker)
─────────────────────────────────────────────────
  Browser → PHP app → Dovecot (IMAP) + Exim (SMTP)
  Mail lives in: Maildir (data/mail/)
  Examples: Roundcube, SnappyMail, Cypht, RainLoop


Model B — Groupware middleware
──────────────────────────────
  Browser → Web UI → Groupware server → Dovecot + SMTP + SQL
  Mail in Maildir; calendar/contacts in separate SQL DB
  Examples: SOGo, Horde (partial)


Model C — Full platform (not IMAP-addon)
────────────────────────────────────────
  Browser → SPA → Java/Python services → own storage model
  Examples: OX App Suite, WildDuck
```

**exim-docker uses Model A today.** Swapping webmail means replacing only the PHP container + optional MariaDB — Exim and Dovecot stay the same.

---

## Product details

### Roundcube *(used in this project)*

| Layer | Technology |
|-------|------------|
| **Language** | PHP 8.2+ (Docker image currently PHP 8.4) |
| **Web server** | Apache (in official Docker image) or nginx + PHP-FPM |
| **Frontend** | JavaScript, jQuery, **Elastic** skin (responsive HTML/CSS) |
| **Database** | MariaDB/MySQL (required for sessions, contacts cache, settings) |
| **Protocols** | IMAP, SMTP, ManageSieve (optional plugin) |
| **Not used** | Node.js, React, Java |

**Docker in exim-docker:** `roundcube/roundcubemail` image → nginx proxies HTTPS → Roundcube talks to Dovecot:31993 and Exim:587.

**Resource profile:** Light (~256–512 MB RAM for PHP container + small MariaDB).

**Pros for this stack:** Mature, GPL, huge plugin ecosystem, already integrated.

---

### SnappyMail

| Layer | Technology |
|-------|------------|
| **Language** | PHP 7.4+ (moving toward PHP 8.1+) |
| **Frontend** | JavaScript, **Knockout.js**, Rollup bundler |
| **Database** | **Not required** (file-based `application.ini` config) |
| **Optional** | MySQL/MariaDB for contacts plugin; Redis for caching |
| **Protocols** | IMAP, SMTP, Sieve, OAuth2 (XOAUTH2) |
| **Not used** | Node.js, React, Java |

Fork of **RainLoop** with security fixes and modern PHP.

**Resource profile:** Very light — often the lowest-RAM PHP webmail option.

**Swap effort vs Roundcube:** Low — same IMAP/SMTP model; remove MariaDB dependency if you do not need contact DB.

Official Docker image: `djmaze/snappymail`

---

### RainLoop *(legacy)*

| Layer | Technology |
|-------|------------|
| **Language** | PHP 5.x lineage (outdated) |
| **Frontend** | JavaScript |
| **Database** | None |

**Status:** Community edition effectively superseded by **SnappyMail**. Do not start new deployments on RainLoop.

---

### Cypht

| Layer | Technology |
|-------|------------|
| **Language** | PHP |
| **Frontend** | JavaScript (modular “module sets”) |
| **Database** | MySQL/MariaDB, PostgreSQL, or SQLite |
| **Protocols** | IMAP, SMTP, POP3, JMAP, EWS (Exchange), RSS |
| **Not used** | Node.js, React |

**Unique design:** Aggregator — combined inbox across multiple accounts; minimal server-side mail storage (proxy model).

**Resource profile:** Light to medium.

**Good if:** You want multi-account unified inbox without ident_switch-style plugins.

---

### SOGo

#### SOGo 5 (current stable — v5.12.x)

| Layer | Technology |
|-------|------------|
| **Backend** | **Objective-C** on **GNUstep** / SOPE framework |
| **Frontend** | **AngularJS** (legacy JS framework) |
| **Database** | MariaDB/MySQL or PostgreSQL (calendars, contacts, prefs) |
| **Cache** | **Memcached** |
| **Mail** | IMAP (Dovecot), SMTP (Exim), CalDAV, CardDAV, ActiveSync (add-on) |
| **Not used** | PHP, Node.js, React |

#### SOGo 6 (in development, not GA for production)

| Layer | Technology |
|-------|------------|
| **Backend** | **Python** — Flask + gunicorn, REST API |
| **Frontend** | **React** |
| **Database** | **PostgreSQL** (required) |
| **Cache** | **Redis** (replaces Memcached) |

**Resource profile:** Medium–heavy (Objective-C/Java services + DB + memcached/redis).

**Integration with exim-docker:** Possible but non-trivial — add SOGo container, PostgreSQL/MariaDB for groupware data, LDAP or SQL auth bridge to `data/passwd`, nginx routes.

**Good if:** You need calendar + contacts + webmail and accept operational complexity.

---

### OX App Suite (Open-Xchange)

| Layer | Technology |
|-------|------------|
| **Backend** | **Java** (OX middleware server) |
| **Frontend** | **JavaScript** (large single-page application) |
| **Database** | MySQL/MariaDB |
| **Optional** | Redis, object storage for OX Drive |
| **Protocols** | IMAP, SMTP, CalDAV, CardDAV; EAS with license |
| **Not used** | PHP, Node.js (main stack) |

**License split:** Backend GPLv2; frontend **CC BY-NC-SA** — commercial hosting requires paid license.

**Resource profile:** Heavy — typically **4 GB+ RAM**, multiple Java processes.

**Integration:** Does not plug in as a Roundcube replacement; requires OX middleware layer and separate provisioning.

---

### Horde

| Layer | Technology |
|-------|------------|
| **Language** | **PHP** |
| **Frontend** | JavaScript, Horde UI framework |
| **Database** | SQL via Horde’s DB abstraction |
| **Components** | IMP (webmail), Kronolith (calendar), Turba (contacts), Ingo (filters) |
| **Not used** | Node.js, React, Java |

**Status:** Long-running project; smaller community than Roundcube/SOGo today.

**Resource profile:** Medium (full PHP groupware suite).

---

### Mailpile

| Layer | Technology |
|-------|------------|
| **Language** | **Python** |
| **Frontend** | HTML5 / JavaScript |
| **Storage** | Local encrypted index + keyring (privacy-focused) |
| **Protocols** | Designed as client; not a classic Dovecot thin client |

**Model:** Different from IMAP webmail — indexes mail for search/encryption. Not a drop-in for exim-docker’s Maildir + Dovecot pattern.

**Status:** Development slowed; niche use case.

---

### WildDuck Mail Server

| Layer | Technology |
|-------|------------|
| **Language** | **Node.js** |
| **Database** | **MongoDB** + **Redis** |
| **Role** | Complete mail server (SMTP, IMAP, API) — not just webmail |

**Replaces** Exim + Dovecot rather than sitting on top. Separate project path entirely.

---

## Other open-source options (brief)

| Product | Stack | Notes |
|---------|-------|-------|
| **Stalwart** | **Rust** | All-in-one mail server (SMTP, IMAP, JMAP); not webmail-only |
| **Maddy** | **Go** | Combined mail server; no built-in webmail |
| **iRedMail** | Meta-distribution | Bundles Postfix + Dovecot + **Roundcube or SOGo** — installer, not one app |
| **Mailcow** | Docker meta-stack | Postfix + Dovecot + SOGo/Rspamd + PHP components |
| **Z-Push** | **PHP** | ActiveSync bridge for SOGo/Horde, not standalone webmail |

---

## What exim-docker itself uses (full stack)

For context — the whole project, not just webmail:

| Component | Technology |
|-----------|------------|
| **SMTP** | Exim4 (C) |
| **IMAP/POP** | Dovecot (C) |
| **Webmail** | Roundcube (**PHP** + MariaDB) |
| **Admin panel** | **Python** (FastAPI + Uvicorn) |
| **Reverse proxy / TLS** | **nginx** + Certbot |
| **Orchestration** | Docker Compose |
| **Mail storage** | Maildir on disk |
| **Auth** | Flat file `data/passwd` (MD5-CRYPT) |

No Node.js or React in the current exim-docker stack (except inside upstream Roundcube’s JS frontend assets).

---

## Choosing by technology preference

| If you prefer… | Consider |
|----------------|----------|
| **PHP only** (match current stack) | Roundcube, SnappyMail, Cypht, Horde |
| **Python** | SOGo 6 (future), Mailpile (different model) |
| **Java** | OX App Suite (licensed for commercial) |
| **Node.js** | WildDuck (full server replacement) |
| **React UI** | SOGo 6 (upcoming), OX App Suite |
| **No database for webmail** | SnappyMail |
| **Multi-account inbox** | Cypht |
| **Calendar + contacts** | SOGo 5, Horde, OX (licensed) |
| **Minimal RAM** | SnappyMail or Roundcube |
| **GPL, commercial hosting OK** | Roundcube, SOGo, Cypht, SnappyMail (AGPL) |

---

## Recommendation for exim-docker upgrades

| Goal | Best candidate | Why |
|------|----------------|-----|
| Stay as-is | **Roundcube** | Already integrated, PHP, MariaDB in compose |
| Modern UI, less RAM, no DB | **SnappyMail** | PHP, drop-in IMAP client, active development |
| Multi-account webmail | **Cypht** | Built for aggregation |
| Full groupware | **SOGo 5** | Dovecot-native; wait for SOGo 6 if you want Python/React |
| Enterprise groupware | **OX App Suite** | Budget for Java ops + commercial license |

See also: [ox-app-suite-vs-roundcube.md](ox-app-suite-vs-roundcube.md)

---

## Official links

| Product | Repository / site |
|---------|-------------------|
| Roundcube | https://github.com/roundcube/roundcubemail |
| SnappyMail | https://github.com/the-djmaze/snappymail |
| Cypht | https://github.com/cypht-org/cypht |
| SOGo | https://github.com/Alinto/sogo — https://www.sogo.nu |
| OX App Suite | https://www.open-xchange.com |
| Horde | https://www.horde.org |
| Mailpile | https://github.com/mailpile/Mailpile |

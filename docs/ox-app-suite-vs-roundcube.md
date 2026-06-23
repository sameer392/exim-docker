# OX App Suite vs Roundcube

Should you replace Roundcube with **OX App Suite** (Open-Xchange) in exim-docker?

## Short answer

| Question | Answer |
|----------|--------|
| Is OX App Suite free? | **Partially** — free for personal/non-commercial use; **commercial/hosting requires a paid license** |
| Can you drop it into this stack easily? | **No** — major architecture change; not a simple Roundcube swap |
| Best for exim-docker today? | **Roundcube** — designed as an IMAP/SMTP frontend for Exim+Dovecot |

---

## What each product is

### Roundcube (current)

- **Type:** Webmail client (IMAP + SMTP)
- **Connects to:** Dovecot (IMAP) + Exim (SMTP) — already configured
- **Storage:** Mail stays in Maildir; Roundcube only caches metadata in MariaDB
- **License:** GPL — free for any use, including commercial hosting
- **Resources:** Light (~256 MB RAM for PHP container)

### OX App Suite (Open-Xchange)

- **Type:** Full **groupware platform** — email, calendar, contacts, tasks, optional documents (OX Documents), file sync (OX Drive), encryption (OX Guard)
- **Architecture:** Own middleware (OX server), not a thin IMAP client
- **Storage:** Uses its own data model; integration with plain Maildir/Exim is non-trivial
- **License:** Split license model (see below)
- **Resources:** Heavy — typically multiple Java services, PostgreSQL/MySQL, more RAM (4 GB+ for small installs)

---

## OX App Suite licensing (is it free?)

Open-Xchange uses a **split license**:

| Component | License | Commercial use |
|-----------|---------|----------------|
| **Backend (server)** | GPLv2 | Backend can be used under GPL terms |
| **Frontend (web UI)** | **CC BY-NC-SA 2.5** (NonCommercial) | **Not free for commercial/hosting use** |

Official FAQ ([Open-Xchange Product FAQ](https://wiki.open-xchange.com/wiki/index.php?title=Product_FAQ)):

- Free for **non-commercial** use — you can download, customize, and redistribute without selling it
- **Commercial use** (including offering mail to paying customers) requires a **paid license** for packages, support, and some modules
- The frontend NC license is **not OSI-approved open source**

**Additional paid modules** (typically not in free/community builds):

- Exchange ActiveSync (EAS) for mobile
- Outlook connector
- OX Guard (encryption), OX Documents, OX Drive — often licensed separately

**Bottom line for a hosting business:** budget for **OX commercial licenses**. Do not assume OX App Suite is a free Roundcube replacement for selling mail hosting.

### Roundcube licensing

- **GPLv3** — free for personal and commercial hosting
- No per-user or per-domain license fee

---

## Integration with exim-docker

### Roundcube (current) — fits naturally

```
Browser → nginx:443 → Roundcube → Dovecot:31993 (IMAP)
                              → Exim:587 (SMTP)
Mail stored in: data/mail/ (Maildir)
```

- Works with existing `data/passwd` auth
- Admin panel creates users; they log into Roundcube immediately
- Minimal moving parts

### OX App Suite — major replatform

```
Browser → OX Web UI → OX Middleware (Java) → ??? → Dovecot or OX storage
```

Challenges:

1. **No official “OX + Exim Maildir” Docker recipe** in this repo — you would need OX middleware, separate DB, and integration layer
2. **User provisioning** — admin panel would need to sync to OX, not just `data/passwd`
3. **Calendar/contacts** — require OX’s own storage, not Dovecot alone
4. **Resource footprint** — much larger than Roundcube on the same VPS
5. **Certified path** — OX is often deployed via Univention, commercial appliances, or OX’s own install guides

Replacing Roundcube with OX is a **new project phase**, not a config change.

---

## Pros and cons

### OX App Suite — Pros

| Advantage | Detail |
|-----------|--------|
| **Rich UI** | Modern webmail comparable to Outlook Web / Gmail |
| **Groupware** | Calendar, contacts, tasks built-in |
| **Collaboration** | Shared calendars, OX Documents (with license) |
| **Mobile** | ActiveSync with commercial license |
| **Enterprise credibility** | Used by ISPs and large deployments |
| **AI features** | OX is adding in-app AI (commercial roadmap) |

### OX App Suite — Cons

| Disadvantage | Detail |
|--------------|--------|
| **License cost** | NC frontend; commercial hosting needs paid license |
| **Complexity** | Java stack, multiple services, harder to debug |
| **Resources** | Needs more CPU/RAM than Roundcube |
| **Integration effort** | Does not plug into Exim+Dovecot Maildir stack trivially |
| **Overkill for SMTP-only** | If you only need webmail for transactional mail, OX is heavy |
| **Vendor dependency** | Updates and modules tied to Open-Xchange release cycle |

### Roundcube — Pros

| Advantage | Detail |
|-----------|--------|
| **Free (GPL)** | No license fees for hosting customers |
| **Lightweight** | Runs well on small VPS |
| **Perfect fit** | Native IMAP client for Dovecot |
| **Already integrated** | Working in this repo with TLS, sent folder, admin panel |
| **Simple ops** | One container + MariaDB |

### Roundcube — Cons

| Disadvantage | Detail |
|--------------|--------|
| **Email only** | No built-in calendar/contacts (plugins exist, limited) |
| **UI dated** | Functional but not Gmail/Outlook level |
| **No ActiveSync** | Mobile uses IMAP apps, not native sync |
| **No multi-account** | Gmail-style “add account” not built-in (plugins are awkward) |
| **Plugin quality varies** | Third-party plugins differ in maintenance |

---

## Recommendation matrix

| Your goal | Recommendation |
|-----------|----------------|
| Transactional mail + simple webmail | **Keep Roundcube** |
| Hosting many small business mailboxes cheaply | **Keep Roundcube** |
| Sell “Outlook-like” groupware at premium price | **Evaluate OX** — budget licenses + separate infra |
| Need calendar/contacts in webmail only | Consider **SOGo** or **SnappyMail + CalDAV** before OX |
| Need mobile ActiveSync | OX (licensed) or **Z-Push** with SOGo/Dovecot |
| Open-source only, commercial hosting | **Roundcube, SOGo, or SnappyMail** — not OX frontend |

---

## Alternatives worth considering (lighter than OX)

If Roundcube feels too basic but OX is too heavy:

| Product | License | Notes |
|---------|---------|-------|
| **SnappyMail** | AGPL | Modern UI, IMAP-only, lighter than Roundcube |
| **SOGo** | LGPL | Email + calendar + contacts; integrates with Dovecot |
| **RainLoop** | AGPL (community) | Simple IMAP webmail (less active development) |

All of these fit the **Exim + Dovecot** model better than OX App Suite.

---

## Decision summary

- **OX App Suite is not “free Roundcube plus extras”** for a mail hosting business — plan for commercial licensing.
- **Staying on Roundcube** is the right choice for exim-docker’s current architecture and scale.
- **Moving to OX** means replatforming webmail and groupware, not swapping a Docker image.

If you want calendar/contacts without OX licensing costs, the next doc to write would be a **SOGo integration guide** — that is a more realistic upgrade path for this stack.

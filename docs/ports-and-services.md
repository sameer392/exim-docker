# Ports and Services Reference

Each mail protocol uses **its own standard port**. Webmail and the admin panel are separate HTTP services.

## Default port map (current setup)

| Service | Protocol | Host port | Container | TLS | Notes |
|---------|----------|-----------|-----------|-----|-------|
| **SMTP (inbound)** | SMTP | **25** | exim:25 | Optional STARTTLS | Receiving mail from other servers |
| **SMTP (submission)** | SMTP | **587** | exim:587 | STARTTLS | Authenticated sending (recommended for clients) |
| **SMTPS** | SMTP | **465** | exim:465 | Implicit TLS | Legacy clients; some apps still use this |
| **IMAP** | IMAP | **143** | dovecot:31143 | STARTTLS | Plain IMAP; upgrade to TLS |
| **IMAPS** | IMAP | **993** | dovecot:31993 | Implicit TLS | **Recommended** for mail clients |
| **POP3** | POP3 | **110** | dovecot:31110 | STARTTLS | Legacy download-and-delete |
| **POP3S** | POP3 | **995** | dovecot:31995 | Implicit TLS | Secure POP3 |
| **Webmail (HTTP)** | HTTP | **80** | nginx:80 | No | Redirects to HTTPS; ACME challenges |
| **Webmail (HTTPS)** | HTTPS | **443** | nginx:443 → Roundcube | TLS | **Primary webmail URL** |
| **Admin panel** | HTTP | **8090** | mailpanel:8000 | No* | *Use HTTPS reverse proxy in production |
| **MariaDB** | MySQL | *(internal)* | db:3306 | No | Not exposed to host; Roundcube only |

### Client configuration examples

Use your `HOSTNAME` from `.env` (e.g. `smtp0.hemochrom.com`).

**Thunderbird / Outlook / mobile app:**

| Setting | Value |
|---------|-------|
| Incoming (IMAP) | `smtp0.example.com`, port **993**, SSL/TLS |
| Outgoing (SMTP) | `smtp0.example.com`, port **587**, STARTTLS |
| Username | full email (`user@domain.com`) |
| Password | mailbox password |

**POP3 (if required):**

| Setting | Value |
|---------|-------|
| Incoming (POP3) | `smtp0.example.com`, port **995**, SSL/TLS |

**Webmail (browser):**

```
https://smtp0.example.com
```

**Admin panel:**

```
http://YOUR_SERVER_IP:8090   ← development only
https://mailadmin.example.com  ← recommended in production
```

---

## Firewall checklist

Open on the host (firewalld / ufw / cloud security group):

```
25/tcp    SMTP inbound
80/tcp    HTTP (Let's Encrypt + redirect)
443/tcp   HTTPS webmail
587/tcp   SMTP submission
465/tcp   SMTPS (optional if all clients use 587)
993/tcp   IMAPS (if clients connect directly)
143/tcp   IMAP (optional; prefer 993 only)
110/tcp   POP3 (optional; many deployments disable)
995/tcp   POP3S (optional)
8090/tcp  Admin panel (restrict to your IP in production)
```

**Recommended minimal exposure:**

- **25, 80, 443, 587, 993** — required for most setups
- **465, 995** — if legacy clients need them
- **8090** — restrict to admin IPs or put behind VPN / HTTPS

---

## Why ports are mapped this way

### SMTP (Exim) — ports 25, 587, 465

Defined in `docker-compose.yml` under `mailserver.ports`. All three are standard and already on separate host ports.

### IMAP / POP3 (Dovecot) — 143, 993, 110, 995

Dovecot listens on non-standard **internal** ports (31143, 31993, etc.) and Docker maps them to standard **host** ports:

```yaml
ports:
  - "143:31143"   # IMAP
  - "993:31993"   # IMAPS
  - "110:31110"   # POP3
  - "995:31995"   # POP3S
```

This avoids conflicts inside the container while exposing standard ports externally.

### Webmail — port 443 (not 8080)

Roundcube does **not** expose a host port directly. Traffic flow:

```
Browser :443 → nginx-acme → roundcube-webmail:80 (internal Docker network)
```

Benefits:

- Single TLS certificate for webmail (Let's Encrypt)
- HTTP on 80 only for cert renewal and redirect
- Webmail is clearly separated from SMTP/IMAP ports

### Optional: dedicated webmail port 8080

If you want webmail on its **own port** (e.g. for testing or a separate URL without sharing 443):

Add to `roundcube` service in `docker-compose.yml`:

```yaml
ports:
  - "8080:80"
```

Then access: `http://YOUR_IP:8080` (HTTP only unless you add a second nginx listener).

For production, **443 via nginx is still recommended** — browsers and Let's Encrypt expect HTTPS on 443.

### Optional: webmail on a subdomain with separate nginx server block

Example: `webmail.example.com` on 443 and `mail.example.com` for something else — add a `server_name` block in `certbot/nginx.conf`.

---

## Internal Docker ports (not on host)

Services talk inside the `mailnet` bridge:

| From | To | Port | Purpose |
|------|-----|------|---------|
| Roundcube | Dovecot | 31993 | IMAP (SSL) |
| Roundcube | Exim | 587 | SMTP submission |
| Exim | Dovecot | 2525 | LMTP (sent-folder copy) |
| Roundcube | MariaDB | 3306 | Webmail database |

These are not exposed to the internet.

---

## Changing ports

To use non-standard host ports (e.g. IMAPS on 4993):

1. Edit `docker-compose.yml` port mapping: `"4993:31993"`
2. Update firewall rules
3. Tell users the new port in client settings
4. PTR/MX records are unaffected (SMTP hostname stays the same)

Do **not** change port 25 without understanding inbound mail delivery requirements — remote MX servers always connect on 25.

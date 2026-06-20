import os
from pathlib import Path

DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
LOG_DIR = DATA_DIR / "log"
PASSWD_FILE = DATA_DIR / "passwd"
DOMAINS_FILE = DATA_DIR / "exim" / "domains"
MAIL_DIR = DATA_DIR / "mail"
PRIMARY_HOSTNAME_FILE = DATA_DIR / "exim" / "primary_hostname"
QUALIFY_DOMAIN_FILE = DATA_DIR / "exim" / "qualify_domain"
DKIM_SELECTOR_FILE = DATA_DIR / "exim" / "dkim_selector"
RATE_TIERS_FILE = DATA_DIR / "exim" / "rate_tiers.json"
RATE_ASSIGNMENTS_FILE = DATA_DIR / "exim" / "rate_assignments.json"
RATE_10M_FILE = DATA_DIR / "exim" / "rate_10m"
RATE_1H_FILE = DATA_DIR / "exim" / "rate_1h"
RATE_1D_FILE = DATA_DIR / "exim" / "rate_1d"

ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "ChangeAdminPass!")
ADMIN_SECRET = os.getenv("ADMIN_SECRET", "change-me-in-production")
SESSION_COOKIE = "mailpanel_session"
SESSION_MAX_AGE = 60 * 60 * 12  # 12 hours

EXIM_CONTAINER = os.getenv("EXIM_CONTAINER", "exim-mailserver")
DOVECOT_CONTAINER = os.getenv("DOVECOT_CONTAINER", "dovecot-mailserver")
ROUNDCUBE_CONTAINER = os.getenv("ROUNDCUBE_CONTAINER", "roundcube-webmail")

MAIL_UID = 8
MAIL_GID = 8

WEBMAIL_PORT = os.getenv("WEBMAIL_PORT", "8080")
PUBLIC_HOST = os.getenv("PUBLIC_HOST", "").strip()

import re


def parse_dkim_txt_value(raw: str) -> str:
    """Extract a single-line TXT value from OpenDKIM zone record output."""
    text = raw.split("; -----", 1)[0]
    parts = re.findall(r'"([^"]*)"', text)
    if parts:
        return "".join(parts)
    match = re.search(r"(v=DKIM1[^\s;]*)", text)
    return match.group(1).strip() if match else text.strip()


def domain_dns_records(
    domain: str,
    hostname: str,
    selector: str,
    dkim_raw: str | None,
) -> list[dict]:
    """DNS records formatted for typical provider panels (Cloudflare, etc.)."""
    mx_host = hostname or f"smtp0.{domain}"
    records: list[dict] = [
        {
            "type": "MX",
            "name": "@",
            "value": mx_host,
            "priority": 10,
            "label": "Mail server",
        },
        {
            "type": "TXT",
            "name": "@",
            "value": f"v=spf1 mx a:{mx_host} ~all",
            "label": "SPF",
        },
    ]
    if selector and dkim_raw:
        records.append(
            {
                "type": "TXT",
                "name": f"{selector}._domainkey",
                "value": parse_dkim_txt_value(dkim_raw),
                "label": "DKIM",
            }
        )
    records.append(
        {
            "type": "TXT",
            "name": "_dmarc",
            "value": f"v=DMARC1; p=none; rua=mailto:admin@{domain}",
            "label": "DMARC",
        }
    )
    return records

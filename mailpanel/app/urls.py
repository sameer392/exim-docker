from fastapi import Request

from .config import PUBLIC_HOST, WEBMAIL_PORT


def public_host(request: Request) -> str:
    if PUBLIC_HOST:
        return PUBLIC_HOST
    forwarded = request.headers.get("x-forwarded-host", "")
    if forwarded:
        return forwarded.split(":")[0]
    return request.url.hostname or "localhost"


def webmail_url(request: Request) -> str:
    host = public_host(request)
    scheme = request.url.scheme if request.url.scheme in ("http", "https") else "http"
    return f"{scheme}://{host}:{WEBMAIL_PORT}"

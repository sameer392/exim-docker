from fastapi import Request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from .config import ADMIN_PASSWORD, ADMIN_SECRET, SESSION_COOKIE, SESSION_MAX_AGE

_serializer = URLSafeTimedSerializer(ADMIN_SECRET, salt="mailpanel-auth")


def create_session_token() -> str:
    return _serializer.dumps({"authenticated": True})


def verify_session_token(token: str) -> bool:
    try:
        data = _serializer.loads(token, max_age=SESSION_MAX_AGE)
        return bool(data.get("authenticated"))
    except (BadSignature, SignatureExpired):
        return False


def verify_admin_password(password: str) -> bool:
    return password == ADMIN_PASSWORD


def is_authenticated(request: Request) -> bool:
    token = request.cookies.get(SESSION_COOKIE)
    if not token:
        return False
    return verify_session_token(token)

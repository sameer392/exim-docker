import logging

import docker
from docker.errors import DockerException, NotFound

from ..config import DOVECOT_CONTAINER, EXIM_CONTAINER, ROUNDCUBE_CONTAINER

logger = logging.getLogger(__name__)


def _client():
    try:
        return docker.from_env()
    except DockerException as exc:
        logger.warning("Docker unavailable: %s", exc)
        return None


def container_status(name: str) -> dict:
    client = _client()
    if not client:
        return {"name": name, "status": "unknown", "running": False}
    try:
        container = client.containers.get(name)
        state = container.status
        return {"name": name, "status": state, "running": state == "running"}
    except NotFound:
        return {"name": name, "status": "not found", "running": False}
    except DockerException as exc:
        return {"name": name, "status": str(exc), "running": False}


def all_service_status() -> list[dict]:
    return [
        container_status(EXIM_CONTAINER),
        container_status(DOVECOT_CONTAINER),
        container_status(ROUNDCUBE_CONTAINER),
    ]


def restart_mail_services() -> str:
    client = _client()
    if not client:
        raise RuntimeError("Docker socket not available")
    restarted = []
    for name in (EXIM_CONTAINER, DOVECOT_CONTAINER):
        try:
            client.containers.get(name).restart(timeout=30)
            restarted.append(name)
        except NotFound:
            raise RuntimeError(f"Container not found: {name}")
    return ", ".join(restarted)


def run_setup_dkim() -> str:
    client = _client()
    if not client:
        raise RuntimeError("Docker socket not available")
    try:
        container = client.containers.get(EXIM_CONTAINER)
    except NotFound:
        raise RuntimeError(f"Container not found: {EXIM_CONTAINER}")
    exit_code, output = container.exec_run("/scripts/setup-dkim.sh")
    text = output.decode("utf-8", errors="replace")
    if exit_code != 0:
        raise RuntimeError(text or "DKIM setup failed")
    return text


def read_dkim_record(domain: str, selector: str) -> str | None:
    client = _client()
    if not client:
        return None
    path = f"/etc/opendkim/keys/{domain}/{selector}.txt"
    try:
        container = client.containers.get(EXIM_CONTAINER)
        exit_code, output = container.exec_run(f"cat {path}")
        if exit_code != 0:
            return None
        return output.decode("utf-8", errors="replace").strip()
    except (NotFound, DockerException):
        return None

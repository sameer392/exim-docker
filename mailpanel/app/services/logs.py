import os
from pathlib import Path

from ..config import LOG_DIR

LOG_FILES = {
    "main": ("mainlog", "Main log — accepted, delivered, and routed mail"),
    "reject": ("rejectlog", "Reject log — rejected connections and ACL denials"),
    "panic": ("paniclog", "Panic log — critical Exim errors"),
}

DEFAULT_LINES = 200
MAX_LINES = 2000


def list_log_types() -> dict[str, str]:
    return {key: meta[1] for key, meta in LOG_FILES.items()}


def _log_path(log_type: str) -> Path:
    if log_type not in LOG_FILES:
        raise ValueError(f"Unknown log type: {log_type}")
    return LOG_DIR / LOG_FILES[log_type][0]


def _tail_file(path: Path, lines: int) -> list[str]:
    if not path.exists():
        return []

    with path.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            return []

        block = 8192
        data = b""
        while handle.tell() > 0 and data.count(b"\n") <= lines:
            read_size = min(block, handle.tell())
            handle.seek(-read_size, os.SEEK_CUR)
            data = handle.read(read_size) + data
            handle.seek(-read_size, os.SEEK_CUR)

    text = data.decode("utf-8", errors="replace")
    return text.splitlines()[-lines:]


def get_log_info(log_type: str) -> dict:
    path = _log_path(log_type)
    if not path.exists():
        return {"exists": False, "size": 0, "lines": 0}

    size = path.stat().st_size
    lines = 0
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            lines += chunk.count(b"\n")

    return {"exists": True, "size": size, "lines": lines}


def read_log_tail(log_type: str, lines: int = DEFAULT_LINES, query: str = "") -> dict:
    lines = max(1, min(int(lines), MAX_LINES))
    path = _log_path(log_type)
    entries = _tail_file(path, lines)

    if query:
        needle = query.lower()
        entries = [line for line in entries if needle in line.lower()]

    return {
        "log_type": log_type,
        "path": str(path),
        "entries": entries,
        "count": len(entries),
        "info": get_log_info(log_type),
    }


def clear_logs(log_types: list[str] | None = None) -> list[str]:
    cleared = []
    targets = log_types or list(LOG_FILES.keys())

    for log_type in targets:
        path = _log_path(log_type)
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.touch()
        with path.open("r+"):
            os.truncate(path.fileno(), 0)
        cleared.append(LOG_FILES[log_type][0])

    return cleared

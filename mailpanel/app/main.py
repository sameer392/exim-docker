from urllib.parse import quote

from fastapi import Depends, FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pathlib import Path

from .auth import create_session_token, is_authenticated, verify_admin_password
from .config import SESSION_COOKIE
from .services import docker_ops, logs, mail
from .urls import webmail_url

app = FastAPI(title="Mail Admin Panel", docs_url=None, redoc_url=None)

BASE_DIR = Path(__file__).resolve().parent
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")


def _log_line_class(line: str) -> str:
    lower = line.lower()
    if "**" in line or "error" in lower or "failed" in lower or "deferred" in lower or "rejected" in lower:
        return "log-error"
    if "=>" in line or "completed" in lower or "250 2.0.0 ok" in lower:
        return "log-ok"
    if "<=" in line:
        return "log-in"
    if "tls error" in lower or "panic" in lower:
        return "log-warn"
    return ""


templates.env.filters["log_class"] = _log_line_class


def render(request: Request, template: str, status_code: int = 200, **context):
    context.setdefault("webmail_url", webmail_url(request))
    context["request"] = request
    return templates.TemplateResponse(template, context, status_code=status_code)


def require_auth(request: Request):
    if not is_authenticated(request):
        return RedirectResponse("/login", status_code=303)
    return None


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if is_authenticated(request):
        return RedirectResponse("/", status_code=303)
    return render(request, "login.html", error=None)


@app.post("/login")
async def login_submit(request: Request, password: str = Form(...)):
    if verify_admin_password(password):
        response = RedirectResponse("/", status_code=303)
        response.set_cookie(SESSION_COOKIE, create_session_token(), httponly=True, samesite="lax")
        return response
    return render(request, "login.html", status_code=401, error="Invalid password")


@app.get("/logout")
async def logout():
    response = RedirectResponse("/login", status_code=303)
    response.delete_cookie(SESSION_COOKIE)
    return response


@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    if redirect := require_auth(request):
        return redirect
    info = mail.get_server_info()
    services = docker_ops.all_service_status()
    return render(
        request,
        "dashboard.html",
        info=info,
        services=services,
        message=request.query_params.get("msg"),
    )


@app.get("/domains", response_class=HTMLResponse)
async def domains_page(request: Request):
    if redirect := require_auth(request):
        return redirect
    domains = mail.list_domains()
    selector = mail.read_text_file(mail.DKIM_SELECTOR_FILE, "")
    dkim_records = {}
    for domain in domains:
        if selector:
            record = docker_ops.read_dkim_record(domain, selector)
            if record:
                dkim_records[domain] = record
    return render(
        request,
        "domains.html",
        domains=domains,
        dkim_records=dkim_records,
        selector=selector,
        hostname=mail.read_text_file(mail.PRIMARY_HOSTNAME_FILE, ""),
        message=request.query_params.get("msg"),
        error=request.query_params.get("error"),
    )


@app.post("/domains/add")
async def domains_add(request: Request, domain: str = Form(...)):
    if redirect := require_auth(request):
        return redirect
    try:
        mail.add_domain(domain)
        docker_ops.run_setup_dkim()
        docker_ops.restart_mail_services()
        return RedirectResponse(f"/domains?msg=Domain+{domain}+added", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/domains?error={quote(str(exc))}", status_code=303)


@app.post("/domains/delete")
async def domains_delete(request: Request, domain: str = Form(...)):
    if redirect := require_auth(request):
        return redirect
    try:
        mail.remove_domain(domain)
        docker_ops.restart_mail_services()
        return RedirectResponse(f"/domains?msg=Domain+{domain}+removed", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/domains?error={quote(str(exc))}", status_code=303)


@app.get("/users", response_class=HTMLResponse)
async def users_page(request: Request):
    if redirect := require_auth(request):
        return redirect
    return render(
        request,
        "users.html",
        users=mail.list_users(),
        domains=mail.list_domains(),
        message=request.query_params.get("msg"),
        error=request.query_params.get("error"),
    )


@app.post("/users/add")
async def users_add(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
):
    if redirect := require_auth(request):
        return redirect
    if password != confirm_password:
        return RedirectResponse("/users?error=Passwords+do+not+match", status_code=303)
    try:
        mail.upsert_user(email, password)
        docker_ops.restart_mail_services()
        return RedirectResponse(f"/users?msg=User+{email}+saved", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/users?error={quote(str(exc))}", status_code=303)


@app.post("/users/password")
async def users_password(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
):
    if redirect := require_auth(request):
        return redirect
    if password != confirm_password:
        return RedirectResponse("/users?error=Passwords+do+not+match", status_code=303)
    try:
        mail.upsert_user(email, password)
        docker_ops.restart_mail_services()
        return RedirectResponse(f"/users?msg=Password+updated+for+{email}", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/users?error={quote(str(exc))}", status_code=303)


@app.post("/users/delete")
async def users_delete(request: Request, email: str = Form(...)):
    if redirect := require_auth(request):
        return redirect
    try:
        mail.delete_user(email)
        docker_ops.restart_mail_services()
        return RedirectResponse(f"/users?msg=User+{email}+deleted", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/users?error={quote(str(exc))}", status_code=303)


@app.post("/services/restart")
async def services_restart(request: Request):
    if redirect := require_auth(request):
        return redirect
    try:
        names = docker_ops.restart_mail_services()
        return RedirectResponse(f"/?msg=Restarted:+{names}", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/?error={quote(str(exc))}", status_code=303)


@app.get("/logs", response_class=HTMLResponse)
async def logs_page(request: Request):
    if redirect := require_auth(request):
        return redirect

    log_type = request.query_params.get("type", "main")
    if log_type not in logs.LOG_FILES:
        log_type = "main"

    lines = int(request.query_params.get("lines", logs.DEFAULT_LINES))
    query = request.query_params.get("q", "").strip()
    info = logs.read_log_tail(log_type, lines=lines, query=query)

    return render(
        request,
        "logs.html",
        log_type=log_type,
        log_types=logs.list_log_types(),
        lines=lines,
        query=query,
        info=info,
        message=request.query_params.get("msg"),
        error=request.query_params.get("error"),
    )


@app.get("/logs/data")
async def logs_data(request: Request):
    if redirect := require_auth(request):
        return redirect

    log_type = request.query_params.get("type", "main")
    if log_type not in logs.LOG_FILES:
        log_type = "main"

    lines = int(request.query_params.get("lines", logs.DEFAULT_LINES))
    query = request.query_params.get("q", "").strip()
    return logs.read_log_tail(log_type, lines=lines, query=query)


@app.post("/logs/clear")
async def logs_clear(request: Request):
    if redirect := require_auth(request):
        return redirect
    try:
        cleared = logs.clear_logs()
        names = ", ".join(cleared)
        return RedirectResponse(f"/logs?msg=Cleared:+{quote(names)}", status_code=303)
    except Exception as exc:
        return RedirectResponse(f"/logs?error={quote(str(exc))}", status_code=303)

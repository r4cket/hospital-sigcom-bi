# -*- coding: utf-8 -*-
"""
Renderiza el tablero de Grafana como PNG (via el servicio 'renderer') y lo
envia por correo. Pensado para correr desde cron dentro del contenedor.

Variables de entorno:
  GRAFANA_URL        http://grafana:3000
  GRAFANA_USER       admin
  GRAFANA_PASSWORD   (= GF_ADMIN_PASSWORD)
  DASHBOARD_UID      hospital-financial-kpis
  DASHBOARD_SLUG     kpis-financieros
  REPORT_FROM        now-13M         (rango temporal del tablero)
  REPORT_TO          now
  REPORT_TZ          America/Santiago
  REPORT_WIDTH       1400
  REPORT_HEIGHT      3600
  SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASSWORD
  MAIL_FROM          bi-hospital@dominio.cl
  MAIL_TO            a@h.cl, b@h.cl
"""
import datetime as dt
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage

import requests

GRAFANA_URL = os.environ.get("GRAFANA_URL", "http://grafana:3000").rstrip("/")
GRAFANA_USER = os.environ.get("GRAFANA_USER", "admin")
GRAFANA_PASSWORD = os.environ.get("GRAFANA_PASSWORD", "")
DASHBOARD_UID = os.environ.get("DASHBOARD_UID", "hospital-financial-kpis")
DASHBOARD_SLUG = os.environ.get("DASHBOARD_SLUG", "kpis-financieros")

RANGE_FROM = os.environ.get("REPORT_FROM", "now-13M")
RANGE_TO = os.environ.get("REPORT_TO", "now")
TZPARAM = os.environ.get("REPORT_TZ", "America/Santiago")
WIDTH = os.environ.get("REPORT_WIDTH", "1400")
HEIGHT = os.environ.get("REPORT_HEIGHT", "3600")

SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
MAIL_FROM = os.environ.get("MAIL_FROM", "")
MAIL_TO = [x.strip() for x in os.environ.get("MAIL_TO", "").split(",") if x.strip()]


def fail(msg):
    print(f"[reporter] ERROR: {msg}", flush=True)
    sys.exit(1)


def render_png():
    url = f"{GRAFANA_URL}/render/d/{DASHBOARD_UID}/{DASHBOARD_SLUG}"
    params = {
        "orgId": "1",
        "kiosk": "true",
        "width": WIDTH,
        "height": HEIGHT,
        "tz": TZPARAM,
        "from": RANGE_FROM,
        "to": RANGE_TO,
    }
    r = requests.get(url, params=params, auth=(GRAFANA_USER, GRAFANA_PASSWORD), timeout=180)
    if r.status_code != 200:
        fail(f"Grafana /render devolvio {r.status_code}: {r.text[:300]}")
    if "image" not in r.headers.get("Content-Type", ""):
        fail(f"Grafana no devolvio imagen ({r.headers.get('Content-Type')}): {r.text[:300]}")
    return r.content


def send(png):
    if not (SMTP_HOST and MAIL_FROM and MAIL_TO):
        fail("faltan SMTP_HOST / MAIL_FROM / MAIL_TO")
    periodo = dt.date.today().strftime("%Y-%m")
    msg = EmailMessage()
    msg["Subject"] = f"KPIs Financieros - Hospital San Jose de Coronel - {periodo}"
    msg["From"] = MAIL_FROM
    msg["To"] = ", ".join(MAIL_TO)
    msg.set_content(
        "Adjunto el tablero de KPIs financieros SIGCOM (Cubo 9) del periodo.\n\n"
        "Generado automaticamente por el servicio 'reporter'.\n"
    )
    msg.add_attachment(png, maintype="image", subtype="png",
                       filename=f"kpis-financieros-{periodo}.png")

    ctx = ssl.create_default_context()
    if SMTP_PORT == 465:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=ctx, timeout=60) as s:
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PASSWORD)
            s.send_message(msg)
    else:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=60) as s:
            s.ehlo()
            try:
                s.starttls(context=ctx)
                s.ehlo()
            except smtplib.SMTPNotSupportedError:
                pass
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PASSWORD)
            s.send_message(msg)


if __name__ == "__main__":
    print(f"[reporter] {dt.datetime.now().isoformat(timespec='seconds')} render {DASHBOARD_UID} "
          f"({RANGE_FROM}..{RANGE_TO})", flush=True)
    img = render_png()
    print(f"[reporter] PNG {len(img)} bytes -> enviando a {MAIL_TO}", flush=True)
    send(img)
    print("[reporter] enviado", flush=True)

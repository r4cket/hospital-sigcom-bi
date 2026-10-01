#!/bin/sh
set -e
: "${REPORT_CRON:=0 8 5 * *}"

# Disparo manual:  docker compose -f docker-compose.full.yml run --rm reporter now
if [ "$1" = "now" ]; then
  exec python /app/send_report.py
fi

# cron arranca con un entorno minimo: volcamos las variables que necesita el job.
printenv \
  | grep -E '^(GRAFANA_|SMTP_|MAIL_|REPORT_|DASHBOARD_|TZ)=' \
  | sed 's/=/="/; s/$/"/; s/^/export /' > /app/env.sh
touch /var/log/report.log

{
  echo "TZ=${TZ:-America/Santiago}"
  echo "$REPORT_CRON root . /app/env.sh; /usr/local/bin/python /app/send_report.py >> /var/log/report.log 2>&1"
} > /etc/cron.d/report
chmod 0644 /etc/cron.d/report

echo "reporter activo | cron: '$REPORT_CRON' | zona: ${TZ:-?}"
echo "prueba: docker compose -f docker-compose.full.yml run --rm reporter now"
cron
exec tail -f /var/log/report.log

#!/bin/sh
set -e

mkdir -p /incoming /processed /failed
: "${MODE:=watch}"

if [ "$MODE" = "oneshot" ]; then
  exec python /app/load_sigcom.py --xlsx "${XLSX:-/incoming/Dashboard_SIGCOM.xlsx}"
fi

echo "loader en modo watch: vigilando /incoming/*.xlsx cada ${POLL_SECONDS:-30}s"
exec python /app/watch.py

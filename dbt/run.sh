#!/bin/sh
# Ejecuta dbt. Sin argumentos -> "dbt build" (corre modelos + todas las pruebas).
#   docker compose -f docker-compose.full.yml --profile quality run --rm dbt
#   docker compose -f docker-compose.full.yml --profile quality run --rm dbt test
set -e
cd /dbt
dbt debug --no-version-check || true
if [ "$#" -eq 0 ]; then
  set -- build
fi
exec dbt "$@"

# Stack completo con Docker

Extiende el despliegue base (Postgres + Grafana + Caddy) con tres piezas que
convierten el tablero en un **pipeline de costos**:

| Servicio | Qué hace | Cómo se usa |
|---|---|---|
| **loader** | Carga automática del Cubo 9. Dejas el `.xlsx` en `data/incoming/` y lo sube solo a Postgres (esquema + datos), controlando la cuadratura RH+GG+Insumos+Indirecto vs. el total del Excel. | Copiar el archivo a `deploy/data/incoming/`. |
| **dbt** | Pruebas de calidad de datos sobre la base. Falla si algo no cuadra; avisa (`warn`) en las anomalías conocidas. | `docker compose -f docker-compose.full.yml --profile quality run --rm dbt` |
| **renderer** + **reporter** | `renderer` es el motor de imágenes de Grafana; `reporter` renderiza el tablero como PNG y lo envía por correo según un cron. | Automático (cron). Prueba: `... run --rm reporter now` |

> **Requiere una máquina con Docker** (una VM/VPS: Oracle Cloud *Always Free*,
> un servidor del hospital, etc.). En este PC Windows sigue sin poder correr
> Docker porque las funciones de virtualización están desactivadas — eso no
> cambió. La gracia del `compose` es que en la VM "solo funciona".

---

## Puesta en marcha

```bash
cd deploy
cp .env.full.example .env      # y completar (claves nuevas, dominio, SMTP)
docker compose -f docker-compose.full.yml up -d
```

Levanta: `postgres`, `grafana`, `renderer`, `caddy`, `loader`, `reporter`.
En el primer arranque Postgres se siembra con `postgres/init/01_schema.sql` +
`02_data.sql`. Después, los datos los refresca el `loader`.

Ver estado / logs:

```bash
docker compose -f docker-compose.full.yml ps
docker compose -f docker-compose.full.yml logs -f loader
```

---

## 1) Carga automática (loader)

Cuando llegue un Cubo 9 nuevo:

```bash
cp "Dashboard_SIGCOM (11).xlsx" deploy/data/incoming/
```

El `loader` lo detecta cuando el tamaño se estabiliza, reaplica
`01_schema.sql` (borra y recrea) + inserta todo, y mueve el archivo a
`data/processed/AAAAMMDD-HHMMSS_<nombre>.xlsx`. Si algo falla, va a
`data/failed/` y el log dice por qué. Grafana lee en vivo: no hay que
redeployar nada.

- `POLL_SECONDS` (env): cada cuánto revisa la carpeta. Default 30 s.
- `STRICT=1` (env): si RH+GG+Insumos+Indirecto no cuadra con el `total` del
  Excel (diferencia > $1) en alguna fila, la carga se marca como fallida.
  Con `STRICT=0` (default) igual carga, pero deja los avisos en el log.
- Carga puntual sin esperar el watcher:
  ```bash
  docker compose -f docker-compose.full.yml run --rm -e MODE=oneshot \
    -v "$PWD/una-carpeta:/incoming" loader
  ```

Hojas que espera el Excel: `Base_Insumos` (obligatoria) y `Ranking_CC`
(clasificación Final/Apoyo; opcional).

---

## 2) Pruebas de calidad (dbt)

```bash
docker compose -f docker-compose.full.yml --profile quality run --rm dbt
# o solo las pruebas, sin reconstruir modelos:
docker compose -f docker-compose.full.yml --profile quality run --rm dbt test
```

`dbt build` construye el modelo de ejemplo `mart_gasto_hospital` (migración a
dbt del view `v_gasto_hospital`, en el esquema `analytics`) y corre **todas**
las pruebas. Si alguna con severidad `error` falla, el comando termina con
código ≠ 0 — sirve como *gate* antes de dar por buena una carga.

Pruebas incluidas:

| Prueba | Severidad | Qué vigila |
|---|---|---|
| `unique` / `not_null` en claves, `relationships` | error | Integridad básica de las 3 tablas. |
| `accepted_values` en `tipo` y `clasificacion` | error | Que la carga no invente categorías. |
| `assert_costo_directo_consistente` | error | `costo_directo` == RH+GG+Insumos exacto. |
| `assert_costos_no_negativos` | error | Ningún componente de costo < 0. |
| `assert_una_fila_por_cc_y_periodo` | error | Sin duplicados (CC, mes). |
| `assert_produccion_para_cada_costo` | error | Todo mes con costo tiene su fila de producción. |
| `assert_gasto_cuadra` | error | El total del mart = suma de sus componentes. |
| `warn_ocupacion_plausible` | **warn** | Ocupación > 200% (probable `camas_dotacion` mal cargada). 100–200% se tolera: es el hallazgo real de sobreocupación. |
| `warn_cc_externo_sin_costo_directo` | **warn** | El "Centro de Costos Externo" cargando costo directo propio (anomalía de imputación conocida desde 2025). |

Para migrar más vistas a dbt: agregar un `.sql` en `dbt/models/` con la lógica
del view y su `not_null`/`unique` en `dbt/models/schema.yml`. Después se puede
apuntar Grafana al esquema `analytics` en vez de `public`.

---

## 3) Reporte por correo (reporter)

El `reporter` corre un cron (`REPORT_CRON`, default `0 8 5 * *` = 08:00 del día
5). Cada disparo:

1. Pide a Grafana `/render/d/<uid>` — Grafana usa el servicio `renderer` para
   generar un PNG del tablero completo (rango `REPORT_FROM..REPORT_TO`).
2. Lo manda por correo (`MAIL_TO`) vía el SMTP configurado.

Configuración en `.env`: `SMTP_HOST/PORT/USER/PASSWORD`, `MAIL_FROM`,
`MAIL_TO` (lista separada por comas), `REPORT_CRON`, `REPORT_TZ`.

Prueba inmediata (no espera al cron):

```bash
docker compose -f docker-compose.full.yml run --rm reporter now
```

Ver ejecuciones del cron: `docker compose -f docker-compose.full.yml logs -f reporter`.

> Grafana OSS no trae "Reporting" (es de Enterprise/Cloud); por eso el
> `reporter` hace el render + envío por su cuenta. Si más adelante quieres
> PDF en vez de PNG, se arma con varias páginas del render o con un
> `wkhtmltopdf`/`img2pdf` en el mismo contenedor.

---

## Qué NO cambia

- El despliegue gratis de `DESPLIEGUE-GRATIS.md` (Neon + Render) sigue igual y
  no necesita nada de esto.
- `docker-compose.yml` (el simple) queda tal cual como opción mínima.
- El tablero (`grafana/provisioning/dashboards/hospital_kpis.json`) es el mismo.

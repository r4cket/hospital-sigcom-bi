# Publicar el dashboard en internet — costo $0

Enlace público, de **solo lectura** (los visitantes ven, no editan ni
necesitan login), sin tarjeta de crédito.

Arquitectura: **Neon** hospeda la base Postgres · **Render** hospeda Grafana
como contenedor sin estado (el dashboard y la conexión van dentro de la
imagen, así el tier gratis sirve sin disco persistente).

```
  Visitante ──HTTPS──> Grafana (Render, gratis) ──SSL──> Postgres (Neon, gratis)
```

---

## Antes de empezar

Los datos son del Cubo 9 SIGCOM **agregados por centro de costo y mes**
(costos, producción, días cama). No hay información de pacientes ni datos
personales — es información de gestión.

**Claves.** No uses las de ejemplo (`cambia_esta_clave...`). Genera dos
claves largas nuevas: una para el admin de Grafana, otra para Postgres.
La única credencial que da control total es `GF_SECURITY_ADMIN_PASSWORD`.

---

## Paso 1 — Base de datos en Neon (5 min)

1. Entra a **https://neon.tech** → *Sign up* con GitHub (sin tarjeta).
2. *Create project* → región la más cercana (p. ej. AWS `us-east-2` o
   `sa-east-1` São Paulo) → nombre `hospital-bi`.
3. Te muestra una **connection string**. Anota estos datos (los pide Render):
   - Host: algo como `ep-cool-name-123456.us-east-2.aws.neon.tech`
   - Database: `neondb` (el que venga)
   - User / Password: los que venga
   - Puerto: `5432` · SSL: `require`
4. Abre **SQL Editor** (menú izquierdo) y ejecuta, en este orden, el
   contenido de:
   - `deploy/postgres/init/01_schema.sql`
   - `deploy/postgres/init/02_data.sql`
   (copia-pega cada archivo completo y *Run*. El 02 es largo pero corre en
   segundos.)
5. Verifica con:
   ```sql
   SELECT count(*) FROM centros_costo;      -- 36
   SELECT count(*) FROM costos_mensuales;   -- 1004
   ```

## Paso 2 — Grafana en Render (10 min)

Necesitas este proyecto en un repo Git (GitHub/GitLab). Si no lo tienes:
crea un repo, sube la carpeta del proyecto (con `deploy/` dentro).

1. Entra a **https://render.com** → *Sign up* con GitHub (sin tarjeta).
2. *New* → *Web Service* → conecta el repo.
3. Configura:
   - **Root Directory**: `deploy`
   - **Runtime**: `Docker`
   - **Instance Type**: `Free`
4. En **Environment** agrega estas variables:

   | Key | Value |
   |---|---|
   | `GF_SECURITY_ADMIN_PASSWORD` | tu clave admin nueva |
   | `GF_SERVER_ROOT_URL` | `https://EL-NOMBRE-QUE-ELIJAS.onrender.com` |
   | `GF_SERVER_HTTP_PORT` | `10000` |
   | `PG_HOST` | el host de Neon |
   | `PG_PORT` | `5432` |
   | `PG_DATABASE` | la db de Neon |
   | `PG_USER` | el user de Neon |
   | `PG_PASSWORD` | el password de Neon |
   | `PG_SSLMODE` | `require` |

5. *Create Web Service*. El primer build tarda ~3-5 min.
6. Abre `https://EL-NOMBRE.onrender.com` → carga el dashboard directo
   (acceso anónimo Viewer). Para administrar: `/login` con `admin` + tu clave.

   > Si `GF_SERVER_ROOT_URL` quedó con otro nombre, corrígelo en Environment
   > y *Manual Deploy* de nuevo.

## Paso 3 — Actualizar datos cada mes

Cuando llegue un Cubo 9 nuevo:
1. En tu PC: reemplaza `Dashboard_SIGCOM.xlsx`, corre `py load_excel.py`
   (genera `sql_real/02_data.sql`), cópialo a `deploy/postgres/init/02_data.sql`.
2. En Neon SQL Editor: ejecuta `01_schema.sql` (borra y recrea) y luego el
   nuevo `02_data.sql`.
3. Grafana lee la base en vivo — no hay que redeployar nada.

---

## Límites del tier gratis (aceptables para mostrar un enlace)

- **Render free**: el servicio se **duerme tras 15 min sin visitas**; la
  primera visita después tarda ~50 s en despertar. Luego va fluido.
- **Neon free**: la base se **autosuspende** por inactividad y despierta en
  ~1 s en la primera consulta. 0,5 GB de almacenamiento (usamos < 10 MB).
- Sin tarjeta, sin vencimiento.

## Endurecimiento (ya viene aplicado en el Dockerfile)

- Acceso anónimo = **Viewer** (ven, no editan). Sign-up desactivado.
- Snapshots externos desactivados, analytics/telemetría off, gravatar off,
  cookie `Secure`.
- La única credencial sensible es `GF_SECURITY_ADMIN_PASSWORD` → que sea
  larga y no se comparta.
- Render sirve HTTPS por defecto en `*.onrender.com`.

---

## Alternativas gratis equivalentes

- **Grafana en Hugging Face Spaces** (Docker Space, público, sin tarjeta):
  igual que Render pero el puerto es `7860` → pon `GF_SERVER_HTTP_PORT=7860`
  y `GF_SERVER_ROOT_URL=https://<usuario>-<space>.hf.space`.
- **Koyeb** free: mismo Dockerfile, un servicio web gratis.
- **VM gratis** (Oracle Cloud *Always Free*): usa `deploy/docker-compose.yml`
  + `deploy/Caddyfile` + un dominio. Todo en una máquina, sin dormirse.
  Pide tarjeta para verificación (no cobra) y Oracle puede reclamar
  instancias ociosas.

## Si NO puedes/quieres backend (100 % estático)

- Grafana → *Share* → *Export* → *Save to file* de cada panel, o capturas
  por sección, y súbelas a **GitHub Pages** o **Netlify Drop** (gratis).
  Datos congelados, cero mantención, cero servidor.

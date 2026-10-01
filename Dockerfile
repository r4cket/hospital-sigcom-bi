# Grafana "sin estado": el dashboard y la conexion a Postgres van horneados
# en la imagen via provisioning. No necesita disco persistente -> corre en
# el tier gratis de Render / Hugging Face Spaces / Railway / Koyeb.
FROM grafana/grafana-oss:11.2.0

COPY grafana/provisioning /etc/grafana/provisioning

# --- Acceso publico de solo lectura + endurecimiento ---
ENV GF_AUTH_ANONYMOUS_ENABLED=true \
    GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
    GF_AUTH_ANONYMOUS_ORG_NAME="Main Org." \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_USERS_VIEWERS_CAN_EDIT=false \
    GF_SNAPSHOTS_EXTERNAL_ENABLED=false \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false \
    GF_SECURITY_DISABLE_GRAVATAR=true \
    GF_SECURITY_COOKIE_SECURE=true \
    GF_NEWS_NEWS_FEED_ENABLED=false \
    GF_SERVER_HTTP_PORT=3000

# En runtime hay que pasar (como env / secrets del proveedor):
#   GF_SECURITY_ADMIN_PASSWORD   -> clave admin real (NO la de ejemplo)
#   GF_SERVER_ROOT_URL           -> https://<tu-app>.onrender.com  (o la que sea)
#   PG_HOST PG_PORT PG_DATABASE PG_USER PG_PASSWORD PG_SSLMODE  -> datos de Neon
#   GF_SERVER_HTTP_PORT          -> 10000 en Render, 7860 en HF Spaces (si aplica)

EXPOSE 3000

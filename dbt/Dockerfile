FROM python:3.12-slim

WORKDIR /dbt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x run.sh

ENV DBT_PROFILES_DIR=/dbt \
    DBT_SEND_ANONYMOUS_USAGE_STATS=0

ENTRYPOINT ["/dbt/run.sh"]

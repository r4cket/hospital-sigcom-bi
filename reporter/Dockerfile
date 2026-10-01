FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends cron tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY send_report.py entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENV REPORT_CRON="0 8 5 * *" \
    TZ=America/Santiago

ENTRYPOINT ["./entrypoint.sh"]

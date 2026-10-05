# ============================================================
# SERVIÇO PROCESSADOR — segundo backend, chamado pela API
# Não publica porta: só é alcançável de dentro da rede do Compose.
# ============================================================

FROM python:3.11 AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt


FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=1.0.0

RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

COPY --chown=appuser:appuser ./src ./src

USER appuser
EXPOSE 8001

HEALTHCHECK --interval=15s --timeout=3s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8001/api/health').status==200 else 1)"

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8001", "--access-logfile", "-", "src.app:app"]

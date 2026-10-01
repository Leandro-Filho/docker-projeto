# ============================================================
# BACKEND - FastAPI em PRODUÇÃO
# ============================================================

FROM python:3.11 AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt


FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

COPY --chown=appuser:appuser ./app ./app

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

# Em produção: uvicorn com workers (ou gunicorn com worker uvicorn).
# --host 0.0.0.0 é obrigatório. NÃO use --reload em produção.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]

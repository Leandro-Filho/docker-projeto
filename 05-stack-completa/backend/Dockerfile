# ============================================================
# BACKEND (produção) — Flask + gunicorn, multi-stage
# ============================================================

# ---------- ESTÁGIO 1: BUILD ----------
# Imagem completa: tem o compilador e os headers que o psycopg2 pode precisar.
# Pode rodar como root — esta imagem NÃO vai para produção.
FROM python:3.11 AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt


# ---------- ESTÁGIO 2: RUNTIME ----------
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Usuário sem privilégio (menor privilégio)
RUN useradd --create-home --uid 1000 appuser

WORKDIR /app

# Só as dependências instaladas; compilador fica no estágio 1
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Código por último: muda mais, então fica no topo do cache
COPY --chown=appuser:appuser ./src ./src

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

# NOTA: src/ tem um __init__.py para ser um pacote Python — é o que permite
# o gunicorn resolver "src.app:app". Sem ele, dá ModuleNotFoundError.
#
# gunicorn = servidor de PRODUÇÃO (o embutido do Flask é só para dev).
# -b 0.0.0.0:8000 é obrigatório em container.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "--access-logfile", "-", "src.app:app"]

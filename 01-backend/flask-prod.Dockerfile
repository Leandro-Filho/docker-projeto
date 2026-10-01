# ============================================================
# BACKEND - Flask em PRODUÇÃO (gunicorn), multi-stage
# ============================================================

# ---------- ESTÁGIO 1: BUILD ----------
# Imagem completa: tem compilador e headers que psycopg2/numpy podem precisar.
# Pode ser root — esta imagem NÃO vai para produção.
FROM python:3.11 AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt


# ---------- ESTÁGIO 2: RUNTIME ----------
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Usuário sem privilégio: a imagem de build pode ser root, a de run não precisa
RUN useradd --create-home --uid 1000 appuser

WORKDIR /app

# Só as dependências instaladas — compilador fica no estágio 1
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Código por último (muda mais -> fica no topo do cache)
COPY --chown=appuser:appuser ./src ./src

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

# ATENÇÃO: para "src.app:app" funcionar, a pasta src/ precisa ter um
# __init__.py (ser um pacote Python). Sem ele:
#   ModuleNotFoundError: No module named 'src'
# Alternativa sem __init__.py:
#   CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8000", "--chdir", "src", "app:app"]
#
# gunicorn: servidor de PRODUÇÃO (o embutido do Flask é só para dev)
#   -w 4            4 workers
#   -b 0.0.0.0:8000 ouve em todas as interfaces (obrigatório em container)
#   --access-logfile -   log em stdout
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8000", "--access-logfile", "-", "src.app:app"]

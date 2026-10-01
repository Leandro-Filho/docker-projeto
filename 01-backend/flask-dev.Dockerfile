# ============================================================
# BACKEND - Flask em DESENVOLVIMENTO (com reload)
# Use com bind mount do código no compose de dev
# ============================================================

FROM python:3.11

ENV PYTHONUNBUFFERED=1 \
    FLASK_DEBUG=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# NÃO copia o código: ele vem por BIND MOUNT no compose de dev,
# para que editar na minha máquina reflita na hora.

EXPOSE 8000

# --reload reinicia o servidor quando um arquivo muda
CMD ["flask", "--app", "src/app.py", "run", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ============================================================
# EXERCÍCIO 2 (fácil) — ordem das instruções e cache
#
# O Dockerfile abaixo FUNCIONA, mas tem um problema de desempenho:
# cada mudança no código reinstala todas as dependências.
#
# TAREFA:
#   a) Identifique qual é o problema e por que ele acontece.
#   b) Reescreva as linhas na ordem correta.
#   c) Explique a regra geral em uma frase.
# ============================================================

FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# ---- O PROBLEMA ESTÁ NESTAS DUAS LINHAS ----
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
# --------------------------------------------

EXPOSE 8000

CMD ["python", "src/app.py"]


# RESPONDA AQUI:
#
# a) Qual o problema?
#    ______________________________________________________________
#
# b) Ordem correta:
#    ______________________________________________________________
#    ______________________________________________________________
#    ______________________________________________________________
#
# c) A regra geral:
#    ______________________________________________________________

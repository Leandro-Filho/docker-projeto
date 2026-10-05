# ============================================================
# EXERCÍCIO 7 (difícil) — ache os 8 erros
#
# Este Dockerfile tem OITO problemas. Alguns impedem o container
# de funcionar; outros são más práticas. Encontre todos e explique.
#
# Contexto: backend Flask, código em src/, ouve na porta 8000,
# vai para produção.
# ============================================================

FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y python3 python3-pip
RUN apt-get install -y gcc build-essential

ENV API_TOKEN=ghp_abc123segredoreal

WORKDIR /app

ADD . /app

RUN pip3 install -r requirements.txt --break-system-packages

EXPOSE 8000

USER root

CMD python3 src/app.py &


# OS 8 ERROS:
#
# 1. ______________________________________________________________
# 2. ______________________________________________________________
# 3. ______________________________________________________________
# 4. ______________________________________________________________
# 5. ______________________________________________________________
# 6. ______________________________________________________________
# 7. ______________________________________________________________
# 8. ______________________________________________________________
#
# Agora reescreva o Dockerfile corrigido:

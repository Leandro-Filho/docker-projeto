# ============================================================
# EXERCÍCIO 5 (médio) — segurança e observabilidade
#
# Este Dockerfile funciona, mas tem 4 problemas de segurança
# e falta 1 recurso de observabilidade.
#
# TAREFA: identifique os 5 pontos e corrija.
# ============================================================

FROM python:latest

ENV PYTHONUNBUFFERED=1
ENV DB_PASSWORD=senha_super_secreta_123

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

EXPOSE 8000

CMD python src/app.py


# OS 5 PONTOS (identifique e corrija):
#
# 1. ______________________________________________________________
#    correção: _____________________________________________________
#
# 2. ______________________________________________________________
#    correção: _____________________________________________________
#
# 3. ______________________________________________________________
#    correção: _____________________________________________________
#
# 4. ______________________________________________________________
#    correção: _____________________________________________________
#
# 5. (falta um recurso) ___________________________________________
#    correção: _____________________________________________________

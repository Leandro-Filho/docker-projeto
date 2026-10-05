# ============================================================
# EXERCÍCIO 3 (médio) — multi-stage build
#
# Objetivo: a imagem final NÃO deve conter o compilador nem as
# ferramentas de build, apenas o necessário para EXECUTAR.
#
# Preencha as 7 lacunas.
# ============================================================

# ---------- ESTÁGIO 1: BUILD ----------
# [ ? 1 ] — imagem Python 3.11 COMPLETA (tem compilador), nomeada "builder"
____________________

WORKDIR /build

COPY requirements.txt .

# [ ? 2 ] — instale as dependências em ~/.local (para poder copiar depois)
#           dica: a flag é --user
____________________


# ---------- ESTÁGIO 2: RUNTIME ----------
# [ ? 3 ] — imagem Python 3.11 ENXUTA
____________________

ENV PYTHONUNBUFFERED=1

# [ ? 4 ] — crie um usuário sem privilégio chamado appuser, uid 1000
____________________

WORKDIR /app

# [ ? 5 ] — traga SÓ as dependências instaladas do estágio builder
#           origem: /root/.local   destino: /home/appuser/.local
____________________

# [ ? 6 ] — ajuste o PATH para encontrar os binários instalados
____________________

COPY --chown=appuser:appuser ./src ./src

# [ ? 7 ] — passe a rodar como o usuário sem privilégio
____________________

EXPOSE 8000

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "src.app:app"]


# PERGUNTAS DE FECHAMENTO:
#   1. O que atravessou do estágio 1 para o 2? ________________________
#   2. O que ficou para trás?                 ________________________
#   3. Duas vantagens da imagem final:        ________________________

# ============================================================
# EXERCÍCIO 1 (fácil) — estrutura mínima de um backend Flask
#
# Contexto: a pasta tem requirements.txt e src/app.py.
# A aplicação ouve na porta 8000.
# Preencha as 6 lacunas.
# ============================================================

# [ ? 1 ] — defina a imagem base: Python 3.11, variante enxuta, versão fixada
____________________

# Logs sem buffer (aparecem na hora no docker logs)
ENV PYTHONUNBUFFERED=1

# [ ? 2 ] — defina o diretório de trabalho como /app
____________________

# [ ? 3 ] — copie SÓ o arquivo de dependências (ainda não o código)
____________________

# [ ? 4 ] — instale as dependências sem guardar cache
____________________

# Agora o código
COPY ./src ./src

# [ ? 5 ] — documente que a aplicação usa a porta 8000
____________________

# [ ? 6 ] — comando de início, na forma exec, rodando src/app.py
____________________

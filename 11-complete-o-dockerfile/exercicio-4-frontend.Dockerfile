# ============================================================
# EXERCÍCIO 4 (médio) — front React/Vite servido por nginx
#
# Contexto: o projeto tem package.json e package-lock.json.
# "npm run build" gera a pasta dist/.
# Há um nginx.conf na pasta, com try_files e proxy_pass.
#
# Preencha as 6 lacunas.
# ============================================================

# ---------- ESTÁGIO 1: BUILD ----------
# [ ? 1 ] — imagem Node 20 alpine, nomeada "builder"
____________________

WORKDIR /app

# [ ? 2 ] — copie os manifestos (os DOIS arquivos) antes do código
____________________

# [ ? 3 ] — instale as dependências de forma reprodutível
#           dica: NÃO é "npm install"
____________________

COPY . .

# [ ? 4 ] — gere os arquivos estáticos
____________________


# ---------- ESTÁGIO 2: RUNTIME ----------
FROM nginx:1.27-alpine

# [ ? 5 ] — traga SÓ a pasta dist/ do estágio builder para a raiz do nginx
#           destino: /usr/share/nginx/html
____________________

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# [ ? 6 ] — comando de início. CUIDADO: o nginx precisa rodar em
#           FOREGROUND, senão o container morre na hora. Qual a flag?
____________________


# PERGUNTAS DE FECHAMENTO:
#   1. Por que o Node NÃO vai para a imagem final? ___________________
#   2. O que o try_files do nginx.conf resolve?     ___________________
#   3. O que o proxy_pass resolve?                  ___________________

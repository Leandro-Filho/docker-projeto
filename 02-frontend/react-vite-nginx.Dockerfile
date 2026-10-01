# ============================================================
# FRONTEND - React/Vite (SPA) servido por nginx
# O caso mais comum. Multi-stage obrigatório.
# ============================================================

# ---------- ESTÁGIO 1: BUILD ----------
FROM node:20-alpine AS builder

WORKDIR /app

# package*.json primeiro: aproveita o cache de camadas.
# npm ci usa o package-lock.json (build reprodutível).
COPY package*.json ./
RUN npm ci

# ---- OPÇÃO A: URL da API via build-arg ----
# Descomente SÓ se NÃO estiver usando proxy reverso.
# Lembre: a variável é COZIDA no bundle agora, no build.
# ARG VITE_API_URL=/api
# ENV VITE_API_URL=$VITE_API_URL

COPY . .

# TRANSPILAÇÃO + BUNDLING: TypeScript/JSX -> JavaScript padrão.
# Gera a pasta dist/ com os estáticos.
RUN npm run build


# ---------- ESTÁGIO 2: RUNTIME ----------
FROM nginx:1.27-alpine

# Só os ESTÁTICOS. Node, npm, node_modules e o código fonte ficam para trás.
# Resultado: imagem de ~25-30 MB em vez de ~400 MB.
COPY --from=builder /app/dist /usr/share/nginx/html

# Configuração com try_files (rotas do SPA) e proxy_pass (API)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/nginx-health || exit 1

# "daemon off" é ESSENCIAL: o nginx precisa rodar em FOREGROUND para ser o PID 1.
# Se virar daemon, o processo principal termina e o container morre na hora.
CMD ["nginx", "-g", "daemon off;"]

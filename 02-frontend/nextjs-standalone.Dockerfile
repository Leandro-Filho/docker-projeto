# ============================================================
# FRONTEND - Next.js com SSR (output standalone)
# Diferente do SPA: o runtime é NODE, não nginx
#
# PRÉ-REQUISITO em next.config.js:
#   module.exports = { output: 'standalone' }
# ============================================================

# ---------- ESTÁGIO 1: dependências ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci


# ---------- ESTÁGIO 2: build ----------
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# ATENÇÃO: NEXT_PUBLIC_* é COZIDO aqui, no build.
# Para o código client-side, use caminho relativo (/api) e proxy,
# ou passe via build-arg.
# ARG NEXT_PUBLIC_API_URL=/api
# ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build


# ---------- ESTÁGIO 3: runtime ----------
FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# O output "standalone" já traz só o necessário, inclusive as deps usadas
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

USER node
EXPOSE 3000

# HOSTNAME=0.0.0.0 acima é o equivalente ao --host dos outros
CMD ["node", "server.js"]

# ------------------------------------------------------------
# LEMBRETE sobre Next.js em Docker:
#   - código SERVER-SIDE (getServerSideProps, route handlers)
#     PODE usar http://api:8000   (roda no container)
#   - código CLIENT-SIDE (useEffect, fetch no componente)
#     NÃO pode usar api:8000      (roda no navegador)
#   É o mesmo projeto com duas realidades de rede.
# ------------------------------------------------------------

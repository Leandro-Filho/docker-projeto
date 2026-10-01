# ============================================================
# BACKEND - Node/Express (ou NestJS)
# ============================================================

# ---------- ESTÁGIO 1: dependências de PRODUÇÃO ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# npm ci usa o package-lock (build reprodutível)
# --omit=dev deixa devDependencies de fora
RUN npm ci --omit=dev


# ---------- ESTÁGIO 2 (só se houver build, ex. TypeScript/NestJS) ----------
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build


# ---------- ESTÁGIO 3: RUNTIME ----------
FROM node:20-alpine

ENV NODE_ENV=production

WORKDIR /app

# node:alpine já traz um usuário "node" sem privilégio
COPY --from=deps  --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --chown=node:node package*.json ./

USER node
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8000/api/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# node direto, não nodemon (nodemon é de desenvolvimento)
CMD ["node", "dist/main.js"]

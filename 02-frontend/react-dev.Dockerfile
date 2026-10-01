# ============================================================
# FRONTEND - React/Vite em DESENVOLVIMENTO (hot reload)
# Use com bind mount no compose de dev
# ============================================================

FROM node:20-alpine

WORKDIR /app

# Instala as dependências DENTRO do container (Linux).
# O volume anônimo no compose protege esta pasta de ser sobrescrita
# pelo node_modules da minha máquina.
COPY package*.json ./
RUN npm ci

# NÃO copia o código: vem por bind mount no compose de dev.

# Detecta mudanças de arquivo dentro de volume montado
ENV CHOKIDAR_USEPOLLING=true

EXPOSE 5173

# --host 0.0.0.0 é obrigatório: sem isso o Vite só ouve em localhost
# dentro do container e o port mapping não funciona.
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]

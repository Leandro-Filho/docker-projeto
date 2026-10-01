# ============================================================
# FRONTEND — estáticos servidos por nginx, com proxy reverso
#
# Este front é HTML/CSS/JS puro, então não há etapa de build.
# Se o seu projeto usa React/Vue/Svelte, veja
#   ../../02-frontend/react-vite-nginx.Dockerfile
# que tem o estágio de build (npm run build) antes do nginx.
# ============================================================

FROM nginx:1.27-alpine

# Os arquivos estáticos
COPY index.html style.css app.js /usr/share/nginx/html/

# A configuração que faz as duas coisas essenciais:
#   1. try_files  -> rotas do SPA não dão 404 no F5
#   2. proxy_pass -> /api/ vai para http://api:8000 POR DENTRO do Docker
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/nginx-health || exit 1

# "daemon off" é ESSENCIAL: o nginx precisa rodar em FOREGROUND para ser o
# PID 1. Se virar daemon, o processo principal termina e o container morre.
CMD ["nginx", "-g", "daemon off;"]

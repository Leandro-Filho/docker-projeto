#!/bin/sh
# ============================================================
# Variáveis de ambiente do FRONT em RUNTIME
#
# PROBLEMA: VITE_*/REACT_APP_*/NEXT_PUBLIC_* são substituídas no BUILD.
#           Passar `environment:` no compose não chega nelas.
#
# SOLUÇÃO: gerar um config.js quando o CONTAINER sobe, lendo o ambiente.
#          Assim UMA imagem serve todos os ambientes.
#
# COMO USAR
#   1. No Dockerfile do front, antes do CMD:
#        COPY entrypoint-runtime-env.sh /entrypoint.sh
#        RUN chmod +x /entrypoint.sh
#        ENTRYPOINT ["/entrypoint.sh"]
#        CMD ["nginx", "-g", "daemon off;"]
#
#   2. No index.html, ANTES do bundle:
#        <script src="/config.js"></script>
#
#   3. No código, em vez de import.meta.env.VITE_API_URL:
#        const API = window.APP_CONFIG?.API_URL ?? "/api";
#
#   4. No compose:
#        environment:
#          API_URL: /api
# ============================================================

set -e

DESTINO="${HTML_DIR:-/usr/share/nginx/html}/config.js"

echo "[entrypoint] gerando $DESTINO"

cat > "$DESTINO" <<CONFIG
// Gerado automaticamente na subida do container. Não editar.
window.APP_CONFIG = {
  API_URL: "${API_URL:-/api}",
  AMBIENTE: "${AMBIENTE:-producao}",
  VERSAO: "${APP_VERSION:-dev}"
};
CONFIG

echo "[entrypoint] config.js:"
cat "$DESTINO"

# exec: substitui o shell pelo processo real, para que ele seja o PID 1
# e receba SIGTERM corretamente no docker stop.
exec "$@"

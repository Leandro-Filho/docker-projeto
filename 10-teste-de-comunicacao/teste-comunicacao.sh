#!/usr/bin/env bash
# ============================================================
# TESTE DE COMUNICACAO ENTRE SERVICOS
#
# Roda as 8 provas e imprime um relatorio. Use a saida como
# EVIDENCIA no README da ponderada.
#
# Uso:
#   cd 05-stack-completa
#   docker compose up -d --build
#   ../10-teste-de-comunicacao/teste-comunicacao.sh
#
# Variaveis (opcionais):
#   PORTA_FRONT=3000  API_SVC=api  PROC_SVC=processador  DB_SVC=db
# ============================================================

set -uo pipefail

PORTA_FRONT="${PORTA_FRONT:-3000}"
API_SVC="${API_SVC:-api}"
PROC_SVC="${PROC_SVC:-processador}"
DB_SVC="${DB_SVC:-db}"
FRONT_SVC="${FRONT_SVC:-frontend}"
PROC_PORTA="${PROC_PORTA:-8001}"
API_PORTA="${API_PORTA:-8000}"

OK=0
FALHOU=0

c_verde=$'\033[32m'; c_vermelho=$'\033[31m'; c_cinza=$'\033[90m'; c_azul=$'\033[36m'; c_off=$'\033[0m'

titulo() { printf '\n%s=== %s ===%s\n' "$c_azul" "$1" "$c_off"; }
passou() { OK=$((OK+1));     printf '  %sOK    %s %s\n' "$c_verde" "$c_off" "$1"; }
falhou() { FALHOU=$((FALHOU+1)); printf '  %sFALHOU%s %s\n' "$c_vermelho" "$c_off" "$1"; }
detalhe(){ printf '        %s%s%s\n' "$c_cinza" "$1" "$c_off"; }

printf '%s\n' "============================================================"
printf '  TESTE DE COMUNICACAO ENTRE SERVICOS\n'
printf '  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '%s\n' "============================================================"

# ------------------------------------------------------------
titulo "PROVA 1 - os servicos subiram e estao saudaveis"
if ! docker compose ps >/dev/null 2>&1; then
  falhou "docker compose ps nao funcionou (estou na pasta do compose?)"
  detalhe "rode este script de dentro de 05-stack-completa"
  exit 1
fi
docker compose ps
for svc in "$FRONT_SVC" "$API_SVC" "$PROC_SVC" "$DB_SVC"; do
  estado=$(docker compose ps --format '{{.Service}} {{.State}} {{.Status}}' 2>/dev/null | awk -v s="$svc" '$1==s {$1="";print}')
  if printf '%s' "$estado" | grep -qi "running"; then
    if printf '%s' "$estado" | grep -qi "unhealthy"; then
      falhou "$svc esta UNHEALTHY"
    else
      passou "$svc esta rodando"
    fi
  else
    falhou "$svc NAO esta rodando"
    detalhe "veja: docker compose logs $svc"
  fi
done

# ------------------------------------------------------------
titulo "PROVA 2 - o DNS interno resolve o nome dos servicos"
for alvo in "$PROC_SVC" "$DB_SVC"; do
  saida=$(docker compose exec -T "$API_SVC" python -c \
    "import socket;print(socket.gethostbyname('$alvo'))" 2>&1 | tr -d '\r')
  if printf '%s' "$saida" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    passou "de '$API_SVC', o nome '$alvo' resolve"
    detalhe "IP interno: $saida"
  else
    falhou "de '$API_SVC', o nome '$alvo' NAO resolve"
    detalhe "$saida"
    detalhe "causa provavel: servicos em redes diferentes"
  fi
done

# ------------------------------------------------------------
titulo "PROVA 3 - HTTP de um container para o outro (pelo NOME)"
saida=$(docker compose exec -T "$API_SVC" python -c \
  "import urllib.request;print(urllib.request.urlopen('http://$PROC_SVC:$PROC_PORTA/api/health',timeout=5).read().decode())" 2>&1 | tr -d '\r')
if printf '%s' "$saida" | grep -q '"status"'; then
  passou "$API_SVC -> $PROC_SVC por HTTP, pelo nome do servico"
  detalhe "$saida"
else
  falhou "$API_SVC -> $PROC_SVC falhou"
  detalhe "$saida"
  detalhe "causa provavel: a app do destino ouve em 127.0.0.1 em vez de 0.0.0.0"
fi

saida=$(docker compose exec -T "$FRONT_SVC" wget -qO- "http://$API_SVC:$API_PORTA/api/health" 2>&1 | tr -d '\r')
if printf '%s' "$saida" | grep -q '"status"'; then
  passou "$FRONT_SVC -> $API_SVC por HTTP, pelo nome do servico"
  detalhe "$saida"
else
  falhou "$FRONT_SVC -> $API_SVC falhou"
  detalhe "$saida"
fi

# ------------------------------------------------------------
titulo "PROVA 4 - TESTE NEGATIVO: localhost DEVE falhar"
saida=$(docker compose exec -T "$API_SVC" python -c \
  "import urllib.request;urllib.request.urlopen('http://localhost:$PROC_PORTA/api/health',timeout=3)" 2>&1 | tr -d '\r')
if printf '%s' "$saida" | grep -qiE "refused|URLError|erro|error|timed out"; then
  passou "localhost:$PROC_PORTA falhou de dentro de '$API_SVC' -- CORRETO"
  detalhe "cada container tem seu proprio network namespace e seu proprio loopback;"
  detalhe "localhost aponta para ESTE container, nao para o $PROC_SVC"
else
  falhou "localhost:$PROC_PORTA RESPONDEU -- inesperado"
  detalhe "os servicos estao realmente em containers separados?"
fi

# ------------------------------------------------------------
titulo "PROVA 5 - HTTP de FORA, atravessando a cadeia"
if ! command -v curl >/dev/null 2>&1; then
  detalhe "curl nao encontrado -- pule para o Postman/Insomnia"
else
  saida=$(curl -s --max-time 8 "http://localhost:$PORTA_FRONT/api/health" 2>&1)
  if printf '%s' "$saida" | grep -q '"status"'; then
    passou "host -> frontend -> (proxy) -> api"
    detalhe "$saida"
  else
    falhou "host -> frontend -> api falhou"
    detalhe "${saida:-sem resposta}"
    detalhe "causa provavel: falta ports: no frontend, ou proxy_pass errado no nginx"
  fi

  saida=$(curl -s --max-time 10 -X POST "http://localhost:$PORTA_FRONT/api/analisar" \
          -H "Content-Type: application/json" \
          -d '{"valores":[10,12,9,30,11]}' 2>&1)
  if printf '%s' "$saida" | grep -q '"media"'; then
    passou "cadeia completa: host -> front -> api -> processador -> db"
    detalhe "$saida"
    h_api=$(printf '%s' "$saida"  | python3 -c "import sys,json;print(json.load(sys.stdin).get('recebido_por','?'))" 2>/dev/null)
    h_proc=$(printf '%s' "$saida" | python3 -c "import sys,json;print(json.load(sys.stdin).get('processado_por','?'))" 2>/dev/null)
    if [ -n "${h_api:-}" ] && [ -n "${h_proc:-}" ] && [ "$h_api" != "$h_proc" ]; then
      passou "dois hostnames DIFERENTES na mesma resposta"
      detalhe "recebido_por=$h_api  !=  processado_por=$h_proc"
      detalhe "prova que dois containers distintos participaram da requisicao"
    fi
  else
    falhou "a cadeia completa falhou"
    detalhe "${saida:-sem resposta}"
  fi
fi

# ------------------------------------------------------------
titulo "PROVA 6 - endpoint de diagnostico (/api/comunicacao)"
if command -v curl >/dev/null 2>&1; then
  saida=$(curl -s --max-time 15 "http://localhost:$PORTA_FRONT/api/comunicacao" 2>&1)
  if printf '%s' "$saida" | grep -q '"veredito"'; then
    printf '%s\n' "$saida" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$saida"
    if printf '%s' "$saida" | grep -q 'TODOS OS SERVICOS SE COMUNICAM'; then
      passou "o relatorio interno confirma: todos os servicos se comunicam"
    else
      falhou "o relatorio interno acusou falha -- veja o JSON acima"
    fi
  else
    falhou "o endpoint /api/comunicacao nao respondeu"
    detalhe "${saida:-sem resposta}"
  fi
fi

# ------------------------------------------------------------
titulo "PROVA 7 - o dado atravessou e foi persistido"
saida=$(docker compose exec -T "$DB_SVC" psql -U "${DB_USER:-app}" -d "${DB_NAME:-tarefas}" \
        -tAc "SELECT count(*) FROM analises;" 2>&1 | tr -d '\r' | tr -d ' ')
if printf '%s' "$saida" | grep -qE '^[0-9]+$' && [ "$saida" -gt 0 ]; then
  passou "a analise foi gravada no banco ($saida registro(s))"
  docker compose exec -T "$DB_SVC" psql -U "${DB_USER:-app}" -d "${DB_NAME:-tarefas}" \
    -c "SELECT id, n, media, processado_por, criada_em FROM analises ORDER BY id DESC LIMIT 3;" 2>/dev/null
else
  falhou "nenhum registro em 'analises'"
  detalhe "$saida"
fi

# ------------------------------------------------------------
# PROVA 8 - TESTE NEGATIVO DINAMICO
#
# A prova mais forte de todas. Se eu DERRUBO o processador e a api
# continua devolvendo 200, entao a api nunca falava com ele de verdade
# (era dado fixo). Se ela passa a devolver 502/503, a dependencia era real.
#
# Pule com:  SEM_TESTE_NEGATIVO=1 ./teste-comunicacao.sh
# ------------------------------------------------------------
if [ "${SEM_TESTE_NEGATIVO:-0}" = "1" ]; then
  titulo "PROVA 8 - teste negativo dinamico (PULADO)"
  detalhe "SEM_TESTE_NEGATIVO=1"
else
  titulo "PROVA 8 - teste negativo dinamico (derrubar o $PROC_SVC)"

  detalhe "parando o servico '$PROC_SVC'..."
  docker compose stop "$PROC_SVC" >/dev/null 2>&1

  codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
           -X POST "http://localhost:$PORTA_FRONT/api/analisar" \
           -H 'Content-Type: application/json' \
           -d '{"valores":[1,2,3]}' 2>/dev/null)

  case "$codigo" in
    502|503|504)
      passou "com o $PROC_SVC parado a api respondeu HTTP $codigo"
      detalhe "a dependencia entre api e $PROC_SVC e REAL, nao simulada"
      ;;
    200)
      falhou "a api respondeu 200 com o $PROC_SVC PARADO"
      detalhe "isso significa que a resposta nao vinha do $PROC_SVC (dado fixo/cache)"
      ;;
    000)
      falhou "nenhuma resposta (HTTP 000) -- o frontend tambem caiu?"
      detalhe "verifique: docker compose ps"
      ;;
    *)
      passou "com o $PROC_SVC parado a api respondeu HTTP $codigo (!= 200)"
      detalhe "o ideal seria 502/503, mas o importante e que mudou de comportamento"
      ;;
  esac

  detalhe "religando o servico '$PROC_SVC'..."
  docker compose start "$PROC_SVC" >/dev/null 2>&1

  # espera o healthcheck voltar a ficar verde (ate ~60s)
  i=0
  while [ "$i" -lt 30 ]; do
    estado=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}' \
             "$(docker compose ps -q "$PROC_SVC" 2>/dev/null)" 2>/dev/null || echo "")
    [ "$estado" = "healthy" ] && break
    [ "$estado" = "sem-healthcheck" ] && break
    i=$((i+1)); sleep 2
  done

  codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
           -X POST "http://localhost:$PORTA_FRONT/api/analisar" \
           -H 'Content-Type: application/json' \
           -d '{"valores":[1,2,3]}' 2>/dev/null)
  if [ "$codigo" = "200" ]; then
    passou "apos religar o $PROC_SVC a api voltou a responder 200"
    detalhe "a stack se recuperou sozinha -- o ciclo quebra/arruma esta completo"
  else
    falhou "apos religar, a api devolveu HTTP $codigo (esperado 200)"
    detalhe "aguarde o healthcheck e rode de novo: docker compose ps"
  fi
fi

# ------------------------------------------------------------
printf '\n%s\n' "============================================================"
printf '  RESULTADO:  %sOK: %s%s   |   %sFALHOU: %s%s\n' \
  "$c_verde" "$OK" "$c_off" "$c_vermelho" "$FALHOU" "$c_off"
if [ "$FALHOU" -eq 0 ]; then
  printf '  %sTODAS AS PROVAS DE COMUNICACAO PASSARAM%s\n' "$c_verde" "$c_off"
else
  printf '  %sHA FALHAS -- veja a tabela de diagnostico no LEIA-ME.md%s\n' "$c_vermelho" "$c_off"
fi
printf '%s\n' "============================================================"
printf '\nCopie esta saida para o README como evidencia do teste.\n\n'

[ "$FALHOU" -eq 0 ] || exit 1

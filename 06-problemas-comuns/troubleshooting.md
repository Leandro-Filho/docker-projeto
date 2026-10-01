# Troubleshooting geral

> Para problemas específicos de front+back, veja [pegadinhas-front-back.md](pegadinhas-front-back.md).

## O container sobe e morre na hora

| Causa | Como verificar | Solução |
|---|---|---|
| O processo **virou daemon** | `docker logs` vazio, `Exited (0)` | rodar em **foreground**: `nginx -g "daemon off;"` |
| O comando terminou normalmente | `Exited (0)` | o container vive enquanto o PID 1 vive |
| Erro na aplicação | `docker logs` mostra o traceback | corrigir |
| Comando não existe na imagem | `not found` | `bash` não existe em alpine — use `sh` |

## Exit codes

| Code | Significa | O que fazer |
|---|---|---|
| `0` | terminou normalmente | esperado em container de tarefa |
| `1` | erro da aplicação | ver logs |
| `125` | erro no comando docker | revisar as flags |
| `126` | não executável | permissão ou não é binário |
| `127` | comando não encontrado | caminho errado |
| **`137`** | **SIGKILL — geralmente OOM** | `docker inspect` -> `OOMKilled`; aumentar memória |
| `139` | segfault | incompatibilidade de arquitetura (ex.: imagem amd64 em ARM) |
| `143` | SIGTERM | parada normal |

## "port is already allocated"

```bash
docker ps                       # quem está usando
# ou trocar a porta do HOST:
ports: ["8081:80"]
```

## "no space left on device"

```bash
docker system df
docker system prune -a -f
docker builder prune -f
```

## O build está lento

| Causa | Solução |
|---|---|
| Build context gigante | criar/ajustar o `.dockerignore` |
| `COPY . .` antes de instalar dependências | copiar o manifesto primeiro |
| `--no-cache` sem necessidade | remover |

Conferir o tamanho do contexto: a primeira linha do build diz `transferring context: X MB`.

## A imagem está enorme

| Causa | Solução |
|---|---|
| Base completa | usar `-slim` ou `-alpine` |
| Ferramentas de build na imagem final | **multi-stage** |
| Cache de pacotes nas camadas | `--no-cache-dir`, `rm -rf /var/lib/apt/lists/*` **no mesmo RUN** |
| `node_modules` de dev | `npm ci --omit=dev` |
| Arquivos desnecessários | `.dockerignore` |

Diagnóstico: `docker history imagem` mostra o tamanho de cada camada.

## Permissão negada ao escrever

O `USER` do container não tem permissão no caminho.
- `COPY --chown=appuser:appuser`
- ou `RUN chown -R appuser:appuser /app` antes do `USER`
- em bind mount no Linux: alinhar UID (`--user $(id -u):$(id -g)`)

## Mudei o código e não refletiu

| Em dev | Em produção |
|---|---|
| falta bind mount | é esperado: `docker compose up -d --build` |

## "exec format error"

Imagem de arquitetura errada (amd64 num Mac M1, ou vice-versa).
Use imagens multi-arch (as oficiais são) ou `--platform linux/amd64`.

## Variáveis do `.env` não chegam

| Causa | Solução |
|---|---|
| O `.env` não está na mesma pasta do `docker-compose.yml` | mover para lá |
| Usou `environment:` com valor fixo em vez de `${VAR}` | usar `${VAR}` |
| Confundiu `.env` (do compose) com `env_file:` (do container) | `.env` alimenta o **YAML**; `env_file:` alimenta o **container** |

Conferir: `docker compose config` mostra os valores já substituídos.

## O healthcheck nunca fica healthy

| Causa | Solução |
|---|---|
| O comando do healthcheck não existe na imagem | alpine não tem `curl`; use `wget -q --spider` ou um `python -c` |
| `start_period` curto demais | aumentar (banco pode levar 10-20s) |
| O endpoint testado não existe | conferir a rota |
| Testando `localhost` numa app que ouve só em `0.0.0.0` | usar `127.0.0.1` no teste |

## Os logs não aparecem

| Causa | Solução |
|---|---|
| Python com buffer | `ENV PYTHONUNBUFFERED=1` |
| App escrevendo em arquivo | redirecionar para **stdout/stderr** |
| Logs rotacionados | `docker compose logs --tail 200` |

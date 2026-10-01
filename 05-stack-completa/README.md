# Stack completa — front + back + banco em Docker

Projeto **funcional** para rodar, estudar e usar como base.
Front em HTML/CSS/JS puro servido por nginx, API em Flask + gunicorn, banco Postgres.

> Se o seu projeto usa React/Vue/Svelte, o Dockerfile do front muda: precisa de um estágio de
> build (`npm run build`). Veja `../02-frontend/react-vite-nginx.Dockerfile`.

## Rodar

```bash
cp .env.example .env            # ajuste as senhas se quiser
docker compose up -d --build
docker compose ps               # todos devem ficar "healthy"
```

Abra **http://localhost:3000** e adicione uma tarefa.

## Rodar em modo desenvolvimento

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Agora editar `backend/src/app.py` recarrega a API sozinho, e a porta 8000 fica aberta
para testar com Postman.

## Derrubar

```bash
docker compose down             # mantém os dados
docker compose down -v          # APAGA os dados (e faz o init.sql rodar de novo)
```

---

## A arquitetura

```
              NAVEGADOR (fora do Docker)
                      │
                      │  http://localhost:3000
                      ▼
       ┌──────────────────────────────────┐
       │  frontend : nginx  (porta 80)    │ ← única porta publicada
       │                                  │
       │   /          → index.html        │
       │   /api/...   → proxy_pass ───────┼───┐
       └──────────────────────────────────┘   │  por dentro do Docker
                                              ▼
                        ┌──────────────────────────────┐
                        │  api : gunicorn  (8000)      │
                        └──────────────┬───────────────┘
                                       │  db:5432
                                       ▼
                        ┌──────────────────────────────┐
                        │  db : postgres  (5432)       │
                        │  volume: dadospg             │
                        └──────────────────────────────┘
```

## Por que foi feito assim

| Decisão | Motivo |
|---|---|
| Só o front publica porta | menos superfície exposta; API e banco são internos |
| Front chama `/api/...` relativo | o JS roda no navegador, que **não** resolve `api:8000` |
| nginx faz `proxy_pass` para `api:8000` | o nginx roda **dentro** do Docker e resolve esse nome |
| Sem CORS no backend | com proxy reverso, para o navegador é a **mesma origem** |
| `try_files ... /index.html` | sem isso, F5 numa rota do SPA dá 404 |
| gunicorn, não `flask run` | o servidor embutido é de desenvolvimento |
| Multi-stage no backend | compilador fica fora da imagem final |
| `USER appuser` | menor privilégio: build pode ser root, run não precisa |
| `healthcheck` + `condition: service_healthy` | esperar o banco **pronto**, não só **iniciado** |
| Named volume no Postgres | a camada de escrita morre com o container |
| Retry de conexão no código | robustez: o banco pode cair e voltar depois |
| `networks: appnet` explícita | documentado e permite segmentar depois |
| Senhas no `.env` (fora do Git) | nunca segredo no Dockerfile nem no compose |

---

## Experimentos — é aqui que se aprende

| # | Experimento | Comando | O que você observa |
|---|---|---|---|
| 1 | Ver o namespace UTS e PID | abrir a página; a pílula mostra host e PID da API | hostname próprio; a app é PID 1 |
| 2 | Provar que o volume funciona | criar tarefas → `docker compose down` → `up -d` | as tarefas continuam lá |
| 3 | Provar que a camada de escrita morre | `exec api touch /app/lixo.txt` → `down` → `up` → procurar | o arquivo sumiu |
| 4 | Ver o DNS interno | `docker compose exec frontend getent hosts api` | o nome `api` resolve para um IP |
| 5 | **Provar a armadilha nº 1** | no console do navegador: `fetch("http://api:8000/api/health")` | falha — o navegador não resolve `api` |
| 6 | Provar que `/api` funciona | no console: `fetch("/api/health").then(r=>r.json()).then(console.log)` | funciona, via proxy |
| 7 | Quebrar o cache de build | editar `requirements.txt` → `up -d --build` | o pip install roda de novo |
| 8 | Ver o cache funcionando | editar `backend/src/app.py` → `up -d --build` | só as camadas finais são refeitas |
| 9 | Ver as camadas | `docker history tarefas-api` | tamanho de cada camada |
| 10 | Testar o healthcheck | `docker compose ps` | coluna STATUS mostra `(healthy)` |
| 11 | Simular OOM | adicionar `mem_limit: 30m` à api e subir | `exit code 137`, `OOMKilled: true` |
| 12 | Ver o shutdown gracioso | `docker compose logs api` depois de um `stop` | a linha "recebi sinal 15, encerrando" |
| 13 | Reaplicar o `init.sql` | editar `banco/init.sql` → `down -v` → `up -d` | os novos dados aparecem |
| 14 | Confirmar que o banco não é exposto | `curl localhost:5432` (em produção) | sem resposta — não está publicado |

O **experimento 5** é o mais importante: ele prova com os próprios olhos a diferença entre a rede
do Docker e o navegador. Vale citar no README da ponderada.

---

## Testar a API direto

Com a porta 8000 publicada (modo dev ou descomentando no compose):

```bash
curl http://localhost:8000/api/health
curl http://localhost:8000/api/info
curl http://localhost:8000/api/tarefas

curl -X POST http://localhost:8000/api/tarefas \
  -H "Content-Type: application/json" \
  -d '{"titulo":"Testar pelo curl"}'

curl -X PATCH  http://localhost:8000/api/tarefas/1
curl -X DELETE http://localhost:8000/api/tarefas/1
```

Pelo proxy (sempre disponível, sem publicar a 8000):
```bash
curl http://localhost:3000/api/health
```

## Entrar nos containers

```bash
docker compose exec api sh                        # terminal na API
docker compose exec frontend sh                   # terminal no nginx
docker compose exec db psql -U app -d tarefas     # psql no banco
```

## Onde cada conceito está no código

| Conceito | Arquivo | Trecho |
|---|---|---|
| Ouvir em `0.0.0.0` | `backend/src/app.py` | `app.run(host="0.0.0.0")` |
| Config por ambiente | `backend/src/app.py` | `os.environ.get("DATABASE_URL")` |
| Retry de conexão | `backend/src/app.py` | função `conectar()` |
| Shutdown gracioso | `backend/src/app.py` | `signal.signal(signal.SIGTERM, ...)` |
| Log em stdout | `backend/src/app.py` | `stream=sys.stdout` |
| Caminho relativo `/api` | `frontend/app.js` | `const API = "/api"` |
| Proxy reverso | `frontend/nginx.conf` | `location /api/ { proxy_pass ... }` |
| Rotas do SPA | `frontend/nginx.conf` | `try_files $uri $uri/ /index.html` |
| Multi-stage | `backend/Dockerfile` | `FROM ... AS builder` |
| Menor privilégio | `backend/Dockerfile` | `USER appuser` |
| gunicorn | `backend/Dockerfile` | `CMD ["gunicorn", ...]` |
| `daemon off` | `frontend/Dockerfile` | `CMD ["nginx", "-g", "daemon off;"]` |
| DNS interno | `docker-compose.yml` | `@db:5432` |
| Esperar o banco | `docker-compose.yml` | `condition: service_healthy` |
| Volume | `docker-compose.yml` | `dadospg:/var/lib/postgresql/data` |
| init.sql | `docker-compose.yml` | `/docker-entrypoint-initdb.d/` |

# Amarrando tudo no Docker Compose

## O desenho da stack

```
                    NAVEGADOR
                        │
                        │ http://localhost:3000
                        ▼
          ┌─────────────────────────────┐
          │  frontend (nginx)  :80      │  ← única porta publicada
          │                             │
          │  /         -> estáticos     │
          │  /api/...  -> proxy_pass ───┼──┐
          └─────────────────────────────┘  │ (por dentro do Docker)
                                           ▼
                            ┌──────────────────────────┐
                            │  api (gunicorn)  :8000   │
                            └────────────┬─────────────┘
                                         │ db:5432
                                         ▼
                            ┌──────────────────────────┐
                            │  db (postgres)  :5432    │
                            │  volume: dadospg         │
                            └──────────────────────────┘
```

**Repare:** só o front publica porta. API e banco são alcançados **por dentro**.

## As 7 regras do compose

| # | Regra | Por quê |
|---|---|---|
| 1 | `ports:` **só** em quem precisa de acesso externo | menos superfície exposta |
| 2 | Conexões internas pelo **nome do serviço** | o DNS interno resolve; IP muda |
| 3 | **Named volume** para o banco | a camada de escrita morre com o container |
| 4 | **`networks:` explícita** | documentado e permite segmentar |
| 5 | `healthcheck` + `condition: service_healthy` | esperar *pronto*, não só *iniciado* |
| 6 | Senhas via **`${VARIAVEL}`** do `.env` | não commitar segredo |
| 7 | `restart: unless-stopped` | o serviço volta se cair |

## Dev vs Produção — as diferenças

| | **Dev** | **Produção** |
|---|---|---|
| Código | **bind mount** (hot reload) | **copiado para a imagem** |
| Dockerfile | `Dockerfile.dev` ou `target: builder` | Dockerfile final |
| Servidor do back | `flask run --reload` | **gunicorn** |
| Servidor do front | `npm run dev` (Vite) | **nginx** com os estáticos |
| Porta do banco | publicada (para DBeaver) | **não publicada** |
| `node_modules` | volume anônimo protegendo | dentro da imagem |
| Senhas | no `.env` local | injetadas pelo ambiente |

## Como usar dois arquivos

```bash
# Produção (usa só o docker-compose.yml)
docker compose up -d --build

# Desenvolvimento (mescla os dois; o segundo sobrescreve o primeiro)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Atalho: se o arquivo se chamar `docker-compose.override.yml`, ele é mesclado
**automaticamente** no `docker compose up` — bom para dev, porque o comando fica curto.

## A ordem de subida que eu quero

```
1. db        sobe e passa no healthcheck
2. migrate   roda as migrations e MORRE (service_completed_successfully)
3. api       sobe e conecta no banco já pronto
4. frontend  sobe e faz proxy para a api
```

Declarada assim:
```yaml
migrate:
  depends_on:
    db: {condition: service_healthy}
api:
  depends_on:
    migrate: {condition: service_completed_successfully}
frontend:
  depends_on:
    - api
```

## Comandos do dia a dia

| Comando | O que faz |
|---|---|
| `docker compose config` | **valida** o YAML e mostra o resultado final (rode antes de subir) |
| `docker compose up -d --build` | sobe tudo reconstruindo |
| `docker compose ps` | estado de cada serviço (procure `healthy`) |
| `docker compose logs -f api` | logs de um serviço |
| `docker compose exec api sh` | terminal dentro de um serviço |
| `docker compose restart api` | reinicia só um |
| `docker compose down` | derruba mantendo os dados |
| `docker compose down -v` | derruba **apagando os volumes** |

## Erro clássico de YAML

Indentação **com espaços**, nunca tab. E `ports` é lista de **strings**:

```yaml
ports:
  - "8000:8000"      # ✅ com aspas
  - 8000:8000        # ⚠️ YAML pode interpretar como sexagesimal
```

Sempre rode `docker compose config` para conferir antes de subir.

---

## `profiles:` — serviços que só sobem quando eu pedir

```yaml
  testador:
    image: curlimages/curl:latest
    profiles: ["teste"]
    networks: [appnet]
```

```bash
docker compose up -d                              # o testador NÃO sobe
docker compose --profile teste run --rm testador  # agora sim, e sai quando terminar
```

Para que serve: serviços **auxiliares** que não fazem parte da aplicação — teste de rede,
seed de banco, migração, backup, geração de relatório. Eles ficam declarados no compose
(versionados, documentados, na rede certa) sem poluir o `up` do dia a dia.

É a resposta certa para *"como rodo um comando pontual dentro da rede da stack?"*.
Alternativa sem compose, para quando a rede já existe:

```bash
docker run --rm --network <pasta>_appnet curlimages/curl -sS http://api:8000/api/health
```


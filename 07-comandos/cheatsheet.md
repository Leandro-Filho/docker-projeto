# Cheatsheet — os comandos que eu vou usar de verdade

## O ciclo do dia

```bash
docker compose config                  # 1. valida o YAML ANTES de subir
docker compose up -d --build           # 2. sobe tudo reconstruindo
docker compose ps                      # 3. confere: todos "healthy"?
docker compose logs -f api             # 4. acompanha os logs
docker compose down                    # 5. derruba (mantém dados)
```

## Compose

| Comando | O que faz |
|---|---|
| `docker compose config` | **valida** e mostra o YAML final resolvido |
| `docker compose up -d` | sobe em background |
| `docker compose up -d --build` | reconstrói as imagens antes de subir |
| `docker compose up -d --force-recreate` | recria os containers mesmo sem mudança |
| `docker compose up api` | sobe só um serviço (e suas dependências) |
| `docker compose ps` | estado de cada serviço |
| `docker compose logs -f` | logs de tudo |
| `docker compose logs -f --tail 50 api` | últimas 50 linhas de um serviço, seguindo |
| `docker compose exec api sh` | **terminal dentro** de um serviço |
| `docker compose exec db psql -U app -d meubanco` | psql no banco |
| `docker compose restart api` | reinicia um serviço |
| `docker compose build --no-cache api` | reconstrói sem cache |
| `docker compose stop` / `start` | para / inicia sem remover |
| `docker compose down` | remove containers e redes, **mantém volumes** |
| `docker compose down -v` | **apaga os volumes** também |
| `docker compose -f a.yml -f b.yml up -d` | mescla dois arquivos (dev) |

## Build e imagens

| Comando | O que faz |
|---|---|
| `docker build -t nome:tag ./pasta` | constrói (a pasta é o **build context**) |
| `docker build --target builder -t x ./pasta` | para num estágio do multi-stage |
| `docker build --build-arg VITE_API_URL=/api -t x .` | passa um ARG |
| `docker images` | lista imagens e **tamanhos** |
| `docker history nome:tag` | camadas e o tamanho de cada uma |
| `docker rmi nome:tag` | remove imagem |

## Containers soltos

| Comando | O que faz |
|---|---|
| `docker run --rm -p 8000:8000 meu-back` | sobe e remove ao parar (ótimo para testar) |
| `docker run -it --rm python:3.11 bash` | shell descartável |
| `docker ps` / `docker ps -a` | rodando / todos |
| `docker logs -f <id>` | logs |
| `docker exec -it <id> sh` | terminal dentro |
| `docker stop <id>` / `docker rm <id>` | para / remove |

## Diagnóstico — na ordem

```bash
docker compose ps                        # 1. está rodando? exit code? healthy?
docker compose logs api                  # 2. o que a aplicação disse?
docker inspect tarefas-api               # 3. OOMKilled? exit code? mounts? env?
docker compose exec api sh               # 4. entrar e olhar por dentro
docker compose exec frontend getent hosts api   # 5. o DNS interno resolve?
docker stats                             # 6. está estourando recurso?
docker compose config                    # 7. o YAML é o que eu penso?
docker history minha-imagem              # 8. por que a imagem está grande?
```

## Testar a rede por dentro

```bash
# o nome do serviço resolve?
docker compose exec frontend getent hosts api

# a api responde de dentro da rede?
docker compose exec frontend wget -qO- http://api:8000/api/health

# o banco aceita conexão?
docker compose exec api python -c "import psycopg2,os; psycopg2.connect(os.environ['DATABASE_URL']); print('ok')"
```

Esses três comandos resolvem quase todo problema de "não consigo conectar".

## Limpeza

| Comando | O que faz |
|---|---|
| `docker system df` | quanto espaço está sendo usado |
| `docker system prune -f` | containers parados, redes órfãs, cache de build |
| `docker system prune -a -f` | **+ imagens não usadas** |
| `docker volume prune -f` | volumes órfãos |
| `docker builder prune -f` | só o cache de build |

## Banco

```bash
# backup
docker compose exec db pg_dump -U app meubanco > backup.sql

# restore
cat backup.sql | docker compose exec -T db psql -U app -d meubanco

# listar tabelas
docker compose exec db psql -U app -d meubanco -c "\dt"
```

## Os 5 que eu mais vou digitar

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f api
docker compose exec api sh
docker compose down
```

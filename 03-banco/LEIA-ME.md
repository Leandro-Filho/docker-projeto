# Banco de dados em Docker

## Regra número um

> **NÃO construa o banco. Use a imagem oficial.**

Você não escreve Dockerfile para Postgres. Você usa `image: postgres:16` e configura por variáveis
de ambiente.

## As três coisas que todo banco precisa no compose

```yaml
db:
  image: postgres:16                          # 1. imagem oficial, versão FIXADA
  environment:
    POSTGRES_USER: app
    POSTGRES_PASSWORD: ${DB_PASSWORD}
    POSTGRES_DB: meubanco
  volumes:
    - dadospg:/var/lib/postgresql/data        # 2. VOLUME (senão os dados morrem)
  healthcheck:                                # 3. HEALTHCHECK (para o back esperar)
    test: ["CMD-SHELL", "pg_isready -U app -d meubanco"]
    interval: 5s
    timeout: 3s
    retries: 5
    start_period: 10s
```

E **sem `ports:`** — o banco só precisa ser alcançado pelo backend, de dentro da rede.
Publicar a porta do banco é desnecessário e é risco de segurança.
(Em dev, pode publicar para conectar um cliente como DBeaver ou pgAdmin.)

## Os caminhos do volume por banco

Errar o caminho é o erro mais comum: o volume é criado mas os dados continuam morrendo.

| Banco | Imagem | Caminho dos dados | Healthcheck |
|---|---|---|---|
| **PostgreSQL** | `postgres:16` | `/var/lib/postgresql/data` | `pg_isready -U usuario -d banco` |
| **MySQL** | `mysql:8` | `/var/lib/mysql` | `mysqladmin ping -h localhost` |
| **MariaDB** | `mariadb:11` | `/var/lib/mysql` | `healthcheck.sh --connect` |
| **MongoDB** | `mongo:7` | `/data/db` | `mongosh --eval "db.adminCommand('ping')"` |
| **Redis** | `redis:7-alpine` | `/data` | `redis-cli ping` |
| **SQLite** | (sem imagem) | o arquivo `.db` — monte a **pasta** dele | — |

> **SQLite em Docker:** funciona, mas o arquivo precisa estar num volume, e não escala com várias
> réplicas (bloqueio de arquivo). Para a ponderada é aceitável se o enunciado permitir, mas
> Postgres mostra mais domínio.

## Variáveis de ambiente por banco

| Banco | Variáveis |
|---|---|
| Postgres | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
| MySQL | `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` |
| Mongo | `MONGO_INITDB_ROOT_USERNAME`, `MONGO_INITDB_ROOT_PASSWORD`, `MONGO_INITDB_DATABASE` |

## Criar as tabelas — 4 opções

| Opção | Como | Quando usar |
|---|---|---|
| **`init.sql`** | montar em `/docker-entrypoint-initdb.d/` | ⭐ projeto pequeno; mais simples |
| **Migrations** | Alembic, Prisma, Sequelize, Django | projeto com evolução de schema |
| **Serviço `migrate`** | serviço separado que roda e morre | ⭐ mais limpo com migrations |
| **No código** | `CREATE TABLE IF NOT EXISTS` no startup | rápido; aceitável em projeto pequeno |

### A pegadinha do init.sql

```yaml
volumes:
  - ./banco/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

> **Os scripts em `/docker-entrypoint-initdb.d/` rodam APENAS quando o volume de dados está VAZIO.**

Mudou o `init.sql` e não aplicou? É isso. Para forçar:
```bash
docker compose down -v        # apaga o volume
docker compose up -d          # recria do zero, roda o init.sql
```

Aceita `.sql`, `.sql.gz` e `.sh`, executados em ordem alfabética — por isso é comum nomear
`01-schema.sql`, `02-dados.sql`.

### Migrations como serviço separado

```yaml
services:
  migrate:
    build: ./backend
    command: alembic upgrade head
    environment:
      DATABASE_URL: postgresql://app:${DB_PASSWORD}@db:5432/meubanco
    depends_on:
      db:
        condition: service_healthy
    restart: "no"              # roda uma vez e morre
    networks: [appnet]

  api:
    depends_on:
      migrate:
        condition: service_completed_successfully   # espera a migration TERMINAR
```

`service_completed_successfully` é a condição que espera um serviço **terminar com êxito** —
exatamente o que se quer de uma migration.

## A connection string

```
postgresql://usuario:senha@HOST:PORTA/banco
                           ↑
                    nome do SERVIÇO no compose
```

| De onde | Host |
|---|---|
| **Do backend (dentro do Docker)** | `db` ✅ |
| Do meu PC (com `ports: 5432:5432`) | `localhost` |
| Nunca | o IP do container (muda a cada recriação) |

## Backup e restore

```bash
# Backup
docker compose exec db pg_dump -U app meubanco > backup.sql

# Restore
cat backup.sql | docker compose exec -T db psql -U app -d meubanco

# Entrar no psql
docker compose exec db psql -U app -d meubanco
```

## Checklist do banco

- [ ] Imagem oficial com **versão fixada** (não `latest`)
- [ ] **Volume** no caminho certo do banco
- [ ] **Healthcheck** configurado
- [ ] Senha vindo de **variável de ambiente**, não fixa no YAML
- [ ] **Sem `ports:`** em produção
- [ ] O backend conecta usando o **nome do serviço**
- [ ] Testei: `docker compose down` + `up` e os dados continuaram lá

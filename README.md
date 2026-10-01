# Kit de containerização — front + back + banco

Repositório de trabalho para a **atividade ponderada**: subir um projeto completo em Docker.

O foco é **prático**: como dockerizar cada parte, fazer elas conversarem, e resolver os problemas
que sempre aparecem quando se junta front, back e banco.

---

## Fluxo de trabalho recomendado

```
1. CÓDIGO funcionando fora do Docker       (pode usar IA)
         ↓
2. DOCKERFILE do backend                   -> testar isolado
         ↓
3. BANCO no compose                        -> testar back + banco
         ↓
4. DOCKERFILE do frontend                  -> testar isolado
         ↓
5. COMPOSE juntando tudo                   -> testar a integração
         ↓
6. README escrito por mim                  <- o entregável principal
```

> **Nunca dockerize tudo de uma vez.** Um serviço por vez, testando. Se der erro com os três juntos,
> você não sabe onde está o problema.

---

## Índice

### 00 — Plano
| Arquivo | Conteúdo |
|---|---|
| [01-arquitetura.md](00-plano/01-arquitetura.md) | Decidir quantos serviços e quem fala com quem |
| [02-ordem-de-trabalho.md](00-plano/02-ordem-de-trabalho.md) | A ordem de execução, passo a passo |

### 01 — Backend
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](01-backend/LEIA-ME.md) | Como dockerizar um back: as regras e as armadilhas |
| [flask-prod.Dockerfile](01-backend/flask-prod.Dockerfile) | Flask + gunicorn, multi-stage |
| [fastapi-prod.Dockerfile](01-backend/fastapi-prod.Dockerfile) | FastAPI + uvicorn |
| [node-express.Dockerfile](01-backend/node-express.Dockerfile) | Express/NestJS |
| [flask-dev.Dockerfile](01-backend/flask-dev.Dockerfile) | Versão de desenvolvimento com reload |

### 02 — Frontend ⚠️
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](02-frontend/LEIA-ME.md) | **As 4 armadilhas do front em Docker** — leia antes de tudo |
| [react-vite-nginx.Dockerfile](02-frontend/react-vite-nginx.Dockerfile) | React/Vite -> estáticos no nginx |
| [nextjs-standalone.Dockerfile](02-frontend/nextjs-standalone.Dockerfile) | Next.js com SSR |
| [nginx.conf](02-frontend/nginx.conf) | SPA + **proxy reverso para a API** |
| [react-dev.Dockerfile](02-frontend/react-dev.Dockerfile) | Dev com hot reload |
| [entrypoint-runtime-env.sh](02-frontend/entrypoint-runtime-env.sh) | Variáveis de ambiente em runtime |

### 03 — Banco
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](03-banco/LEIA-ME.md) | Postgres/MySQL/Mongo, init scripts, migrations, backup |
| [init.sql](03-banco/init.sql) | Script de inicialização de exemplo |

### 04 — Compose
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](04-compose/LEIA-ME.md) | Como amarrar tudo; dev vs produção |
| [docker-compose.yml](04-compose/docker-compose.yml) | Produção |
| [docker-compose.dev.yml](04-compose/docker-compose.dev.yml) | Desenvolvimento |
| [.env.example](04-compose/.env.example) | Variáveis |

### 05 — Stack completa ⭐
Projeto **funcional** front + back + banco para rodar, estudar e usar como base.
Ver [05-stack-completa/README.md](05-stack-completa/README.md).

### 06 — Problemas comuns
| Arquivo | Conteúdo |
|---|---|
| [pegadinhas-front-back.md](06-problemas-comuns/pegadinhas-front-back.md) | ⭐ **O arquivo mais importante do repo** |
| [troubleshooting.md](06-problemas-comuns/troubleshooting.md) | Erro -> causa -> solução |

### 07 — Comandos
| [cheatsheet.md](07-comandos/cheatsheet.md) | Os comandos que eu vou usar de verdade |

### 08 — Entrega
(ver também [COMO-SUBIR-NO-GITHUB.md](COMO-SUBIR-NO-GITHUB.md) e [09-minhas-anotacoes/](09-minhas-anotacoes/))

| Arquivo | Conteúdo |
|---|---|
| [CHECKLIST.md](08-entrega/CHECKLIST.md) | Checklist antes de entregar |
| [README-ESQUELETO.md](08-entrega/README-ESQUELETO.md) | Perguntas para eu responder com minhas palavras |

---

## As regras da ponderada (anotadas da aula)

| Item | Regra |
|---|---|
| Consulta | liberada ao **meu GitHub** — por isso este repo precisa estar lá antes |
| **Código** | pode usar IA (Gemini, Codex, qualquer um) |
| **Arquivos Docker** | usar os **meus** |
| **README** | escrito **por mim**, sem passar por IA |
| Entregável principal | **o README** |

> *"O que eu pedi de código, pode usar IA para fazer, não tem problema.
> O que eu pedi de Docker, por favor, usem os arquivos de vocês."*

> *"Eu quero ver nós vai, nós fumo, deu problema. Foda-se. Eu quero ler o que você escreveu ali."*

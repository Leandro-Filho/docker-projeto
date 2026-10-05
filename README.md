# Kit de containerização — front + back + banco

Repositório de trabalho para a **atividade ponderada**: subir um projeto completo em Docker.

O foco é **prático**: como dockerizar cada parte, fazer elas conversarem, e resolver os problemas
que sempre aparecem quando se junta front, back e banco.

---

> ⭐ **O que o professor mais vai avaliar:** que exista um **teste da comunicação entre os
> serviços**. Comece por [10-teste-de-comunicacao/](10-teste-de-comunicacao/).
>
> 🧭 **Se você só tem tempo para abrir um arquivo:**
> [00-plano/03-PASSO-A-PASSO.md](00-plano/03-PASSO-A-PASSO.md) — as 11 etapas da ponderada,
> cada uma com "pronto quando" e "se travar".

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
6. TESTAR A COMUNICAÇÃO entre os serviços  <- ⭐ o que ele vai avaliar
         ↓
7. README escrito por mim                  <- o entregável principal
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
| [03-PASSO-A-PASSO.md](00-plano/03-PASSO-A-PASSO.md) | 🧭 **As 11 etapas da ponderada**, com "pronto quando" e "se travar" em cada uma |

### 01 — Backend
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](01-backend/LEIA-ME.md) | Como dockerizar um back: as regras e as armadilhas |
| [flask-em-container.md](01-backend/flask-em-container.md) | ⭐ **Host x porta x servidor** — a tabela que resolve o erro nº 1 (`0.0.0.0` vs `127.0.0.1`) |
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
Projeto **funcional** com **4 serviços** — `frontend` (nginx) + `api` (gunicorn) + `processador`
(o segundo backend, que prova a comunicação **serviço → serviço**) + `db` (Postgres) — mais um
quinto serviço `testador` sob `profiles:`, que só sobe quando você pede:

```bash
cd 05-stack-completa
docker compose up -d --build
docker compose --profile teste run --rm testador     # testa a rede de DENTRO
../10-teste-de-comunicacao/teste-comunicacao.sh      # as 8 provas
```

Ver [05-stack-completa/README.md](05-stack-completa/README.md).

### 10 — Teste de comunicação ⭐
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](10-teste-de-comunicacao/LEIA-ME.md) | ⭐ **As 8 provas de que um serviço fala com o outro** (inclui o teste negativo dinâmico) |
| [teste-comunicacao.sh](10-teste-de-comunicacao/teste-comunicacao.sh) | script que roda as 8 provas e imprime o relatório |
| [ferramentas-http.md](10-teste-de-comunicacao/ferramentas-http.md) | Postman, Insomnia, curl, HTTPie, Thunder Client — e a armadilha de cada um |
| [colecao-postman.json](10-teste-de-comunicacao/colecao-postman.json) | collection pronta para importar (9 requisições) |
| [requisicoes.http](10-teste-de-comunicacao/requisicoes.http) | alternativa em texto, versionável no Git (REST Client) |
| [evidencias.md](10-teste-de-comunicacao/evidencias.md) | como documentar as provas no README |

### 11 — Complete o Dockerfile ⭐
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](11-complete-o-dockerfile/LEIA-ME.md) | 7 exercícios de completar / achar erros |
| [gabarito.md](11-complete-o-dockerfile/gabarito.md) | gabarito **comentado** — a justificativa é o que vale |

### 06 — Problemas comuns
| Arquivo | Conteúdo |
|---|---|
| [pegadinhas-front-back.md](06-problemas-comuns/pegadinhas-front-back.md) | ⭐ **O arquivo mais importante do repo** — as 10 armadilhas de juntar front + back |
| [erros-e-codigos.md](06-problemas-comuns/erros-e-codigos.md) | ⭐ **Dicionário de erros**: código do curl, status HTTP, exit code do container, erro de build, erro de banco |
| [troubleshooting.md](06-problemas-comuns/troubleshooting.md) | Erro -> causa -> solução |

### 07 — Comandos
| Arquivo | Conteúdo |
|---|---|
| [cheatsheet.md](07-comandos/cheatsheet.md) | Os comandos que eu vou usar de verdade |
| [problema-para-recurso.md](07-comandos/problema-para-recurso.md) | ⭐⭐ **Problema → recurso do Docker → onde está no repo.** É exatamente o critério de avaliação: saber qual recurso resolve cada problema |

### 12 — UML e padrões de projeto
| Arquivo | Conteúdo |
|---|---|
| [LEIA-ME.md](12-uml-e-padroes/LEIA-ME.md) | Os 14 diagramas, foco em **sequência**, **classes** e **implantação** (a ponte com Docker) |
| [padroes-de-projeto.md](12-uml-e-padroes/padroes-de-projeto.md) | Os 10 padrões por família + tabela "o enunciado diz X → use Y" |

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

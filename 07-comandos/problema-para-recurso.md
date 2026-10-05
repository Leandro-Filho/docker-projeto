# Problema → Recurso → Onde está

O professor disse que **não desconta por erro de sintaxe**. O que ele avalia é:
**você sabe QUAL recurso do Docker resolve CADA problema?**

Então esta é a tabela mais importante do repositório para a prova e para a
ponderada. Leia da esquerda para a direita: "tenho esse problema" → "uso esse
recurso" → "está documentado aqui".

---

## 1. Imagem e build

| Problema | Recurso que resolve | Onde está no repo |
|---|---|---|
| Preciso transformar meu código em imagem | `Dockerfile` + `docker build -t nome:tag .` | `01-backend/flask-prod.Dockerfile` |
| Build demora toda vez que mudo uma linha de código | Ordenar camadas: copiar `requirements.txt` e instalar ANTES de copiar o código | `01-backend/LEIA-ME.md` (cache busting) |
| Imagem ficou com 1,2 GB | **multi-stage build** (`FROM ... AS builder` + `FROM` enxuto) + imagem base `-slim`/`alpine` | `02-frontend/react-nginx.Dockerfile` |
| `node_modules`, `.git` e `.env` estão entrando na imagem | `.dockerignore` | `05-stack-completa/backend/.dockerignore` |
| Preciso mudar o nome do arquivo de build | `docker build -f outro.Dockerfile .` | `07-comandos/cheatsheet.md` |
| Quero passar um valor só no momento do build | `ARG` no Dockerfile + `--build-arg` no comando | `11-complete-o-dockerfile/gabarito.md` (ex. 4) |
| Quero passar um valor na hora de rodar | `ENV` / `environment:` no compose | `04-compose/LEIA-ME.md` |
| A variável do React/Vite não chega no navegador | `ARG` + `ENV` no build (ela é "assada" no bundle, não lida em runtime) | `06-problemas-comuns/pegadinhas-front-back.md` (armadilha 1) |
| Quero ver o que tem dentro da imagem sem rodar o app | `docker run -it --entrypoint sh imagem` ou `docker image history` | `07-comandos/cheatsheet.md` |

---

## 2. Rodar o container

| Problema | Recurso que resolve | Onde está no repo |
|---|---|---|
| Container sobe e morre na hora | Processo em primeiro plano (`CMD` que não termina) + `docker logs` para ver o motivo | `06-problemas-comuns/troubleshooting.md` |
| Preciso acessar o app pelo navegador da minha máquina | **Publicar porta**: `-p 8000:8000` ou `ports:` no compose | `04-compose/LEIA-ME.md` |
| `EXPOSE 8000` não fez a porta funcionar | `EXPOSE` é só documentação; quem publica é `-p` / `ports:` | `01-backend/LEIA-ME.md` |
| Acesso `localhost:8000` e dá "connection reset" | App precisa escutar em `0.0.0.0`, não em `127.0.0.1` | `01-backend/flask-em-container.md` |
| Porta 8000 já está em uso | Trocar o lado esquerdo: `-p 8010:8000` | `06-problemas-comuns/troubleshooting.md` |
| Preciso entrar no container para investigar | `docker exec -it nome sh` (ou `bash`) | `07-comandos/cheatsheet.md` |
| Quero rodar um comando único e descartar o container | `docker run --rm imagem comando` | `07-comandos/cheatsheet.md` |
| Container não para com Ctrl+C / demora 10s | `SIGTERM` → 10s → `SIGKILL`. Tratar sinal no PID 1 ou usar `--init` | `06-problemas-comuns/troubleshooting.md` (exit 137/143) |

---

## 3. Dados e persistência

| Problema | Recurso que resolve | Onde está no repo |
|---|---|---|
| Perdi os dados do banco quando derrubei o container | **Volume nomeado** (`volumes:` no compose) | `03-banco/LEIA-ME.md` |
| Quero editar o código e ver o reflexo sem rebuildar | **Bind mount** (`./src:/app/src`) + servidor em modo reload | `01-backend/flask-dev.Dockerfile` |
| Preciso popular o banco na primeira subida | Script em `/docker-entrypoint-initdb.d/` | `05-stack-completa/banco/init.sql` |
| `init.sql` não rodou de novo depois que editei | Ele só roda com volume vazio → `docker compose down -v` | `06-problemas-comuns/troubleshooting.md` |
| Quero apagar só os volumes do projeto | `docker compose down -v` | `07-comandos/cheatsheet.md` |
| Quero ver o que existe de volume ocupando disco | `docker volume ls` / `docker system df` | `07-comandos/cheatsheet.md` |

---

## 4. Comunicação entre serviços ⭐

> Esta seção é a que o professor pediu explicitamente para verificar.

| Problema | Recurso que resolve | Onde está no repo |
|---|---|---|
| Backend não acha o banco | Usar o **nome do serviço** como host (`db`), não `localhost` | `10-teste-de-comunicacao/LEIA-ME.md` (prova 2) |
| `localhost` dentro do container aponta para o próprio container | Rede do Compose + DNS embutido em `127.0.0.11` | `10-teste-de-comunicacao/LEIA-ME.md` (prova 4, teste negativo) |
| Backend sobe antes do banco e quebra | `depends_on` com `condition: service_healthy` + `healthcheck` | `05-stack-completa/docker-compose.yml` |
| `depends_on` sozinho não resolveu | `depends_on` só espera **iniciar**, não **ficar pronto** → precisa do healthcheck | `04-compose/LEIA-ME.md` |
| Preciso provar que o serviço A fala com o serviço B | Endpoint que faz a chamada A→B e devolve quem respondeu (`/api/analisar`) | `05-stack-completa/backend/src/app.py` |
| Preciso de um relatório de diagnóstico de rede | Endpoint `/api/comunicacao` (6 provas automáticas) | `05-stack-completa/backend/src/app.py` |
| Quero testar de fora sem instalar nada | `docker compose exec api curl ...` ou serviço de teste com `profiles` | `10-teste-de-comunicacao/teste-comunicacao.sh` |
| Não tenho `curl` dentro da imagem slim | `docker run --rm --network <rede> curlimages/curl ...` | `10-teste-de-comunicacao/ferramentas-http.md` |
| Preciso de uma ferramenta HTTP para a entrega | Postman (coleção pronta), `requisicoes.http` (REST Client), `curl` | `10-teste-de-comunicacao/colecao-postman.json` |
| Quero isolar serviços em redes diferentes | Várias `networks:` no compose, cada serviço só nas que precisa | `04-compose/LEIA-ME.md` |
| Preciso saber o nome da rede criada | `docker network ls` (padrão: `<pasta>_default`) | `07-comandos/cheatsheet.md` |

---

## 5. Orquestração (Compose)

| Problema | Recurso que resolve | Onde está no repo |
|---|---|---|
| Tenho 4 serviços e não quero 4 `docker run` | `docker-compose.yml` + `docker compose up` | `05-stack-completa/docker-compose.yml` |
| Mudei o Dockerfile e o compose não pegou | `docker compose up --build` | `07-comandos/cheatsheet.md` |
| Quero rodar em background | `docker compose up -d` | `07-comandos/cheatsheet.md` |
| Quero os logs de um serviço só | `docker compose logs -f api` | `07-comandos/cheatsheet.md` |
| Quero um serviço que só roda quando eu pedir | `profiles:` no compose + `--profile teste` | `10-teste-de-comunicacao/LEIA-ME.md` |
| Quero reiniciar automaticamente se cair | `restart: unless-stopped` | `04-compose/LEIA-ME.md` |
| Preciso de segredos sem commitar | `.env` fora do git + `env_file:` no compose | `08-entrega/LEIA-ME.md` |
| Quero verificar se o YAML está válido antes de subir | `docker compose config` | `07-comandos/cheatsheet.md` |

---

## 6. Diagnóstico — "não sei nem por onde começar"

Ordem de investigação, sempre a mesma:

| Pergunta | Comando |
|---|---|
| Os containers estão de pé? | `docker compose ps` |
| O que deu errado na subida? | `docker compose logs <servico>` |
| O processo está escutando na porta certa dentro do container? | `docker compose exec <servico> sh -c "ss -ltnp \|\| netstat -ltnp"` |
| O nome do outro serviço resolve? | `docker compose exec api getent hosts db` |
| A porta do outro serviço responde? | `docker compose exec api curl -sS http://db:5432` (ou `nc -zv db 5432`) |
| A rede existe e quem está nela? | `docker network inspect <rede>` |
| O healthcheck está passando? | `docker inspect --format '{{.State.Health.Status}}' <container>` |
| Está faltando disco? | `docker system df` |

---

## Como usar isso na prova discursiva

A estrutura de resposta que funciona é sempre a mesma:

1. **Nomeie o sintoma** ("o backend recebe `Could not resolve host: db`").
2. **Nomeie a causa em termos técnicos** ("o container não está na mesma rede
   do Compose / está usando `localhost` em vez do nome do serviço").
3. **Nomeie o recurso** ("rede do Compose + DNS embutido em `127.0.0.11`;
   o host correto é o nome do serviço").
4. **Diga como você comprova** ("`docker compose exec api getent hosts db`
   deve devolver um IP; e um teste negativo com `localhost` deve falhar").

O passo 4 é o que separa a resposta boa da resposta mediana. Quase ninguém
escreve como provaria que resolveu.

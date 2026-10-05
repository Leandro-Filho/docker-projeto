# ⭐ PASSO A PASSO DA PONDERADA

> **Abra este arquivo primeiro no dia.** São 11 etapas, cada uma com o comando, o critério de
> "pronto" e o que fazer se falhar. Siga na ordem — não pule etapas, e **não dockerize tudo de
> uma vez**.

## Antes de começar (2 min)

- [ ] Este repositório aberto numa aba do navegador
- [ ] Terminal aberto na pasta do projeto
- [ ] `docker --version` e `docker compose version` respondem
- [ ] Ferramenta HTTP aberta (Postman/Insomnia) ou `curl` disponível
- [ ] Um arquivo `anotacoes.txt` aberto para colar saídas enquanto trabalha ⭐

> **O `anotacoes.txt` é a coisa mais fácil de esquecer e a mais caro de reconstruir.** Cole nele
> toda saída relevante **na hora**. No fim, ele vira a seção de evidências do README.

---

## ETAPA 1 — Ler a aplicação e desenhar o fluxo

**O que fazer:** antes de tocar em Docker, responda no papel:

| Pergunta | Onde achar a resposta |
|---|---|
| Quantos serviços existem? | pastas do projeto, ou o enunciado |
| Em que **porta** cada um escuta? | `app.run(port=...)`, `--bind`, `--port`, `EXPOSE` |
| **Quem chama quem?** | busque `http://` no código, ou variáveis tipo `*_URL` |
| Que **variáveis de ambiente** cada um espera? | `os.environ.get(...)`, `os.getenv(...)` |
| Qual serviço o **cliente** acessa? | o que tem interface, ou a API principal |
| Tem banco? | `psycopg2`, `sqlalchemy`, `DATABASE_URL` |

```bash
# atalhos para descobrir rápido
grep -rn "app.run\|--bind\|--port\|--host" . --include="*.py" --include="Dockerfile*"
grep -rn "os.environ\|os.getenv" . --include="*.py"
grep -rn "http://" . --include="*.py" --include="*.js"
```

**✅ Pronto quando:** você consegue desenhar a seta de cada chamada, assim:
```
cliente ──localhost:PORTA──> servico-a (:porta) ──http://servico-b:porta──> servico-b
```

**❌ Se travar:** preencha o mapa de [01-arquitetura.md](01-arquitetura.md). Se o enunciado não
disser quem chama quem, procure no código por `requests.get`, `fetch(`, `urlopen`.

---

## ETAPA 2 — Conferir o host de cada serviço ⭐

**O erro nº 1 da ponderada mora aqui.** Antes de construir qualquer imagem:

```bash
grep -rn "app.run\|--host\|--bind" . --include="*.py" --include="Dockerfile*"
```

| O que você encontrou | Funciona em container? | O que fazer |
|---|---|---|
| `app.run()` | ❌ **não** | trocar para `app.run(host="0.0.0.0", port=5000)` |
| `app.run(host="127.0.0.1")` | ❌ **não** | trocar para `0.0.0.0` |
| `app.run(host="0.0.0.0")` | ✅ sim | ok |
| `flask run` sem `--host` | ❌ **não** | acrescentar `--host 0.0.0.0` |
| `gunicorn --bind 0.0.0.0:5000` | ✅ sim | ok, e é o ideal |

**Por quê:** dentro do container, `127.0.0.1` é o loopback **do próprio container**. As conexões
chegam pela interface de rede (`eth0`), e o Flask não estaria ouvindo nela.

**✅ Pronto quando:** todo serviço ouve em `0.0.0.0`.

Detalhes em [../01-backend/flask-em-container.md](../01-backend/flask-em-container.md).

---

## ETAPA 3 — Um Dockerfile por serviço

**O que fazer:** para cada serviço que **você** constrói (banco e Redis usam imagem oficial, não
se constrói), crie `Dockerfile` e `.dockerignore`.

Parta de um modelo:

| Se o serviço é | Use o modelo |
|---|---|
| Flask simples | [../01-backend/flask-prod.Dockerfile](../01-backend/flask-prod.Dockerfile) |
| FastAPI | [../01-backend/fastapi-prod.Dockerfile](../01-backend/fastapi-prod.Dockerfile) |
| Node/Express | [../01-backend/node-express.Dockerfile](../01-backend/node-express.Dockerfile) |
| React/Vue/Vite | [../02-frontend/react-vite-nginx.Dockerfile](../02-frontend/react-vite-nginx.Dockerfile) |
| Next.js | [../02-frontend/nextjs-standalone.Dockerfile](../02-frontend/nextjs-standalone.Dockerfile) |

**As regras e armadilhas**, se for escrever do zero: [../01-backend/LEIA-ME.md](../01-backend/LEIA-ME.md) ·
host/porta/servidor em [../01-backend/flask-em-container.md](../01-backend/flask-em-container.md)

**✅ Pronto quando:** cada pasta de serviço tem `Dockerfile` + `.dockerignore` (+ `requirements.txt`
ou `package.json`).

**❌ Se travar numa instrução:** [../11-complete-o-dockerfile/gabarito.md](../11-complete-o-dockerfile/gabarito.md) ·
treino em [../11-complete-o-dockerfile/LEIA-ME.md](../11-complete-o-dockerfile/LEIA-ME.md)

---

## ETAPA 4 — Construir e testar CADA imagem sozinha ⭐

**Não pule esta etapa.** Se os três serviços subirem juntos de primeira e algo falhar, você não
sabe onde está o problema.

```bash
# para cada serviço, um por vez:
docker build -t servico-a:1.0 ./servico-a
docker run --rm -p 8000:5000 servico-a:1.0
# noutro terminal:
curl http://localhost:8000/health
```

**✅ Pronto quando:** cada imagem constrói, o container sobe **e não morre**, e responde isolado.

**❌ Se o container sobe e morre na hora:**
```bash
docker run --rm servico-a:1.0        # sem -d, para ver o erro na tela
```
| Causa | Correção |
|---|---|
| processo virou daemon | rodar em **foreground** (`nginx -g "daemon off;"`) |
| `CMD` com `&` no fim | remover o `&` — mata o PID 1 |
| erro na aplicação | ler o traceback |
| comando inexistente | `bash` não existe em alpine → use `sh` |

**❌ Se sobe mas não responde:** 9 de 10 vezes é a Etapa 2 (host `127.0.0.1`).

---

## ETAPA 5 — Escrever o compose.yaml

**O que fazer:** amarrar os serviços. O esqueleto mínimo:

```yaml
services:
  servico-a:                       # o que o cliente acessa
    build: ./servico-a
    ports: ["8000:5000"]           # HOST:CONTAINER  <- só quem o cliente acessa
    environment:
      URL_SERVICO_B: http://servico-b:5000   # NOME DO SERVIÇO, nunca localhost
    depends_on:
      servico-b:
        condition: service_healthy
    networks: [app-net]

  servico-b:                       # interno
    build: ./servico-b
    # SEM ports: só é alcançado de dentro da rede
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request;urllib.request.urlopen('http://127.0.0.1:5000/health')"]
      interval: 5s
      retries: 5
    networks: [app-net]

networks:
  app-net:
    driver: bridge
```

**As 4 regras que não se negociam:**

| # | Regra |
|---|---|
| 1 | `ports:` **só** em quem o cliente acessa |
| 2 | URL do outro serviço = **nome do serviço** + porta **interna** |
| 3 | A URL vem de `environment:`, **nunca fixa no código** |
| 4 | Rede **declarada explicitamente** |

```bash
docker compose config        # VALIDA o YAML antes de subir
```

**✅ Pronto quando:** `docker compose config` roda sem erro e mostra as variáveis já substituídas.

**❌ Se der erro de YAML:** indentação com **espaços**, nunca tab; `ports` como lista de strings
com aspas.

Referência: [../04-compose/LEIA-ME.md](../04-compose/LEIA-ME.md)

---

## ETAPA 6 — Subir tudo

```bash
docker compose up --build -d
docker compose ps
docker compose logs -f          # Ctrl+C para sair do follow
```

**✅ Pronto quando:** todos os serviços aparecem `Up` ou `Up (healthy)`.

**❌ Se um serviço fica `restarting` ou `unhealthy`:**
```bash
docker compose logs <servico>   # SEMPRE o primeiro comando
```

**❌ Se der "port is already allocated":** troque o lado **HOST**: `"8081:5000"`.

---

## ETAPA 7 — ⭐ TESTAR A COMUNICAÇÃO (a etapa avaliada)

**Rode o script e salve a saída:**
```bash
../10-teste-de-comunicacao/teste-comunicacao.sh | tee ../anotacoes-testes.txt
```

Ou faça à mão as **5 provas mínimas**:

```bash
# 1. os serviços subiram
docker compose ps

# 2. o DNS interno resolve o nome do outro serviço
docker compose exec servico-a python -c "import socket;print(socket.gethostbyname('servico-b'))"

# 3. HTTP de um container para o outro, PELO NOME
docker compose exec servico-a python -c "import urllib.request;print(urllib.request.urlopen('http://servico-b:5000/health').read().decode())"

# 4. ⭐ TESTE NEGATIVO: a mesma chamada com localhost DEVE FALHAR
docker compose exec servico-a python -c "import urllib.request;urllib.request.urlopen('http://localhost:5000/health')"

# 5. de fora, com a ferramenta HTTP, atravessando a cadeia
curl http://localhost:8000/health
curl -X POST http://localhost:8000/<rota-que-chama-o-outro> -H "Content-Type: application/json" -d '{...}'
```

**E o teste negativo dinâmico** (prova que a comunicação é real, não simulada):
```bash
docker compose stop servico-b
curl -i http://localhost:8000/<rota-que-chama-o-outro>   # deve dar 502 ou 503
docker compose start servico-b
```

**✅ Pronto quando:** você tem, salvo em arquivo, a saída de **cada** prova — e sabe dizer o que
cada uma prova.

**❌ Se a prova 2 falhar (DNS):** serviços em redes diferentes, ou nome escrito errado.
**❌ Se a prova 3 falhar:** Etapa 2 (host), ou porta interna errada na URL.
**❌ Se a prova 4 FUNCIONAR:** os serviços não estão realmente separados.
**❌ Se não tiver `curl` na máquina:** use o serviço `testador` do compose —
`docker compose --profile teste run --rm testador`.
**❌ Para decifrar a mensagem de erro:** [../06-problemas-comuns/erros-e-codigos.md](../06-problemas-comuns/erros-e-codigos.md)
(código do `curl`, status HTTP, exit code do container).

Guia completo: [../10-teste-de-comunicacao/LEIA-ME.md](../10-teste-de-comunicacao/LEIA-ME.md)

---

## ETAPA 8 — Guardar as evidências

```bash
{
  echo "== docker compose ps";            docker compose ps
  echo; echo "== imagens construidas";    docker images | head
  echo; echo "== DNS interno";            docker compose exec -T servico-a python -c "import socket;print(socket.gethostbyname('servico-b'))"
  echo; echo "== A -> B pelo nome";       docker compose exec -T servico-a python -c "import urllib.request;print(urllib.request.urlopen('http://servico-b:5000/health').read().decode())"
  echo; echo "== teste negativo";         docker compose exec -T servico-a python -c "import urllib.request;urllib.request.urlopen('http://localhost:5000/health')" 2>&1 | tail -2
  echo; echo "== de fora";                curl -s -w "\nHTTP %{http_code}\n" http://localhost:8000/health
} 2>&1 | tee evidencias.txt
```

**✅ Pronto quando:** existe um `evidencias.txt` com as saídas reais, e prints da ferramenta HTTP.

**Os 3 prints que valem mais:** `docker compose ps` com tudo healthy · a requisição principal no
Postman respondendo · o **teste negativo falhando**.

---

## ETAPA 9 — Teste final do zero ⭐

Simula a máquina do professor:

```bash
docker compose down -v
docker system prune -f
docker compose up --build -d
docker compose ps
```

**✅ Pronto quando:** subiu do zero sem erro e os testes continuam passando.

**Por que importa:** se só funciona na sua máquina com cache e volumes antigos, não funciona.

---

## ETAPA 10 — ⭐ O README (o entregável principal)

**Escreva com as suas palavras.** Ele pediu isso explicitamente.

As 9 seções: [../08-entrega/README-ESQUELETO.md](../08-entrega/README-ESQUELETO.md)
Como documentar as evidências: [../10-teste-de-comunicacao/evidencias.md](../10-teste-de-comunicacao/evidencias.md)

**A regra de ouro de cada decisão técnica:** não escreva *o que* você fez, escreva *por que*.

> ❌ "Usei multi-stage build."
> ✅ "Usei multi-stage porque o Node só é necessário para compilar o React; sem ele na imagem
> final, ela caiu de ~400 MB para ~30 MB e não carrega ferramentas de build em produção."

**✅ Pronto quando:** alguém que não viu o projeto consegue subir ele lendo só o seu README.

---

## ETAPA 11 — Encerrar e entregar

```bash
docker compose down
git add .
git commit -m "Ponderada Docker: <n> servicos conteinerizados com teste de comunicacao"
git push
```

- [ ] `.env` **não** foi commitado (confira o `.gitignore`)
- [ ] Nenhuma senha dentro de Dockerfile ou compose
- [ ] README no repositório, renderizando certo no GitHub
- [ ] Histórico com vários commits, não um só gigante

Checklist final completo: [../08-entrega/CHECKLIST.md](../08-entrega/CHECKLIST.md)

---

# A tabela de "pronto quando" — para conferir de relance

| Etapa | ✅ Pronto quando |
|---|---|
| 1. Ler a aplicação | consigo desenhar o fluxo `cliente → A → B` |
| 2. Conferir o host | todo serviço ouve em `0.0.0.0` |
| 3. Dockerfiles | cada serviço tem `Dockerfile` + `.dockerignore` |
| 4. Imagens isoladas | cada container sobe sozinho e responde |
| 5. compose.yaml | `docker compose config` sem erro |
| 6. Subir | todos `Up (healthy)` |
| 7. **Testar comunicação** | **tenho a saída de cada prova salva** |
| 8. Evidências | `evidencias.txt` + prints |
| 9. Teste do zero | `down -v` + `up --build` funciona |
| 10. README | alguém sobe o projeto lendo só ele |
| 11. Entregar | `.env` fora do Git, README renderizando |

---

# Se o tempo apertar — a ordem de corte

Se faltar tempo, **sacrifique nesta ordem** (do menos para o mais importante):

| Corte primeiro | Nunca corte |
|---|---|
| ~~Multi-stage~~ (imagem grande é aceitável) | **A aplicação subindo** |
| ~~Healthcheck~~ (use `depends_on` simples) | **O teste de comunicação** |
| ~~USER sem privilégio~~ | **O README com as suas palavras** |
| ~~Dev vs prod separados~~ | **As evidências salvas** |
| ~~Rede segmentada~~ | |

E se faltar tempo mesmo no README: escreva **a seção de testes e a de decisões**. São as duas que
mostram compreensão. Uma seção de "como executar" sem a de "por que fiz assim" vale muito menos.

---

# Mapa rápido de consulta

| Quando bater a dúvida | Abra |
|---|---|
| "qual recurso do Docker resolve isso?" | [../07-comandos/problema-para-recurso.md](../07-comandos/problema-para-recurso.md) |
| "o que essa mensagem de erro quer dizer?" | [../06-problemas-comuns/erros-e-codigos.md](../06-problemas-comuns/erros-e-codigos.md) |
| "sobe mas não abre no navegador" | [../01-backend/flask-em-container.md](../01-backend/flask-em-container.md) |
| "a variável do front chega `undefined`" | [../06-problemas-comuns/pegadinhas-front-back.md](../06-problemas-comuns/pegadinhas-front-back.md) |
| "como provo que os serviços se falam?" | [../10-teste-de-comunicacao/LEIA-ME.md](../10-teste-de-comunicacao/LEIA-ME.md) |
| "qual comando era mesmo?" | [../07-comandos/cheatsheet.md](../07-comandos/cheatsheet.md) |
| "quero treinar Dockerfile" | [../11-complete-o-dockerfile/LEIA-ME.md](../11-complete-o-dockerfile/LEIA-ME.md) |
| "caiu UML na prova" | [../12-uml-e-padroes/LEIA-ME.md](../12-uml-e-padroes/LEIA-ME.md) |
| "o que escrever no README" | [../08-entrega/README-ESQUELETO.md](../08-entrega/README-ESQUELETO.md) |

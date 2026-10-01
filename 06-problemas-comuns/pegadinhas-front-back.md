# As armadilhas de juntar front + back + banco em Docker

**Leia este arquivo antes de começar.** Todo mundo cai nestas. Saber que existem economiza horas.

---

# 1. ⚠️ O NAVEGADOR NÃO RESOLVE O NOME DO SERVIÇO

**A armadilha mais comum e mais confusa.**

Você aprende que containers se falam pelo nome do serviço (`http://api:8000`). Então você coloca isso
no seu front e **não funciona**.

## Por que

```
┌─────────────────────────────────────────────────┐
│  NAVEGADOR DO USUÁRIO  (FORA do Docker!)        │
│                                                 │
│   O JavaScript do SPA roda AQUI.                │
│   Ele não está na rede do Docker.               │
│   Para ele, "api" não existe.                   │
└──────────────────┬──────────────────────────────┘
                   │ precisa de um endereço REAL
                   ▼
┌─────────────────────────────────────────────────┐
│  DOCKER                                         │
│   ┌──────────┐      ┌──────────┐    ┌────────┐  │
│   │ frontend │      │   api    │───▶│   db   │  │
│   │  nginx   │      │  :8000   │    │ :5432  │  │
│   └──────────┘      └──────────┘    └────────┘  │
│        aqui dentro, "api" e "db" resolvem        │
└─────────────────────────────────────────────────┘
```

**A regra:** o nome do serviço só funciona em chamadas **de servidor para servidor**, dentro do Docker.
Se o código roda no **navegador**, ele precisa de um endereço que o navegador alcance.

## Quem usa qual

| Quem faz a chamada | Endereço correto |
|---|---|
| Backend -> banco | `db:5432` ✅ (nome do serviço) |
| Backend -> outra API interna | `api2:8000` ✅ |
| **JavaScript no navegador -> API** | `http://localhost:8000` ou `/api/...` ❌ **nunca `api:8000`** |
| Next.js **server-side** (SSR, API routes) | `api:8000` ✅ (roda no container) |
| Next.js **client-side** (useEffect, fetch no browser) | `http://localhost:8000` ou `/api/...` |

> Next.js é o caso mais traiçoeiro: o **mesmo projeto** tem código que roda no servidor
> (pode usar `api:8000`) e código que roda no navegador (não pode).

## As duas soluções

### Solução A — publicar a API e usar localhost (mais simples)

```yaml
services:
  api:
    ports:
      - "8000:8000"      # precisa publicar
```
No front: `fetch("http://localhost:8000/api/tarefas")`

**Problema:** só funciona na sua máquina. Em outro host, `localhost` é o navegador do usuário.
E exige configurar **CORS** no backend.

### Solução B — PROXY REVERSO no nginx (recomendado) ⭐

O front chama um caminho **relativo**, e o nginx encaminha para a API **por dentro** do Docker:

```nginx
# dentro do container do front
location /api/ {
    proxy_pass http://api:8000/api/;   # "api" resolve AQUI, dentro do Docker
}
```
No front: `fetch("/api/tarefas")` — caminho relativo, sem host nenhum.

**Vantagens:**
- ✅ Funciona em qualquer máquina, sem mudar código
- ✅ **Elimina CORS** (mesma origem para o navegador)
- ✅ Só **uma porta** publicada
- ✅ Não precisa de variável de ambiente com a URL da API

**É a solução que eu recomendo para a ponderada.** Explique essa escolha no README — mostra que você
entendeu a diferença entre a rede do Docker e o navegador.

---

# 2. ⚠️ VARIÁVEIS DE AMBIENTE DO FRONT SÃO "COZIDAS" NO BUILD

**A segunda armadilha mais comum.**

Você faz:
```yaml
frontend:
  environment:
    VITE_API_URL: http://localhost:8000     # ❌ NÃO FUNCIONA
```
E a variável chega **vazia** no navegador.

## Por que

Frameworks de front **substituem** as variáveis pelo valor literal durante o `npm run build`.
Depois do build, não existe mais variável — existe o texto que foi colocado no lugar.

```javascript
// Código fonte:
const url = import.meta.env.VITE_API_URL;

// Depois do build (o que vai para o navegador):
const url = "http://localhost:8000";    // texto fixo, cozido
```

E o build aconteceu **dentro do `docker build`**, antes de qualquer `environment:` do compose existir.

Vale para: `VITE_*` (Vite), `REACT_APP_*` (CRA), `NEXT_PUBLIC_*` (Next), `VUE_APP_*` (Vue CLI).

## As três soluções

### A — build-arg (funciona, mas amarra a imagem ao ambiente)

```dockerfile
FROM node:20-alpine AS builder
ARG VITE_API_URL                      # declara o ARG
ENV VITE_API_URL=$VITE_API_URL        # vira ENV para o build ver
RUN npm run build
```
```yaml
frontend:
  build:
    context: ./frontend
    args:
      VITE_API_URL: http://localhost:8000
```

**Desvantagem:** uma imagem por ambiente. Fere o "build once, run anywhere".

### B — Proxy reverso e nenhuma variável ⭐ (o mais simples)

Se o front chama `/api/...` relativo, **não existe URL para configurar**. Problema eliminado na raiz.

### C — Config em runtime (o profissional)

Um script de entrypoint gera um `config.js` quando o container sobe:

```sh
#!/bin/sh
cat > /usr/share/nginx/html/config.js <<EOT
window.APP_CONFIG = { API_URL: "${API_URL}" };
EOT
exec nginx -g 'daemon off;'
```
```html
<script src="/config.js"></script>   <!-- antes do bundle -->
```
No código: `window.APP_CONFIG.API_URL`

**Vantagem:** uma imagem serve todos os ambientes.

> **Para a ponderada: use B.** Se o enunciado exigir URL configurável, use C e explique.

---

# 3. ⚠️ SPA DÁ 404 AO RECARREGAR A PÁGINA

Você acessa `/`, navega para `/tarefas`, funciona. Aperta **F5** e toma **404**.

## Por que

O roteamento do SPA é no **JavaScript**. O nginx não sabe que `/tarefas` é uma rota do app — ele
procura um **arquivo** chamado `/tarefas`, não encontra, e devolve 404.

## A solução

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

Lê-se: *"tenta o arquivo; tenta a pasta; se nada existir, entrega o `index.html`"* — e aí o JS assume
o roteamento.

**Uma linha. Sempre coloque.**

---

# 4. ⚠️ CORS

Erro no console do navegador:
```
Access to fetch at 'http://localhost:8000/api/tarefas' from origin
'http://localhost:3000' has been blocked by CORS policy
```

## Por que

Origem = **protocolo + host + porta**. `localhost:3000` e `localhost:8000` são **origens diferentes**.
O navegador bloqueia por padrão.

## As duas soluções

### A — Proxy reverso (elimina o problema) ⭐
Com o front chamando `/api/...`, para o navegador tudo vem de `localhost:3000`. **Mesma origem,
sem CORS.**

### B — Habilitar CORS no backend

```python
# Flask
from flask_cors import CORS
CORS(app, origins=["http://localhost:3000"])
```
```python
# FastAPI
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:3000"],
                   allow_methods=["*"], allow_headers=["*"])
```

> Nunca use `allow_origins=["*"]` com credenciais. E em prova/README, saber **por que** o CORS
> existe (política de mesma origem do navegador) vale mais que saber a linha que o desliga.

---

# 5. ⚠️ O BACKEND SUBE ANTES DO BANCO ESTAR PRONTO

Erro intermitente: `connection refused`, `could not connect to server`. Às vezes funciona, às vezes não.

## Por que

`depends_on` **só garante que o container iniciou**, não que o Postgres terminou de inicializar e
está aceitando conexões.

## A solução correta

```yaml
api:
  depends_on:
    db:
      condition: service_healthy     # espera o HEALTHCHECK passar

db:
  image: postgres:16
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U app -d meubanco"]
    interval: 5s
    timeout: 3s
    retries: 5
    start_period: 10s
```

**Solução complementar (boa prática):** retry na aplicação. Mesmo com healthcheck, o banco pode cair
e voltar em produção. Código que tenta reconectar é mais robusto que depender só da orquestração.

---

# 6. ⚠️ O NODE_MODULES DO HOST BRIGA COM O DO CONTAINER

Em dev, você monta o código com bind mount e a app quebra com erro estranho de módulo.

## Por que

```yaml
volumes:
  - ./frontend:/app          # isso SOBRESCREVE /app/node_modules do container
```

O `node_modules` instalado **dentro** do container (Linux) é substituído pelo da sua máquina
(que pode ser macOS/Windows, ou não existir). Binários nativos não são compatíveis.

## A solução — volume anônimo

```yaml
volumes:
  - ./frontend:/app
  - /app/node_modules        # ⭐ protege essa pasta de ser sobrescrita
```

O volume anônimo tem **precedência** sobre o bind mount naquele caminho.
O mesmo truque vale para `.venv` em Python e `target/` em Rust.

---

# 7. ⚠️ HOT RELOAD NÃO FUNCIONA

Você edita o arquivo, salva, e nada acontece.

| Causa | Solução |
|---|---|
| Falta bind mount do código | `- ./src:/app/src` |
| Vite/webpack não detecta mudança no volume | ativar polling: `CHOKIDAR_USEPOLLING=true` ou `WATCHPACK_POLLING=true` |
| Vite não aceita conexão externa | `vite --host 0.0.0.0` |
| Está usando a imagem de produção | em dev, use o estágio de build (`target: builder`) ou um Dockerfile.dev |
| Flask sem modo debug | `FLASK_DEBUG=1` ou `--reload` |

---

# 8. ⚠️ SERVIDOR DE DESENVOLVIMENTO EM PRODUÇÃO

```dockerfile
CMD ["python", "app.py"]      # ❌ servidor de dev do Flask
CMD ["npm", "run", "dev"]     # ❌ servidor de dev do Vite
```

O servidor embutido do Flask avisa no log: *"This is a development server. Do not use it in a
production deployment."* Ele é single-thread e não aguenta carga.

| Stack | Dev | Produção |
|---|---|---|
| Flask | `flask run` / `python app.py` | **gunicorn** `-w 4 -b 0.0.0.0:8000 app:app` |
| FastAPI | `uvicorn --reload` | **uvicorn** com workers ou **gunicorn -k uvicorn.workers.UvicornWorker** |
| Express | `nodemon` | `node server.js` (com PM2 ou réplicas) |
| React/Vue | `npm run dev` | `npm run build` + **nginx** servindo os estáticos |

Mesmo numa atividade acadêmica, usar gunicorn/nginx e **explicar por quê** no README mostra
compreensão. É um ponto fácil de ganhar.

---

# 9. ⚠️ MIGRATIONS DO BANCO

Onde rodar `alembic upgrade head` / `prisma migrate deploy` / `python manage.py migrate`?

| Abordagem | Como | Avaliação |
|---|---|---|
| No `CMD` da API | `CMD sh -c "alembic upgrade head && gunicorn ..."` | simples; ruim com várias réplicas (todas tentam migrar) |
| Serviço separado que roda e morre | serviço `migrate` com `restart: "no"` | ⭐ mais limpo e explícito |
| Manual | `docker compose exec api alembic upgrade head` | bom para aprender; ruim para automatizar |
| `init.sql` no Postgres | montar em `/docker-entrypoint-initdb.d/` | ⭐ ótimo para projeto pequeno; **só roda no primeiro boot do volume** |

**Pegadinha do `init.sql`:** ele executa **apenas quando o volume de dados está vazio**. Se você já
subiu o banco antes, mudou o SQL e subiu de novo, ele **não roda**. Para forçar:
`docker compose down -v` (apaga os dados).

---

# 10. ⚠️ SEGREDOS E O ARQUIVO .env

| Erro | Certo |
|---|---|
| Senha no `Dockerfile` (`ENV SENHA=...`) | fica nas camadas **para sempre**; nunca faça |
| `.env` commitado no Git | adicione ao `.gitignore`; commite um `.env.example` sem valores |
| Senha fixa no `docker-compose.yml` | use `${VARIAVEL}` lido do `.env` |

```yaml
# docker-compose.yml
environment:
  POSTGRES_PASSWORD: ${DB_PASSWORD}
```
```bash
# .env  (NÃO vai para o Git)
DB_PASSWORD=senha_de_verdade
```
```bash
# .env.example  (VAI para o Git)
DB_PASSWORD=troque_aqui
```

---

# TABELA-RESUMO: sintoma -> causa -> solução

| Sintoma | Causa provável | Solução |
|---|---|---|
| Front não alcança a API | usou `api:8000` no JS do navegador | proxy reverso (`/api/`) ou `localhost:8000` |
| Variável do front chega vazia | é substituída no **build**, não no runtime | `build-arg`, proxy reverso, ou config em runtime |
| 404 ao recarregar rota do SPA | nginx procura arquivo que não existe | `try_files $uri $uri/ /index.html` |
| Erro de CORS no console | origens diferentes | proxy reverso ou CORS no back |
| `connection refused` no banco, às vezes | banco iniciou mas não está pronto | `healthcheck` + `condition: service_healthy` |
| Erro estranho de módulo em dev | `node_modules` do host sobrescreveu | volume anônimo `- /app/node_modules` |
| Hot reload não funciona | falta bind mount ou polling | bind mount + `CHOKIDAR_USEPOLLING=true` |
| API lenta / cai sob carga | servidor de desenvolvimento | gunicorn / uvicorn workers |
| Mudei o `init.sql` e não aplicou | só roda com volume vazio | `docker compose down -v` |
| "port is already allocated" | porta do host ocupada | trocar a porta do host |
| Container sobe e morre | processo virou daemon ou terminou | rodar em **foreground** |

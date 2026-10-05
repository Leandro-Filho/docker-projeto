# Gabarito comentado

> **Leia a justificativa, não só a linha.** O professor avalia se você sabe **qual recurso resolve
> qual problema** — então o "por quê" é o que vale.

---

## Exercício 1 — básico

| # | Resposta | Por quê |
|---|---|---|
| 1 | `FROM python:3.11-slim` | versão **fixada** (não `latest`) para build reprodutível; `slim` é menor e tem menos CVEs |
| 2 | `WORKDIR /app` | define o diretório e evita caminhos absolutos repetidos; cria a pasta se não existir |
| 3 | `COPY requirements.txt .` | copiar **só o manifesto** primeiro aproveita o cache de camadas |
| 4 | `RUN pip install --no-cache-dir -r requirements.txt` | `--no-cache-dir` evita guardar o cache do pip dentro da imagem |
| 5 | `EXPOSE 8000` | **documenta** a porta. Não publica nada — quem publica é `-p` ou `ports:` |
| 6 | `CMD ["python", "src/app.py"]` | forma **exec** (lista JSON): o processo é PID 1 e recebe SIGTERM, permitindo shutdown gracioso |

---

## Exercício 2 — cache

**a) O problema:** `COPY . .` vem **antes** do `pip install`. Qualquer mudança em qualquer arquivo
do projeto invalida a camada do `COPY`, e **todas as camadas acima dela são refeitas** — inclusive
a instalação das dependências. Trocar uma vírgula no código refaz o `pip install` inteiro.

**b) A ordem correta:**
```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

**c) A regra geral:** *o que muda pouco fica embaixo; o que muda muito fica em cima.* Dependências
mudam raramente, código muda a toda hora.

> Nome do fenômeno: **cache busting**. Se uma camada muda, todas as de cima são invalidadas.

---

## Exercício 3 — multi-stage

| # | Resposta |
|---|---|
| 1 | `FROM python:3.11 AS builder` |
| 2 | `RUN pip install --user --no-cache-dir -r requirements.txt` |
| 3 | `FROM python:3.11-slim` |
| 4 | `RUN useradd --create-home --uid 1000 appuser` |
| 5 | `COPY --from=builder /root/.local /home/appuser/.local` |
| 6 | `ENV PATH=/home/appuser/.local/bin:$PATH` |
| 7 | `USER appuser` |

**Perguntas de fechamento:**

1. **O que atravessou:** as dependências instaladas (`/root/.local`), o código da aplicação e — num
   projeto de ML — o artefato do modelo e o do preprocessing.
2. **O que ficou para trás:** compilador, headers de desenvolvimento, cache do pip, ferramentas de
   build, testes e notebooks.
3. **Duas vantagens:**
   - **Imagem menor** → pull e start mais rápidos, menos disco e banda; importa para escalar e para
     rolling update.
   - **Menor superfície de ataque** → menos pacotes, menos CVEs; sem compilador, um invasor tem
     muito menos a explorar.
   - *(Terceira:* **menor privilégio** — a imagem de build pode ser root, a de runtime não precisa.)

**Detalhe importante:** para `src.app:app` funcionar no gunicorn, a pasta `src/` precisa de um
`__init__.py` (ser um pacote Python). Sem ele: `ModuleNotFoundError: No module named 'src'`.
Alternativa: `CMD ["gunicorn", "--chdir", "src", "app:app", ...]`.

---

## Exercício 4 — frontend

| # | Resposta |
|---|---|
| 1 | `FROM node:20-alpine AS builder` |
| 2 | `COPY package*.json ./` |
| 3 | `RUN npm ci` |
| 4 | `RUN npm run build` |
| 5 | `COPY --from=builder /app/dist /usr/share/nginx/html` |
| 6 | `CMD ["nginx", "-g", "daemon off;"]` |

**Por que `npm ci` e não `npm install`:** o `ci` usa o `package-lock.json` como fonte da verdade e
falha se houver divergência. Resultado: **build reprodutível**. O `install` pode atualizar o lock e
trazer versões diferentes a cada build.

**Por que `daemon off;`:** o nginx, por padrão, se desprende e roda como daemon em background.
Se ele fizer isso, o processo principal termina e **o container morre na hora**. A flag o mantém em
**foreground**, como PID 1.

**Perguntas de fechamento:**

1. **Por que o Node não vai para a imagem final:** depois do build, a aplicação é só HTML, CSS e JS
   estáticos. Servir arquivo estático é trabalho de servidor web, não de runtime Node. A imagem cai
   de ~400 MB para ~30 MB.
2. **`try_files $uri $uri/ /index.html`:** o roteamento do SPA é no JavaScript. Sem essa linha, dar
   F5 numa rota interna faz o nginx procurar um **arquivo** com aquele nome, não encontrar, e
   devolver **404**.
3. **`proxy_pass http://api:8000/api/`:** o JavaScript roda **no navegador**, que está **fora** do
   Docker e não resolve o nome `api`. Com o proxy, o front chama `/api/...` relativo e o nginx —
   que está **dentro** do Docker — encaminha. Elimina o CORS de brinde, porque para o navegador
   fica tudo na mesma origem.

---

## Exercício 5 — segurança

| # | Problema | Correção |
|---|---|---|
| 1 | **`FROM python:latest`** | `FROM python:3.11-slim` — `latest` quebra a reprodutibilidade; a imagem pode mudar entre dois builds |
| 2 | **`ENV DB_PASSWORD=...`** | **remover.** Segredo em `ENV` fica gravado **nas camadas da imagem para sempre** — `docker history` revela. Injetar por variável de ambiente no run, `env_file`, ou secrets |
| 3 | **`COPY . .` antes do `pip install`** | copiar `requirements.txt` primeiro — cache |
| 4 | **Roda como root** (não tem `USER`) | `RUN useradd --create-home --uid 1000 appuser` + `USER appuser`. Container como root é risco real: se a app for explorada, o invasor já está como root |
| 5 | **Falta `HEALTHCHECK`** | adicionar — permite ao Docker e ao orquestrador saber se o container está saudável, e habilita `depends_on: condition: service_healthy` |

**Bônus (dois a mais, se você achou):**
- `CMD python src/app.py` na **forma shell** → o processo não recebe SIGTERM direito. Use a forma exec.
- Servidor de **desenvolvimento** em produção → `gunicorn -w 2 -b 0.0.0.0:8000 src.app:app`.
- Falta `pip install --no-cache-dir`.

**Versão corrigida:**
```dockerfile
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser ./src ./src

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "src.app:app"]
```

---

## Exercício 6 — compose

```yaml
services:

  frontend:
    build: ./frontend
    ports:                          # [1]
      - "3000:80"                   #     HOST:CONTAINER
    depends_on:
      - api
    networks:
      - appnet

  api:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://app:senha@db:5432/meubanco   # [2] host = "db"
    depends_on:
      db:
        condition: service_healthy  # [3]
    networks:
      - appnet
    # [4] não precisa publicar porta, se o front faz proxy reverso.
    #     Publicar só se eu quiser testar a API direto com Postman.

  db:
    image: postgres:16              # [5]
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: senha
      POSTGRES_DB: meubanco
    volumes:
      - dadospg:/var/lib/postgresql/data                       # [6]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d meubanco"]     # [7]
      interval: 5s
      retries: 5
    networks:
      - appnet

volumes:                            # [8]
  dadospg:

networks:                           # [9]
  appnet:
    driver: bridge
```

**Perguntas de fechamento:**

1. **Por que pelo nome e não pelo IP:** o Compose cria uma rede **definida pelo usuário** e o Docker
   fornece um **DNS interno (127.0.0.11)** que resolve nomes de serviço. O IP interno é **dinâmico** —
   muda a cada recriação do container —, então código que dependesse dele quebraria a cada deploy.
   O nome é estável. Isso se chama **service discovery**.
2. **`down -v`:** apaga os volumes, portanto **apaga os dados** do banco. Sem o `-v`, os dados
   sobrevivem.
3. **Como provar que a api fala com o db:** `docker compose exec api python -c "import socket;
   print(socket.gethostbyname('db'))"` para o DNS, e um `SELECT 1` pela aplicação para a conexão real.
   O jeito mais limpo é um endpoint de diagnóstico que faça o teste de dentro do container.

**Atenção ao `depends_on` simples:** `- db` só garante que o container **iniciou**, não que o
Postgres está **aceitando conexão**. Daí a necessidade do `healthcheck` + `condition:
service_healthy`.

---

## Exercício 7 — os 8 erros

| # | Erro | Por que é problema | Correção |
|---|---|---|---|
| 1 | `FROM ubuntu:latest` | base genérica (instala Python na mão, imagem grande) **e** `latest` quebra reprodutibilidade | `FROM python:3.11-slim` |
| 2 | Três `RUN apt-get` separados | três camadas; e o cache do apt fica gravado | um `RUN` só, com `&&` e `rm -rf /var/lib/apt/lists/*` no mesmo comando |
| 3 | `gcc` e `build-essential` na imagem final | ferramentas de build não deviam ir para produção | **multi-stage build** |
| 4 | `ENV API_TOKEN=ghp_...` | **segredo gravado nas camadas para sempre**; `docker history` revela. É o erro mais grave da lista | remover; injetar em runtime |
| 5 | `ADD . /app` | `ADD` tem comportamento extra (baixa URL, descompacta tar); é menos transparente | `COPY` |
| 6 | `ADD . /app` **antes** do `pip install` | quebra o cache a cada mudança de código | copiar `requirements.txt` primeiro |
| 7 | `USER root` | explicitamente dá privilégio máximo — o oposto do que se quer | criar usuário e usar `USER appuser` |
| 8 | `CMD python3 src/app.py &` | o **`&`** joga o processo para background → **o PID 1 termina → o container morre na hora**. E está na forma shell | `CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "src.app:app"]` |

**Erros bônus, se você achou:** falta `EXPOSE` coerente com o servidor usado; falta `WORKDIR` antes
do `ADD` (está, mas vale conferir a ordem); falta `HEALTHCHECK`; falta `--no-cache-dir` no pip;
`--break-system-packages` é um sintoma de estar usando o Python do sistema em vez de uma imagem
Python própria.

**O erro nº 8 é o mais instrutivo:** ele resume o princípio de que **o container vive enquanto o
PID 1 vive**. Qualquer coisa que jogue o processo principal para background mata o container —
é a mesma razão do `daemon off;` no nginx.

**Versão corrigida:**
```dockerfile
# ---------- BUILD ----------
FROM python:3.11 AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ---------- RUNTIME ----------
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

COPY --chown=appuser:appuser ./src ./src

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "src.app:app"]
```

---

# O resumo do que estes 7 exercícios ensinam

| Conceito | Exercícios |
|---|---|
| Versão fixada, não `latest` | 1, 5, 7 |
| Ordem das instruções e cache | 2, 5, 7 |
| Multi-stage: separar build de runtime | 3, 4, 7 |
| `COPY --from=` | 3, 4 |
| Usuário sem privilégio | 3, 5, 7 |
| Segredo nunca no Dockerfile | 5, 7 |
| Forma exec no CMD | 1, 5, 7 |
| Servidor de produção, não de dev | 5, 7 |
| **PID 1: o container vive enquanto ele vive** | 4 (`daemon off`), 7 (`&`) |
| `EXPOSE` documenta, `ports` publica | 1, 6 |
| Nome do serviço, não IP nem localhost | 6 |
| Volume para persistir | 6 |
| Healthcheck + `condition: service_healthy` | 5, 6 |
| Rede explícita | 6 |
| Como **provar** a comunicação | 6 |

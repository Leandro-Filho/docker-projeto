# Dicionário de erros: mensagem → causa → correção

Este arquivo existe para um momento específico: você roda o teste de
comunicação, aparece uma mensagem feia, e você precisa saber em 10 segundos
**de qual lado está o problema**.

Regra geral que resolve 80% dos casos:

| O erro fala de... | O problema é de... |
|---|---|
| nome, host, resolve, DNS | **rede** (nome de serviço errado ou container fora da rede) |
| connect, refused, timeout | **porta** (serviço não subiu, escuta no host errado, ou porta errada) |
| 4xx | **sua requisição** (rota, método, corpo, header) |
| 5xx | **o servidor** (exceção no código ou dependência caída) |

---

## 1. Erros do `curl` (código de saída)

O código de saída do `curl` é mais informativo que a mensagem. Veja com
`echo $?` logo depois do comando.

| Saída | Mensagem típica | Causa real | Correção |
|---|---|---|---|
| **0** | — | deu certo (mesmo com HTTP 500! `curl` só olha o transporte) | use `-f` ou `-w "%{http_code}"` para checar o status |
| **6** | `Could not resolve host: db` | o nome não existe na rede. Serviço com outro nome, erro de digitação, ou container fora da rede do Compose | confira `services:` no compose e rode `docker compose exec api getent hosts db` |
| **7** | `Failed to connect to api port 8000: Couldn't connect to server` | o nome resolveu, mas **ninguém atende na porta**. Processo não subiu, morreu, escuta em `127.0.0.1`, ou a porta é outra | `docker compose logs api`; conferir `0.0.0.0`; conferir a porta real |
| **22** | `The requested URL returned error: 404` | só aparece com `-f`. O transporte foi bem; o HTTP é que deu erro | é problema de rota/método, não de rede |
| **28** | `Operation timed out` | conexão aceita mas sem resposta no prazo. Query travada, deadlock, ou firewall engolindo pacote | aumentar `--max-time` só para diagnosticar; investigar o handler |
| **52** | `Empty reply from server` | algo escuta na porta mas **não fala HTTP** (ex.: apontar HTTP para a porta 5432 do Postgres) | conferir se a porta é a do serviço HTTP |
| **56** | `Recv failure: Connection reset by peer` | o servidor derrubou a conexão no meio. Processo morreu, ou protocolo trocado | `docker compose logs`; checar exit code do container |
| **35** | `SSL connect error` | você usou `https://` num serviço que só fala HTTP | troque para `http://` entre containers |

> **Pegadinha de prova:** `curl` com saída **0** e HTTP **500** significa que
> a rede está perfeita e o bug está no código. Muita gente confunde os dois.

---

## 2. Status HTTP — o que cada um diz sobre a stack

| Status | Significado | No contexto de containers |
|---|---|---|
| **200** | OK | tudo certo |
| **201** | Created | `POST` que criou recurso (seu `POST /api/tarefas`) |
| **204** | No Content | `DELETE` bem-sucedido sem corpo |
| **400** | Bad Request | JSON inválido ou campo obrigatório faltando — **culpa do cliente** |
| **401 / 403** | não autenticado / sem permissão | token ou credencial ausente |
| **404** | Not Found | rota digitada errada **ou** registro inexistente. Olhe a lista de rotas do app |
| **405** | Method Not Allowed | a rota existe, mas você usou `GET` onde é `POST` (erro clássico ao testar no navegador) |
| **422** | Unprocessable Entity | típico de FastAPI/Pydantic: corpo com tipo errado |
| **500** | Internal Server Error | **exceção não tratada no seu código**. Sempre tem traceback em `docker compose logs` |
| **502** | Bad Gateway | o nginx (ou o seu backend como gateway) tentou falar com o serviço de trás e **não conseguiu**. É o status esperado no teste negativo com `docker compose stop` |
| **503** | Service Unavailable | serviço de trás existe mas se declara indisponível (healthcheck falhando) |
| **504** | Gateway Timeout | serviço de trás aceitou mas não respondeu no prazo do proxy |

> **502/503 são os seus amigos na ponderada.** Quando você derruba um serviço
> de propósito e a API devolve 502, você acabou de **provar** que a comunicação
> entre serviços era real. Se continuar devolvendo 200, o dado era mock.

---

## 3. Códigos de saída do container

Veja com `docker compose ps -a` ou `docker inspect --format '{{.State.ExitCode}}' <container>`.

| Exit | Significado | Causa comum |
|---|---|---|
| **0** | terminou normalmente | o `CMD` era um comando de uma vez (ex.: `python script.py`), não um servidor. Container "morre" porque acabou o trabalho |
| **1** | erro genérico da aplicação | exceção na inicialização. `docker logs` tem o traceback |
| **2** | uso incorreto de comando shell | erro de sintaxe no `CMD`/`ENTRYPOINT` |
| **125** | o próprio `docker run` falhou | flag inválida no comando docker |
| **126** | comando encontrado mas não executável | script sem `chmod +x` |
| **127** | **comando não encontrado** | binário não existe na imagem (ex.: `CMD ["bash"]` numa imagem alpine que só tem `sh`) |
| **137** | morto por **SIGKILL** (128+9) | `docker kill`, **OOM** (estourou memória), ou não respondeu ao SIGTERM em 10s |
| **143** | morto por **SIGTERM** (128+15) | parada normal via `docker stop`. Não é erro |

> `137` por OOM confirma-se com `docker inspect --format '{{.State.OOMKilled}}'`.

---

## 4. Erros de build

| Mensagem | Causa | Correção |
|---|---|---|
| `failed to compute cache key: "/requirements.txt" not found` | o arquivo não está no **contexto de build** (ou está no `.dockerignore`) | ajustar o caminho no `COPY` e o `context:` do compose |
| `COPY failed: file not found in build context` | mesma coisa: caminho relativo ao contexto, não ao Dockerfile | `docker build -t x .` ← esse `.` é o contexto |
| `pull access denied` / `manifest unknown` | nome ou tag da imagem base errada | conferir no Docker Hub; `python:3.12-slim`, não `python:3.12-slin` |
| `exec /app/entrypoint.sh: no such file or directory` | script com **CRLF** (editado no Windows) ou shebang errado | `dos2unix`, ou `.gitattributes` com `* text eol=lf` |
| `E: Unable to locate package` | `apt-get install` sem `apt-get update` na mesma camada | juntar com `&&` numa linha só |
| `ModuleNotFoundError: No module named 'src'` | pacote Python sem `__init__.py`, ou `WORKDIR` errado para o `gunicorn src.app:app` | criar `src/__init__.py` e conferir o `WORKDIR` |
| `no space left on device` | disco tomado por imagens/camadas antigas | `docker system prune -a` e `docker volume prune` |

---

## 5. Erros de banco (Postgres, via Python)

| Mensagem | Causa | Correção |
|---|---|---|
| `could not translate host name "db" to address` | DNS: nome do serviço errado, ou app rodando **fora** do Compose | host = nome do serviço; rodar via `docker compose` |
| `connection to server at "db" ... Connection refused` | o Postgres ainda está iniciando | `healthcheck` com `pg_isready` + `depends_on: condition: service_healthy` |
| `password authentication failed for user "app"` | variáveis divergentes entre o serviço `db` e o `api` | usar o mesmo `.env` nos dois |
| `database "app" does not exist` | `POSTGRES_DB` diferente do nome usado na string de conexão | alinhar os dois |
| `relation "tarefas" does not exist` | o `init.sql` não rodou — ele **só executa com volume vazio** | `docker compose down -v && docker compose up --build` |
| `too many connections` | abrir conexão por requisição sem fechar | usar pool, ou `with` para fechar |

---

## 6. Erros de frontend / nginx

| Sintoma | Causa | Correção |
|---|---|---|
| Página carrega mas requisição à API dá `ERR_CONNECTION_REFUSED` | o navegador roda **na sua máquina**, não na rede do Docker. Ele não conhece `http://api:8000` | o front chama caminho relativo (`/api/...`) e o nginx faz `proxy_pass` para `http://api:8000` |
| `404` ao recarregar uma rota do React | nginx procura o arquivo físico | `try_files $uri $uri/ /index.html;` |
| Variável de ambiente do front chega `undefined` | `VITE_`/`REACT_APP_`/`NEXT_PUBLIC_` são **assadas no build**, não lidas em runtime | passar via `ARG` + `ENV` no estágio de build |
| `CORS policy: No 'Access-Control-Allow-Origin'` | front e back em origens diferentes e sem CORS liberado | usar proxy no nginx (mesma origem) ou liberar CORS no backend |
| `502 Bad Gateway` no nginx | o `proxy_pass` aponta para nome/porta que não responde | conferir nome do serviço e porta interna (não a publicada) |

---

## 7. Checklist de 30 segundos

Quando algo quebra, nesta ordem:

```bash
docker compose ps                      # está de pé?
docker compose logs --tail=50 <serv>   # qual foi o erro?
docker compose exec api getent hosts db   # o nome resolve?
docker compose exec api curl -sS -o /dev/null -w "%{http_code}\n" http://processador:8001/api/health
docker compose config                  # o YAML está válido?
```

Se os quatro primeiros passam e o app ainda falha, o problema é **código**, não
Docker — e aí o traceback nos logs resolve.

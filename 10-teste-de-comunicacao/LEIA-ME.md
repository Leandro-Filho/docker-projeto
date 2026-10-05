# Como PROVAR que um serviço fala com o outro

> ⭐ **Esta é a parte central da ponderada.** O professor disse que a forma de testar é livre,
> mas que **precisa existir um teste da comunicação** — e recomendou uma ferramenta HTTP.

A questão não é "funcionou?". É **"como você provou que funcionou?"**

---

## Os dois tipos de comunicação — não confunda

```
         ┌──────────────── FORA do Docker ────────────────┐
         │   navegador / Postman / curl no meu terminal   │
         └───────────────────────┬───────────────────────┘
                                 │  (A) EXTERNA
                                 │  endereço: localhost:PORTA_PUBLICADA
                                 ▼
 ╔═══════════════════════ rede do Compose ═══════════════════════╗
 ║  ┌──────────┐      ┌──────────┐      ┌─────────────┐          ║
 ║  │ frontend │─────▶│   api    │─────▶│ processador │          ║
 ║  │  :80     │      │  :8000   │      │   :8001     │          ║
 ║  └──────────┘      └────┬─────┘      └─────────────┘          ║
 ║                         │                                     ║
 ║        (B) INTERNA      ▼                                     ║
 ║        nome do serviço  ┌────────┐                            ║
 ║                         │   db   │                            ║
 ║                         │ :5432  │                            ║
 ║                         └────────┘                            ║
 ╚═══════════════════════════════════════════════════════════════╝
```

| | **(A) Externa** | **(B) Interna** |
|---|---|---|
| Quem chama | navegador, Postman, curl **da minha máquina** | um container chamando outro |
| Endereço | `localhost:PORTA_DO_HOST` | **`nome-do-servico:PORTA_INTERNA`** |
| Precisa `ports:`? | **sim** | **não** |
| O que prova | que a porta está publicada | que a **rede do Compose e o DNS** funcionam |

> **Um teste só de (A) não prova comunicação entre serviços.** Se você só chamar
> `localhost:3000` e a página abrir, você provou que o front subiu — não que ele fala com a API.

---

## As 8 provas, da mais simples à mais completa

Use **pelo menos as provas 1, 3 e 5**. As três juntas cobrem externo, interno e serviço→serviço.

### Prova 1 — `docker compose ps`: todos subiram e estão saudáveis

```bash
docker compose ps
```
Procure **`(healthy)`** na coluna STATUS. Se um serviço está `unhealthy` ou `restarting`,
nem tente testar comunicação — resolva isso primeiro.

**O que prova:** os containers subiram e os healthchecks passam.
**O que NÃO prova:** que eles conversam.

---

### Prova 2 — o DNS interno resolve o nome do outro serviço

```bash
docker compose exec api getent hosts processador
docker compose exec api getent hosts db
```
Saída esperada: um IP interno e o nome.

```bash
# alternativa, se getent não existir na imagem:
docker compose exec api python -c "import socket; print(socket.gethostbyname('processador'))"
```

**O que prova:** os serviços estão na **mesma rede** e o **DNS embutido do Docker** funciona.
**Por que importa:** se isso falha, nenhum teste de HTTP interno vai funcionar. É o primeiro
lugar para olhar.

---

### Prova 3 — HTTP de dentro de um container para o outro ⭐

**A prova mais importante da comunicação interna.**

```bash
# da API para o processador, pelo NOME DO SERVIÇO
docker compose exec api python -c "import urllib.request; print(urllib.request.urlopen('http://processador:8001/api/health').read().decode())"

# do frontend (nginx/alpine) para a API — alpine tem wget, não curl
docker compose exec frontend wget -qO- http://api:8000/api/health
```

**O que prova:** um container alcança o outro **pelo nome**, sem publicar porta e sem saber o IP.

---

### Prova 4 — o TESTE NEGATIVO ⭐⭐

**Esta é a prova que diferencia quem entendeu de quem só seguiu receita.**

```bash
# a MESMA chamada, usando localhost -> DEVE FALHAR
docker compose exec api python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/api/health')"
```

Resultado esperado: **erro de conexão** (`Connection refused` / `URLError`).

**Por que isso é uma prova e não um bug:** cada container tem seu **próprio network namespace**,
logo sua **própria interface de loopback**. `localhost` dentro do container da API aponta para
**o próprio container da API** — onde não há nada na porta 8001.

> **Mostrar que a chamada por nome FUNCIONA e a por localhost FALHA prova que você entendeu
> o modelo de rede do Docker.** Documente as duas no README.

---

### Prova 5 — HTTP de fora, atravessando a cadeia ⭐

Com uma ferramenta HTTP (Postman, Insomnia, curl, Thunder Client):

```bash
# atravessa front (nginx) -> proxy -> api
curl http://localhost:3000/api/health

# faz a API chamar o PROCESSADOR e salvar no BANCO numa única requisição
curl -X POST http://localhost:3000/api/analisar \
  -H "Content-Type: application/json" \
  -d '{"valores":[10,12,9,30,11]}'
```

A resposta do segundo traz **`processado_por`** (o hostname do container do processador) e
**`recebido_por`** (o da API). **Dois hostnames diferentes na mesma resposta provam que dois
containers distintos participaram.**

**O que prova:** a cadeia completa — externo → front → api → processador → banco.

---

### Prova 6 — o endpoint de diagnóstico ⭐⭐⭐

A stack tem um endpoint que roda **todos os testes de dentro do container** e devolve um relatório:

```bash
curl http://localhost:3000/api/comunicacao
```

Ele testa: DNS do `processador`, DNS do `db`, HTTP para o processador, chamada funcional,
SQL no banco, **e o teste negativo com localhost**. Devolve um JSON com veredito:

```json
{
  "executado_de": "a1b2c3d4e5f6",
  "testes": [
    {"teste": "DNS resolve 'processador'", "resultado": "OK", "detalhe": "IP interno 172.20.0.3"},
    {"teste": "HTTP api -> processador (pelo nome)", "resultado": "OK", "detalhe": "..."},
    {"teste": "SQL api -> db (pelo nome)", "resultado": "OK", "detalhe": "SELECT 1 respondeu"},
    {"teste": "NEGATIVO: localhost:8001 falhou como esperado", "resultado": "OK", "detalhe": "..."}
  ],
  "resumo": {"total": 6, "ok": 6, "falhou": 0, "veredito": "TODOS OS SERVICOS SE COMUNICAM"}
}
```

**Por que é a melhor prova:** é **uma única chamada HTTP**, funciona em qualquer ferramenta,
e o retorno é uma evidência pronta para colar no README.

> ⚠️ **Rode sempre com a stack no Compose.** Se você rodar a aplicação direto na sua máquina
> (fora do Docker), os testes de DNS vão falhar e o teste negativo também — porque não existe rede
> do Compose e `localhost` realmente alcança tudo. O endpoint detecta isso e inclui um campo
> `resumo.observacao` avisando. Essas falhas, **fora** do Compose, são esperadas e não indicam
> problema na stack.

---

### Prova 7 — persistência: o dado atravessou e ficou

```bash
# a análise foi salva no banco?
curl http://localhost:3000/api/analises

# confirmar direto no Postgres
docker compose exec db psql -U app -d tarefas -c "SELECT id, n, media, processado_por FROM analises ORDER BY id DESC LIMIT 5;"
```

**O que prova:** o dado saiu do navegador, passou pela API, foi processado por **outro container**
e foi gravado num **terceiro**. É a prova de ponta a ponta.

---

### Prova 8 — o TESTE NEGATIVO DINÂMICO ⭐⭐⭐ (a mais forte de todas)

A Prova 4 mostra que `localhost` não alcança o outro serviço. Esta aqui mostra
algo mais difícil de fingir: **que a resposta da API realmente depende do outro
container**.

```bash
# 1. a cadeia funciona
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3000/api/analisar \
  -H "Content-Type: application/json" -d '{"valores":[1,2,3]}'
# esperado: 200

# 2. derruba de propósito o serviço de trás
docker compose stop processador

# 3. a MESMA chamada, agora
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3000/api/analisar \
  -H "Content-Type: application/json" -d '{"valores":[1,2,3]}'
# esperado: 502 ou 503

# 4. religa e espera o healthcheck
docker compose start processador
docker compose ps        # aguarde "healthy"

# 5. voltou?
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3000/api/analisar \
  -H "Content-Type: application/json" -d '{"valores":[1,2,3]}'
# esperado: 200 de novo
```

**O que prova:** que a dependência é real. Se o passo 3 ainda devolvesse `200`,
a resposta não vinha do `processador` — era dado fixo ou cache, e a
"comunicação entre serviços" seria de fachada.

**Por que isso vale nota:** o professor pediu para *verificar* a comunicação.
Mostrar que funciona é o mínimo. Mostrar que **para de funcionar quando você
quebra de propósito, e volta quando você arruma**, é o que prova que você
entendeu o mecanismo. Essa é a prova que quase ninguém faz.

Está automatizada como a Prova 8 do script (pule com `SEM_TESTE_NEGATIVO=1`).

---

## O serviço `testador` — teste de dentro, sem instalar nada

No `docker-compose.yml` existe um quinto serviço que **não sobe** no
`docker compose up`:

```yaml
  testador:
    image: curlimages/curl:latest
    profiles: ["teste"]        # <- é isso que o mantém fora do up normal
    networks: [appnet]
```

Para rodar:

```bash
docker compose --profile teste run --rm testador
```

Ele entra na rede `appnet`, chama `frontend`, `api` e `processador` **pelos
nomes dos serviços**, faz o teste negativo com `localhost` e exercita a cadeia
`api → processador`. Sai com código 0 se tudo passou.

Três motivos para ele existir:

| Problema | Como o `testador` resolve |
|---|---|
| "não tenho `curl` na minha máquina" / PowerShell atrapalha | o `curl` roda dentro de um container Alpine |
| "a imagem slim da API não tem `curl`" | o `testador` tem, e está na mesma rede |
| "teria que publicar porta só para testar" | não precisa: ele alcança por nome, por dentro |

`profiles:` é o recurso-chave aqui: serviços auxiliares (teste, seed, migração,
backup) ficam declarados no compose mas só sobem quando você pede pelo nome do
profile. É a resposta certa para "como rodar um comando pontual na rede da
stack sem sujar o `up`".

---

## O script que roda tudo

```bash
./10-teste-de-comunicacao/teste-comunicacao.sh
```

Executa as 8 provas em sequência e imprime um relatório com OK/FALHOU por linha.
**Rode, copie a saída e cole no README.** É evidência objetiva.

A Prova 8 para e religa o `processador`; se você não quiser isso (por exemplo,
rodando durante a apresentação), use:

```bash
SEM_TESTE_NEGATIVO=1 ./10-teste-de-comunicacao/teste-comunicacao.sh
```

---

## Tabela de diagnóstico

| A prova que falhou | Onde está o problema |
|---|---|
| 1 (`ps` não fica healthy) | o serviço não sobe — `docker compose logs <servico>` |
| 2 (DNS não resolve) | serviços em **redes diferentes**, ou nome do serviço escrito errado |
| 3 (HTTP interno falha) | a app do destino ouve em `127.0.0.1` em vez de **`0.0.0.0`**; ou porta interna errada |
| 4 (localhost **funciona**) | os serviços **não estão separados** — provavelmente estão no mesmo container |
| 5 (externo falha) | falta `ports:`, ou o `proxy_pass` do nginx está errado |
| 6 (endpoint acusa falha) | o próprio relatório diz qual salto quebrou |
| 7 (não persistiu) | problema de banco: credencial, tabela inexistente, ou falta o volume |
| 8 (continua 200 com o serviço parado) | a resposta **não vem** do outro serviço — é dado fixo, mock ou cache |
| 8 (não volta a 200 depois do `start`) | normal se o healthcheck ainda não ficou verde: `docker compose ps` e repita |

---

## O que levar para o README

Para cada prova que você rodar, registre três coisas:

| Registre | Exemplo |
|---|---|
| **O comando** | `docker compose exec api getent hosts processador` |
| **A saída** | `172.20.0.3  processador` |
| **O que isso prova** | "o DNS interno da rede do Compose resolve o nome do serviço" |

Ver [evidencias.md](evidencias.md) para o formato completo.

# Como documentar as evidências no README

O professor disse que o **README é o artefato principal de avaliação**, e que quer ler
**com as suas palavras** o que foi feito e compreendido. Então a seção de testes do README não é
"rodei e funcionou" — é **evidência + interpretação**.

---

## A estrutura de cada evidência — 3 partes

Para **cada** teste que você rodar:

```
1. O QUE EU TESTEI     (uma frase)
2. O COMANDO E A SAÍDA  (bloco de código, colado de verdade)
3. O QUE ISSO PROVA     (uma ou duas frases, suas)
```

A parte **3** é a que vale nota. Sem ela, você entregou um log; com ela, você entregou compreensão.

---

## Modelo pronto para a seção do README

Copie a estrutura e troque pelas suas saídas reais.

````markdown
## Testes de comunicação entre os serviços

A aplicação tem 4 containers: `frontend` (nginx), `api` (Flask/gunicorn),
`processador` (Flask/gunicorn) e `db` (Postgres). Só o `frontend` publica porta.
Testei a comunicação em três níveis: de fora para dentro, de container para
container, e serviço para serviço.

### 1. Os serviços subiram e estão saudáveis

```
$ docker compose ps
NAME                  SERVICE       STATUS
tarefas-front         frontend      Up 2 minutes (healthy)
tarefas-api           api           Up 2 minutes (healthy)
tarefas-processador   processador   Up 2 minutes (healthy)
tarefas-db            db            Up 2 minutes (healthy)
```

**O que prova:** os quatro containers subiram e os healthchecks passaram. Ainda não
prova comunicação — só que estão de pé.

### 2. O DNS interno resolve o nome dos serviços

```
$ docker compose exec api python -c "import socket; print(socket.gethostbyname('processador'))"
172.20.0.3
```

**O que prova:** `api` e `processador` estão na **mesma rede** do Compose e o DNS
embutido do Docker resolve o nome do serviço para o IP interno. Não preciso conhecer
o IP — e nem devo, porque ele muda a cada recriação do container.

### 3. HTTP de um container para o outro, pelo nome

```
$ docker compose exec api python -c "import urllib.request; print(urllib.request.urlopen('http://processador:8001/api/health').read().decode())"
{"servico":"processador","status":"ok","versao":"1.0.0"}
```

**O que prova:** comunicação **serviço → serviço** funcionando por HTTP, usando o nome
do serviço e a porta interna, **sem publicar porta nenhuma** no processador.

### 4. Teste negativo: localhost falha, como deveria

```
$ docker compose exec api python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/api/health')"
urllib.error.URLError: <urlopen error [Errno 111] Connection refused>
```

**O que prova:** cada container tem seu próprio network namespace, logo sua própria
interface de loopback. `localhost` dentro do container da `api` aponta para o próprio
container da `api`, onde não há nada na porta 8001. É por isso que a comunicação entre
containers **tem** que usar o nome do serviço. Este teste falhando é o resultado correto.

### 5. A cadeia completa, de fora

```
$ curl -X POST http://localhost:3000/api/analisar \
    -H "Content-Type: application/json" \
    -d '{"valores":[10,12,9,30,11]}'

{"n":5,"media":14.4,"minimo":9.0,"maximo":30.0,"desvio":7.7357,
 "processado_por":"8f3c1d2e4a5b","recebido_por":"a1b2c3d4e5f6",
 "id":1,"persistido":true}
```

**O que prova:** a requisição saiu da minha máquina, entrou pelo `frontend` (única porta
publicada), foi encaminhada à `api` pelo proxy reverso do nginx, a `api` chamou o
`processador` por HTTP, e o resultado foi gravado no `db`. Os campos `processado_por` e
`recebido_por` trazem **hostnames diferentes** — prova de que dois containers distintos
participaram da mesma requisição.

### 6. Relatório de comunicação interno

```
$ curl -s http://localhost:3000/api/comunicacao | python3 -m json.tool
{
  "executado_de": "a1b2c3d4e5f6",
  "testes": [
    {"teste": "DNS resolve 'processador'", "resultado": "OK", "detalhe": "IP interno 172.20.0.3"},
    {"teste": "DNS resolve 'db'", "resultado": "OK", "detalhe": "IP interno 172.20.0.2"},
    {"teste": "HTTP api -> processador (pelo nome)", "resultado": "OK", "detalhe": "..."},
    {"teste": "HTTP api -> processador (/processar)", "resultado": "OK", "detalhe": "media=20.0"},
    {"teste": "SQL api -> db (pelo nome)", "resultado": "OK", "detalhe": "SELECT 1 respondeu"},
    {"teste": "NEGATIVO: localhost:8001 falhou como esperado", "resultado": "OK", "detalhe": "..."}
  ],
  "resumo": {"total": 6, "ok": 6, "falhou": 0, "veredito": "TODOS OS SERVICOS SE COMUNICAM"}
}
```

**O que prova:** este endpoint roda os testes **de dentro** do container da `api` e
devolve o resultado por HTTP. Criei ele porque o Postman roda **fora** do Docker e não
resolve nomes de serviço — então ele não consegue testar a rede interna diretamente.
Com este endpoint, uma única chamada externa me dá a prova da comunicação interna.

### 7. Persistência

```
$ docker compose exec db psql -U app -d tarefas -c "SELECT id, n, media, processado_por FROM analises;"
 id | n | media   | processado_por
----+---+---------+----------------
  1 | 5 | 14.4000 | 8f3c1d2e4a5b
```

**O que prova:** o dado atravessou os três serviços e ficou gravado. E sobrevive a
`docker compose down` + `up`, porque o Postgres usa um named volume.

### Ferramenta HTTP usada

Usei o **Postman** para a demonstração (collection em
`10-teste-de-comunicacao/colecao-postman.json`) e o **curl** para registrar as saídas aqui,
porque saída de terminal é mais fácil de colar como evidência.
````

---

## Prints: o que vale fotografar

Se for anexar imagens, estas três valem mais que dez:

| Print | Por que vale |
|---|---|
| **`docker compose ps`** com todos `(healthy)` | mostra que são **vários containers** separados |
| **Postman na requisição `/api/comunicacao`** com o veredito visível | é a prova de comunicação num print só |
| **Postman na requisição `/api/analisar`** mostrando os dois hostnames | prova visual de que dois containers participaram |

Se quiser um quarto: o **teste negativo falhando**. Um print de erro que você *queria* ver é
contraintuitivo e memorável — e deixa claro que você entendeu o motivo.

---

## O que NÃO fazer

| Evite | Por quê |
|---|---|
| "Testei e funcionou" | não é evidência |
| Colar 300 linhas de log | ninguém lê; recorte o relevante |
| Print de código-fonte | o código já está no repositório |
| Só o print do navegador com a página abrindo | prova que o front subiu, **não** que ele fala com a API |
| Saída sem explicação | o log sem a interpretação não mostra compreensão |
| README escrito por IA | ele pediu explicitamente a sua voz |

---

## A frase de fechamento da seção

Encerre a seção de testes com algo que amarre o raciocínio. Por exemplo:

> "Os testes foram desenhados em dois eixos. De fora para dentro, para confirmar que a porta
> publicada funciona e que o proxy alcança a API. De dentro para dentro, para confirmar que os
> containers se encontram pelo nome do serviço — e o teste negativo com `localhost` confirma, por
> contraste, que o isolamento de rede entre containers existe de verdade e é por isso que o nome
> do serviço é necessário."

Escreva com as suas palavras. O conteúdo acima é o raciocínio; a redação tem que ser sua.

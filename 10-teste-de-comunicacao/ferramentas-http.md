# Ferramentas HTTP — Postman, Insomnia, curl, Thunder Client

> O professor **recomendou uma ferramenta HTTP** para o teste de comunicação.
> Qualquer uma serve. O que importa é **ter o teste e saber mostrar o resultado**.

## Qual escolher

| Ferramenta | Onde roda | Vantagem | Quando usar |
|---|---|---|---|
| **Postman** | app próprio | collection organizada, fácil de printar | ⭐ o mais reconhecido |
| **Insomnia** | app próprio | mais leve, interface limpa | alternativa ao Postman |
| **Thunder Client** | **extensão do VS Code** | não sai do editor | se você já vive no VS Code |
| **curl** | terminal | já está instalado, **saída fácil de colar no README** | ⭐ evidência em texto |
| **HTTPie** | terminal | saída colorida e legível | alternativa ao curl |
| **REST Client** | extensão do VS Code | salva as requisições num arquivo `.http` **versionável no Git** | ⭐ fica no repositório |

**Minha sugestão:** use **Postman** (para a demonstração e o print) **+ curl** (para a evidência em
texto no README). Os dois juntos cobrem "mostrei funcionando" e "registrei a prova".

---

## Importar a collection pronta

Este repositório tem uma collection pronta: **[colecao-postman.json](colecao-postman.json)**

**No Postman:** `Import` → arraste o arquivo → a collection "Ponderada Docker" aparece com
as requisições já montadas, na ordem dos testes.

**No Insomnia:** `Import/Export` → `Import Data` → `From File` → o formato do Postman é aceito.

A collection tem uma variável `{{base_url}}` definida como `http://localhost:3000`.
Se você publicou o front em outra porta, altere só essa variável.

### O que tem dentro

| # | Requisição | O que prova |
|---|---|---|
| 1 | `GET {{base_url}}/api/health` | o front está publicado e o proxy alcança a API |
| 2 | `GET {{base_url}}/api/info` | qual container respondeu (hostname e PID) |
| 3 | `GET {{base_url}}/api/comunicacao` | ⭐ **o relatório completo de comunicação** |
| 4 | `POST {{base_url}}/api/analisar` | ⭐ a cadeia inteira: front → api → processador → db |
| 5 | `GET {{base_url}}/api/analises` | o dado foi persistido |
| 6 | `GET {{base_url}}/api/tarefas` | CRUD funcionando |
| 7 | `POST {{base_url}}/api/tarefas` | escrita no banco |
| 8 | `GET http://localhost:8001/api/health` | **deve falhar** em produção (porta não publicada) |

A requisição **8 é o teste negativo pelo lado de fora**: o processador não publica porta, então
ele **não deve** ser alcançável da sua máquina. Se responder, você publicou porta desnecessariamente.

---

## O arquivo `.http` — a alternativa que fica no Git

Este repositório também tem **[requisicoes.http](requisicoes.http)**, que funciona com a extensão
**REST Client** do VS Code. Vantagem: é texto, fica versionado no repositório, e o professor
consegue ler sem instalar nada.

Para usar: abra o arquivo no VS Code com a extensão instalada e clique em **"Send Request"**
acima de cada bloco.

---

## curl — os comandos essenciais

```bash
# 1. saúde, atravessando o proxy do front
curl http://localhost:3000/api/health

# 2. quem respondeu (hostname do container da API)
curl http://localhost:3000/api/info

# 3. ⭐ o relatório completo de comunicação
curl http://localhost:3000/api/comunicacao

# 4. ⭐ a cadeia inteira numa requisição
curl -X POST http://localhost:3000/api/analisar \
  -H "Content-Type: application/json" \
  -d '{"valores":[10,12,9,30,11]}'

# 5. o dado persistiu?
curl http://localhost:3000/api/analises
```

### Flags do curl que valem conhecer

| Flag | Para que serve |
|---|---|
| `-s` | silencioso (sem barra de progresso) — bom para colar no README |
| `-i` | mostra os **headers** da resposta |
| `-v` | verboso: mostra a negociação completa — ótimo para depurar |
| `-X POST` | método HTTP |
| `-H "..."` | header |
| `-d '...'` | corpo da requisição |
| `-w "\nHTTP %{http_code}\n"` | imprime o **status code** no fim |
| `--max-time 10` | timeout |
| `-o arquivo.json` | salva a resposta num arquivo |

### Deixar a saída legível

```bash
# formatar o JSON com python (sempre disponível)
curl -s http://localhost:3000/api/comunicacao | python3 -m json.tool

# só o status code (útil para script)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health
```

---

## HTTPie — se preferir

```bash
# instalar
pip install httpie

http GET  localhost:3000/api/health
http POST localhost:3000/api/analisar valores:='[10,12,9,30,11]'
```
A saída já vem colorida e formatada, sem precisar de `python -m json.tool`.

---

## ⚠️ A armadilha de testar com ferramenta HTTP

O Postman roda **na sua máquina**, ou seja, **fora do Docker**. Então ele:

| Consegue | Não consegue |
|---|---|
| chamar `localhost:3000` (porta publicada) ✅ | chamar `http://api:8000` ❌ |
| chamar `localhost:8000` se você publicou ✅ | chamar `http://processador:8001` ❌ |

**O nome do serviço só resolve DENTRO da rede do Docker.** Se você digitar `http://api:8000` no
Postman, vai dar erro de DNS — e isso é **esperado**, não é bug.

> **Consequência prática:** a ferramenta HTTP prova a comunicação **externa** e, indiretamente, a
> interna (quando a resposta só pode ter vindo de outro container). Para provar a interna
> **diretamente**, use `docker compose exec` — as provas 2, 3 e 4 do [LEIA-ME.md](LEIA-ME.md).
>
> É por isso que o endpoint **`/api/comunicacao`** existe: ele roda os testes internos **de dentro**
> do container e devolve o resultado por HTTP. Assim uma ferramenta externa consegue, com **uma
> chamada**, obter a prova da comunicação interna.

Explicar essa distinção no README vale ponto — mostra que você entendeu onde cada ferramenta alcança.

# Passo 1 — decidir a arquitetura

Antes de escrever qualquer Dockerfile, responda estas perguntas no papel.

## 1. Quais são os serviços?

| Pergunta | Resposta típica |
|---|---|
| Tem interface de usuário? | sim -> serviço **frontend** |
| Tem API / lógica de negócio? | sim -> serviço **api** (ou backend) |
| Tem banco de dados? | sim -> serviço **db** |
| Tem cache / fila? | talvez -> serviço **cache** (Redis) |
| Tem processamento em background? | talvez -> serviço **worker** |

## 2. Quais eu construo e quais uso prontos?

| Construo (tenho Dockerfile) | Uso imagem pronta |
|---|---|
| frontend (meu código) | postgres, mysql, mongo |
| api (meu código) | redis, rabbitmq |
| worker (meu código) | nginx (quando é só servidor) |

> **Nunca escreva Dockerfile para banco de dados.** Use a imagem oficial.

## 3. Quem fala com quem?

Desenhe as setas. Exemplo típico:

```
navegador ──▶ frontend ──▶ api ──▶ db
                                └─▶ cache
```

Para cada seta, pergunte: **quem faz a chamada roda dentro ou fora do Docker?**

| Seta | Quem chama roda | Endereço |
|---|---|---|
| navegador -> frontend | **fora** | `localhost:3000` (porta publicada) |
| JS do navegador -> api | **fora** | `/api/...` relativo (proxy) ou `localhost:8000` |
| frontend (nginx) -> api | **dentro** | `http://api:8000` |
| api -> db | **dentro** | `db:5432` |

Essa tabela é onde mora a armadilha nº 1. Preencha antes de codar.

## 4. Quem publica porta?

| Serviço | Publica? | Por quê |
|---|---|---|
| frontend | **sim** | o usuário acessa pelo navegador |
| api | depende | **não**, se o front faz proxy. **sim**, se o JS chama direto ou se eu quero testar com Postman |
| db | **não** (em produção) | só a api precisa alcançá-lo |
| cache | **não** | idem |

## 5. O que precisa persistir?

| Dado | Vai para |
|---|---|
| Banco de dados | **named volume** |
| Uploads de usuário | **named volume** |
| Código em desenvolvimento | **bind mount** |
| Cache, sessão, temporário | nada (pode morrer) |

## 6. Há ordem de inicialização?

```
db (healthy) -> [migrate] -> api (healthy) -> frontend
```

## O preenchimento final

Copie e preencha para o seu projeto:

```
SERVIÇOS
  [ ] frontend  — stack: ______________  construo: sim  publica porta: 3000
  [ ] api       — stack: ______________  construo: sim  publica porta: ____
  [ ] db        — imagem: ______________ construo: não  publica porta: não
  [ ] outros:   ______________________________________________

CHAMADAS
  navegador -> frontend  : localhost:____
  JS -> api              : ____________________  (relativo? localhost?)
  frontend -> api        : http://api:____
  api -> db              : db:____

VOLUMES
  [ ] ______________ : ______________________ (caminho no container)

ORDEM
  ______________ -> ______________ -> ______________
```

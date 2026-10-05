# Exercícios: complete o Dockerfile

> O professor disse que pode pedir para **escrever ou completar** um Dockerfile, e que **não vai
> descontar por pequenos erros de sintaxe** — quer avaliar se você **sabe qual recurso resolve
> cada problema**.

Então o treino aqui não é decorar. É olhar uma lacuna e saber **o que falta e por quê**.

## Como usar

1. Abra um arquivo `exercicio-N-*.Dockerfile`
2. Preencha as lacunas marcadas com `# [ ? ]`
3. Confira no `gabarito.md` — e leia a **justificativa**, não só a linha

## Os exercícios

| Arquivo | Nível | Tema |
|---|---|---|
| `exercicio-1-basico.Dockerfile` | fácil | estrutura mínima: FROM, WORKDIR, COPY, RUN, EXPOSE, CMD |
| `exercicio-2-cache.Dockerfile` | fácil | ordem das instruções e cache de camadas |
| `exercicio-3-multistage.Dockerfile` | médio | dois estágios e o `COPY --from` |
| `exercicio-4-frontend.Dockerfile` | médio | build do front + nginx servindo estáticos |
| `exercicio-5-seguranca.Dockerfile` | médio | usuário sem privilégio e healthcheck |
| `exercicio-6-compose.txt` | médio | compose com rede, volume, healthcheck e comunicação |

> O exercício 6 tem extensão `.txt` de propósito: ele é um YAML **com lacunas**, portanto
> inválido. Assim seu editor não acusa erro de sintaxe enquanto você resolve.
| `exercicio-7-ache-os-erros.Dockerfile` | difícil | 8 erros plantados — encontre e explique |

## As 8 perguntas que preenchem qualquer lacuna

Quando bater dúvida, percorra esta lista:

| # | Pergunta | Instrução |
|---|---|---|
| 1 | Qual a imagem **base**? | `FROM` com **versão fixada** + slim/alpine |
| 2 | Preciso de **dois estágios**? | `FROM ... AS builder` + `COPY --from=builder` |
| 3 | Onde o código **mora**? | `WORKDIR` |
| 4 | Quais as **dependências**? | `COPY` do manifesto + `RUN` do instalador — **antes do código** |
| 5 | Qual o **código**? | `COPY . .` depois |
| 6 | Qual **porta**? | `EXPOSE` (documenta; não publica) |
| 7 | Com que **usuário**? | `RUN useradd` + `USER` |
| 8 | Qual o **comando de início**? | `CMD` na forma exec, servidor de **produção** |

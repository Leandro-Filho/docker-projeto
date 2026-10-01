# Passo 2 — a ordem de execução

> **Nunca dockerize tudo de uma vez.** Se os três serviços subirem juntos de primeira e algo falhar,
> você não sabe onde está o problema. Um por vez, testando.

---

## Etapa 0 — código funcionando FORA do Docker

Antes de qualquer Dockerfile:

- [ ] O backend roda na minha máquina e responde
- [ ] O frontend roda e consegue falar com o backend
- [ ] Sei exatamente qual comando sobe cada parte
- [ ] Sei quais variáveis de ambiente cada parte precisa

> O professor liberou IA para o código. Use — e depois **leia** o que ela gerou, porque você vai
> precisar explicar as escolhas no README.

---

## Etapa 1 — backend isolado

```bash
# escrever backend/Dockerfile e backend/.dockerignore
docker build -t meu-back ./backend
docker run --rm -p 8000:8000 meu-back
curl http://localhost:8000/api/health
```

- [ ] Build passa
- [ ] Container sobe e **não morre**
- [ ] `/health` responde

**Se não responder:** 9 de 10 vezes é a app ouvindo em `127.0.0.1` em vez de `0.0.0.0`.

---

## Etapa 2 — backend + banco

```bash
# escrever docker-compose.yml com api + db
docker compose up -d --build
docker compose ps           # os dois devem ficar healthy
docker compose logs -f api
curl http://localhost:8000/api/health
```

- [ ] O banco fica `healthy`
- [ ] A api conecta no banco usando o host `db`
- [ ] `docker compose down` + `up` e os dados continuam (volume funcionando)

**Se der `connection refused` intermitente:** falta `condition: service_healthy`.

---

## Etapa 3 — frontend isolado

```bash
docker build -t meu-front ./frontend
docker run --rm -p 3000:80 meu-front
# abrir http://localhost:3000
```

- [ ] A página carrega
- [ ] Navego para uma rota interna, aperto **F5** e **não** dá 404

---

## Etapa 4 — a stack toda

```bash
docker compose up -d --build
docker compose ps
# abrir http://localhost:3000 e usar a aplicação
```

- [ ] A página carrega
- [ ] As chamadas à API funcionam (abra a aba **Network** do navegador)
- [ ] Nenhum erro de CORS no console
- [ ] Nenhuma variável chegando `undefined`
- [ ] Os dados persistem depois de `down` + `up`

**Se o front não alcançar a API:** armadilha nº 1 — ou o JS está chamando `api:8000`, ou falta o
`proxy_pass` no nginx.

---

## Etapa 5 — polimento

- [ ] `.dockerignore` em cada serviço
- [ ] Versões **fixadas** nas imagens base
- [ ] `USER` sem privilégio onde der
- [ ] Senhas no `.env`, com `.env.example` no Git
- [ ] `restart: unless-stopped`
- [ ] `healthcheck` nos serviços
- [ ] `docker compose config` sem avisos
- [ ] Imagem final em tamanho razoável (`docker images`)

---

## Etapa 6 — o README (o entregável)

Ver [../08-entrega/README-ESQUELETO.md](../08-entrega/README-ESQUELETO.md).

**Escreva enquanto faz, não no fim.** Anote cada erro que você tomou e como resolveu — essa é a
parte mais valiosa do README e é impossível reconstruir depois.

---

## O comando de teste final

Simula a máquina do professor, limpa:

```bash
docker compose down -v                 # apaga tudo, inclusive dados
docker system prune -f                 # limpa cache de build
docker compose up -d --build           # sobe do zero
docker compose ps                      # tudo healthy?
# abrir no navegador e usar a aplicação
```

Se isso funcionar do zero, funciona na máquina de qualquer pessoa.

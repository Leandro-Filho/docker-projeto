# Dockerizando o BACKEND

## As 6 regras

| # | Regra | Por quê |
|---|---|---|
| 1 | Ouvir em **`0.0.0.0`**, nunca `127.0.0.1` | com localhost, só aceita conexão de dentro do próprio container |
| 2 | Config por **variável de ambiente** | a mesma imagem serve dev e produção |
| 3 | Banco pelo **nome do serviço** (`db:5432`) | o backend roda dentro do Docker, o DNS interno resolve |
| 4 | **Esperar o banco** estar pronto | healthcheck + `condition: service_healthy` |
| 5 | Servidor de **produção** (gunicorn/uvicorn), não o de dev | o embutido é single-thread e avisa que não serve |
| 6 | Endpoint **`/health`** | para o HEALTHCHECK e para o orquestrador |

## Onde cada framework precisa do 0.0.0.0

| Framework | Comando |
|---|---|
| Flask (dev) | `flask run --host 0.0.0.0` ou `app.run(host="0.0.0.0")` |
| Flask (prod) | `gunicorn -w 4 -b 0.0.0.0:8000 app:app` |
| FastAPI | `uvicorn app.main:app --host 0.0.0.0 --port 8000` |
| Express | `app.listen(8000, "0.0.0.0")` |
| Django (dev) | `python manage.py runserver 0.0.0.0:8000` |
| Django (prod) | `gunicorn projeto.wsgi:application -b 0.0.0.0:8000` |
| Spring Boot | `server.address=0.0.0.0` |

## Quantos workers no gunicorn

Regra comum: `(2 × núcleos) + 1`. Para a ponderada, `-w 2` ou `-w 4` está ótimo —
o importante é **usar gunicorn e saber explicar por quê**.

## Estrutura de pastas que eu recomendo

```
backend/
├── Dockerfile
├── Dockerfile.dev          (opcional, para hot reload)
├── .dockerignore
├── requirements.txt
└── src/
    ├── app.py
    └── ...
```

Manter o backend numa pasta própria deixa o `build: ./backend` limpo no compose e o build context
pequeno.

## .dockerignore do backend

```
.git
__pycache__/
*.pyc
.venv/
venv/
.env
.pytest_cache/
tests/
notebooks/
data/raw/
*.log
```

## Checklist antes de passar para o próximo serviço

- [ ] `docker build -t meu-back ./backend` funciona
- [ ] `docker run -p 8000:8000 meu-back` sobe
- [ ] `curl localhost:8000/health` responde
- [ ] A app ouve em `0.0.0.0` (se não responder, é quase sempre isso)
- [ ] Nenhuma senha dentro do Dockerfile

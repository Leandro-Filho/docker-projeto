# Flask dentro de container: host, porta e servidor

Este é o erro número 1 da ponderada: o container sobe, `docker compose ps` diz
`Up`, os logs estão limpos — e no navegador dá "connection reset" ou
"empty reply". Quase sempre é **host**, não porta.

---

## A regra em uma frase

> Dentro de um container, `127.0.0.1` significa **"só eu mesmo"**.
> Para alguém de fora alcançar o app, ele precisa escutar em `0.0.0.0`.

Cada container tem a sua própria pilha de rede. Se o Flask escuta em
`127.0.0.1:8000`, ele está acessível **apenas por processos dentro daquele
container**. O `-p 8000:8000` entrega o pacote na borda do container e não
encontra ninguém escutando ali → conexão derrubada.

---

## Tabela: o que cada forma de subir o Flask realmente faz

| Como você sobe | Escuta em | Funciona com `-p 8000:8000`? | Serve para produção? |
|---|---|---|---|
| `app.run()` | `127.0.0.1:5000` | ❌ não | ❌ não |
| `app.run(debug=True)` | `127.0.0.1:5000` | ❌ não | ❌ não |
| `app.run(host="0.0.0.0")` | `0.0.0.0:5000` | ✅ sim (`-p 8000:5000`) | ❌ não (servidor de desenvolvimento) |
| `app.run(host="0.0.0.0", port=8000)` | `0.0.0.0:8000` | ✅ sim | ❌ não |
| `flask run` | `127.0.0.1:5000` | ❌ não | ❌ não |
| `flask run --host=0.0.0.0` | `0.0.0.0:5000` | ✅ sim | ❌ não |
| `flask run --host=0.0.0.0 --port=8000 --reload` | `0.0.0.0:8000` | ✅ sim | ❌ não — **é o certo para DEV** com bind mount |
| `gunicorn -b 0.0.0.0:8000 src.app:app` | `0.0.0.0:8000` | ✅ sim | ✅ **sim — é o certo para PROD** |
| `gunicorn -b :8000 src.app:app` | `0.0.0.0:8000` (`:porta` já é todas) | ✅ sim | ✅ sim |
| `gunicorn -b 127.0.0.1:8000 ...` | só o próprio container | ❌ não | ❌ (erro clássico) |
| `uvicorn src.app:app --host 0.0.0.0 --port 8000` | `0.0.0.0:8000` | ✅ sim | ✅ sim (FastAPI) |

Equivalente para FastAPI: o servidor de dev é `uvicorn --reload`; em produção,
`uvicorn` com workers ou `gunicorn -k uvicorn.workers.UvicornWorker`.

---

## Os três avisos que você vai ver nos logs (e o que fazer)

**1.** `WARNING: This is a development server. Do not use it in a production
deployment.`
→ Você está usando `app.run()` / `flask run`. Em dev, pode. Na entrega da
ponderada, troque para gunicorn: é um ponto fácil de ganhar.

**2.** `Running on http://127.0.0.1:5000`
→ **Alarme.** Se não aparecer também uma linha com `0.0.0.0` ou
`Running on all addresses`, ninguém de fora vai conseguir entrar.

**3.** `Running on all addresses (0.0.0.0)` + `Running on http://172.18.0.4:5000`
→ Está certo. Aquele `172.18.x.x` é o IP do container na rede do Docker.

---

## Dev vs Prod: as duas receitas

### Dev — quero editar o código e ver na hora

```dockerfile
# flask-dev.Dockerfile
ENV FLASK_APP=src/app.py
CMD ["flask", "run", "--host=0.0.0.0", "--port=8000", "--reload"]
```

```yaml
    volumes:
      - ./src:/app/src      # bind mount: o código da sua máquina entra no container
```

O bind mount é o que faz o reload valer a pena. Sem ele, o container tem a
cópia que foi para a imagem no `build`, e editar no seu editor não muda nada.

### Prod — quero que seja de verdade

```dockerfile
# flask-prod.Dockerfile
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "--access-logfile", "-", "src.app:app"]
```

Três detalhes que importam:

- `-w 2` → número de workers. Processos de verdade, não uma thread só.
- `--access-logfile -` → o `-` manda o log de acesso para o **stdout**, que é
  onde o `docker logs` lê. Sem isso, as requisições não aparecem nos logs.
- `src.app:app` → é `módulo:variável`. Precisa de **`src/__init__.py`** para o
  Python reconhecer `src` como pacote, e o `WORKDIR` precisa ser a pasta que
  contém `src/`. Faltando o `__init__.py`, o erro é
  `ModuleNotFoundError: No module named 'src'`.

---

## Como provar que está escutando no lugar certo

De dentro do container:

```bash
docker compose exec api sh -c "ss -ltnp 2>/dev/null || netstat -ltnp"
```

Leia a coluna `Local Address`:

| O que aparece | Leitura |
|---|---|
| `0.0.0.0:8000` | ✅ aceita de qualquer lugar |
| `*:8000` ou `:::8000` | ✅ idem (notação IPv6) |
| `127.0.0.1:8000` | ❌ é este o seu bug |

Se nem `ss` nem `netstat` existem na imagem slim, vale o teste indireto:

```bash
# de dentro do PRÓPRIO container: funciona mesmo com 127.0.0.1
docker compose exec api curl -sS http://127.0.0.1:8000/api/health

# de OUTRO container: só funciona se estiver em 0.0.0.0
docker compose exec frontend curl -sS http://api:8000/api/health
```

Se o primeiro passa e o segundo falha, está provado: o app escuta só em
`127.0.0.1`.

---

## Porta de dentro ≠ porta de fora

```yaml
ports:
  - "8080:8000"
#    ^^^^ ^^^^
#    HOST CONTAINER
```

- `8000` é a porta onde o **gunicorn** escuta. Está no Dockerfile.
- `8080` é a porta que você digita no navegador. Está no compose.
- **Outro container** sempre usa a porta de **dentro**: `http://api:8000`,
  nunca `http://api:8080`.
- `EXPOSE 8000` no Dockerfile **não publica nada**. É documentação. Quem
  publica é `-p` / `ports:`.

Por isso, na stack deste repositório, só o `frontend` tem `ports:`. A `api` e o
`processador` são alcançados por nome, pela rede interna — e isso é um ponto
positivo na avaliação, não uma falta.

---

## Armadilhas por sistema operacional

**macOS — porta 5000 ocupada.** O AirPlay Receiver usa a 5000. O sintoma é um
403 esquisito vindo de um servidor que não é o seu. Use outra porta
(`-p 8000:8000`) ou desligue em Ajustes → Geral → AirDrop e Handoff.

**Windows / PowerShell — `curl` não é curl.** No PowerShell, `curl` é alias de
`Invoke-WebRequest`, que tem outra sintaxe e ignora `-sS`, `-d`, `-H`. Use:

```powershell
curl.exe -sS http://localhost:3000/api/health
```

Ou rode tudo de dentro do container, que é mais confiável:

```powershell
docker compose exec api curl -sS http://processador:8001/api/health
```

**Windows — scripts com CRLF.** Um `entrypoint.sh` salvo com fim de linha do
Windows gera
`exec /app/entrypoint.sh: no such file or directory` (o `\r` entra no caminho
do shebang). Resolva com `.gitattributes`:

```
*.sh text eol=lf
```

**Linux — permissão de arquivo em bind mount.** Se o container roda com um
usuário não-root (`USER app`) e escreve numa pasta montada do host, pode dar
`Permission denied`. Ajuste o dono no host ou escreva num volume nomeado.

---

## Checklist antes de entregar o backend

- [ ] Escuta em `0.0.0.0` (conferido com outro container, não só com `curl` local)
- [ ] Usa gunicorn/uvicorn, não o servidor de desenvolvimento
- [ ] `--access-logfile -` para os logs aparecerem no `docker logs`
- [ ] `src/__init__.py` existe se o comando é `src.app:app`
- [ ] Tem rota `/api/health` simples, para o `healthcheck` do compose usar
- [ ] `HEALTHCHECK` no Dockerfile apontando para `127.0.0.1` (aqui é correto:
      quem testa é o próprio container)
- [ ] Credenciais vêm de variável de ambiente, nunca escritas no código

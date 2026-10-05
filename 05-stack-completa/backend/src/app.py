"""
API de tarefas — backend da stack completa.

Pontos de Docker demonstrados (procure os comentarios DOCKER:):
  - ouvir em 0.0.0.0
  - configuracao por variavel de ambiente
  - banco pelo NOME DO SERVICO
  - retry de conexao (robustez, alem do healthcheck)
  - /api/health para o HEALTHCHECK
  - log em stdout
  - shutdown gracioso
"""

import os
import sys
import time
import json
import signal
import socket
import logging
import urllib.request
import urllib.error

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, jsonify, request

# DOCKER: log em stdout -- e de onde o Docker coleta (`docker compose logs`)
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("api")

app = Flask(__name__)

# DOCKER: toda configuracao vem do AMBIENTE (Twelve-Factor).
# A connection string usa o host "db", que e o NOME DO SERVICO no compose.
DATABASE_URL = os.environ.get("DATABASE_URL", "")
APP_VERSION = os.environ.get("APP_VERSION", "dev")
PORT = int(os.environ.get("PORT", "8000"))

# DOCKER: a URL do outro servico vem do AMBIENTE, nunca fixa no codigo.
# O host "processador" e o NOME DO SERVICO no docker-compose, resolvido pelo
# DNS interno da rede. NUNCA use localhost aqui -- localhost dentro deste
# container aponta para ESTE container, nao para o processador.
PROCESSADOR_URL = os.environ.get("PROCESSADOR_URL", "http://processador:8001")


def chamar_processador(valores, url=None, timeout=5):
    """
    Chama o servico processador por HTTP.

    Usa urllib (biblioteca padrao) de proposito: uma dependencia a menos
    na imagem. Em projeto real, `requests` e mais idiomatico.
    """
    destino = (url or PROCESSADOR_URL).rstrip("/") + "/api/processar"
    corpo = json.dumps({"valores": valores}).encode()
    req = urllib.request.Request(
        destino, data=corpo,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def conectar(tentativas: int = 10, espera: float = 2.0):
    """
    DOCKER: retry de conexao.

    O healthcheck + depends_on resolvem a subida inicial, mas o banco pode
    cair e voltar depois. Codigo que tenta reconectar e mais robusto do que
    depender somente da orquestracao.
    """
    ultimo_erro = None
    for n in range(1, tentativas + 1):
        try:
            return psycopg2.connect(DATABASE_URL, connect_timeout=3)
        except psycopg2.OperationalError as exc:
            ultimo_erro = exc
            log.warning("banco indisponivel (tentativa %s/%s): %s", n, tentativas, exc)
            time.sleep(espera)
    raise RuntimeError(f"nao foi possivel conectar ao banco: {ultimo_erro}")


def garantir_tabela():
    """Cria a tabela caso o init.sql nao tenha rodado (volume reaproveitado)."""
    try:
        conn = conectar()
        with conn, conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tarefas (
                    id        SERIAL PRIMARY KEY,
                    titulo    VARCHAR(200) NOT NULL,
                    concluida BOOLEAN      NOT NULL DEFAULT FALSE,
                    criada_em TIMESTAMP    NOT NULL DEFAULT NOW()
                );
            """)
        conn.close()
        log.info("tabela 'tarefas' verificada")
    except Exception as exc:
        log.error("falha ao garantir a tabela: %s", exc)


# ---------------------------------------------------------------- rotas

@app.get("/api/health")
def health():
    """DOCKER: usado pelo HEALTHCHECK do Dockerfile e pelo orquestrador."""
    return jsonify(status="ok", versao=APP_VERSION), 200


@app.get("/api/info")
def info():
    """Mostra os namespaces em acao: hostname proprio e PID proprio."""
    return jsonify(
        hostname=os.uname().nodename,   # namespace UTS
        pid=os.getpid(),                # namespace PID
        versao=APP_VERSION,
        banco_configurado=bool(DATABASE_URL),
    ), 200


@app.get("/api/tarefas")
def listar():
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, titulo, concluida, criada_em "
                        "FROM tarefas ORDER BY criada_em DESC, id DESC;")
            linhas = cur.fetchall()
        conn.close()
        for linha in linhas:
            linha["criada_em"] = linha["criada_em"].isoformat()
        return jsonify(linhas), 200
    except Exception as exc:
        log.error("erro ao listar: %s", exc)
        return jsonify(erro=str(exc)), 503


@app.post("/api/tarefas")
def criar():
    dados = request.get_json(silent=True) or {}
    titulo = (dados.get("titulo") or "").strip()
    if not titulo:
        return jsonify(erro="campo 'titulo' e obrigatorio"), 400
    if len(titulo) > 200:
        return jsonify(erro="titulo tem no maximo 200 caracteres"), 400
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("INSERT INTO tarefas (titulo) VALUES (%s) "
                        "RETURNING id, titulo, concluida, criada_em;", (titulo,))
            nova = cur.fetchone()
        conn.close()
        nova["criada_em"] = nova["criada_em"].isoformat()
        log.info("tarefa criada: id=%s titulo=%r", nova["id"], titulo)
        return jsonify(nova), 201
    except Exception as exc:
        log.error("erro ao criar: %s", exc)
        return jsonify(erro=str(exc)), 503


@app.patch("/api/tarefas/<int:tarefa_id>")
def alternar(tarefa_id):
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("UPDATE tarefas SET concluida = NOT concluida WHERE id = %s "
                        "RETURNING id, titulo, concluida, criada_em;", (tarefa_id,))
            linha = cur.fetchone()
        conn.close()
        if not linha:
            return jsonify(erro="tarefa nao encontrada"), 404
        linha["criada_em"] = linha["criada_em"].isoformat()
        return jsonify(linha), 200
    except Exception as exc:
        log.error("erro ao alternar: %s", exc)
        return jsonify(erro=str(exc)), 503


@app.delete("/api/tarefas/<int:tarefa_id>")
def remover(tarefa_id):
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM tarefas WHERE id = %s;", (tarefa_id,))
            apagadas = cur.rowcount
        conn.close()
        if not apagadas:
            return jsonify(erro="tarefa nao encontrada"), 404
        log.info("tarefa removida: id=%s", tarefa_id)
        return jsonify(removida=tarefa_id), 200
    except Exception as exc:
        log.error("erro ao remover: %s", exc)
        return jsonify(erro=str(exc)), 503


@app.post("/api/analisar")
def analisar():
    """
    SERVICO -> SERVICO: a API chama o PROCESSADOR por HTTP e guarda o
    resultado no banco. Demonstra os dois tipos de comunicacao interna
    numa unica requisicao.

    Entrada: {"valores": [10, 12, 9, 30]}
    """
    dados = request.get_json(silent=True) or {}
    valores = dados.get("valores")
    if not isinstance(valores, list) or not valores:
        return jsonify(erro="campo 'valores' deve ser uma lista nao vazia"), 400

    # --- salto 1: api -> processador (HTTP, pelo nome do servico) ---
    try:
        resultado = chamar_processador(valores)
    except urllib.error.URLError as exc:
        log.error("falha ao chamar o processador em %s: %s", PROCESSADOR_URL, exc)
        return jsonify(
            erro="nao consegui falar com o servico processador",
            detalhe=str(exc),
            url_tentada=PROCESSADOR_URL,
            dica="confira se o host e o NOME DO SERVICO e se ambos estao na mesma rede",
        ), 502

    # --- salto 2: api -> banco (persiste o resultado) ---
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO analises (n, media, minimo, maximo, desvio, processado_por) "
                "VALUES (%s,%s,%s,%s,%s,%s) RETURNING id;",
                (resultado["n"], resultado["media"], resultado["minimo"],
                 resultado["maximo"], resultado["desvio"], resultado["processado_por"]),
            )
            novo_id = cur.fetchone()[0]
        conn.close()
        resultado["id"] = novo_id
        resultado["persistido"] = True
    except Exception as exc:
        log.error("erro ao persistir a analise: %s", exc)
        resultado["persistido"] = False
        resultado["erro_persistencia"] = str(exc)

    resultado["recebido_por"] = os.uname().nodename
    return jsonify(resultado), 200


@app.get("/api/analises")
def listar_analises():
    """Lista as analises salvas -- prova que a persistencia funcionou."""
    try:
        conn = conectar(tentativas=3, espera=1)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, n, media, minimo, maximo, desvio, "
                        "processado_por, criada_em FROM analises "
                        "ORDER BY id DESC LIMIT 20;")
            linhas = cur.fetchall()
        conn.close()
        for l in linhas:
            l["criada_em"] = l["criada_em"].isoformat()
        return jsonify(linhas), 200
    except Exception as exc:
        return jsonify(erro=str(exc)), 503


@app.get("/api/comunicacao")
def comunicacao():
    """
    ENDPOINT DE DIAGNOSTICO -- o mais util deste projeto para a ponderada.

    Executa, de DENTRO do container da API, todos os testes de comunicacao
    e devolve um relatorio JSON. Basta uma chamada no Postman/Insomnia/curl
    para provar que os servicos se falam.

    Inclui um TESTE NEGATIVO proposital: a mesma chamada usando localhost
    DEVE falhar -- e isso demonstra por que se usa o nome do servico.
    """
    relatorio = {
        "executado_de": os.uname().nodename,
        "testes": [],
    }

    def registrar(nome, ok, detalhe):
        relatorio["testes"].append(
            {"teste": nome, "resultado": "OK" if ok else "FALHOU", "detalhe": detalhe}
        )

    # 1. DNS: o nome "processador" resolve?
    try:
        ip = socket.gethostbyname("processador")
        registrar("DNS resolve 'processador'", True, f"IP interno {ip}")
    except Exception as exc:
        registrar("DNS resolve 'processador'", False, str(exc))

    # 2. DNS: o nome "db" resolve?
    try:
        ip = socket.gethostbyname("db")
        registrar("DNS resolve 'db'", True, f"IP interno {ip}")
    except Exception as exc:
        registrar("DNS resolve 'db'", False, str(exc))

    # 3. HTTP: api -> processador (pelo NOME DO SERVICO)
    try:
        with urllib.request.urlopen(
            PROCESSADOR_URL.rstrip("/") + "/api/health", timeout=5
        ) as r:
            corpo = json.loads(r.read().decode())
        registrar("HTTP api -> processador (pelo nome)", True,
                  f"{PROCESSADOR_URL} respondeu {corpo}")
    except Exception as exc:
        registrar("HTTP api -> processador (pelo nome)", False, str(exc))

    # 4. HTTP funcional: api -> processador processando de verdade
    try:
        res = chamar_processador([10, 20, 30])
        registrar("HTTP api -> processador (/processar)", True,
                  f"media={res.get('media')} processado_por={res.get('processado_por')}")
    except Exception as exc:
        registrar("HTTP api -> processador (/processar)", False, str(exc))

    # 5. TCP/SQL: api -> banco
    try:
        conn = conectar(tentativas=2, espera=1)
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
        conn.close()
        registrar("SQL api -> db (pelo nome)", True, "SELECT 1 respondeu")
    except Exception as exc:
        registrar("SQL api -> db (pelo nome)", False, str(exc))

    # 6. TESTE NEGATIVO: localhost DEVE falhar
    try:
        with urllib.request.urlopen("http://localhost:8001/api/health", timeout=3):
            pass
        registrar("NEGATIVO: localhost:8001 deveria falhar", False,
                  "respondeu -- inesperado (os servicos nao estao separados?)")
    except Exception as exc:
        registrar("NEGATIVO: localhost:8001 falhou como esperado", True,
                  f"{type(exc).__name__} -- correto: localhost dentro do container "
                  f"aponta para ESTE container, nao para o processador")

    falhas = [t for t in relatorio["testes"] if t["resultado"] == "FALHOU"]
    relatorio["resumo"] = {
        "total": len(relatorio["testes"]),
        "ok": len(relatorio["testes"]) - len(falhas),
        "falhou": len(falhas),
        "veredito": "TODOS OS SERVICOS SE COMUNICAM" if not falhas
                    else "HA FALHA DE COMUNICACAO",
    }

    # Se o DNS dos nomes de servico nao resolve, provavelmente a app NAO esta
    # rodando dentro da rede do Compose (ex.: rodando direto na maquina, para
    # desenvolvimento). Nesse caso as falhas de DNS e do teste negativo sao
    # ESPERADAS e nao indicam problema na stack.
    dns_falhou = any(
        t["resultado"] == "FALHOU" and t["teste"].startswith("DNS")
        for t in relatorio["testes"]
    )
    if dns_falhou:
        relatorio["resumo"]["observacao"] = (
            "Os nomes de servico nao resolveram. Isto indica que a aplicacao nao "
            "esta rodando dentro da rede do Docker Compose. Fora do Compose, as "
            "falhas de DNS e do teste negativo com localhost sao ESPERADAS. "
            "Para o teste valer como evidencia, suba com: docker compose up -d --build"
        )

    return jsonify(relatorio), (200 if not falhas else 503)


# ---------------------------------------------------------------- sinais

def encerrar(signum, _frame):
    """DOCKER: shutdown gracioso. Funciona porque o CMD usa a forma exec."""
    log.info("recebi sinal %s, encerrando", signum)
    sys.exit(0)


signal.signal(signal.SIGTERM, encerrar)
signal.signal(signal.SIGINT, encerrar)

if DATABASE_URL:
    garantir_tabela()

if __name__ == "__main__":
    log.info("subindo API na porta %s (versao %s)", PORT, APP_VERSION)
    # DOCKER: host="0.0.0.0" e OBRIGATORIO. Com 127.0.0.1 a app so aceitaria
    # conexao de dentro do proprio container e o port mapping nao funcionaria.
    app.run(host="0.0.0.0", port=PORT)

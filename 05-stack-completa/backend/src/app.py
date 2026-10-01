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
import signal
import logging

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

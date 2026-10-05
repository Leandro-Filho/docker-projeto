"""
SERVICO PROCESSADOR - o segundo backend da stack.

Por que este servico existe neste repositorio:
  A ponderada pede para VERIFICAR SE UM SERVICO CONSEGUE FALAR COM O OUTRO.
  Front -> API -> Banco ja mostra comunicacao, mas o caso mais cobrado e
  SERVICO -> SERVICO por HTTP, que e o que acontece aqui:

      api  ──HTTP──▶  processador

  A API chama este servico pelo NOME DO SERVICO (http://processador:8001),
  resolvido pelo DNS interno da rede do Compose. Este servico NAO publica
  porta: ele so e alcancavel de dentro da rede.

O que ele faz: recebe uma lista de leituras e devolve estatisticas.
E deliberadamente simples -- o ponto nao e a logica, e a COMUNICACAO.
"""

import os
import sys
import signal
import logging
import statistics

from flask import Flask, jsonify, request

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s | PROCESSADOR | %(levelname)-7s | %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("processador")

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "dev")
PORT = int(os.environ.get("PORT", "8001"))


@app.get("/api/health")
def health():
    """Usado pelo HEALTHCHECK e pelo teste de comunicacao."""
    return jsonify(status="ok", servico="processador", versao=APP_VERSION), 200


@app.get("/api/info")
def info():
    """Mostra o hostname proprio (namespace UTS) -- prova que e OUTRO container."""
    return jsonify(
        servico="processador",
        hostname=os.uname().nodename,
        pid=os.getpid(),
        versao=APP_VERSION,
    ), 200


@app.post("/api/processar")
def processar():
    """
    Recebe {"valores": [1.0, 2.0, ...]} e devolve estatisticas.
    Chamado pela API, nunca diretamente pelo navegador.
    """
    dados = request.get_json(silent=True) or {}
    valores = dados.get("valores")

    if not isinstance(valores, list) or not valores:
        return jsonify(erro="campo 'valores' deve ser uma lista nao vazia"), 400
    try:
        nums = [float(v) for v in valores]
    except (TypeError, ValueError):
        return jsonify(erro="todos os itens de 'valores' devem ser numericos"), 400

    resultado = {
        "n": len(nums),
        "media": round(statistics.fmean(nums), 4),
        "minimo": min(nums),
        "maximo": max(nums),
        "desvio": round(statistics.pstdev(nums), 4) if len(nums) > 1 else 0.0,
        "processado_por": os.uname().nodename,   # prova de qual container processou
    }
    log.info("processei %s valores -> media=%s", len(nums), resultado["media"])
    return jsonify(resultado), 200


def encerrar(signum, _frame):
    log.info("recebi sinal %s, encerrando", signum)
    sys.exit(0)


signal.signal(signal.SIGTERM, encerrar)
signal.signal(signal.SIGINT, encerrar)

if __name__ == "__main__":
    log.info("subindo PROCESSADOR na porta %s", PORT)
    # 0.0.0.0 e obrigatorio: com 127.0.0.1 a API em OUTRO container nao alcanca.
    app.run(host="0.0.0.0", port=PORT)

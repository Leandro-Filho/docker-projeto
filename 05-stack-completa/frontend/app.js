// ============================================================
// Front da stack completa.
//
// DOCKER - o ponto mais importante deste arquivo:
//
//   Este JavaScript roda no NAVEGADOR DO USUARIO, que esta FORA do Docker.
//   Por isso ele NAO pode chamar "http://api:8000" -- esse nome so existe
//   dentro da rede do Docker, e o navegador nao o resolve.
//
//   Em vez disso, chamamos um CAMINHO RELATIVO: "/api/...".
//   O nginx (que roda DENTRO do Docker) recebe e faz proxy_pass para
//   http://api:8000/api/.
//
//   Beneficios:
//     - funciona em qualquer maquina, sem mudar codigo
//     - mesma origem para o navegador -> SEM CORS
//     - uma unica porta publicada
//     - nenhuma variavel de ambiente com a URL da API
// ============================================================

const API = "/api";

const form   = document.getElementById("form");
const titulo = document.getElementById("titulo");
const lista  = document.getElementById("lista");
const vazio  = document.getElementById("vazio");
const erroEl = document.getElementById("erro");
const pillApi  = document.getElementById("pill-api");
const pillHost = document.getElementById("pill-host");

function mostrarErro(msg) {
  erroEl.textContent = msg;
  erroEl.hidden = false;
}

function limparErro() {
  erroEl.hidden = true;
}

async function verificarApi() {
  try {
    const r = await fetch(`${API}/info`);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const info = await r.json();
    pillApi.textContent = `API: ok (v${info.versao})`;
    pillApi.className = "pill ok";
    // hostname do container da API -> namespace UTS em acao
    pillHost.textContent = `host da API: ${info.hostname} (pid ${info.pid})`;
  } catch (e) {
    pillApi.textContent = "API: indisponivel";
    pillApi.className = "pill ruim";
    mostrarErro(`Nao consegui falar com a API: ${e.message}. ` +
                `Veja os logs com: docker compose logs -f api`);
  }
}

function formatarData(iso) {
  try {
    return new Date(iso).toLocaleString("pt-BR", {
      day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit"
    });
  } catch { return ""; }
}

function render(tarefas) {
  lista.innerHTML = "";
  vazio.hidden = tarefas.length > 0;

  for (const t of tarefas) {
    const li = document.createElement("li");
    if (t.concluida) li.classList.add("feita");

    const span = document.createElement("span");
    span.className = "titulo";
    span.textContent = t.titulo;

    const data = document.createElement("span");
    data.className = "data";
    data.textContent = formatarData(t.criada_em);

    const btnOk = document.createElement("button");
    btnOk.className = "acao";
    btnOk.textContent = t.concluida ? "reabrir" : "concluir";
    btnOk.onclick = () => alternar(t.id);

    const btnDel = document.createElement("button");
    btnDel.className = "acao remover";
    btnDel.textContent = "remover";
    btnDel.onclick = () => remover(t.id);

    li.append(span, data, btnOk, btnDel);
    lista.appendChild(li);
  }
}

async function carregar() {
  try {
    const r = await fetch(`${API}/tarefas`);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    render(await r.json());
    limparErro();
  } catch (e) {
    mostrarErro(`Nao consegui carregar as tarefas: ${e.message}`);
  }
}

async function alternar(id) {
  try {
    const r = await fetch(`${API}/tarefas/${id}`, { method: "PATCH" });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    await carregar();
  } catch (e) { mostrarErro(e.message); }
}

async function remover(id) {
  try {
    const r = await fetch(`${API}/tarefas/${id}`, { method: "DELETE" });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    await carregar();
  } catch (e) { mostrarErro(e.message); }
}

form.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const texto = titulo.value.trim();
  if (!texto) return;
  try {
    const r = await fetch(`${API}/tarefas`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ titulo: texto })
    });
    if (!r.ok) {
      const corpo = await r.json().catch(() => ({}));
      throw new Error(corpo.erro || `HTTP ${r.status}`);
    }
    titulo.value = "";
    await carregar();
  } catch (e) { mostrarErro(e.message); }
});

verificarApi();
carregar();

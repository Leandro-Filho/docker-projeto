# Dockerizando o FRONTEND

> ⚠️ **Leia primeiro:** [../06-problemas-comuns/pegadinhas-front-back.md](../06-problemas-comuns/pegadinhas-front-back.md)
> As armadilhas 1, 2, 3 e 4 são todas de frontend.

---

## A decisão que define tudo: SPA ou SSR?

| | **SPA** (React, Vue, Svelte, Angular) | **SSR** (Next.js, Nuxt, SvelteKit) |
|---|---|---|
| O que o build gera | **arquivos estáticos** (HTML, JS, CSS) | uma **aplicação Node** |
| Quem serve | **nginx** (ou qualquer servidor web) | **Node** |
| Imagem final | `nginx:alpine` (~25 MB) | `node:alpine` (~150 MB) |
| Multi-stage | obrigatório | obrigatório |
| Chama a API de onde | **navegador** | navegador **e** servidor |

**SPA é o caso mais comum e o mais simples.** Build gera `dist/`, nginx serve, fim.

---

## O padrão SPA — build + nginx

```
┌─ ESTÁGIO 1: node:20-alpine ──────────┐
│  npm ci                              │
│  npm run build   -> gera dist/       │
└──────────────┬───────────────────────┘
               │ COPY --from=builder /app/dist
               ▼
┌─ ESTÁGIO 2: nginx:alpine ────────────┐
│  serve os estáticos                  │
│  + try_files (rotas do SPA)          │
│  + proxy_pass /api/ -> http://api    │
└──────────────────────────────────────┘
```

O que **não** vai para a imagem final: Node, npm, `node_modules`, TypeScript, o código fonte.
Só os estáticos compilados. É o caso mais dramático de ganho com multi-stage.

---

## As 4 coisas que o nginx.conf precisa ter

Ver [nginx.conf](nginx.conf) completo. O essencial:

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;

    # 1. ROTAS DO SPA — sem isso, F5 numa rota dá 404
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 2. PROXY REVERSO PARA A API — resolve "api" por dentro do Docker
    #    e elimina CORS (mesma origem para o navegador)
    location /api/ {
        proxy_pass http://api:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 3. CACHE dos assets com hash no nome
    location ~* \.(js|css|woff2?|png|jpg|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 4. index.html SEM cache (senão o usuário fica preso numa versão antiga)
    location = /index.html {
        add_header Cache-Control "no-store";
    }
}
```

---

## Variáveis de ambiente — o resumo

> **Variáveis `VITE_*`, `REACT_APP_*`, `NEXT_PUBLIC_*` são substituídas no BUILD.**
> `environment:` no compose **não chega** nelas.

| Preciso de URL configurável? | Solução |
|---|---|
| **Não** (uso proxy reverso) | ⭐ nada a fazer — o front chama `/api/...` relativo |
| Sim, e uma imagem por ambiente serve | `ARG` + `--build-arg` |
| Sim, e quero uma imagem para todos | [entrypoint-runtime-env.sh](entrypoint-runtime-env.sh) |

---

## Hot reload em desenvolvimento

Para dev, não construa os estáticos — rode o servidor de dev do framework:

```yaml
frontend:
  build:
    context: ./frontend
    dockerfile: Dockerfile.dev
  ports:
    - "5173:5173"
  volumes:
    - ./frontend:/app
    - /app/node_modules          # ⭐ protege o node_modules do container
  environment:
    CHOKIDAR_USEPOLLING: "true"  # detecta mudança dentro do volume
```

E o Vite precisa de `--host 0.0.0.0` para aceitar conexão de fora do container.

---

## Checklist do frontend

- [ ] `docker build -t meu-front ./frontend` funciona
- [ ] `docker run -p 3000:80 meu-front` serve a página
- [ ] Navego para uma rota interna, aperto **F5**, e **não** dá 404
- [ ] As chamadas à API funcionam (aba Network do navegador, sem erro de CORS)
- [ ] Nenhuma variável de ambiente chegando `undefined` no console
- [ ] A imagem final **não** tem `node_modules` (`docker images` mostra tamanho pequeno)

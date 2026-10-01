# Checklist da entrega

## Antes do dia

- [ ] Este repositório está **no meu GitHub** (a consulta é liberada ao meu GitHub)
- [ ] Rodei a stack de `05-stack-completa/` e fiz pelo menos os experimentos 2, 5 e 6
- [ ] Li `06-problemas-comuns/pegadinhas-front-back.md` inteiro
- [ ] Sei de cabeça o fluxo de `00-plano/02-ordem-de-trabalho.md`
- [ ] Minhas anotações de aula estão neste repo também
- [ ] Anotações em papel separadas (pode levar)

## As regras do professor

| Item | Regra |
|---|---|
| Consulta | **liberada ao meu GitHub** |
| Livro de Docker | pode usar |
| Anotações em papel | pode levar |
| **Código da aplicação** | **pode usar IA** |
| **Arquivos Docker** | usar os **meus** |
| **README** | escrito **por mim**, sem IA |
| Entregável principal | **o README** |

## Durante — a ordem

1. [ ] Ler o enunciado e preencher o mapa de `00-plano/01-arquitetura.md`
2. [ ] Código funcionando **fora** do Docker (pode usar IA)
3. [ ] Dockerfile do **backend** -> testar isolado
4. [ ] **Banco** no compose -> testar back + banco
5. [ ] Dockerfile do **frontend** -> testar isolado
6. [ ] **Compose** juntando tudo -> testar a integração
7. [ ] Polimento
8. [ ] **README** (escrito por mim, anotando os erros pelo caminho)

## Verificação do Dockerfile (cada serviço)

- [ ] `FROM` com **versão fixada** (não `latest`) e variante slim/alpine
- [ ] **Multi-stage** se há compilação ou transpilação
- [ ] Manifesto de dependências copiado **antes** do código
- [ ] `WORKDIR` definido
- [ ] `EXPOSE` da porta
- [ ] `USER` sem privilégio
- [ ] `CMD` na **forma exec** (lista JSON)
- [ ] Servidor de **produção** (gunicorn/uvicorn/nginx), não o de dev
- [ ] **Nenhum segredo** no arquivo
- [ ] `.dockerignore` existe

## Verificação do Compose

- [ ] `ports:` **só** em quem precisa de acesso externo
- [ ] Conexões internas pelo **nome do serviço**, nunca IP
- [ ] **Named volume** no banco, no caminho correto
- [ ] `networks:` declarada **explicitamente**
- [ ] `healthcheck` no banco + `condition: service_healthy` na api
- [ ] `restart: unless-stopped`
- [ ] Senhas via `${VARIAVEL}` do `.env`
- [ ] `.env` no `.gitignore` e `.env.example` no Git

## Verificação do frontend (as armadilhas)

- [ ] O JS **não** chama `api:8000` (o navegador não resolve)
- [ ] Ou uso `proxy_pass` no nginx, ou publico a API e trato CORS
- [ ] `try_files $uri $uri/ /index.html` no nginx (F5 não dá 404)
- [ ] Nenhuma variável de ambiente chegando `undefined` no console
- [ ] Se uso `VITE_*`, passo por `--build-arg` (não por `environment:`)

## Teste final — simular a máquina do professor

```bash
docker compose down -v
docker system prune -f
docker compose up -d --build
docker compose ps              # tudo healthy?
```
- [ ] Subiu do zero sem erro
- [ ] Abri no navegador e usei a aplicação
- [ ] `down` + `up` e os dados persistiram

## Entrega

- [ ] README escrito **por mim** (ver `README-ESQUELETO.md`)
- [ ] Repositório com histórico de commits (não um commit único gigante)
- [ ] `.env` **não** commitado
- [ ] Instruções de "como rodar" testadas por mim do zero

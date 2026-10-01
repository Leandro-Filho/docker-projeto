# Esqueleto do README da ponderada

> **Este arquivo tem PERGUNTAS, não texto pronto.**
> O professor quer ler **a minha voz**, sem passar por IA:
> *"Eu quero ver nós vai, nós fumo, deu problema. Foda-se. Eu quero ler o que você escreveu ali."*
>
> E o que ele avalia: *"o quanto você conseguiu compreender, o quanto você conseguiu entender
> de cada uma das coisas."*

---

## 1. Identificação
Nome, turma, nome da atividade.

## 2. O que é o projeto
> **Pergunta:** Com as minhas palavras, o que a aplicação faz?
> (Duas ou três frases. Não é para impressionar, é para situar quem lê.)

## 3. Como rodar
> **Pergunta:** Quais comandos, na ordem exata, alguém precisa dar para subir isso?
> Como essa pessoa confere que funcionou?

Testar essas instruções do zero antes de entregar. Numa máquina limpa, elas funcionam?

## 4. A arquitetura
> **Pergunta:** Quantos containers eu tenho? O que cada um faz? Quem fala com quem?

Vale desenhar em texto, tipo:
```
navegador -> frontend (nginx) -> api (gunicorn) -> db (postgres)
```

> **Pergunta:** Por que eu separei assim e não num container só?

## 5. As decisões que eu tomei

Para cada linha: **o que escolhi** e **por quê**. Esta é a seção que mais vale.

| Decisão | Pergunta para eu responder |
|---|---|
| Imagem base de cada serviço | Qual escolhi? Por que slim/alpine? Por que fixei a versão? |
| Multi-stage | Usei onde? O que ficou de fora da imagem final? Quanto diminuiu? |
| Ordem do Dockerfile | Por que copiei dependências antes do código? |
| Usuário | Rodo como root ou não? Por quê? |
| Servidor de produção | Por que gunicorn/nginx em vez do servidor de desenvolvimento? |
| Portas | Quais serviços publiquei e quais não? Por quê? |
| **Como o front alcança a API** | Proxy reverso ou porta publicada? **Por que essa escolha?** |
| CORS | Precisei configurar? Por que sim ou por que não? |
| Rede | Como os serviços se encontram? Por que não usei IP? |
| Volumes | O que precisa sobreviver? Named volume ou bind mount? |
| Ordem de inicialização | Precisei de healthcheck? Por quê? |
| Segredos | Onde ficam as senhas? Por que não no Dockerfile? |

> A pergunta sobre **como o front alcança a API** é a mais reveladora de todas. Se eu souber
> explicar que o JavaScript roda no navegador — fora da rede do Docker — e por isso não resolve
> `api:8000`, eu demonstrei que entendi o modelo de rede do Docker de verdade.

## 6. O que deu errado no caminho ⭐
> **Pergunta:** Que erros eu tomei? O que a mensagem dizia? Como descobri a causa? Como resolvi?

**Esta é provavelmente a seção mais valiosa do README.** Erro real e resolvido mostra que eu mexi,
não que eu copiei. Escreva na hora que acontecer — depois não dá para reconstruir.

Candidatos (marque os que acontecerem com você):
- [ ] container subiu e morreu na hora
- [ ] "port is already allocated"
- [ ] a API não respondia (ouvindo em 127.0.0.1)
- [ ] o front não alcançava a API
- [ ] erro de CORS
- [ ] variável do front chegando undefined
- [ ] 404 ao recarregar uma rota do SPA
- [ ] connection refused no banco, intermitente
- [ ] perdi os dados ao recriar
- [ ] node_modules brigando com o do host
- [ ] imagem gigante
- [ ] permissão negada ao escrever
- [ ] init.sql que não aplicava

## 7. O que ficou simplificado
> **Pergunta:** O que eu sei que está simplificado ou que faria diferente com mais tempo?

Honestidade aqui pesa a favor. Exemplos: segredos ainda em `.env` em vez de secrets; sem HTTPS;
sem CI; migrations rodando no startup em vez de serviço separado.

## 8. Uso de IA
> **Pergunta:** Onde usei IA e onde não usei?

O professor liberou IA para o **código** e pediu os arquivos **Docker** e o **README** meus.
Ser explícito aqui é honestidade — e ele valoriza isso.

---

## Como escrever (dicas que não são escrever por mim)

- **Escreva enquanto faz**, não no fim. Especialmente a seção 6.
- Primeiro jogue tudo no papel, depois organize. Não tente escrever bonito de primeira.
- Frase curta. Se ficou com três vírgulas, quebre em duas.
- Toda escolha técnica tem duas partes: **o que fiz** e **por que fiz**.
- Não use palavra que eu não usaria falando.
- Erro não é vergonha — é evidência de trabalho real.
- Se eu não consigo explicar uma linha do meu Dockerfile, eu não entendi aquela linha ainda.
  Volte, entenda, e **depois** escreva.

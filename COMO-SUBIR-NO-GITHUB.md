# Como subir este repositório no meu GitHub

A consulta na ponderada é liberada ao **meu GitHub**, então isto precisa estar lá **antes** do dia.

## Pelo terminal

```bash
cd docker-projeto

git init
git add .
git commit -m "Kit de containerizacao para a ponderada"
git branch -M main

# trocar SEU-USUARIO pelo meu usuário do GitHub
git remote add origin https://github.com/SEU-USUARIO/docker-projeto.git
git push -u origin main
```

Se pedir senha: o GitHub não aceita mais senha. Use um **Personal Access Token**
(Settings -> Developer settings -> Personal access tokens -> Generate new token, escopo `repo`)
como senha, ou configure SSH.

## Pelo site

1. github.com -> **New repository**
2. Nome: `docker-projeto` · visibilidade **Private** serve
3. Criar **sem** README
4. Usar **"uploading an existing file"** e arrastar a pasta

## Depois de subir

- [ ] Abrir no navegador e conferir que o **README aparece com o índice navegável**
- [ ] Clicar em alguns links do índice (são caminhos relativos, funcionam no GitHub)
- [ ] Adicionar minhas anotações de aula em `09-minhas-anotacoes/`
- [ ] No dia, deixar o repositório aberto numa aba

## Importante: o `.env`

O `.gitignore` já bloqueia o `.env`. **Nunca commite senhas.**
O que vai para o Git é o `.env.example`, com valores de placeholder.

Se por acidente você commitar um `.env`, trocar a senha é obrigatório — ela fica no histórico do Git
para sempre, mesmo depois de apagada do arquivo.

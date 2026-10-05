# Padrões de projeto — referência enxuta

Padrão de projeto é uma **solução reutilizável para um problema recorrente de
design**. Não é código pronto: é a forma da solução. Vêm do catálogo GoF
(*Design Patterns*, 1994), dividido em três famílias:

| Família | Resolve | Padrões aqui |
|---|---|---|
| **Criacionais** | como objetos são **criados** | Singleton, Prototype, Builder, Factory |
| **Estruturais** | como objetos são **compostos** | Facade, Proxy |
| **Comportamentais** | como objetos **interagem** | Iterator, Observer, Mediator, State |

Saber a família de cada um já responde meia questão.

---

## Criacionais

### Singleton
**Problema:** preciso garantir que existe **uma única instância** de algo, com
ponto de acesso global.
**Como:** construtor privado + um método estático que devolve sempre a mesma
instância.
**Usa quando:** conexão/pool de banco, objeto de configuração, logger.
**Cuidado:** é o padrão mais criticado — dificulta teste (estado global) e vira
desculpa para variável global. Em sistemas concorrentes precisa de cuidado com
thread safety.

```python
class Config:
    _inst = None
    def __new__(cls):
        if cls._inst is None:
            cls._inst = super().__new__(cls)
        return cls._inst
```

### Prototype
**Problema:** criar um objeto novo é caro ou complicado, mas eu já tenho um
pronto parecido.
**Como:** o próprio objeto sabe se **clonar** (`clone()`), em vez de alguém de
fora remontá-lo do zero.
**Usa quando:** objetos com muita configuração interna; "duplicar este registro".
**Detalhe de prova:** cópia **rasa** (shallow) copia referências; cópia
**profunda** (deep) copia o conteúdo. Em Python, `copy.copy` vs `copy.deepcopy`.

### Builder
**Problema:** um construtor com 12 parâmetros, metade opcionais.
**Como:** monta o objeto **passo a passo**, com métodos encadeados, e só no fim
`build()` entrega o objeto pronto e válido.
**Usa quando:** criar um relatório, uma query, uma requisição HTTP complexa.
**Diferença de Factory:** Factory decide **qual** classe criar; Builder decide
**como montar** uma classe só, em etapas.

```python
q = (Query().select("id","nome").de("tarefas").onde("feito = false").limite(10).build())
```

### Factory (Factory Method / Abstract Factory)
**Problema:** o código precisa criar objetos, mas não deve depender da classe
concreta.
**Como:** delega a criação a um método/objeto fábrica que devolve a interface.
**Usa quando:** "se o formato é csv devolve `LeitorCSV`, se é json devolve
`LeitorJSON`" — e quem chama só conhece `Leitor`.
**Factory Method** = um método que cria **um** tipo de produto, sobrescrevível
por subclasses. **Abstract Factory** = uma fábrica que cria **famílias**
inteiras de produtos relacionados.

---

## Estruturais

### Facade (Fachada)
**Problema:** um subsistema tem 8 classes e usar direito exige saber a ordem
certa de chamar tudo.
**Como:** uma classe de fachada expõe **um método simples** e esconde a
orquestração interna.
**Usa quando:** sua API tem `POST /api/analisar` que por dentro chama o
processador, valida, grava no banco e monta a resposta. **Esse endpoint é uma
fachada.**
**Chave:** simplifica, mas **não restringe** — você ainda pode usar as classes
internas direto.

### Proxy
**Problema:** quero controlar o acesso a um objeto — cachear, autorizar, adiar
a criação, registrar log — sem mudar o objeto nem quem o chama.
**Como:** um objeto com a **mesma interface** do real, que decide se/quando
repassa a chamada.
**Tipos:** *virtual* (cria só quando precisa), *de proteção* (checa permissão),
*remoto* (o real está em outra máquina), *de cache*.
**Na sua stack:** o **nginx fazendo `proxy_pass` para `api:8000`** é literalmente
este padrão — mesma interface HTTP, controla o acesso, o cliente não sabe que
existe outro servidor atrás.

> **Facade vs Proxy** é pergunta clássica: a fachada tem interface
> **diferente** (mais simples) da do subsistema; o proxy tem a **mesma**
> interface do objeto real.

---

## Comportamentais

### Iterator
**Problema:** percorrer uma coleção sem expor como ela é guardada por dentro
(array? árvore? paginação de API?).
**Como:** um objeto iterador com "tem próximo?" e "próximo".
**Usa quando:** você quer o mesmo `for` funcionando para lista, arquivo e
resultado de query paginada.
**Em Python:** é nativo — `__iter__` / `__next__`, e todo gerador (`yield`) é um
iterador.

### Observer
**Problema:** quando algo muda, vários interessados precisam saber — e eu não
quero que o objeto que muda conheça cada um deles.
**Como:** o *subject* mantém uma lista de observadores e **notifica** todos na
mudança. Observadores se inscrevem e se desinscrevem.
**Usa quando:** eventos, webhooks, publish/subscribe, reatividade de interface.
**Chave:** acoplamento **um-para-muitos** e de mão única (o subject não sabe o
que cada observador faz).

### Mediator
**Problema:** N objetos se conhecendo mutuamente = malha de dependências
(N² relações).
**Como:** todos falam com um **mediador** central, que coordena. As peças
passam a conhecer só o mediador.
**Usa quando:** campos de um formulário que se habilitam entre si; sala de chat;
controlador que orquestra serviços.

> **Observer vs Mediator:** Observer é **notificação** (um avisa muitos, sem
> coordenar). Mediator é **coordenação** (um centro decide o que cada um faz).

### State
**Problema:** um objeto se comporta de forma diferente dependendo do seu estado,
e o código virou um `if estado == "x" elif estado == "y"` gigante em todo método.
**Como:** cada estado vira uma **classe** com o comportamento daquele estado; o
objeto delega para o estado atual e troca de estado quando preciso.
**Usa quando:** pedido (`novo → pago → enviado → entregue`), tarefa
(`pendente → fazendo → feita`), conexão.
**Ligação com UML:** é o padrão que materializa um **diagrama de máquina de
estados**.

---

## Tabela de decisão — "qual padrão usar?"

| O enunciado diz... | Padrão |
|---|---|
| "uma única instância compartilhada" | Singleton |
| "clonar um objeto existente" | Prototype |
| "muitos parâmetros opcionais / montar por etapas" | Builder |
| "escolher a classe concreta em tempo de execução" | Factory |
| "simplificar o uso de um subsistema complicado" | Facade |
| "controlar/interceptar o acesso mantendo a mesma interface" | Proxy |
| "percorrer sem expor a estrutura interna" | Iterator |
| "avisar vários interessados quando algo mudar" | Observer |
| "reduzir o acoplamento entre muitos objetos que se conversam" | Mediator |
| "comportamento muda conforme o estado" | State |

---

## Como isso aparece na ponderada de Docker

Você pode ganhar pontos citando os padrões que **já estão** na sua arquitetura —
sem inventar código novo:

| Na stack | Padrão |
|---|---|
| nginx com `proxy_pass` para `api:8000` | **Proxy** |
| `POST /api/analisar` orquestrando processador + banco numa chamada só | **Facade** |
| objeto de configuração lido de variáveis de ambiente, instanciado uma vez | **Singleton** |
| camada de acesso a dados devolvendo a mesma interface para o endpoint | Repository (não é GoF, mas conta) |
| `GET /api/comunicacao` percorrendo a lista de provas uma a uma | **Iterator** |

Dizer "o nginx no meu compose é um Proxy, e o endpoint `/api/analisar` é uma
Facade sobre o processador e o banco" é o tipo de frase que mostra que você
entendeu os dois assuntos ao mesmo tempo.

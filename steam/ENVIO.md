# Envio para a Steam, passo a passo

Regras conferidas na documentação da Steamworks em **22/11/2026**. Os arquivos
citados ficam em `builds/steam-envio/` (gerado por `python3 tools/steam_kit.py`).

São **três envios, nesta ordem**:

1. **Cadastro** no Steam Direct: hoje.
2. **Página "Em breve"** do jogo-base: assim que o cadastro liberar.
3. **Demo**, com App ID próprio: depois do playtest.

> **Nunca envie o build da demo como build do jogo-base.** A análise recusa
> ("Submit the full game, not the demo"). O build do jogo-base só vai quando as
> 5 regiões existirem. A página "Em breve" não precisa de build.

---

## Etapa 0: decidir antes de se cadastrar

- [ ] **Nome: Hound.exe, decidido em 22/11/2026.** Depois que a página passa pela análise,
      [não dá para trocar sozinho](https://partner.steamgames.com/doc/store/editing/name).
  - [x] triagem na Steam e no TMview, que inclui INPI, USPTO e EUIPO: [NOME.md](NOME.md)
  - [ ] um advogado de marcas confirmar, antes de mandar a página para análise
        (o cadastro não precisa esperar por isso)
- [ ] **Pessoa física ou empresa.** Como pessoa física, a forma é
      "Sole Proprietorship" e o nome da empresa é o seu nome legal completo.
      Apelido e nome fantasia não servem.
- [ ] **Contato de suporte.** Fica público. Use um e-mail só para o jogo, não o pessoal.
- [ ] **Repositório público ou privado.** Hoje qualquer um compila o jogo.

## Etapa 1: cadastro (30 a 60 minutos, só você)

Entrada: <https://partner.steamgames.com/steamdirect?l=brazilian>

Tenha em mãos:

- [ ] conta Steam sua, com Steam Guard
- [ ] documento de identidade
- [ ] conta bancária **com o mesmo nome legal** do cadastro, SWIFT/BIC, IBAN e
      endereço do banco
- [ ] CPF (ou CNPJ) para a entrevista fiscal
- [ ] US$ 100 num meio de pagamento que não seja a Carteira Steam (pode ter
      imposto em cima)

Na ordem em que aparece:

- [ ] Entrar com a conta Steam que vai administrar o jogo. O crédito de app
      fica preso à conta que pagar.
- [ ] Nome legal e forma da empresa, idênticos aos do banco.
- [ ] Ler e assinar o NDA e o contrato de distribuição.
- [ ] Pagar os US$ 100 por jogo. Não é reembolsável; volta após US$ 1.000 de
      receita bruta ajustada.
- [ ] Banco, entrevista fiscal (W-8BEN para pessoa física fora dos EUA) e identidade.
- [ ] Olhar o e-mail: a verificação leva **até 30 dias** e pode pedir documentos.

Sem tratado de imposto de renda, a Valve
[retém 30% da sua parte nas vendas feitas nos EUA](https://partner.steamgames.com/doc/finance/taxfaq),
e o Brasil não tem esse tratado. Confirme com um contador, inclusive se dá para
compensar aqui.

## Etapa 2: página "Em breve"

No painel: **Create New App**, tipo Game, nome `Hound.exe`. Anote o App ID.
Depois, **Edit Store Page**.

### Basic Info

| Campo | Preencher |
|---|---|
| Name | `Hound.exe` (igual ao das artes) |
| Developer e Publisher | `saulofilho`, ou o nome público que preferir |
| Website | `https://saulofilho.github.io/hound-exe/` |
| Platforms | Windows e Linux + SteamOS. **Não marque macOS** |
| System requirements | `6-textos/requisitos-minimos.en.txt` |
| Languages | English e Portuguese - Brazil, **só Interface** |
| Supported features | **só** Single-player |
| Controller wizard | o que você testou com controle físico. Sem teste, declare sem suporte e mude depois |
| Tags (Tag Wizard) | `6-textos/tags-em-ordem.txt`, nessa ordem. Publica separado da página |
| Support info | o contato da etapa 0 |
| 3rd party accounts, DRM, anti-cheat, EULA | nenhum |

Não marque conquistas, Cloud, cartas, Workshop, Steam Input API nem placares.

### Description

| Campo | Arquivo |
|---|---|
| Short description, English | `6-textos/descricao-curta.en.txt` |
| Short description, Portuguese - Brazil | `6-textos/descricao-curta.pt-BR.txt` |
| About this game, English | `6-textos/sobre-o-jogo.en.bbcode.txt` |
| About this game, Portuguese - Brazil | `6-textos/sobre-o-jogo.pt-BR.bbcode.txt` |

Se o editor visual mostrar os `[h2]` como texto, cole o `.sem-formato.txt` e
formate título e lista nos botões dele. O inglês é obrigatório.

### Graphical Assets

| Campo | Arquivo |
|---|---|
| Header Capsule | `1-capsulas-da-loja/header-capsule.png` |
| Small Capsule | `1-capsulas-da-loja/small-capsule.png` |
| Main Capsule | `1-capsulas-da-loja/main-capsule.png` |
| Vertical Capsule | `1-capsulas-da-loja/vertical-capsule.png` |
| Page Background | `1-capsulas-da-loja/page-background.png` |
| Screenshots | as 8 de `2-capturas/`, na ordem. **Marque todas** como gameplay e "suitable for all ages" |
| Library Capsule | `4-biblioteca/library-capsule.png` |
| Library Header | `4-biblioteca/library-header.png` |
| Library Hero | `4-biblioteca/library-hero.png` |
| Library Logo | `4-biblioteca/library-logo.png`, posição "centered top" e confira na prévia |
| Shortcut Icon | `5-icones/shortcut-icon.png` |
| App Icon | `5-icones/app-icon.jpg` |

### Trailers

- [ ] Enviar `3-trailer/hound-exe-gameplay-en.mp4`.
- [ ] Nome "Gameplay Trailer", categoria Gameplay, todas as idades,
      "Visible on Store", primeiro da lista.
- [ ] Esperar a conversão (pode levar horas).

### Content Survey

| Pergunta | Resposta |
|---|---|
| Violência | fantasiosa e leve: um cão atira em bugs e arquivos. Sem sangue |
| Sexo, nudez, drogas, álcool, apostas, linguagem imprópria | não |
| Interação on-line, compras, coleta de dados | não |
| Conteúdo adulto | nenhum |
| IA pré-gerada | **sim**: `6-textos/ia-pre-gerada.en.txt`. **Leia e corrija antes**: aparece na página e é você quem responde por ela |
| IA ao vivo | não |

### Release date (na página inicial do app)

- [ ] Uma data interna real, em dia útil e longe: a produção das regiões 2 a 5
      está estimada em 12 a 18 meses, então meados de 2028.
- [ ] Exibição: **Coming soon**, sem data.

### Enviar

- [ ] "Preview changes in store": ler a página inteira nos dois idiomas.
- [ ] O advogado de marcas liberou o nome: é a última chance de trocar.
- [ ] **Mark as ready for review**, pelo menos 7 dias úteis antes de querer no ar.
      A análise leva de 3 a 5.
- [ ] Aprovada, clicar **Post as Coming Soon**. Ela não publica sozinha.
- [ ] Trocar "Planned for Steam" no site pelo link da página.

## Etapa 3: demo

Antes, sem exceção:

- [ ] playtest com 3 a 5 pessoas ([roteiro](../docs/PLAYTEST.md))
- [ ] partida inteira com controle físico
- [ ] abrir num Windows e, se marcar Linux, num Linux ou Deck de verdade
- [ ] CI verde no commit do build

No painel do jogo-base:

- [ ] "All associated packages, DLC, demos and tools" > **Add Demo**. Anote o
      App ID **da demo**.
- [ ] Não ligue página separada para a demo: ela exigiria cápsulas com "DEMO".
      Vira um botão na página do jogo.
- [ ] Na demo, **SteamPipe > Depots**: um para Windows, outro para Linux
      (64-bit, All languages). Anote os dois IDs.
- [ ] Os dois depots nos pacotes da demo (Developer Comp e o da loja).
- [ ] **Installation > General**: pasta `HoundExe`. Duas opções de início:

| Sistema | Executável |
|---|---|
| Windows 64-bit | `HoundExe.exe` |
| Linux + SteamOS | `HoundExe.x86_64` |

- [ ] Common redistributables: nenhum.
- [ ] Baixar o [Steamworks SDK](https://partner.steamgames.com/downloads/list)
      (exige o seu login). O `steamcmd` de macOS está em
      `tools/ContentBuilder/builder_osx`.

Na pasta do jogo, trocando os IDs:

```bash
tools/build.sh
```

```bash
python3 tools/steam_build.py --app ID_DA_DEMO --windows ID_DEPOT_WIN --linux ID_DEPOT_LINUX
```

Isso gera uma prévia e imprime o comando do `steamcmd`. Se a prévia passar,
repita com `--upload` e rode o comando impresso. Senha e Steam Guard: só você
digita, nunca num arquivo ou num chat.

- [ ] **SteamPipe > Builds**: pôr no branch default e publicar as mudanças.
- [ ] Instalar pela Steam e **jogar 5 minutos pelo botão Play** (vale por 7 dias).
- [ ] Notas para o analista: `6-textos/notas-para-o-analista-da-demo.txt`.
- [ ] Mark as ready for review. Aprovada: **Release Demo**, depois republicar a
      página do jogo-base para o botão de download aparecer.

## Next Fest: uma chance só por jogo

| Edição | Inscrição até | Tudo para análise até | Festival |
|---|---|---|---|
| [Fevereiro 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027) | 10/01/2027 | 01/02 (18/01 para a prévia de imprensa) | 22/02 a 01/03 |
| [Junho 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027) | 25/04/2027 | 24/05 (10/05 para a prévia de imprensa) | 14/06 a 21/06 |

**Recomendação: pular fevereiro.** Com até 30 dias de verificação, mais 7 dias
úteis de análise e as festas de fim de ano, a página mal fica pública até
10/01, e a demo iria sem refinamento. Como só se participa uma vez e o jogo
completo está a mais de um ano, use a edição mais perto do lançamento.

## Etapa 4: jogo completo, lá na frente

Regiões 2 a 5, preço, build completo no App ID do jogo, pelo menos 2 semanas
de "Em breve" e 21 dias desde o pagamento da taxa. Detalhes em
[PUBLICAR.md](PUBLICAR.md).

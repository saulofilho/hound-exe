# Hound.exe na Steam: guia de publicação

Requisitos conferidos na documentação da Steamworks em **22/11/2026**. Ela muda:
confira os links no fim antes de cada envio.

## Onde estamos

| Objetivo | Situação |
|---|---|
| Página "Em breve" | **Material pronto.** Dependem de você: conta, taxa, nome, contato de suporte e respostas do questionário |
| Demo (Windows e Linux) | **Builds prontos, ainda não envie:** o bot leva 5 min 30 s pela região inteira, e a duração para quem joga pela primeira vez (meta: 15 a 20) ainda não foi medida com pessoas (roteiro em docs/PLAYTEST.md). Os builds nunca foram abertos nesses sistemas: o CI faz isso no primeiro push |
| Demo (macOS) | **Bloqueada:** falta notarizar (conta Apple Developer, paga à parte) |
| Jogo completo, pago | **Não está pronto.** Existe 1 das 5 regiões do GDD. A análise compara o build com a página e recusa jogo incompleto vendido como completo |

O caminho que fecha com o que existe hoje: página "Em breve", demo, Next Fest e
produção das regiões 2 a 5. O lançamento vem depois.

## 1. Só você pode fazer

- [ ] **Confirmar o nome.** O GDD ainda o chama de provisório. Procure
      "Hound.exe" na loja da Steam e nas bases de marcas (INPI, USPTO, EUIPO).
      Não fiz essa busca. Trocar depois refaz artes, textos e trailer.
- [ ] **Entrar no Steam Direct** e assinar os contratos. O nome legal precisa
      ser o mesmo do titular da conta bancária.
- [ ] **Pagar US$ 100 por jogo.** Não é reembolsável; volta após US$ 1.000 de
      receita bruta ajustada. Não aceita saldo da Carteira Steam.
- [ ] **Banco, impostos e identidade.** A verificação leva de 15 a 30 dias.
- [ ] **Responder ao questionário de conteúdo e de IA** (rascunho na seção 6).
- [ ] **Definir contato de suporte** (e-mail ou site). É obrigatório e público.
- [ ] **Definir preço** (só para o jogo completo).
- [ ] **macOS:** certificado "Developer ID Application" e perfil do notarytool.
      Sem isso, não marque macOS na loja.

## 2. Prazos que se somam

1. Verificação de identidade e impostos: 15 a 30 dias.
2. Entre pagar a taxa e poder lançar: pelo menos 21 dias.
3. Análise da página: 3 a 5 dias úteis. Envie 7 dias úteis antes.
4. Página "Em breve" no ar: pelo menos 2 semanas antes de lançar.
5. Análise do build: envie com a mesma folga. Só depois da página.
6. Next Fest (fevereiro, junho e outubro, uma participação por jogo): a demo
   vai para análise 3 semanas antes, ou 5 para o Press Preview. A inscrição
   fecha antes disso; veja a data da edição.

## 3. Builds

```bash
tools/build.sh
```

| Depot | Pasta | Opção de início |
|---|---|---|
| Windows x86_64 | `builds/windows/` | `HoundExe.exe` |
| Linux / SteamOS x86_64 | `builds/linux/` | `HoundExe.x86_64` |
| macOS universal | `builds/macos/` | `HoundExe.app` |

- Nenhum redistribuível precisa ser marcado (sem VC++, DirectX ou .NET).
- Diretório de instalação: `Hound.exe` pode confundir; use `HoundExe`.
- Os arquivos para testadores ficam em `builds/testers/`.

Para assinar e notarizar o macOS, com o perfil criado por você:

```bash
MAC_IDENTITY="Developer ID Application: SEU NOME (TEAMID)" NOTARY_PROFILE=houndexe tools/build.sh
```

Depois marque "64 Bit Binaries Included" e "App Bundles Are Notarized".

Para enviar, com os IDs que a Steamworks te der (a demo tem App ID próprio):

```bash
python3 tools/steam_build.py --app APPID --windows DEPOT --linux DEPOT
```

Sai um build de prévia, que não envia nada. Com `--upload` sai o de envio. O
comando do `steamcmd` é impresso. A senha e o Steam Guard são digitados por
você. O branch default só muda à mão, no painel.

## 4. Configuração na Steamworks

**Recursos: marque só o que é verdade neste build**

- [x] Um jogador
- [ ] Suporte total a controle: marque depois de testar com controle físico
- [ ] Steam Cloud: marque depois de sincronizar entre dois computadores
- Não marque: conquistas, cartas, Workshop, Steam Input API, placares.
  Nada disso está no jogo.

**Idiomas:** inglês e português do Brasil, só Interface. Sem dublagem e sem
legendas. A primeira abertura segue o idioma do sistema e há opção no jogo.
Para forçar numa opção de início: `-- --language=english` ou `-- --language=brazilian`.

**Steam Auto-Cloud:** cota de 1 MB, 10 arquivos.

| Campo | Valor |
|---|---|
| Raiz | `WinAppDataRoaming` |
| Subpasta | `HoundExe` |
| Padrão | `save.json` (exato: opções e volume ficam por máquina) |
| SO | Cross-Platform |
| Override macOS | `MacAppSupport` |
| Override Linux | `LinuxXdgDataHome` |

Desmarque "Cloud support for developers only" antes da análise. Limitação: duas
contas Steam no mesmo usuário do computador dividem o save, porque separar
exige o SDK da Steam.

**Requisitos mínimos** (derivados dos binários; confirmar em máquina real)

| | Windows | Linux | macOS |
|---|---|---|---|
| Sistema | Windows 10 64 bits | SteamOS 3 ou glibc 2.28+ | 11 (Intel), 13 (Apple) |
| Processador | x86_64, 2 núcleos | x86_64, 2 núcleos | Intel ou Apple |
| Memória | 2 GB | 2 GB | 4 GB |
| Vídeo | OpenGL 3.3 ou Direct3D 11 | OpenGL 3.3 | OpenGL 3.3 ou Metal |
| Espaço | 150 MB | 100 MB | 200 MB |

## 5. Material da loja

| Item | Onde |
|---|---|
| Cápsulas, Library, fundo e ícones | `steam/assets/` (`tools/make_store_art.py`) |
| 8 capturas 1920x1080, em inglês | `steam/screenshots/` (`godot --path . -s tools/capture.gd -- store`) |
| Trailer de gameplay, 38 s | `builds/trailer/` (`tools/make_trailer.sh`) |
| Vídeo de divulgação, 33 s, 16:9 e 9:16 | `builds/promo/` (`tools/make_promo.sh`). Para redes; na Steam, só como trailer secundário |
| Textos em inglês e português | [LOJA.md](LOJA.md) |

Marque as capturas e o trailer como gameplay e para todas as idades.

## 6. Questionário de conteúdo

- **Geral:** violência fantasiosa leve (um cão atira em arquivos e ícones de
  computador). Sem sangue, sexo, drogas, apostas, linguagem imprópria, compras,
  interação on-line ou coleta de dados (tempo e mortes ficam só no save
  local, que o Cloud sincroniza se estiver ligado).
- **Conteúdo adulto:** nenhum.
- **IA pré-gerada: sim.** A Steam exige declarar conteúdo feito com IA que
  chega ao jogador (arte, som, texto, tradução) e mostra a resposta na página.
  Omitir pode derrubar o jogo. Rascunho, para você revisar e corrigir o que
  descreve a sua parte:

  > Generative AI (Claude, by Anthropic) was used during development, directed
  > by the developer, to write game code and the scripts that draw the pixel
  > art and font and synthesize the music and sound effects, to write and
  > translate in-game and store text, and to produce the store artwork and
  > trailer script. No content is generated while the game runs.

- **IA ao vivo: não.** O jogo não acessa a rede.

Pelo contrato de distribuição, é você quem garante ter os direitos sobre tudo
isso. A proteção autoral de material feito por IA varia por país; se for
importante para você, confirme com um advogado.

## 7. Steam Deck Verified

| Critério | Situação |
|---|---|
| Tudo acessível no controle, sem configurar | feito e testado com eventos simulados (e remapeável) |
| Só botões de controle na tela quando em uso | feito e testado |
| Texto com pelo menos 9 px em 1280x800 | 15 px |
| Sem launcher e sem digitação | feito |
| Funciona sem internet | feito |
| Build Linux nativo | exportado, **não testado num Deck** |
| 30 fps em 800p | provável, **não medido num Deck** |

O pedido de análise de compatibilidade só abre depois da análise do build.

## 8. Antes de cada envio

- [ ] Subir a versão em `project.godot` e `export_presets.cfg`.
- [ ] Conferir o roteiro do analista em LOJA.md jogando por ele.
- [ ] Rodar `python3 tools/run_tests.py` e `tools/build.sh`.
- [ ] Conferir o CI verde no commit que vai ser enviado.
- [ ] Fazer o playtest de [docs/PLAYTEST.md](../docs/PLAYTEST.md).
- [ ] Abrir num Windows limpo, sem Godot e sem Visual C++.
- [ ] Abrir num Linux ou Steam Deck.
- [ ] Jogar do começo ao fim com controle físico e sair pelo menu.
- [ ] Instalar pela Steam e jogar 5 minutos pelo botão Jogar (item obrigatório
      do checklist, válido por 7 dias).
- [ ] Testar o Cloud em dois computadores, se marcado.
- [ ] Conferir que página, capturas e trailer só mostram o que está no build.

## Fontes

- [Steam Direct](https://partner.steamgames.com/steamdirect?l=brazilian)
- [Processo de análise](https://partner.steamgames.com/doc/store/review_process)
- [Lançamento](https://partner.steamgames.com/doc/store/releasing)
- [Questionário de conteúdo e IA](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)
- [Plataformas e notarização](https://partner.steamgames.com/doc/store/application/platforms)
- [Artes da loja](https://partner.steamgames.com/doc/store/assets/standard) e [da biblioteca](https://partner.steamgames.com/doc/store/assets/libraryassets)
- [Steam Deck](https://partner.steamgames.com/doc/steamdeck/compat)
- [SteamPipe](https://partner.steamgames.com/doc/sdk/uploading)
- [Steam Cloud](https://partner.steamgames.com/doc/features/cloud)
- [Demos](https://partner.steamgames.com/doc/store/application/demos) e [Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)

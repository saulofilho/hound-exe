# Hound.exe · documento de design (GDD)

> Nome: Hound.exe (definido em 22/11/2026, ver [steam/NOME.md](../steam/NOME.md)). Versão 0.2 · 20/11/2026 · fase de planejamento, nada de código ainda.
> Moodboard: [moodboard.html](moodboard.html)

## 1. Em uma frase

Um metroidvania de ação em pixel art 1-bit: o cão do scopehound invade um
computador infectado, caça bugs a tiro e vasculha a máquina inteira, de pasta
em pasta, até chegar ao kernel.

## 2. Decisões tomadas

| Decisão | Escolha | Referência de sensação |
|---|---|---|
| Perspectiva | **Lateral**, com **salas em visão de cima** em momentos especiais | Gato Roboto e Not a Hero (lateral); Minit e Serious Sam: Bogus Detour (de cima) |
| Combate | **Ação no centro**: tiro, dash e inimigos o tempo todo | Not a Hero, Bogus Detour |
| Estrutura | **Mapa interligado** (metroidvania): habilidades novas reabrem áreas antigas | Gato Roboto |
| Arte | 1-bit, com uma cor de destaque por mundo | Minit, Gato Roboto |
| Engine | Godot 4, exportando para Windows, macOS e Linux | — |
| Plataforma | Steam, com meta de Steam Deck verificado | — |

**Decidido depois:** o nome é próprio, Hound.exe, com o cão do scopehound.

**Ainda em aberto:** tempo disponível e quem faz arte e música; quanto de história o jogo terá.

As referências são de ritmo e sensação. Personagem, mapa, armas e visual são
nossos; nada é copiado desses jogos.

## 3. Pilares

1. **Atirar rápido, farejar esperto.** O combate é ágil e arcade. O faro é a
   vantagem do cão: revela passagens, pontos fracos e o caminho até o ninho.
2. **A máquina inteira é um mapa.** Cada pasta, setor de memória ou porta de
   rede leva a outro lugar. Voltar com uma habilidade nova sempre paga.
3. **A coleira manda.** O equipamento do cão é a própria coleira, que impõe o
   escopo: sair dele custa caro e alguns segredos estão justamente além dela.
4. **Uma máquina com alma.** Ronco de HD, ventoinha, ícones esquecidos e humor
   de informática.

## 4. Personagem e equipamento

**Hound**, o cão do scopehound, em 1-bit. Não fala; reage com orelhas, rabo e
latidos.

**A Coleira** é o equipamento do jogo. É um colar-dispositivo que projeta as
ferramentas do cão e serve de HUD. Ela substitui a armadura ou o veículo comuns
no gênero e amarra o tema: quem define até onde o cão vai é a coleira.

- **Arma inicial:** o *Debugger*, um disparo curto e rápido.
- **Animações:** parado, correndo, pulando, atirando (em 3 direções), dash,
  farejando, latindo, tomando dano e "tela azul" (morte).
- **Tamanho:** 16×16 px numa tela base de 384×216.

## 5. Como se joga

### Na vista lateral (o jogo na maior parte do tempo)

- Correr, pular, atirar, dar dash e se esconder atrás de cobertura (janelas e
  ícones servem de escudo por alguns tiros, no ritmo de Not a Hero).
- **Farejar** (segurar o botão): o tempo desacelera um pouco e aparecem
  rastros, paredes falsas e o ponto fraco dos inimigos.
- **Latir**: atordoa inimigos próximos e revela o mapa em volta, mas atrai
  outros inimigos.

### Nas salas de cima (momentos especiais)

Ao entrar fundo em um arquivo ou processo, a câmera vira para a visão de cima.
São salas curtas e intensas, de 30 a 90 segundos:

- **Arena de varredura:** tiro em dois analógicos contra ondas de bugs, no
  estilo Bogus Detour.
- **Processo com timeout:** um puzzle rápido com cronômetro, no estilo Minit.
  Se o tempo acabar, o processo reinicia.
- **Alguns chefes**, para variar o ritmo.

As salas de cima reaproveitam os mesmos sprites e controles (mirar com o
analógico direito), para não dobrar o trabalho.

### Morte e progresso

- **Tela azul:** ao morrer, o cão volta ao último **ponto de restauração**
  (os pontos de salvamento).
- **Explorer:** o mapa do jogo, que se preenche conforme você explora.
- **Escopo:** cada região tem um escopo. Fora dele, a coleira dá choque
  (dano contínuo) até o cão voltar, a não ser que ele tenha a habilidade Sudo.

## 6. Habilidades (portas do metroidvania)

Cada habilidade abre caminhos novos no mapa e muda o combate.

| Habilidade | No combate | Na exploração | Onde se ganha |
|---|---|---|---|
| Faro | mostra pontos fracos | paredes falsas e rastros | início |
| Dash | atravessa tiros | cruza vãos e lasers | mundo 1 |
| Cavar | ataque para baixo | desce por pisos de arquivo | mundo 2 |
| Pulo duplo (pacote) | esquiva aérea | alcança plataformas altas | mundo 2 |
| Grep | marca todos os inimigos de um tipo | encontra itens escondidos | mundo 3 |
| Debugger+ | tiro carregado que congela | trava plataformas móveis | mundo 3 |
| Ping | sonar que fere | revela a região no Explorer | mundo 4 |
| Sudo | ataque especial | atravessa o firewall (fora do escopo) | mundo 4 |

**Melhorias menores:** *patches* espalhados pelo mapa aumentam vida, munição e
o tempo de faro.

## 7. Mundos (regiões do mapa)

| # | Região | Regra da região | Inimigos | Chefe |
|---|---|---|---|---|
| 1 | Área de trabalho | tutorial; janelas abrem e fecham como plataformas | atalhos quebrados, pop-ups | o Arquivo Fantasma |
| 2 | Memória | o chão vaza: blocos somem e reaparecem | *memory leaks* que crescem, ponteiros nulos (buracos) | o Vazamento |
| 3 | Processador | tudo pulsa no ritmo do clock | *race conditions* (pares que só morrem juntos), loops | o Deadlock |
| 4 | Rede | pacotes viram plataformas em trânsito; o firewall é a borda | intrusos de fora do escopo, pacotes perdidos | o Man-in-the-Middle |
| 5 | Kernel | silencioso; inimigos se disfarçam de cenário | processos disfarçados | o Rootkit |

Cada região tem 2 ou 3 salas de cima. A meta é de 4 a 6 horas de jogo na
primeira vez, e mais com 100% do mapa.

### 7.1 Região 1, como construída (0.2.0)

A porta da Lixeira pede 3 pistas enterradas, uma no fim de cada ala:

1. **Imagens e Galeria:** arquivos ocultos, que o faro materializa por 7 s.
2. **Temp e Setup:** plataformas temporárias sobre setor ruim; dá o dash.
3. **System32 e Drivers:** vãos e lasers; pede dash e faro juntos.

Cada ala fecha numa quarentena (3 ondas), que abre um atalho quando vencida.
Um segredo por sala de exploração aumenta o faro, não a vida: mais vida
deixaria vencer o chefe parado. Inimigo novo: Spam, que avisa e mergulha.

## 8. Estilo visual e som

- **Arte:** 1-bit (preto e branco), com **uma cor de destaque por região**.
  A cor marca tiros inimigos, pontos fracos, rastros e itens; o resto é preto
  e branco, para a leitura ficar instantânea mesmo na ação.
- **Efeitos:** tremor de tela, flash de impacto em 1 quadro e partículas em
  pixel; o peso do tiro vem daí.
- **Interface:** inspirada no Windows 95 do site do scopehound.
- **Som:** chiptune com batida mais forte nas arenas. Sons de máquina reais
  (HD, ventoinha, modem) e um timbre próprio para cada tipo de bug.

## 9. Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover / mirar | WASD ou setas | analógico esquerdo |
| Pular | Espaço | A |
| Atirar | J | X |
| Dash | K | B |
| Farejar (segurar) | Shift | gatilho esquerdo |
| Latir | L | Y |
| Mirar nas salas de cima | mouse | analógico direito |
| Explorer (mapa) | Tab | Select |

## 10. Cronograma

Estimativa para 1 pessoa em meio período (cerca de 15 h por semana). Um
metroidvania é maior que o conceito anterior, então o plano protege o mundo 1.

| Fase | Duração | Entrega | Critério de pronto |
|---|---|---|---|
| 0. Pré-produção | 3 a 4 semanas | este GDD, o moodboard e um protótipo cinza | correr, pular e atirar são gostosos sem arte nenhuma |
| 1. Vertical slice | 3 a 4 meses | região 1 completa, com 1 sala de cima, 1 chefe, arte e som finais | 3 pessoas de fora terminam a região sem ajuda e querem mais |
| 2. Página na Steam | junto com a fase 1 | página "Em breve", trailer de 30 s e demo | página no ar e demo pronta para o Next Fest |
| 3. Produção | 12 a 18 meses | regiões 2 a 5 e os chefes | jogo completo de ponta a ponta |
| 4. Lançamento | — | Early Access ou 1.0 | preço entre US$ 10 e 15 |

## 11. Plano do protótipo (fase 0)

Objetivo: responder duas perguntas antes de qualquer arte.

1. **Correr, pular e atirar com o cão é gostoso?**
2. **O faro acrescenta algo ao combate, ou atrapalha?**

**O que entra:**
- Um corredor lateral de 3 telas, com blocos cinzas.
- Movimento completo: correr, pular (com *coyote time* e *jump buffer*), dash e
  tiro em 3 direções.
- Dois inimigos: um que anda e outro que atira.
- Faro: desacelera o tempo, mostra uma parede falsa e o ponto fraco.
- Uma porta que leva a uma sala de cima (arena de 45 segundos), para testar a
  troca de perspectiva.
- Tremor de tela e flash de impacto, porque o peso do tiro precisa ser
  testado desde o início.

**O que fica de fora:** arte, som, menus, salvamento, mapa e história.

**Como avaliar:** 5 pessoas jogam no controle, sem explicação. Observar se a
troca para a visão de cima confunde, se usam o faro sem ser mandadas e se
morrem por culpa do jogo ou delas.

**Tarefas:**
1. Instalar o Godot 4 e criar o repositório `hound-exe`.
2. Controle do personagem lateral e câmera.
3. Tiro, dano e os dois inimigos.
4. Faro: câmera lenta, parede falsa e ponto fraco.
5. Transição para a sala de cima e o controle de dois analógicos.
6. Efeitos de impacto.
7. Sessão de teste e anotações.

## 12. Steam e negócio

- **Steam Direct:** US$ 100 por jogo, devolvidos depois de US$ 1.000 em vendas.
- **Página cedo:** wishlists são o principal motor do lançamento; a página vai
  ao ar assim que o vertical slice tiver boas imagens.
- **Público:** fãs de metroidvania e de ação em pixel art, de jogos 1-bit, e
  devs e gente de segurança (o tema "caçar bugs" fala direto com eles).
- **Divulgação:** GIFs de combate e do faro, devlogs, festivais da Steam e a
  ponte com o scopehound (site, README e CLI).
- **Publisher:** quando a demo estiver boa, vale apresentar o jogo a
  publishers de indie (o perfil das referências escolhidas).

## 13. Riscos

| Risco | Impacto | Como reduzir |
|---|---|---|
| Metroidvania é grande para 1 pessoa | alto | região 1 como produto mínimo; cortar regiões antes de cortar qualidade |
| Duas perspectivas dobram o trabalho | alto | salas de cima curtas, poucas e com os mesmos sprites e controles |
| Combate sem peso | alto | protótipo foca em sensação (impacto, tremor, som) antes de conteúdo |
| O faro virar só um botão a mais | médio | inimigos e segredos que só se resolvem com faro |
| Arte 1-bit parecer pobre na vitrine | médio | cor de destaque por região e animação caprichada |
| Comparação direta com as referências | médio | identidade própria: o cão, a coleira e o computador como mundo |

## 13.1 Regras que os testes protegem

- **O faro é necessário:** sobe Imagens e Temp, desenterra as pistas, abre a
  parede falsa e é o único jeito de acertar o chefe na segunda fase.
- **Não há atalho:** nenhuma ala se completa sem a habilidade dela e o atalho
  de volta só abre com a quarentena vencida (`tools/check_rooms.py`,
  `tests/region.gd`).
- **A porta é ponto de volta:** morrer na sala de cima ou no chefe devolve à
  Lixeira, nunca a uma ala atrás (`tests/region.gd`).
- **Ninguém fica preso:** de todo chão firme alcançável se sai da sala.
- **Parado não se vence:** nem na sala de cima, nem no chefe.

`tests/exploits.gd` falha se uma delas cair. Toda região nova precisa das duas.

## 14. Perguntas em aberto

1. O tempo disponível e quem faz arte e música.
2. ~~Se o nome é próprio ou ligado ao scopehound.~~ Próprio: Hound.exe (22/11/2026).
3. A história: por que o computador está infectado, e de quem ele é?
4. Se haverá modo cooperativo (um segundo cão), que é um risco de escopo.

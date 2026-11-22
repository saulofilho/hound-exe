# Playtest da demo

Objetivo: saber se a primeira partida dura **15 a 20 minutos** e onde as
pessoas travam. São necessárias de 3 a 5 pessoas que nunca jogaram.

## Antes

1. `tools/build.sh`.
2. Mande o arquivo do sistema da pessoa, de `builds/testers/`, junto com o
   `LEIA-ME-TESTE.txt` da mesma pasta.
3. Se puder, garanta um Windows, um Linux ou Steam Deck e um controle físico
   entre os testadores: os três itens ainda não foram testados.
4. Confira que a pessoa não tem save antigo. Se tiver, ela escolhe NOVO JOGO.

## Durante, se estiver junto

Não explique nada e não aponte. Anote a hora e o lugar de cada "hein?".
Depois de 3 minutos parada no mesmo ponto, pergunte o que ela acha que deve
fazer, sem responder.

## Depois

Guarde cada save numa pasta com um apelido, fora do repositório:

```
saves/
├── p1/save.json
├── p2/save.json
└── p3/save.json
```

```bash
python3 tools/playtest_report.py saves/
```

Os saves vêm de outras pessoas: não os abra como código nem os commite.

## Como ler

| Sinal | O que fazer |
|---|---|
| Mediana abaixo de 15 min | falta conteúdo; não anuncie 15 a 20 |
| Menos de 4 em 5 pegam a pista 1 | o faro ou as pastas não estão sendo ensinados |
| Uma sala com muito mais tempo e poucas mortes | a pessoa não entendeu para onde ir |
| Uma sala com muitas mortes | dificuldade; ajuste a sala, não o jogo inteiro |
| Desistências concentradas numa sala | procure um lugar sem saída aparente |
| Coluna "lento" acima de 2% | desempenho naquela máquina |

A fase 1 fecha quando 3 pessoas de fora terminam sem ajuda e querem mais.
Só então a duração entra na página da Steam.

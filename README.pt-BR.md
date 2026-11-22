# Hound.exe

[English](README.md) · **Português**

Metroidvania de ação em pixel art 1-bit com o cão do
[scopehound](https://github.com/saulofilho/scopehound). Nome provisório.

- Design: [docs/GDD.md](docs/GDD.md)
- Moodboard: [docs/moodboard.html](docs/moodboard.html)

## Protótipo da fase 0

A fase 0 começou com arte cinza, para testar se correr, pular e atirar com o cão é
gostoso (GDD, seção 11).

**O que já tem:** corredor lateral de 3 telas, pulo com *coyote time*, *jump
buffer* e altura variável, dash (também no ar, uma vez), tiro em 3 direções com
coice, dois bugs (um que anda e uma torreta que avisa antes de atirar), tremor
de tela, *hitstop*, estilhaços e a "tela azul" ao morrer.

**Também já tem:** faro (Shift: câmera lenta, parede falsa, rastro e ponto
fraco com tiro dobrado) e a porta para a sala de cima (45 segundos de ondas de
bugs, mira com mouse ou analógico direito). Detalhes atualizados no
[README em inglês](README.md).

**Fase 1 em andamento:** a região Área de trabalho já tem salas ligadas, chip
de dash e o chefe, o Arquivo Fantasma. A arte é 1-bit com teal como cor da região, HUD estilo Windows 95 e fonte
pixel própria com acentos, tudo gerado por `tools/make_art.py`.

![Primeira sala de C:](docs/img/gameplay-start.png)

O jogo abre na tela de título, salva sozinho e pausa com Esc (ou Start).
Ao continuar, o cão volta ao último ponto de restauração.
A música e os efeitos são originais (`tools/make_audio.py`); volume, idioma
(português ou inglês), tela cheia e tremor ficam em OPÇÕES, no título e na pausa.

**Fase 2 (Steam):** `tools/build.sh` exporta Windows, Linux e macOS. O que está
pronto e o que falta para publicar está em [steam/PUBLICAR.md](steam/PUBLICAR.md).

Depois de clonar, importe uma vez antes de rodar:
`godot --headless --path . --import`.

### Como rodar

1. Instale o Godot 4.7.2: `brew install --cask godot`
2. Abra o Godot, clique em **Importar** e escolha o `project.godot` desta pasta.
3. Aperte **F5**.

| Ação | Teclado | Controle |
|---|---|---|
| Mover | A/D ou setas | analógico esquerdo |
| Mirar para cima | W (com A/D: diagonal) | analógico para cima |
| Pular | Espaço ou Z | A |
| Atirar (segurar) | J ou X | X |
| Dash | K ou C | B |
| Pausar | Esc | Start |
| Voltar ao ponto de restauração | R | menu de pausa |

### Estrutura

```
project.godot     configuração (tela base 384×216, escala inteira, pixel nítido)
main.tscn         cena principal
scripts/
├── main.gd       monta o corredor a partir de um mapa ASCII, câmera, HUD e efeitos
├── player.gd     o cão: movimento, dash, tiro, dano
├── bullet.gd     tiros do cão e dos bugs
├── enemy.gd      base dos bugs: vida, piscar, knockback, estilhaços
├── walker.gd     bug que patrulha
└── turret.gd     bug que atira
```

Para mudar o corredor, edite o `MAP` em `scripts/main.gd`:
`#` parede · `P` cão · `w` bug que anda · `t` torreta · `E` fim.

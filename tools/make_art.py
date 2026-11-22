#!/usr/bin/env python3
"""Gera a arte do Hound.exe em art/: sprites 1-bit e a fonte pixel.

Tudo é original e está desenhado neste arquivo, em texto. Só usa a biblioteca
padrão e a saída é determinística.

    python3 tools/make_art.py
    python3 tools/make_art.py --preview folha.png    # tudo junto, 4x

Cores: branco, preto e a cor de destaque da região. `#` branco, `o` preto,
`*` destaque, `.` transparente.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "art"

WHITE = (243, 243, 238, 255)
BLACK = (0, 0, 0, 255)
ACCENT = (47, 181, 168, 255)
CLEAR = (0, 0, 0, 0)
INK = {"#": WHITE, "o": BLACK, "*": ACCENT}


class Image:
    def __init__(self, w: int, h: int, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [fill] * (w * h)

    def set(self, x: int, y: int, c) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def get(self, x: int, y: int):
        return self.px[y * self.w + x] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def rect(self, x: int, y: int, w: int, h: int, c=WHITE) -> None:
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, c)

    def box(self, x: int, y: int, w: int, h: int, c=WHITE) -> None:
        self.rect(x, y, w, 1, c)
        self.rect(x, y + h - 1, w, 1, c)
        self.rect(x, y, 1, h, c)
        self.rect(x + w - 1, y, 1, h, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c=WHITE) -> None:
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.set(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def art(self, x: int, y: int, rows: list[str]) -> None:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in INK:
                    self.set(x + i, y + j, INK[ch])

    def paste(self, other: "Image", x: int, y: int, scale: int = 1) -> None:
        for j in range(other.h):
            for i in range(other.w):
                c = other.get(i, j)
                if c[3]:
                    self.rect(x + i * scale, y + j * scale, scale, scale, c)

    def png(self) -> bytes:
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for c in self.px[y * self.w:(y + 1) * self.w]:
                raw += bytes(c)

        def chunk(tag: bytes, data: bytes) -> bytes:
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

        head = struct.pack(">2I5B", self.w, self.h, 8, 6, 0, 0, 0)
        return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def sheet(frames: list[Image]) -> Image:
    out = Image(frames[0].w * len(frames), frames[0].h)
    for i, frame in enumerate(frames):
        out.paste(frame, i * frame.w, 0)
    return out


# ---------------------------------------------------------------- o cão

HEAD = [
    "...####....",
    "..######...",
    ".##o####...",
    "###o##o##..",
    "###o#######",
    "###o######o",
    ".##o#####..",
    "..o........",
]
HEAD_SHUT = HEAD[:3] + ["###o#ooo#.."] + HEAD[4:]
HEAD_BACK = [  # orelha ao vento
    ".....####..",
    "..#######..",
    "####o####..",
    "##oo##o##..",
    ".....######",
    ".....#####o",
    ".....####..",
]
HEAD_UP = [
    "......#o...",
    ".....###...",
    "....####...",
    "..####o#...",
    ".##o####...",
    "###o###....",
    "##o####....",
    ".#o###.....",
]


def hound(head=HEAD, at=(12, 1), legs=((5, 0), (7, 0), (12, 0), (14, 0)), tail="up", lift=0, stretch=0) -> Image:
    """24x16; os pés ficam na última linha."""
    im = Image(24, 16)
    top = 7 - lift
    tails = {
        "up": [(1, top - 4), (1, top - 3), (2, top - 2), (2, top - 1), (3, top)],
        "wag": [(3, top - 4), (2, top - 3), (2, top - 2), (2, top - 1), (3, top)],
        "flat": [(-1, top + 1), (0, top + 1), (1, top), (2, top), (3, top)],
        "down": [(1, top + 4), (1, top + 3), (2, top + 2), (2, top + 1), (3, top + 1)],
    }
    for x, y in tails[tail]:
        im.set(x, y, WHITE)
    im.rect(4 - stretch, top, 12 + stretch, 4)
    im.rect(3 - stretch, top + 1, 1, 3)
    im.rect(10, top + 4, 6, 1)  # peito
    im.rect(4 - stretch, top + 4, 4, 1)
    for x, dx in legs:
        foot_y = 15 - lift
        im.line(x, top + 4, x + dx, foot_y)
        im.set(x + dx + 1, foot_y, WHITE)
    im.art(at[0], at[1] - lift, head)
    # a Coleira
    im.rect(14, top, 2, 3, ACCENT)
    return im


def hound_frames() -> list[Image]:
    still = ((5, 0), (7, 0), (12, 0), (14, 0))
    return [
        hound(),                                                          # 0 parado
        hound(HEAD_SHUT, tail="wag"),                                     # 1 parado, pisca
        hound(legs=((5, -2), (7, 2), (12, -2), (14, 2)), tail="wag"),     # 2 corrida
        hound(legs=((5, 0), (7, 1), (12, 1), (14, 0)), lift=1),           # 3
        hound(legs=((5, 2), (7, -2), (12, 2), (14, -2)), tail="wag"),     # 4
        hound(legs=((5, 1), (7, 0), (12, 0), (14, 1)), lift=1),           # 5
        hound(legs=((5, -3), (7, -2), (12, 3), (14, 3)), tail="down"),    # 6 subindo
        hound(HEAD_BACK, legs=((5, 2), (7, 2), (12, -1), (14, 0))),       # 7 caindo
        hound(HEAD_BACK, at=(13, 4), legs=((5, -4), (7, -4), (12, 4), (14, 4)), tail="flat", stretch=1),  # 8 dash
        hound(at=(13, 7), legs=still, tail="up"),                         # 9 farejando
        hound(at=(13, 8), legs=still, tail="wag"),                        # 10
        hound(HEAD_BACK, at=(11, 1), legs=((5, -1), (7, 0), (12, 1), (14, 2))),  # 11 atirando
        hound(HEAD_UP, at=(12, 0)),                                       # 12 atirando para cima
        hound(HEAD_SHUT, at=(11, 3), legs=((5, 2), (7, 2), (12, -2), (14, -2)), tail="down"),  # 13 dano
    ]


def top_hound(step: int) -> Image:
    """24x24, olhando para a direita."""
    im = Image(24, 24)
    s = [1, 0, -1, 0][step]
    for x, y, d in ((5, 7, s), (11, 7, -s), (5, 15, -s), (11, 15, s)):
        im.rect(x + d, y, 3, 2)
    im.art(3, 8, [
        "..................",
        "..###....####.....",
        ".############.....",
        "##############....",
        "##############....",
        ".############.....",
        "..###....####.....",
        "..................",
    ])
    im.line(1, 12 - s, 4, 11)
    im.rect(13, 9, 2, 6, ACCENT)
    im.art(14, 6, [
        ".###.....",
        ".####....",
        "..oo##...",
        "#####o#..",
        "########o",
        "########o",
        "#####o#..",
        "..oo##...",
        ".####....",
        ".###.....",
    ])
    return im


# ---------------------------------------------------------------- bugs

def walker(step: int) -> Image:
    """Atalho quebrado: um ícone com a seta, rachado, com patas."""
    im = Image(16, 16)
    up = 1 if step % 2 else 0
    im.art(2, 1 - up + 1, [
        "##########..",
        "###########.",
        "############",
        "##*######*##",
        "############",
        "#oooooooo###",
        "#oooo###o###",
        "#ooooo##o###",
        "#oooo#o#o###",
        "#ooo#oooo###",
        "#oooooooo###",
    ])
    s = [-1, 0, 1, 0][step]
    for x, d in ((3, s), (6, -s), (9, s), (12, -s)):
        im.line(x, 13 - up, x + d, 15)
    return im


def turret(warn: bool) -> Image:
    """Pop-up: uma janela com um olho e um pé."""
    im = Image(16, 16)
    im.box(0, 0, 16, 13)
    im.rect(1, 1, 14, 11, BLACK)
    im.rect(1, 1, 14, 2)
    im.set(13, 1, BLACK)
    im.set(11, 1, BLACK)
    iris = "*" if warn else "o"
    im.art(3, 5, [
        "..######..",
        f".##{iris * 4}##.",
        f"###{iris}##{iris}###",
        f".##{iris * 4}##.",
        "..######..",
    ])
    if warn:
        im.rect(1, 1, 14, 2, ACCENT)
    im.rect(6, 13, 4, 2)
    im.rect(3, 15, 10, 1)
    return im


def chaser(step: int) -> Image:
    """Arquivo corrompido, visto de cima."""
    im = Image(16, 16)
    im.art(3, 1, [
        ".#......#.",
        "..#....#..",
        "..######..",
        ".##*##*##.",
        ".########.",
        "####oo####",
        "##o#oo#o##",
        "####oo####",
        "##o#oo#o##",
        ".###oo###.",
        ".###oo##..",
        "..##oo#...",
    ])
    d = 1 if step else -1
    for y in (6, 9, 12):
        im.line(0, y + d, 3, y)
        im.line(12, y, 15, y - d)
    return im


def ghost(kind: str) -> Image:
    """Arquivo Fantasma, 32x36: solid, hidden, charge, stun, hit."""
    im = Image(32, 36)
    solid = kind in ("solid", "stun", "hit")
    body = ACCENT if kind in ("hit", "charge") else WHITE
    hem = [35, 34, 33, 31, 30, 31, 33, 34]
    inside = set()
    for x in range(3, 29):
        top = 2 + max(0, x - 21)
        for y in range(top, hem[(x - 3) % 8]):
            inside.add((x, y))
    for x, y in inside:
        edge = any(p not in inside for p in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
        if edge or solid:
            im.set(x, y, body)
        elif kind == "charge":
            im.set(x, y, body if (x + y) % 2 == 0 else BLACK)
        elif (x + 2 * y) % 8 == 0:
            im.set(x, y, body)  # quase transparente
    ink = BLACK if solid or kind == "charge" else body
    im.line(21, 3, 21, 9, ink)  # canto dobrado
    im.line(21, 9, 27, 9, ink)
    if kind == "stun":
        for x in (8, 18):
            im.line(x, 12, x + 5, 17, ink)
            im.line(x + 5, 12, x, 17, ink)
        im.box(13, 22, 6, 4, ink)
    else:
        for x in (8, 18):
            im.rect(x, 12, 5, 7, ink)
            im.rect(x + 2, 15, 2, 3, ACCENT if kind != "hit" else WHITE)
        if kind == "charge":
            im.line(7, 9, 13, 12, ink)
            im.line(24, 9, 18, 12, ink)
        im.rect(9, 23, 14, 1, ink)
        im.rect(9, 26, 10, 1, ink)
    return im


# ---------------------------------------------------------------- objetos

def item(kind: str) -> Image:
    im = Image(16, 16)
    if kind in ("restore_off", "restore_on"):
        im.rect(1, 1, 14, 11)
        im.rect(3, 3, 10, 7, BLACK)
        if kind == "restore_on":
            im.rect(3, 3, 10, 7, ACCENT)
            im.art(5, 4, ["......o", ".....oo", "o...oo.", "oo.oo..", ".ooo..."])
        else:
            im.rect(5, 7, 3, 1)
        im.rect(6, 12, 4, 2)
        im.rect(2, 14, 12, 2)
        im.set(12, 14, BLACK)
    elif kind == "chip":
        for i in (4, 7, 10):
            im.rect(i, 1, 1, 14)
            im.rect(1, i, 14, 1)
        im.rect(3, 3, 10, 10, ACCENT)
        im.art(5, 5, ["o..o..", ".o..o.", "..o..o", "..o..o", ".o..o.", "o..o.."])
    elif kind == "patch":
        im.rect(2, 4, 12, 10)
        im.rect(5, 2, 6, 1)
        im.rect(5, 3, 1, 1)
        im.rect(10, 3, 1, 1)
        im.rect(7, 6, 2, 6, ACCENT)
        im.rect(5, 8, 6, 2, ACCENT)
    elif kind in ("door", "door_clear", "door_locked"):
        im.box(1, 0, 14, 16)
        im.rect(2, 1, 12, 14, BLACK)
        im.rect(2, 1, 12, 2)
        c = ACCENT if kind != "door_locked" else WHITE
        if kind == "door":
            im.art(5, 5, ["*.....", "***...", "*****.", "******", "*****.", "***...", "*....."])
        elif kind == "door_clear":
            im.art(4, 6, [".......*", "......**", "*....**.", "**..**..", ".****...", "..**...."])
        else:
            im.box(5, 8, 6, 5, c)
            im.box(6, 5, 4, 4, c)
    return im


def laser(step: int) -> Image:
    im = Image(16, 16)
    im.rect(7, 0, 2, 16, ACCENT)
    for y in range(16):
        if (y + step * 2) % 6 < 3:
            im.set(5, y, ACCENT)
            im.set(8, y, WHITE)
        else:
            im.set(10, y, ACCENT)
            im.set(7, y, WHITE)
    return im


def icon(kind: str) -> Image:
    """Ícones 24x24 do papel de parede; o jogo os escurece."""
    im = Image(24, 24)
    if kind == "folder":
        im.box(2, 7, 20, 14)
        im.box(2, 4, 9, 4)
        im.rect(4, 10, 16, 1)
    elif kind == "page":
        im.box(5, 2, 14, 20)
        im.box(14, 2, 5, 5)
        for y in (9, 12, 15, 18):
            im.rect(8, y, 8 if y < 18 else 5, 1)
    elif kind == "drive":
        im.box(2, 8, 20, 10)
        im.rect(5, 12, 9, 1)
        im.rect(17, 12, 2, 2)
        im.line(2, 8, 5, 4)
        im.line(21, 8, 18, 4)
        im.rect(5, 4, 14, 1)
    elif kind == "download":
        im.rect(10, 2, 4, 10)
        for i in range(6):
            im.rect(6 + i, 11 + i, 12 - 2 * i, 1)
        im.box(3, 18, 18, 4)
        im.rect(5, 20, 9, 1)
    elif kind == "bin":
        im.box(4, 5, 16, 2)
        im.box(9, 2, 6, 4)
        im.line(5, 7, 7, 21)
        im.line(18, 7, 16, 21)
        im.rect(7, 21, 10, 1)
        for x in (9, 12, 15):
            im.rect(x, 10, 1, 9)
    elif kind == "computer":
        im.box(3, 2, 18, 14)
        im.box(6, 5, 12, 8)
        im.rect(10, 16, 4, 2)
        im.box(2, 18, 20, 4)
    return im


def logo() -> Image:
    """A cabeça do cão, para o botão da barra de tarefas."""
    im = Image(12, 10)
    im.art(0, 1, [row.replace("#", "o") if i == 7 else row for i, row in enumerate(HEAD[:7])])
    return im


SHEETS = {
    "hound": lambda: hound_frames(),
    "top_hound": lambda: [top_hound(i) for i in range(4)],
    "walker": lambda: [walker(i) for i in range(4)],
    "turret": lambda: [turret(False), turret(True)],
    "chaser": lambda: [chaser(0), chaser(1)],
    "ghost": lambda: [ghost(k) for k in ("solid", "hidden", "charge", "stun", "hit")],
    "items": lambda: [item(k) for k in ("restore_off", "restore_on", "chip", "patch", "door", "door_clear", "door_locked")],
    "laser": lambda: [laser(i) for i in range(3)],
    "icons": lambda: [icon(k) for k in ("folder", "page", "drive", "download", "bin", "computer")],
    "logo": lambda: [logo()],
}


# ---------------------------------------------------------------- fonte
# Maiúsculas têm 7 linhas; minúsculas começam na linha 2; as linhas 7 e 8 descem
# da linha de base. Largura = a da linha mais larga.

GLYPHS = """
A .###./#...#/#...#/#####/#...#/#...#/#...#
B ####./#...#/#...#/####./#...#/#...#/####.
C .###./#...#/#..../#..../#..../#...#/.###.
D ####./#...#/#...#/#...#/#...#/#...#/####.
E ####/#.../#.../###./#.../#.../####
F ####/#.../#.../###./#.../#.../#...
G .###./#...#/#..../#.###/#...#/#...#/.###.
H #...#/#...#/#...#/#####/#...#/#...#/#...#
I ###/.#./.#./.#./.#./.#./###
J ..##/...#/...#/...#/...#/#..#/.##.
K #...#/#..#./#.#../##.../#.#../#..#./#...#
L #.../#.../#.../#.../#.../#.../####
M #...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#
N #...#/##..#/##..#/#.#.#/#..##/#..##/#...#
O .###./#...#/#...#/#...#/#...#/#...#/.###.
P ####./#...#/#...#/####./#..../#..../#....
Q .###./#...#/#...#/#...#/#.#.#/#..#./.##.#
R ####./#...#/#...#/####./#.#../#..#./#...#
S .####/#..../#..../.###./....#/....#/####.
T #####/..#../..#../..#../..#../..#../..#..
U #...#/#...#/#...#/#...#/#...#/#...#/.###.
V #...#/#...#/#...#/#...#/#...#/.#.#./..#..
W #...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#
X #...#/#...#/.#.#./..#../.#.#./#...#/#...#
Y #...#/#...#/.#.#./..#../..#../..#../..#..
Z #####/....#/...#./..#../.#.../#..../#####
a //.##./...#/.###/#..#/.###
b #.../#.../###./#..#/#..#/#..#/###.
c //.##/#../#../#../.##
d ...#/...#/.###/#..#/#..#/#..#/.###
e //.##./#..#/####/#.../.###
f .##/#../###/#../#../#../#..
g //.###/#..#/#..#/#..#/.###/...#/.##.
h #.../#.../###./#..#/#..#/#..#/#..#
i #/./#/#/#/#/#
j .#/../.#/.#/.#/.#/.#/.#/#.
k #.../#.../#..#/#.#./##../#.#./#..#
l #./#./#./#./#./#./.#
m //####./#.#.#/#.#.#/#.#.#/#.#.#
n //###./#..#/#..#/#..#/#..#
o //.##./#..#/#..#/#..#/.##.
p //###./#..#/#..#/#..#/###./#.../#...
q //.###/#..#/#..#/#..#/.###/...#/...#
r //#.#/##./#../#../#..
s //.###/#.../.##./...#/###.
t .#./.#./###/.#./.#./.#./..#
u //#..#/#..#/#..#/#..#/.###
v //#...#/#...#/.#.#./.#.#./..#..
w //#.#.#/#.#.#/#.#.#/#.#.#/.#.#.
x //#..#/#..#/.##./#..#/#..#
y //#..#/#..#/#..#/#..#/.###/...#/.##.
z //####/...#/.##./#.../####
0 .##./#..#/#.##/##.#/#..#/#..#/.##.
1 .#./##./.#./.#./.#./.#./###
2 .##./#..#/...#/..#./.#../#.../####
3 ###./...#/...#/.##./...#/...#/###.
4 #..#/#..#/#..#/####/...#/...#/...#
5 ####/#.../#.../###./...#/...#/###.
6 .##./#.../#.../###./#..#/#..#/.##.
7 ####/...#/..#./..#./.#../.#../.#..
8 .##./#..#/#..#/.##./#..#/#..#/.##.
9 .##./#..#/#..#/.###/...#/...#/.##.
! #/#/#/#/#/./#
" #.#/#.#
# .#.#./.#.#./#####/.#.#./#####/.#.#./.#.#.
$ ..#../.####/#.#../.###./..#.#/####./..#..
% ##..#/##.#./...#./..#../.#.../.#.##/#..##
& .#.../#.#../.#.../#.#.#/#..#./#..#./.##.#
' #/#
( .#/#./#./#./#./#./.#
) #./.#/.#/.#/.#/.#/#.
* /#.#/.#./#.#
+ //.#./###/.#.
, /////.#/.#/#.
- ///###
. //////#
/ ...#/...#/..#./..#./.#../.#../#...
: //#/.///#
; //.#/../../.#/#.
< /..#/.#./#../.#./..#
= //###/.../###
> /#../.#./..#/.#./#..
? ###./...#/...#/.##./.#../..../.#..
@ .###./#...#/#.###/#.#.#/#.###/#..../.###.
[ ##/#./#./#./#./#./##
\\ #.../#.../.#../.#../..#./..#./...#
] ##/.#/.#/.#/.#/.#/##
^ .#./#.#
_ //////####
` #./.#
{ ..#/.#./.#./#../.#./.#./..#
| #/#/#/#/#/#/#
} #../.#./.#./..#/.#./.#./#..
~ //.#..#/#.##.
· ///#
""".strip()

MARKS = {"acute": ["..#", ".#."], "grave": ["#..", ".#."], "circ": [".#.", "#.#"], "tilde": [".#.#", "#.#."]}
ACCENTED = {
    "acute": ("AEIOUaeiou", "ÁÉÍÓÚáéíóú"),
    "grave": ("Aa", "Àà"),
    "circ": ("AEOaeo", "ÂÊÔâêô"),
    "tilde": ("AOao", "ÃÕãõ"),
}
CELL = 12
BASE = 10  # a linha de base fica logo abaixo da linha 9 da célula


def font() -> tuple[Image, str]:
    glyphs = {" ": ([], 0)}
    for line in GLYPHS.splitlines():
        name, body = line.split(" ", 1)
        rows = body.split("/")
        width = max(len(r) for r in rows)
        glyphs[name] = ([(x, y + 3) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == "#"], width)

    for mark, (plain, marked) in ACCENTED.items():
        for base, out in zip(plain, marked):
            dots, width = glyphs[base]
            lower = base.islower()
            if base == "i":  # sem o pingo, e largo o bastante para o acento
                dots, width = [(1, y) for _, y in dots if y >= 5], 3
            rows = MARKS[mark]
            wide = max(width, len(rows[0]))
            shift = (wide - width) // 2
            at = (wide - len(rows[0])) // 2
            top = 2 if lower else 0
            glyphs[out] = (
                [(x + shift, y) for x, y in dots]
                + [(at + x, top + y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == "#"],
                wide,
            )
    for base, out in (("C", "Ç"), ("c", "ç")):
        dots, width = glyphs[base]
        mid = width // 2
        glyphs[out] = (dots + [(mid, 10), (mid - 1, 11), (mid, 11)], width)

    cols = 16
    size = 8
    names = sorted(glyphs)
    im = Image(cols * size, (len(names) + cols - 1) // cols * CELL)
    lines = [
        'info face="Hound" size=11 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={CELL} base={BASE} scaleW={im.w} scaleH={im.h} pages=1 packed=0",
        'page id=0 file="hound_font.png"',
        f"chars count={len(names)}",
    ]
    for i, name in enumerate(names):
        dots, width = glyphs[name]
        ox, oy = i % cols * size, i // cols * CELL
        for x, y in dots:
            im.set(ox + x, oy + y, (255, 255, 255, 255))
        advance = 3 if name == " " else width + 1
        lines.append(f"char id={ord(name)} x={ox} y={oy} width={max(width, 1)} height={CELL} "
                     f"xoffset=0 yoffset=0 xadvance={advance} page=0 chnl=15")
    return im, "\n".join(lines) + "\n"


def preview(images: list[Image], path: Path, scale: int = 4) -> None:
    gap = 4
    out = Image((max(i.w for i in images) + gap * 2) * scale,
                (sum(i.h + gap for i in images) + gap) * scale, BLACK)
    y = gap
    for im in images:
        out.paste(im, gap * scale, y * scale, scale)
        y += im.h + gap
    path.write_bytes(out.png())


def main() -> None:
    images = {name: sheet(build()) for name, build in SHEETS.items()}
    atlas, fnt = font()
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        preview([*images.values(), atlas], Path(sys.argv[2]))
        return
    OUT.mkdir(exist_ok=True)
    for name, im in images.items():
        (OUT / f"{name}.png").write_bytes(im.png())
    (OUT / "hound_font.png").write_bytes(atlas.png())
    (OUT / "hound_font.fnt").write_text(fnt, encoding="utf-8")
    print(f"{len(images)} folhas e a fonte em {OUT}")


if __name__ == "__main__":
    main()

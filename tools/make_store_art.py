#!/usr/bin/env python3
"""Ícone do jogo e artes da loja e da biblioteca da Steam.

Tamanhos e regras da documentação da Steamworks (conferidos em 2026-11-22):
cápsulas só com arte e nome do jogo; Library Hero sem texto; Library Logo
transparente. Tudo composto com os sprites de make_art.py.

    python3 tools/make_store_art.py
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import make_art as art  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "steam" / "assets"
DIM = (44, 44, 46, 255)
SHADE = (25, 25, 27, 255)

ATLAS, FNT = art.font()
CHARS = {}
for line in FNT.splitlines():
    if line.startswith("char id="):
        f = dict(p.split("=") for p in line.split()[1:])
        CHARS[chr(int(f["id"]))] = (int(f["x"]), int(f["y"]), int(f["width"]), int(f["xadvance"]))


def word_width(text: str) -> int:
    return sum(CHARS[c][3] for c in text) - 1


def word(im: art.Image, x: int, y: int, text: str, color, scale: int = 1, bold: bool = False) -> int:
    """Escreve com o topo das maiúsculas em y."""
    for c in text:
        sx, sy, w, adv = CHARS[c]
        for j in range(3, 10):
            for i in range(w):
                if ATLAS.get(sx + i, sy + j)[3]:
                    im.rect(x + i * scale, y + (j - 3) * scale, scale * 2 if bold else scale, scale, color)
        x += (adv + (1 if bold else 0)) * scale
    return x


def logo_width(scale: int) -> int:
    return (word_width("HOUND.EXE") + len("HOUND.EXE")) * scale


def game_logo(im: art.Image, x: int, y: int, scale: int) -> None:
    x = word(im, x, y, "HOUND", art.WHITE, scale, bold=True)
    word(im, x, y, ".EXE", art.ACCENT, scale, bold=True)


def tinted(sprite: art.Image, color) -> art.Image:
    out = art.Image(sprite.w, sprite.h)
    out.px = [color if p[3] else art.CLEAR for p in sprite.px]
    return out


def platform(im: art.Image, x: int, y: int, w: int) -> None:
    im.rect(x, y, w, 14, art.BLACK)
    im.box(x, y, w, 14)
    im.rect(x, y, w, 5)
    im.rect(x + 3, y + 2, w - 14, 1, art.BLACK)
    im.rect(x + w - 7, y + 1, 4, 3, art.BLACK)


def wallpaper(im: art.Image) -> None:
    kinds = ["folder", "page", "bin", "computer", "download"]
    for gy, y in enumerate(range(5, im.h - 20, 38)):
        for gx, x in enumerate(range(6, im.w - 20, 46)):
            if (gx * 3 + gy * 5) % 4:
                im.paste(tinted(art.icon(kinds[(gx + gy * 2) % len(kinds)]), DIM), x + (gy % 2) * 12, y)


def floor(im: art.Image, y: int) -> None:
    im.rect(0, y, im.w, im.h - y, SHADE)
    for j in range(y + 4, im.h, 4):
        for i in range(2 if (j // 4) % 2 else 0, im.w, 4):
            im.set(i, j, DIM)
    im.rect(0, y, im.w, 2)


def chase(im: art.Image, left: int, width: int, ground: int, dog_scale: int = 2) -> None:
    """A cena-chave: o cão farejador atira no Arquivo Fantasma."""
    dog = art.hound_frames()[11]
    dw, dh = dog.w * dog_scale, dog.h * dog_scale
    im.paste(dog, left, ground - dh, dog_scale)
    muzzle = ground - dh + 5 * dog_scale
    boss_x = left + width - 32 * dog_scale
    x = left + dw + 3
    while x < boss_x - 6:
        im.rect(x, muzzle, 5, 2)
        im.rect(x - 4, muzzle + 1, 2, 1, art.ACCENT)
        x += 16
    im.paste(art.ghost("solid"), boss_x, ground - 34 * dog_scale, dog_scale)


def scaled(im: art.Image, scale: int, w: int, h: int) -> art.Image:
    """Amplia sem borrar e corta no centro."""
    ox, oy = (im.w * scale - w) // 2, (im.h * scale - h) // 2
    out = art.Image(w, h)
    cols = [(x + ox) // scale for x in range(w)]
    out.px = [im.px[((y + oy) // scale) * im.w + c] for y in range(h) for c in cols]
    return out


def canvas(w: int, h: int, scale: int) -> art.Image:
    return art.Image(-(-w // scale), -(-h // scale), art.BLACK)


def landscape(w: int, h: int, scale: int, logo_scale: int) -> art.Image:
    im = canvas(w, h, scale)
    wallpaper(im)
    ground = im.h - 14
    im.rect(0, 0, im.w, 14 + 7 * logo_scale, art.BLACK)  # nada atrás do nome
    game_logo(im, (im.w - logo_width(logo_scale)) // 2, 10, logo_scale)
    platform(im, im.w // 2 - 24, ground - 46, 48)
    im.paste(art.walker(1), im.w // 2 - 8, ground - 62)
    floor(im, ground)
    width = min(im.w - 16, 260)
    chase(im, (im.w - width) // 2, width, ground, 1 if im.h < 120 else 2)
    return scaled(im, scale, w, h)


def portrait(w: int, h: int, scale: int, logo_scale: int) -> art.Image:
    im = canvas(w, h, scale)
    wallpaper(im)
    ground = im.h - 16
    top = 14
    im.rect(0, 0, im.w, top + 18 * logo_scale, art.BLACK)
    for text, color in (("HOUND", art.WHITE), (".EXE", art.ACCENT)):
        width = (word_width(text) + len(text)) * logo_scale
        word(im, (im.w - width) // 2, top, text, color, logo_scale, bold=True)
        top += 9 * logo_scale
    im.paste(art.ghost("solid"), im.w - 70, top + 4, 2)
    platform(im, 8, ground - 52, 52)
    im.paste(art.walker(1), 22, ground - 68)
    floor(im, ground)
    im.paste(art.hound_frames()[12], 10, ground - 32, 2)
    for i in range(1, 5):
        im.rect(48 + i * 9, ground - 30 - i * 9, 3, 3, art.ACCENT)
    return scaled(im, scale, w, h)


def small_capsule() -> art.Image:
    w, h = 462, 174
    im = art.Image(w, h, art.BLACK)
    im.rect(0, h - 12, w, 12, art.ACCENT)
    s = 7  # quase ocupa a cápsula: precisa ser lida em 120x45
    game_logo(im, (w - logo_width(s)) // 2, (h - 12 - 7 * s) // 2, s)
    return im


def hero() -> art.Image:
    im = canvas(3840, 1240, 10)  # 384x124; área segura no centro: 86x38
    wallpaper(im)
    ground = 92
    floor(im, ground)
    platform(im, 70, 56, 48)
    im.paste(art.walker(1), 86, 40)
    platform(im, 276, 46, 56)
    im.paste(art.turret(True), 296, 30)
    chase(im, 138, 110, ground)
    return scaled(im, 10, 3840, 1240)


def library_logo() -> art.Image:
    s = 1280 // logo_width(1)
    im = art.Image(1280, 7 * s + 4)
    game_logo(im, (1280 - logo_width(s)) // 2, 2, s)
    return im


def background() -> art.Image:
    im = canvas(1438, 810, 4)
    wallpaper(im)
    return scaled(im, 4, 1438, 810)


def app_icon(size: int) -> art.Image:
    im = art.Image(32, 32, art.BLACK)
    im.box(0, 0, 32, 32)
    im.rect(0, 0, 32, 6)
    im.rect(25, 1, 4, 4, art.BLACK)
    im.rect(3, 2, 18, 1, art.BLACK)
    im.paste(art.sheet([_head()]), 4, 9, 2)
    im.rect(4, 26, 16, 3, art.ACCENT)
    out = art.Image(size, size)
    out.px = [im.get(x * 32 // size, y * 32 // size) for y in range(size) for x in range(size)]
    return out


def _head() -> art.Image:
    im = art.Image(12, 8)
    im.art(0, 0, art.HEAD[:7])
    return im


def ico(sizes=(16, 32, 48, 64, 128, 256)) -> bytes:
    blobs = [app_icon(s).png() for s in sizes]
    head = struct.pack("<3H", 0, 1, len(sizes))
    at = 6 + 16 * len(sizes)
    entries = b""
    for s, blob in zip(sizes, blobs):
        entries += struct.pack("<4B2H2I", s % 256, s % 256, 0, 0, 1, 32, len(blob), at)
        at += len(blob)
    return head + entries + b"".join(blobs)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "art" / "icon.png").write_bytes(app_icon(512).png())
    images = {
        "header_capsule_920x430": landscape(920, 430, 3, 3),
        "small_capsule_462x174": small_capsule(),
        "main_capsule_1232x706": landscape(1232, 706, 4, 4),
        "vertical_capsule_748x896": portrait(748, 896, 4, 4),
        "library_capsule_600x900": portrait(600, 900, 4, 3),
        "library_header_920x430": landscape(920, 430, 3, 3),
        "library_hero_3840x1240": hero(),
        "library_logo_1280": library_logo(),
        "page_background_1438x810": background(),
        "community_icon_184x184": app_icon(184),
    }
    for name, im in images.items():
        (OUT / f"{name}.png").write_bytes(im.png())
    (OUT / "client_icon.ico").write_bytes(ico())
    print(f"{len(images)} artes, o .ico e art/icon.png prontos")


if __name__ == "__main__":
    main()

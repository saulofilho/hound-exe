#!/usr/bin/env python3
"""Gera site/: a fonte do jogo como webfont, sprites, capturas, imagem social e vídeo.

    python3 tools/make_site.py

O HTML (index.html), o CSS e o JS são escritos à mão; isto só gera os materiais.
Tudo é servido pelo próprio site: nenhum pedido a terceiros.
O vídeo vem de builds/promo/ (tools/make_promo.sh); sem ele, fica o que já estava.
"""

from __future__ import annotations

import shutil
import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import make_art as art  # noqa: E402
import make_store_art as store  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "site" / "media"
PX = 100              # unidades por pixel da fonte; o corpo tem 11 pixels
UPM = 11 * PX
ASCENT = art.BASE * PX
DESCENT = (art.CELL - art.BASE) * PX
SPRITES = ("hound", "walker", "turret", "spam", "chaser", "ghost", "items", "icons")
SHOTS = ("shoot", "copies", "arena", "sniff", "laser", "stunned", "quarantine", "hidden")


def table_checksum(data: bytes) -> int:
    data += b"\0" * (-len(data) % 4)
    return sum(struct.unpack(f">{len(data) // 4}I", data)) & 0xFFFFFFFF


def glyph(cells: set[tuple[int, int]]) -> tuple[bytes, int, int, tuple[int, int, int, int]]:
    """Um contorno por corrida horizontal de pixels, no sentido horário."""
    boxes = []
    for y in range(art.CELL):
        x = 0
        while x < 8:
            if (x, y) in cells:
                start = x
                while (x, y) in cells:
                    x += 1
                top = (art.BASE - y) * PX
                boxes.append((start * PX, top - PX, x * PX, top))
            else:
                x += 1
    if not boxes:
        return b"", 0, 0, (0, 0, 0, 0)
    points = [p for a, b, c, d in boxes for p in ((a, b), (a, d), (c, d), (c, b))]
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    bounds = (min(xs), min(ys), max(xs), max(ys))
    data = struct.pack(">5h", len(boxes), *bounds)
    data += b"".join(struct.pack(">H", i * 4 + 3) for i in range(len(boxes)))
    data += struct.pack(">H", 0) + b"\x01" * len(points)
    for values in (xs, ys):
        last = 0
        for v in values:
            data += struct.pack(">h", v - last)
            last = v
    return data + b"\0" * (-len(data) % 4), len(points), len(boxes), bounds


def truetype() -> bytes:
    """A fonte de make_art.py em TrueType, só com a biblioteca padrão."""
    chars = sorted(store.CHARS, key=ord)
    entries = [(None, set(), 4)]  # .notdef
    for c in chars:
        sx, sy, w, advance = store.CHARS[c]
        entries.append((c, {(x, y) for y in range(art.CELL) for x in range(w) if store.ATLAS.get(sx + x, sy + y)[3]}, advance))

    glyf, loca, metrics = b"", [0], b""
    most_points = most_contours = 0
    boxes = []
    for _, cells, advance in entries:
        data, points, contours, bounds = glyph(cells)
        glyf += data
        loca.append(len(glyf))
        metrics += struct.pack(">Hh", advance * PX, bounds[0])
        most_points, most_contours = max(most_points, points), max(most_contours, contours)
        if contours:
            boxes.append(bounds)
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    widest = max(e[2] for e in entries) * PX
    count = len(entries)

    # cmap formato 4, um segmento por caractere
    codes = [ord(c) for c in chars] + [0xFFFF]
    deltas = [(i + 1 - code) & 0xFFFF for i, code in enumerate(codes[:-1])] + [1]
    n = len(codes)
    select = n.bit_length() - 1
    search = 2 * 2 ** select
    body = struct.pack(f">{n}H", *codes) + b"\0\0" + struct.pack(f">{n}H", *codes) + struct.pack(f">{n}H", *deltas) + b"\0\0" * n
    sub = struct.pack(">7H", 4, 14 + len(body), 0, 2 * n, search, select, 2 * n - search) + body
    cmap = struct.pack(">4HI", 0, 1, 3, 1, 12) + sub

    names = [(1, "Hound Pixel"), (2, "Regular"), (3, "Hound Pixel 1.0"), (4, "Hound Pixel"), (5, "Version 1.000"), (6, "HoundPixel-Regular")]
    records, strings = b"", b""
    for number, text in names:
        raw = text.encode("utf-16-be")
        records += struct.pack(">6H", 3, 1, 0x409, number, len(raw), len(strings))
        strings += raw
    name = struct.pack(">3H", 0, len(names), 6 + len(records)) + records + strings

    tables = {
        "OS/2": struct.pack(">HhHHH11h10B4I4s3H3h2H2I2h3H", 4, widest // 2, 400, 5, 0,
                            700, 700, 0, 100, 700, 700, 0, 400, 100, 300, 0,
                            *([0] * 10), 1, 0, 0, 0, b"HNDX", 0x40, codes[0], codes[-2],
                            ASCENT, -DESCENT, 0, ASCENT, DESCENT, 1, 0, 5 * PX, 7 * PX, 0, 32, 0),
        "cmap": cmap,
        "glyf": glyf,
        "head": struct.pack(">4I2H2q4h2H3h", 0x00010000, 0x00010000, 0, 0x5F0F3CF5, 0x0003, UPM, 0, 0, x0, y0, x1, y1, 0, 8, 2, 1, 0),
        "hhea": struct.pack(">I3hH11hH", 0x00010000, ASCENT, -DESCENT, 0, widest, x0, 0, x1, 1, 0, 0, 0, 0, 0, 0, 0, count),
        "hmtx": metrics,
        "loca": struct.pack(f">{len(loca)}I", *loca),
        "maxp": struct.pack(">I14H", 0x00010000, count, most_points, most_contours, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0),
        "name": name,
        "post": struct.pack(">2I2h5I", 0x00030000, 0, -PX, PX, 0, 0, 0, 0, 0),
    }
    total = len(tables)
    select = total.bit_length() - 1
    search = 16 * 2 ** select
    head = struct.pack(">I4H", 0x00010000, total, search, select, total * 16 - search)
    directory, blob, at = b"", b"", len(head) + total * 16
    head_at = 0
    for tag in sorted(tables):
        data = tables[tag]
        if tag == "head":
            head_at = at + len(blob)
        directory += struct.pack(">4s3I", tag.encode(), table_checksum(data), at + len(blob), len(data))
        blob += data + b"\0" * (-len(data) % 4)
    out = bytearray(head + directory + blob)
    out[head_at + 8:head_at + 12] = struct.pack(">I", (0xB1B0AFBA - table_checksum(bytes(out))) & 0xFFFFFFFF)
    return bytes(out)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "site" / ".gdignore").touch()
    (OUT / "hound-pixel.ttf").write_bytes(truetype())
    (OUT / "og.png").write_bytes(store.landscape(1200, 630, 4, 4).png())
    (OUT / "favicon.png").write_bytes(store.app_icon(64).png())
    for name in SPRITES:
        shutil.copyfile(ROOT / "art" / f"{name}.png", OUT / f"{name}.png")
    found = sorted((ROOT / "steam" / "screenshots").glob("*.png"))
    for short in SHOTS:
        match = [p for p in found if p.stem.endswith("-" + short)]
        if len(match) != 1:
            sys.exit(f"captura '{short}' não achada: rode godot --path . -s tools/capture.gd -- store")
        shutil.copyfile(match[0], OUT / f"shot-{short}.png")
    video = ROOT / "builds" / "promo" / "hound-exe-promo-en-16x9.mp4"
    if video.exists():
        shutil.copyfile(video, OUT / "promo.mp4")
    else:
        print("sem builds/promo: o vídeo do site ficou como estava")
    size = sum(p.stat().st_size for p in OUT.iterdir())
    print(f"site/media pronto: {len(list(OUT.iterdir()))} arquivos, {size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()

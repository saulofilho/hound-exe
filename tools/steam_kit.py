#!/usr/bin/env python3
"""Monta builds/steam-envio/: cada arquivo e texto com o nome do campo da Steamworks
onde entra, conferido. Não envia nada (macOS: usa sips e swift).

    python3 tools/steam_kit.py

Os textos vêm de steam/LOJA.md e steam/PUBLICAR.md; edite lá, não no pacote.
O passo a passo é steam/ENVIO.md.
"""

from __future__ import annotations

import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STEAM = ROOT / "steam"
OUT = ROOT / "builds" / "steam-envio"
TRAILER = ROOT / "builds" / "trailer" / "hound-exe-gameplay-en.mp4"

IMAGES = {
    "1-capsulas-da-loja/header-capsule.png": ("assets/header_capsule_920x430.png", (920, 430)),
    "1-capsulas-da-loja/small-capsule.png": ("assets/small_capsule_462x174.png", (462, 174)),
    "1-capsulas-da-loja/main-capsule.png": ("assets/main_capsule_1232x706.png", (1232, 706)),
    "1-capsulas-da-loja/vertical-capsule.png": ("assets/vertical_capsule_748x896.png", (748, 896)),
    "1-capsulas-da-loja/page-background.png": ("assets/page_background_1438x810.png", (1438, 810)),
    "4-biblioteca/library-capsule.png": ("assets/library_capsule_600x900.png", (600, 900)),
    "4-biblioteca/library-header.png": ("assets/library_header_920x430.png", (920, 430)),
    "4-biblioteca/library-hero.png": ("assets/library_hero_3840x1240.png", (3840, 1240)),
    "4-biblioteca/library-logo.png": ("assets/library_logo_1280.png", (1280, None)),
    "5-icones/shortcut-icon.png": ("../art/icon.png", (512, 512)),
}
SHORT_LIMIT = 300
TAG_LIMIT = 20

problems: list[str] = []


def check(ok: bool, what: str) -> None:
    if not ok:
        problems.append(what)


def png_size(path: Path) -> tuple[int, int]:
    return struct.unpack(">2I", path.read_bytes()[16:24])


def part(text: str, start: str, end: str | None = None) -> str:
    body = text[text.index(start) + len(start):]
    return body[: body.index(end)] if end else body


def quote(text: str) -> str:
    lines = (line.strip() for line in text.splitlines())
    return "\n".join(line[1:].strip() for line in lines if line.startswith(">"))


def put(name: str, text: str) -> None:
    path = OUT / "6-textos" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    body = text.strip()
    check(body != "", f"{name}: vazio")
    check(not body.startswith(">") and "\n>" not in body and "**" not in body, f"{name}: sobrou Markdown, e isto vai para a página")
    path.write_text(body + "\n", encoding="utf-8")


def plain(bbcode: str) -> str:
    """Para o editor visual, caso ele não aceite BBCode colado."""
    return re.sub(r"\[/?[a-z0-9]+\]", "", bbcode.replace("[*]", "- ")).replace("\n\n\n", "\n\n")


def images() -> None:
    for target, (source, (width, height)) in IMAGES.items():
        src = STEAM / source
        w, h = png_size(src)
        check(w == width and height in (None, h), f"{target}: {w}x{h}")
        (OUT / target).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, OUT / target)

    icon = OUT / "5-icones" / "app-icon.jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best",
                    str(STEAM / "assets" / "community_icon_184x184.png"), "--out", str(icon)],
                   check=True, capture_output=True)
    check(icon.read_bytes()[:2] == b"\xff\xd8", "app-icon: não saiu JPG")

    shots = sorted((STEAM / "screenshots").glob("*.png"))
    check(len(shots) >= 5, f"só {len(shots)} capturas (mínimo 5)")
    (OUT / "2-capturas").mkdir(parents=True, exist_ok=True)
    for shot in shots:
        check(png_size(shot) == (1920, 1080), f"{shot.name}: não é 1920x1080")
        shutil.copyfile(shot, OUT / "2-capturas" / shot.name)


def trailer() -> None:
    if not TRAILER.exists():
        check(False, "sem trailer: rode tools/make_trailer.sh")
        return
    done = subprocess.run(["swift", str(ROOT / "tools" / "check_video.swift"), str(TRAILER), "5000"], capture_output=True, text=True)
    check(done.returncode == 0, "trailer: " + done.stdout.strip().replace("\n", "; "))
    (OUT / "3-trailer").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(TRAILER, OUT / "3-trailer" / TRAILER.name)


def texts() -> None:
    store = (STEAM / "LOJA.md").read_text(encoding="utf-8")
    guide = (STEAM / "PUBLICAR.md").read_text(encoding="utf-8")
    short = part(store, "## Short description", "## About this game")
    about = part(store, "## About this game", "## Tags sugeridas")

    for code, heading, until in (("en", "**English**", "**Português (Brasil)**"), ("pt-BR", "**Português (Brasil)**", None)):
        line = " ".join(quote(part(short, heading, until)).split())
        check(0 < len(line) <= SHORT_LIMIT, f"descrição curta {code}: {len(line)} caracteres")
        put(f"descricao-curta.{code}.txt", line)
        body = part(about, heading, until).strip()
        check("http" not in body and "www." not in body, f"sobre o jogo {code}: tem link")
        check(body.count("[list]") == body.count("[/list]") == 1, f"sobre o jogo {code}: BBCode quebrado")
        put(f"sobre-o-jogo.{code}.bbcode.txt", body)
        put(f"sobre-o-jogo.{code}.sem-formato.txt", plain(body))

    listed = part(store, "## Tags sugeridas", "## Notas para o analista").strip().split("\n\n")[-1]
    tags = [tag.strip() for tag in listed.replace("\n", " ").split(",")]
    check(5 <= len(tags) <= TAG_LIMIT, f"{len(tags)} tags (de 5 a 20)")
    put("tags-em-ordem.txt", "\n".join(tags))

    put("notas-para-o-analista-da-demo.txt", quote(part(store, "## Notas para o analista")))
    put("ia-pre-gerada.en.txt", " ".join(quote(part(guide, "**IA pré-gerada: sim.**", "**IA ao vivo")).split()))
    put("requisitos-minimos.en.txt", REQUIREMENTS)


REQUIREMENTS = """
WINDOWS
OS: Windows 10 64-bit
Processor: x86_64, 2 cores
Memory: 2 GB RAM
Graphics: OpenGL 3.3 or Direct3D 11 compatible
Storage: 150 MB available space

LINUX + STEAMOS
OS: SteamOS 3 or a 64-bit distribution with glibc 2.28+
Processor: x86_64, 2 cores
Memory: 2 GB RAM
Graphics: OpenGL 3.3 compatible
Storage: 100 MB available space
"""


def main() -> int:
    if sys.platform != "darwin":
        print("o pacote é montado no macOS (sips e swift)")
        return 2
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    (ROOT / "builds" / ".gdignore").touch()
    images()
    trailer()
    texts()
    steps = (STEAM / "ENVIO.md").read_text(encoding="utf-8")
    steps = steps.replace("](../docs/", "](../../docs/").replace("](NOME.md)", "](../../steam/NOME.md)").replace("](PUBLICAR.md)", "](../../steam/PUBLICAR.md)")
    (OUT / "0-PASSO-A-PASSO.md").write_text(steps, encoding="utf-8")
    for problem in problems:
        print("  FALHA:", problem)
    count = sum(1 for p in OUT.rglob("*") if p.is_file())
    print(f"KIT {'FALHOU (%d)' % len(problems) if problems else 'OK'}: {count} arquivos em {OUT.relative_to(ROOT)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Relatório de playtest a partir dos save.json dos testadores.

    python3 tools/playtest_report.py pasta_ou_saves...

Cada save é uma pessoa; o nome mostrado é o do arquivo (ou o da pasta, se o
arquivo se chamar save.json). Os saves vêm de fora: são lidos só como dados.
"""

from __future__ import annotations

import json
import re
import statistics
import sys
from pathlib import Path

GOAL = (15 * 60, 20 * 60)
WINGS = [("pista 1", "clue:gallery"), ("chip", "dash"), ("pista 2", "clue:installers"),
         ("pista 3", "clue:drivers"), ("arena", "arena_desktop"), ("chefe", "boss_desktop")]
MAX_BYTES = 1_000_000


def number(value) -> int:
    ok = isinstance(value, (int, float)) and not isinstance(value, bool) and 0 <= value < 1e9
    return int(value) if ok else 0


def clean(value, width: int = 24) -> str:
    """Texto de arquivo alheio: sem caractere de controle no terminal."""
    return re.sub(r"[^\w .:~-]", "?", str(value))[:width]


def clock(seconds: int | None) -> str:
    return "-" if seconds is None else f"{seconds // 60}:{seconds % 60:02d}"


def files(args: list[str]):
    for arg in args:
        path = Path(arg)
        if path.is_dir():
            # um save.json e o seu .bak são a mesma pessoa
            yield from sorted(p for p in path.rglob("*.json") if ".options." not in p.name and ".settings." not in p.name)
        else:
            yield path


def read(path: Path) -> dict | str:
    try:
        if path.stat().st_size > MAX_BYTES:
            return "grande demais"
        save = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, RecursionError):
        return "não li como JSON"
    if not isinstance(save, dict) or not isinstance(save.get("stats"), dict):
        return "sem contagem (versão anterior à 0.2.1)"
    stats = save["stats"]
    marks = stats.get("marks") if isinstance(stats.get("marks"), dict) else {}
    # o chip é marcado como "installers:x:y"
    chip = [number(v) for k, v in marks.items() if k.startswith("installers:") and k.count(":") == 2]
    found = {key: number(marks[key]) for _, key in WINGS if key in marks}
    if chip:
        found["dash"] = min(chip)
    rooms = stats.get("rooms") if isinstance(stats.get("rooms"), dict) else {}
    taken = save.get("taken") if isinstance(save.get("taken"), list) else []
    frames = number(stats.get("frames"))
    return {
        "who": clean(path.parent.name if path.name == "save.json" else path.stem),
        "version": clean(stats.get("version", "?"), 10),
        "os": clean(stats.get("os", "?"), 10),
        "pad": stats.get("pad") is True,
        "partial": stats.get("partial") is not False,
        "seconds": number(stats.get("seconds")),
        "deaths": number(stats.get("deaths")),
        "restarts": number(stats.get("restarts")),
        "sessions": number(stats.get("sessions")),
        "secrets": sum(1 for k in taken if str(k).startswith("backup:")),
        "slow": 100.0 * number(stats.get("slow")) / frames if frames else 0.0,
        "marks": found,
        "rooms": {clean(k): {f: number(v.get(f)) for f in ("seconds", "deaths", "restarts")}
                  for k, v in list(rooms.items())[:40] if isinstance(v, dict)},
    }


def report(runs: list[dict]) -> None:
    print(f"{'quem':24} {'versão':7} {'sistema':9} {'entrada':8} {'tempo':>6} {'fim':>6} {'mortes':>6} {'desist.':>7} {'segr.':>5} {'lento':>6}")
    for r in runs:
        end = None if r["partial"] else r["marks"].get("boss_desktop")
        total = "parcial" if r["partial"] else clock(r["seconds"])
        print(f"{r['who']:24} {r['version']:7} {r['os']:9} {'controle' if r['pad'] else 'teclado':8} {total:>6} "
              f"{clock(end):>6} {r['deaths']:6} {r['restarts']:7} {r['secrets']:5} {r['slow']:5.1f}%")

    whole = [r for r in runs if not r["partial"]]
    if not whole:
        print("\nNenhuma partida com contagem completa.")
        return

    print("\nprogresso               chegaram   mediana")
    for label, key in WINGS:
        times = [r["marks"][key] for r in whole if key in r["marks"]]
        print(f"  {label:20} {len(times):3} de {len(whole):<3} {clock(int(statistics.median(times)) if times else None):>7}")

    print("\nsala           mediana   mortes  desistências")
    names = {name for r in whole for name in r["rooms"]}
    rows = []
    for name in names:
        seen = [r["rooms"][name] for r in whole if name in r["rooms"]]
        rows.append((int(statistics.median(s["seconds"] for s in seen)), sum(s["deaths"] for s in seen), sum(s["restarts"] for s in seen), name))
    for seconds, deaths, restarts, name in sorted(rows, reverse=True):
        print(f"  {name:12} {clock(seconds):>7} {deaths:8} {restarts:13}")

    done = [r["marks"]["boss_desktop"] for r in whole if "boss_desktop" in r["marks"]]
    quit_early = len(whole) - len(done)
    print()
    if done:
        mid = int(statistics.median(done))
        verdict = "dentro" if GOAL[0] <= mid <= GOAL[1] else "abaixo" if mid < GOAL[0] else "acima"
        print(f"Terminaram {len(done)} de {len(whole)}. Mediana {clock(mid)}: {verdict} da meta de 15 a 20 minutos.")
    if quit_early:
        print(f"{quit_early} não terminaram: veja em que sala gastaram mais tempo.")
    if len(done) < 3:
        print("Menos de 3 pessoas terminaram: ainda não dá para afirmar a duração na loja.")
    if len({r["version"] for r in whole}) > 1:
        print("ATENÇÃO: há versões diferentes misturadas.")
    if any(r["slow"] > 2.0 for r in whole):
        print("ATENÇÃO: alguém passou de 2% de quadros abaixo de 30 fps (coluna 'lento').")


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="replace")
    if not sys.argv[1:]:
        print(__doc__)
        return 2
    runs = []
    for path in files(sys.argv[1:]):
        run = read(path)
        if isinstance(run, str):
            print(f"ignorado {clean(path.parent.name)}/{clean(path.name, 40)}: {run}", file=sys.stderr)
        else:
            runs.append(run)
    if not runs:
        print("nenhum save com contagem", file=sys.stderr)
        return 1
    report(runs)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Verificador de salas: o que o cão alcança de verdade, com a física do jogo.

Simula quadro a quadro (as constantes são lidas de scripts/player.gd) todo pulo,
queda e dash a partir de cada lugar onde dá para ficar em pé. Serve para provar
duas coisas em cada mapa: o caminho existe, e o atalho não existe.

    python3 tools/check_rooms.py            # prova; sai com 1 se algo falhar
    python3 tools/check_rooms.py -v [sala]  # o que se alcança em cada sala

Não simula inimigos nem dano. Plataforma temporária conta como sólida.
"""

from __future__ import annotations

import ast
import os
import re
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
T = 16
DT = 1 / 60
HALF_W = 5
TOP = 4      # o corpo vai de y-4 a y+8
BOTTOM = 8
GRID = 8     # as posições em pé são agrupadas de 8 em 8 px
MAX_FRAMES = 150


def constants() -> dict[str, float]:
    src = (ROOT / "scripts" / "player.gd").read_text(encoding="utf-8")
    return {m[1]: float(m[2]) for m in re.finditer(r"^const (\w+) := (-?[\d.]+)", src, re.M)}


K = constants()
ACC, FRIC, GRAV = K["ACCEL"] * DT, K["FRICTION"] * DT, K["GRAVITY"] * DT
RUN, FALL, JUMP, CUT = K["RUN"], K["MAX_FALL"], K["JUMP"], K["JUMP_CUT"]
DASH_V = K["DASH_SPEED"]
DASH_FRAMES = round(K["DASH_TIME"] / DT)


def load_rooms() -> dict:
    """Lê o dicionário DATA de scripts/rooms.gd, que é quase um literal Python."""
    src = (ROOT / "scripts" / "rooms.gd").read_text(encoding="utf-8")
    body = src[src.index("const DATA := {") + len("const DATA := ") :]
    body = body[: body.index("\n}\n") + 2]
    body = re.sub(r"Vector2i\((-?\d+), *(-?\d+)\)", r"(\1, \2)", body)
    body = re.sub(r":\s*true\b", ": True", body)
    body = re.sub(r":\s*false\b", ": False", body)
    return ast.literal_eval(body)


class Room:
    """`dash` e `sniff` dizem o que o cão tem. Sem faro, F é parede e o não existe."""

    def __init__(self, rows: list[str], dash: bool, sniff: bool, opened: bool = False):
        self.rows = rows
        self.w, self.h = len(rows[0]), len(rows)
        self.dash = dash
        walls = {"#", "T"}
        walls |= {"o"} if sniff else set()
        walls |= set() if sniff or opened else {"F"}
        self.wall = [[c in walls for c in row] for row in rows]
        self.laser = [[c == "L" for c in row] for row in rows]
        self.deadly = [[c == "^" for c in row] for row in rows]

    def solid(self, cx: int, cy: int, dashing: bool) -> bool:
        if cy < 0 or cy >= self.h:
            return True
        if cx < 0 or cx >= self.w:
            return False
        return self.wall[cy][cx] or (not dashing and self.laser[cy][cx])

    def grounded(self, x: float, y: float) -> bool:
        cy = int((y + BOTTOM + 0.5) // T)
        return any(self.solid(cx, cy, False) for cx in range(int((x - HALF_W) // T), int((x + HALF_W - 0.01) // T) + 1))

    def move(self, x, y, vx, vy, dashing):
        nx = x + vx * DT
        top, low = int((y - TOP + 0.01) // T), int((y + BOTTOM - 0.01) // T)
        if vx:
            cx = int((nx + HALF_W) // T) if vx > 0 else int((nx - HALF_W) // T)
            for cy in range(top, low + 1):
                if self.solid(cx, cy, dashing):
                    nx = cx * T - HALF_W - 0.001 if vx > 0 else (cx + 1) * T + HALF_W + 0.001
                    vx = 0.0
                    break
        ny = y + vy * DT
        landed = False
        if vy:
            cy = int((ny + BOTTOM) // T) if vy > 0 else int((ny - TOP) // T)
            for cx in range(int((nx - HALF_W) // T), int((nx + HALF_W - 0.01) // T) + 1):
                if self.solid(cx, cy, dashing):
                    if vy > 0:
                        ny, landed = float(cy * T - BOTTOM), True
                    else:
                        ny = (cy + 1) * T + TOP + 0.001
                    vy = 0.0
                    break
        return nx, ny, vx, vy, landed

    def cells(self, x: float, y: float):
        for cy in range(int((y - TOP) // T), int((y + BOTTOM - 0.01) // T) + 1):
            for cx in range(int((x - HALF_W) // T), int((x + HALF_W - 0.01) // T) + 1):
                yield cx, cy

    def air(self, x, y, vx, direction, hold, stop, dash_at, seen):
        """Um salto (hold > 0) ou queda (hold = 0). Devolve onde pousou, ou None."""
        vy = 0.0
        face = direction or 1
        dashing = 0
        for frame in range(MAX_FRAMES):
            go = direction if frame < stop else 0
            if frame == dash_at:
                dashing = DASH_FRAMES
            if dashing:
                dashing -= 1
                vx, vy = face * (DASH_V if dashing else RUN), 0.0
            else:
                target = go * RUN
                rate = ACC if go else FRIC
                vx = min(vx + rate, target) if vx < target else max(vx - rate, target)
                vy = min(vy + GRAV, FALL)
                if hold:
                    if frame == 0:
                        vy = JUMP
                    elif frame == hold and vy < 0:
                        vy *= CUT
            x, y, vx, vy, landed = self.move(x, y, vx, vy, dashing > 0)
            if not (0 <= x < self.w * T):
                seen.add((min(max(int(x // T), -1), self.w), int(y // T)))
                return None
            cx, cy = int(x // T), int(y // T)
            seen.add((cx, cy))
            # um dash não termina dentro (ou colado) de um laser: segue até sair
            if dashing == 1 and vx and self.laser_in_path(x, y, face):
                dashing += 1
            elif not dashing and any(self.solid(a, b, False) for a, b in self.cells(x, y)):
                return None  # preso dentro de parede ou laser: não é um lugar válido
            for a, b in self.cells(x, y):
                if 0 <= a < self.w and 0 <= b < self.h and self.deadly[b][a]:
                    return None
            if landed or (frame > 3 and not dashing and vy >= 0 and self.grounded(x, y) and (y + BOTTOM) % T < 0.6):
                return x, y
        return None

    def laser_in_path(self, x, y, face) -> bool:
        """A mesma conta de Player._laser_in_path."""
        for cy in range(max(int((y - TOP) // T), 0), min(int((y + BOTTOM) // T), self.h - 1) + 1):
            for cx in range(max(int(x // T) - 2, 0), min(int(x // T) + 2, self.w - 1) + 1):
                ahead = (cx * T + T / 2 - x) * face
                if self.laser[cy][cx] and -15 < ahead < 21 and abs(y + 2 - (cy * T + T / 2)) < 14:
                    return True
        return False

    def reach(self, starts) -> set[tuple[int, int]]:
        """Células por onde o centro do cão passa, saindo de `starts` (em px)."""
        seen: set[tuple[int, int]] = set()
        done: set[tuple[int, int]] = set()
        todo = []
        for x, y in starts:
            if self.grounded(x, y):
                todo.append((x, y))
            else:
                landed = self.air(x, y, 0.0, 0, 0, 0, -1, seen)
                if landed:
                    todo.append(landed)
        while todo:
            x, y = todo.pop()
            key = (int(x // GRID), int(round(y)))
            if key in done:
                continue
            done.add(key)
            seen.add((int(x // T), int(y // T)))
            for d in (-1, 1):
                # andar
                nx, ny, vx, _, _ = self.move(x, y, d * GRID / DT, 0.0, False)
                if not (0 <= nx < self.w * T):
                    seen.add((-1 if d < 0 else self.w, int(y // T)))
                elif abs(nx - x) > 0.01:
                    if self.grounded(nx, ny):
                        todo.append((nx, ny))
                    else:
                        for stop in (4, 10, MAX_FRAMES):
                            for dash_at in (-1, 1, 8) if self.dash else (-1,):
                                self._push(todo, self.air(nx, ny, d * RUN, d, 0, stop, dash_at, seen))
                # dash no chão
                if self.dash:
                    self._push(todo, self.air(x, y, 0.0, d, 0, 0, 0, seen))
                # pular, parado ou correndo
                for speed in (0.0, d * RUN):
                    for hold in (3, 10, 18):
                        for stop in (6, 14, 24, MAX_FRAMES):
                            self._push(todo, self.air(x, y, speed, d, hold, stop, -1, seen))
                    if self.dash:
                        for dash_at in (6, 14, 18, 26):
                            for stop in (dash_at, MAX_FRAMES):
                                self._push(todo, self.air(x, y, speed, d, 18, stop, dash_at, seen))
            self._push(todo, self.air(x, y, 0.0, 0, 18, 0, -1, seen))
        return seen

    @staticmethod
    def _push(todo, landed):
        if landed:
            todo.append(landed)


def marks(rows: list[str], chars: str) -> list[tuple[str, int, int]]:
    return [(c, x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c in chars]


def near(seen, cx: int, cy: int) -> bool:
    """Passou perto o bastante para pegar (o jogo usa 10 a 12 px)."""
    return (cx, cy) in seen


def entry(rows, link) -> tuple[float, float]:
    """Onde o cão aparece ao chegar por esta abertura."""
    x = 10.0 if link["side"] == "left" else len(rows[0]) * T - 10.0
    return x, float((link["rows"][1] + 1) * T - BOTTOM)


def exits(seen, rows, link) -> bool:
    width = len(rows[0])
    edge = (-1, 0) if link["side"] == "left" else (width, width - 1)
    return any((x, y) in seen for x in edge for y in range(link["rows"][0], link["rows"][1] + 1))


def report(job) -> str:
    name, data, start, dash, sniff = job
    rows = data["map"]
    seen = Room(rows, dash, sniff).reach([start])
    got = [f"{c}@{x},{y}" for c, x, y in marks(rows, "RAHDESV0123456789") if near(seen, x, y)]
    out = [link["to"] for link in data["links"] if exits(seen, rows, link)]
    mode = "dash+faro" if dash and sniff else "dash" if dash else "faro" if sniff else "nada"
    where = f"({int(start[0])},{int(start[1])})"
    return f"{name:10} de {where:12} {mode:10} itens={' '.join(got) or '-'}  saídas={','.join(out) or '-'}"


NADA, FARO, DASH, TUDO = (False, False), (False, True), (True, False), (True, True)

# de onde, com o quê: o que TEM de alcançar e o que NÃO PODE
RULES = [
    ("c_drive", "P", NADA, ">docs R", "S"),
    ("c_drive", "P", FARO, "S", ""),
    ("docs", "<c_drive", NADA, "1 >downloads", ">trash S"),
    ("docs", "<c_drive", FARO, "S", ">trash"),
    ("docs", "<c_drive", TUDO, ">trash", ""),
    ("images", "0", DASH, "R", ">gallery S"),  # subir é só com faro, mesmo com dash
    ("images", "0", FARO, ">gallery S", ""),
    ("gallery", "<images", DASH, "0 R", "V S"),
    ("gallery", "<images", FARO, "V S 0", ""),
    ("downloads", "<docs", DASH, ">temp", "S"),
    ("downloads", "<docs", FARO, "S", ""),
    ("temp", "<downloads", DASH, "R", ">installers S"),
    ("temp", "<downloads", FARO, ">installers S", ""),
    ("installers", "<temp", DASH, "0 A", "V S"),
    ("installers", "<temp", FARO, "V S A 0", ""),
    ("trash", "<docs", DASH, "1", "D S"),
    ("trash", "<docs", FARO, "D S 1", ""),
    ("system32", "0", FARO, "R", ">drivers S"),
    ("system32", "0", DASH, "R", ">drivers S"),
    ("system32", "0", TUDO, ">drivers S", ""),
    ("drivers", "<system32", FARO, "R", "V 0 S"),
    ("drivers", "<system32", DASH, "R", "V 0 S"),
    ("drivers", "<system32", TUDO, "V 0 S", ""),
]
NEED_DASH = ("trash", "system32", "drivers", "ghost")  # só se entra nelas com o chip


def start_of(data: dict, where: str) -> tuple[float, float]:
    rows = data["map"]
    if where.startswith("<"):
        return entry(rows, next(link for link in data["links"] if link["to"] == where[1:]))
    _, x, y = marks(rows, where)[0]
    return x * T + 8.0, y * T + 8.0


def prove(job) -> list[str]:
    name, data, where, (dash, sniff), must, never = job
    rows = data["map"]
    seen = Room(rows, dash, sniff).reach([start_of(data, where)])

    def got(what: str) -> bool:
        if what.startswith(">"):
            return any(exits(seen, rows, link) for link in data["links"] if link["to"] == what[1:])
        return any(near(seen, x, y) for _, x, y in marks(rows, what))

    how = f"{name} de {where} (dash={dash}, faro={sniff})"
    bad = [f"sem caminho: {how} ate {what}" for what in must.split() if not got(what)]
    return bad + [f"ATALHO: {how} alcanca {what}" for what in never.split() if got(what)]


def trapped(job) -> list[str]:
    """Todo chão firme alcançável tem como sair da sala (setor ruim devolve para ele)."""
    name, data, dash = job
    rows = data["map"]
    room = Room(rows, dash, True)
    starts = [entry(rows, link) for link in data["links"]]
    starts += [(x * T + 8.0, y * T + 8.0) for _, x, y in marks(rows, "P0")]
    seen = room.reach(starts)
    spots = [(x, y) for x, y in seen if 0 <= x < room.w and 0 <= y < room.h - 1
             and rows[y + 1][x] == "#" and rows[y][x] not in "#^"]
    ways_out = marks(rows, "0123456789E")

    def leaves(reached) -> bool:
        return any(exits(reached, rows, link) for link in data["links"]) or any(near(reached, x, y) for _, x, y in ways_out)

    free: set[tuple[int, int]] = set()
    bad = []
    # uma amostra a cada três células basta: entre vizinhas se anda
    for x, y in sorted(spots):
        if any((x + i, y) in free for i in (-2, -1, 1, 2)):
            continue
        if leaves(room.reach([(x * T + 8.0, float((y + 1) * T - BOTTOM))])):
            free.add((x, y))
        else:
            bad.append(f"PRESO: {name} em {x},{y} (dash={dash})")
    return bad


def structure(rooms: dict) -> list[str]:
    """Ligações nos dois sentidos, pousos e nascimentos em lugar livre."""
    bad = []
    for name, data in rooms.items():
        rows = data["map"]
        if len({len(row) for row in rows}) != 1:
            bad.append(f"{name}: linhas de larguras diferentes")
        for link in data["links"]:
            back = [b for b in rooms[link["to"]]["links"] if b["to"] == name]
            if len(back) != 1 or back[0]["side"] == link["side"]:
                bad.append(f"{name}: a volta de {link['to']} nao bate")
        doors = data.get("doors", {})
        if sorted(doors) != sorted(c for c, _, _ in marks(rows, "0123456789")):
            bad.append(f"{name}: pastas do mapa e de doors diferem")
        for door in doors.values():
            target = rooms[door["to"]]
            x, y = door["at"]
            if target["map"][y][x] in "#oT^Q" or target["map"][y + 1][x] != "#":
                bad.append(f"{name}: pouso ruim em {door['to']} {x},{y}")
            if door["shortcut"] and "fight" not in target:
                bad.append(f"{name}: atalho para {door['to']}, que nao tem quarentena")
        if "fight" in data:
            x0, y0, x1, y1 = data["fight"]["zone"]
            for wave in data["fight"]["waves"]:
                for kind, x, y in wave:
                    if rows[y][x] in "#oTQ^" or not (x0 <= x <= x1 and y0 <= y <= y1):
                        bad.append(f"{name}: {kind} nasce fora da zona ou dentro de parede em {x},{y}")
                    if kind == "w" and rows[y + 1][x] != "#":
                        bad.append(f"{name}: andador nasce no ar em {x},{y}")
    clues = sum(len(marks(data["map"], "V")) for data in rooms.values())
    declared = int(re.search(r"const CLUES := (\d+)", (ROOT / "scripts" / "rooms.gd").read_text(encoding="utf-8"))[1])
    if clues != declared:
        bad.append(f"{clues} pistas no mapa, CLUES = {declared}")
    for name, data in rooms.items():
        if name != "ghost" and len(marks(data["map"], "S")) != 1:
            bad.append(f"{name}: precisa de um segredo")
    return bad


def check() -> int:
    rooms = load_rooms()
    bad = structure(rooms)
    with ProcessPoolExecutor(os.cpu_count()) as pool:
        for found in pool.map(prove, [(n, rooms[n], w, how, must, no) for n, w, how, must, no in RULES]):
            bad += found
        walks = [(n, d, dash) for n, d in rooms.items() for dash in ((True,) if n in NEED_DASH else (False, True))]
        for found in pool.map(trapped, walks):
            bad += found
    for line in bad:
        print(line)
    print(f"ROOMS {'OK' if not bad else 'FALHOU (%d)' % len(bad)}: {len(rooms)} salas, {len(RULES)} regras de percurso")
    return 1 if bad else 0


def main() -> None:
    if "-v" not in sys.argv:
        sys.exit(check())
    only = [arg for arg in sys.argv[1:] if arg != "-v"]
    jobs = []
    for name, data in load_rooms().items():
        if only and name not in only:
            continue
        rows = data["map"]
        starts = [entry(rows, link) for link in data["links"]]
        starts += [(x * T + 8.0, y * T + 8.0) for _, x, y in marks(rows, "P0")]
        for start in starts:
            for dash, sniff in ((False, False), (False, True), (True, False), (True, True)):
                jobs.append((name, data, start, dash, sniff))
    with ProcessPoolExecutor(os.cpu_count()) as pool:
        for line in pool.map(report, jobs):
            print(line, flush=True)


if __name__ == "__main__":
    main()

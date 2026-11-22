#!/usr/bin/env python3
"""Planejador do bot de tests/campaign.gd: os botões, quadro a quadro.

Recebe em argv[1] um JSON em base64 {room, pos, dash, target?|exit?, ground?} e devolve uma
lista de passos {inputs, end, temps}. Usa a física de tools/check_rooms.py;
onde ela difere do Godot, o bot percebe e pede outro plano.
"""

from __future__ import annotations

import base64
import heapq
import itertools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
sys.dont_write_bytecode = True
import check_rooms as cr  # noqa: E402

COOLDOWN = round(cr.K["DASH_COOLDOWN"] / cr.DT) + 1


def primitives(dash: bool):
    """(direção, corrida, segura o pulo, para de andar, quadro do dash)."""
    for hold in (18, 7):
        yield 0, 0, hold, 0, -1
    for d in (-1, 1):
        for run in (3, 6, 14, 30):
            yield d, run, 0, 0, -1
        for run, hold, stop in itertools.product((0, 12), (18, 7), (5, 11, 20, 34, 99)):
            yield d, run, hold, stop, -1
        if dash:
            yield d, 1, 0, 0, 1
            yield d, 8, 0, 0, 8
            for run, at, extra in itertools.product((0, 12), (5, 12, 17, 24), (0, 8, 40)):
                yield d, run, 18, at + extra, run + at


def simulate(room: cr.Room, x: float, y: float, prim, goal, ground: bool):
    d, run, hold, stop, dash_at = prim
    vx = vy = 0.0
    inputs, temps = [], {}
    dashing, face = 0, d or 1
    moving_until = run + stop
    for f in range(cr.MAX_FRAMES):
        go = d if f < moving_until else 0
        jump = bool(hold) and run <= f < run + hold
        inputs.append([go, int(jump), int(dash_at >= 0 and dash_at <= f < dash_at + 2)])
        if dashing:
            dashing -= 1
            if not dashing and vx and room.laser_in_path(x, y, face):
                dashing = 1
            vx, vy = face * (cr.DASH_V if dashing else cr.RUN), 0.0
        else:
            target = go * cr.RUN
            rate = cr.ACC if go else cr.FRIC
            vx = min(vx + rate, target) if vx < target else max(vx - rate, target)
            vy = min(vy + cr.GRAV, cr.FALL)
            if hold and f == run:
                if not room.grounded(x, y):
                    return None
                vy = cr.JUMP
            if hold and f == run + hold and vy < 0:
                vy *= cr.CUT
            if f == dash_at:
                dashing = int(cr.K["DASH_TIME"] / cr.DT) + 1
        x, y, vx, vy, _ = room.move(x, y, vx, vy, dashing > 0)
        if not 0 <= x < room.w * cr.T:
            if "exit" in goal:
                side, rows = goal["exit"]
                right = x > 0
                if right == (side == "right") and rows[0] <= int(y // cr.T) <= rows[1]:
                    return x, y, inputs + [[go, 0, 0]] * 4, temps, True
            return None
        for a, b in room.cells(x, y):
            if 0 <= a < room.w and 0 <= b < room.h and room.deadly[b][a]:
                return None
            if not dashing and room.solid(a, b, False):
                return None
        below = int((y + cr.BOTTOM + 0.5) // cr.T)
        on_floor = vy >= 0 and room.grounded(x, y)
        if on_floor and 0 <= below < room.h:
            for a in (int((x - cr.HALF_W) // cr.T), int((x + cr.HALF_W - 0.01) // cr.T)):
                if 0 <= a < room.w and room.rows[below][a] == "T":
                    temps.setdefault((a, below), [f, f])[1] = f
        hit = "target" in goal and abs(x - goal["target"][0]) < 7 and abs(y - goal["target"][1]) < 8
        if hit and not ground and not dashing:
            return x, y, inputs, temps, True
        # o passo termina parado, no chão e com o dash recarregado
        over = f >= run + (1 if hold else 0) and (f >= moving_until or on_floor and f > run + 3)
        if hold and on_floor and f > run + 3:
            moving_until = min(moving_until, f + 1)
        if over and on_floor and not dashing and abs(vx) < 0.01 and f >= moving_until:
            if dash_at < 0 or f >= dash_at + COOLDOWN:
                # parado na pontinha, o Godot escorrega: só vale com apoio de verdade
                if not any(room.solid(int((x + a) // cr.T), below, False) for a in (-2.5, 2.5)):
                    return None
                return x, y, inputs, temps, hit
    return None


def plan(job: dict) -> list:
    data = cr.load_rooms()[job["room"]]
    room = cr.Room(data["map"], job["dash"], True)
    ground = job.get("ground", False)
    if "exit" in job:
        link = next(link for link in data["links"] if link["to"] == job["exit"])
        goal = {"exit": (link["side"], link["rows"])}
        gx = 0 if link["side"] == "left" else room.w * cr.T
        gy = link["rows"][1] * cr.T
    else:
        goal = {"target": job["target"]}
        gx, gy = job["target"]
    prims = list(primitives(job["dash"]))

    def estimate(x, y):
        return 1.6 * (abs(x - gx) / 2.0 + abs(y - gy) / 1.1)

    x, y = job["pos"]
    y = round(y)
    if not room.grounded(x, y):
        return []
    key = lambda x, y: (int(x // 5), int(round(y)))
    count = itertools.count()
    todo = [(0.0, next(count), 0, x, y, [])]
    done = set()
    while todo:
        _, _, cost, x, y, steps = heapq.heappop(todo)
        if key(x, y) in done:
            continue
        done.add(key(x, y))
        for prim in prims:
            got = simulate(room, x, y, prim, goal, ground)
            if got is None:
                continue
            nx, ny, inputs, temps, arrived = got
            step = {"inputs": inputs, "end": [nx, ny], "temps": [[a, b, first, last] for (a, b), (first, last) in temps.items()]}
            if arrived:
                return steps + [step]
            if key(nx, ny) not in done:
                spent = cost + len(inputs) + 4
                heapq.heappush(todo, (spent + estimate(nx, ny), next(count), spent, nx, ny, steps + [step]))
    return []


if __name__ == "__main__":
    print(json.dumps(plan(json.loads(base64.b64decode(sys.argv[1])))))

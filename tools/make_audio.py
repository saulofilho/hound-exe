#!/usr/bin/env python3
"""Gera todo o áudio do Hound.exe em audio/: efeitos e trilhas em chiptune.

Tudo é original: os sons são sintetizados aqui (pulso, triângulo e ruído) e as
músicas são as partituras escritas abaixo. Só usa a biblioteca padrão.

    python3 tools/make_audio.py

A saída é determinística. As trilhas saem com ponto de loop gravado no WAV.
Partitura: um compasso = 8 colcheias; "-" segura a nota, "." é pausa.
"""

from __future__ import annotations

import math
import random
import struct
import sys
import zlib
from array import array
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"

NOTE = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}
CHORD = {
    "Dm": ("D", 3, 7), "Bb": ("Bb", 4, 7), "C": ("C", 4, 7), "F": ("F", 4, 7),
    "Gm": ("G", 3, 7), "A": ("A", 4, 7), "Em": ("E", 3, 7), "G": ("G", 4, 7),
    "D": ("D", 4, 7), "Am": ("A", 3, 7), "B": ("B", 4, 7), "Cm": ("C", 3, 7),
    "Ab": ("Ab", 4, 7), "Fm": ("F", 3, 7), "Db": ("Db", 4, 7),
}


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def midi(name: str) -> int:
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def blep(t: float, dt: float) -> float:
    """Suaviza o degrau do pulso, para as notas agudas não chiarem."""
    if t < dt:
        t /= dt
        return t + t - t * t - 1
    if t > 1 - dt:
        t = (t - 1) / dt
        return t * t + t + t + 1
    return 0.0


class Track:
    def __init__(self, seconds: float, seed: str, loop: bool = False):
        self.n = round(seconds * RATE)
        self.buf = [0.0] * self.n
        self.loop = loop
        self.rng = random.Random(zlib.crc32(seed.encode()))

    def tone(self, at, dur, f0, f1=None, vol=0.3, wave="pulse", duty=0.5,
             attack=0.003, release=0.02, decay=0.0, vibrato=0.0):
        """Uma nota ou varredura. Em loop, o que passa do fim volta ao começo."""
        f1 = f0 if f1 is None else f1
        start = round(at * RATE)
        count = max(1, round(dur * RATE))
        phase = held = 0.0
        low = 0.0
        for i in range(count):
            j = start + i
            if j >= self.n:
                if not self.loop:
                    break
                j %= self.n
            t = i / RATE
            f = f0 * (f1 / f0) ** (i / count)
            if vibrato:
                f *= 1 + vibrato * math.sin(math.tau * 5.5 * t)
            dt = f / RATE
            if wave == "pulse":
                v = (1.0 if phase < duty else -1.0) + blep(phase, dt) - blep((phase - duty) % 1.0, dt)
                v -= 2 * duty - 1  # sem componente contínua
            elif wave == "tri":
                v = 1 - 4 * abs(phase - 0.5)
            elif wave == "sine":
                v = math.sin(math.tau * phase)
            else:  # ruído: novo valor a cada ciclo, como nos consoles antigos
                if i == 0 or phase + dt >= 1:
                    held = self.rng.uniform(-1, 1)
                low += (held - low) * 0.5
                v = held if wave == "noise" else low
            env = min(1.0, t / attack, (count - i) / RATE / release)
            if decay:
                env *= math.exp(-t / decay)
            self.buf[j] += v * env * vol
            phase = (phase + dt) % 1.0

    def save(self, name: str, peak: float, folder: Path) -> None:
        mean = sum(self.buf) / self.n
        self.buf = [v - mean for v in self.buf]
        if not self.loop:
            edge = min(110, self.n // 4)  # 5 ms, para não estalar
            for i in range(edge):
                self.buf[i] *= i / edge
                self.buf[-1 - i] *= i / edge
        top = max(1e-9, max(abs(v) for v in self.buf))
        pcm = array("h", (round(v / top * peak * 32767) for v in self.buf))
        if sys.byteorder == "big":
            pcm.byteswap()
        data = pcm.tobytes()
        chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16)
        chunks += b"data" + struct.pack("<I", len(data)) + data
        if self.loop:
            # bloco "smpl": loop para a frente, da primeira à última amostra
            chunks += b"smpl" + struct.pack("<I9I", 60, 0, 0, 10**9 // RATE, 60, 0, 0, 0, 1, 0)
            chunks += struct.pack("<6I", 0, 0, 0, self.n - 1, 0, 0)
        (folder / f"{name}.wav").write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


# ---------------------------------------------------------------- músicas

class Song:
    def __init__(self, name: str, bpm: float, chords: str):
        self.name = name
        self.chords = chords.split()
        self.step = 30.0 / bpm  # colcheia
        self.seconds = len(self.chords) * 8 * self.step

    def layer(self, suffix: str = "") -> Track:
        return Track(self.seconds, self.name + suffix, loop=True)

    def bars(self):
        for bar, chord in enumerate(self.chords):
            root, third, fifth = CHORD[chord]
            yield bar, bar * 8 * self.step, NOTE[root], [0, third, fifth, 12]

    def bass(self, tr, pattern: str, vol: float, octave: int = 2, wave="tri"):
        """pattern: um caractere por colcheia (0 fundamental, 5 quinta, 8 oitava, . pausa)."""
        for _, t, root, _ in self.bars():
            for i, ch in enumerate(pattern):
                if ch != ".":
                    m = 12 * (octave + 1) + root + {"0": 0, "5": 7, "8": 12}[ch]
                    tr.tone(t + i * self.step, self.step * 0.9, hz(m), vol=vol, wave=wave)

    def arp(self, tr, order: str, vol: float, octave: int = 4, div: int = 1, duty: float = 0.125):
        for _, t, root, tones in self.bars():
            for i in range(8 * div):
                ch = order[i % len(order)]
                if ch != ".":
                    m = 12 * (octave + 1) + root + tones[int(ch)]
                    dur = self.step / div
                    tr.tone(t + i * dur, dur * 0.8, hz(m), vol=vol, duty=duty, decay=0.12)

    def melody(self, tr, score: str, vol: float, duty: float = 0.25, wave="pulse"):
        tokens = score.replace("|", " ").split()
        assert len(tokens) == len(self.chords) * 8, f"{self.name}: {len(tokens)} colcheias"
        for i, token in enumerate(tokens):
            if token in "-.":
                continue
            held = 1
            while i + held < len(tokens) and tokens[i + held] == "-":
                held += 1
            tr.tone(i * self.step, held * self.step * 0.92, hz(midi(token)), vol=vol, duty=duty,
                    wave=wave, release=0.05, vibrato=0.006 if held > 2 else 0.0)

    def drums(self, tr, kick: str = "", snare: str = "", hat: str = "", vol: float = 1.0):
        for _, t, _, _ in self.bars():
            for i in range(8):
                at = t + i * self.step
                if kick and kick[i] == "x":
                    tr.tone(at, 0.14, 140, 42, vol=0.55 * vol, wave="sine", decay=0.07)
                if snare and snare[i] == "x":
                    tr.tone(at, 0.12, 5200, 2600, vol=0.22 * vol, wave="noise", decay=0.04)
                if hat and hat[i] == "x":
                    tr.tone(at, 0.04, 11000, vol=0.07 * vol, wave="noise", decay=0.015)


def title(folder: Path) -> None:
    s = Song("music_title", 88, "Dm Bb F C Dm Bb Gm A")
    tr = s.layer()
    s.bass(tr, "0...5...", 0.28)
    s.arp(tr, "0123.21.", 0.10)
    s.melody(tr, """
        A4 - - - F4 - E4 - | D4 - - - . . F4 G4 | A4 - C5 - A4 - - - | G4 - - - E4 - . .
        A4 - - - D5 - C5 - | Bb4 - - - . . A4 F4 | G4 - Bb4 - A4 - G4 - | E4 - - - - - . .
    """, 0.13)
    tr.save(s.name, 0.6, folder)


def desktop(folder: Path) -> None:
    s = Song("music_desktop", 112, "Dm Dm Bb C Dm F Gm A Bb C Dm Dm Gm Bb A A")
    tr = s.layer()
    s.bass(tr, "0..05.8.", 0.30)
    s.arp(tr, "0.2.1.2.", 0.07)
    s.drums(tr, hat="..x...x.")
    s.melody(tr, """
        D4 - F4 - A4 - - . | G4 F4 E4 - D4 - . . | F4 - Bb4 - A4 - F4 - | G4 - - - . . E4 -
        F4 - A4 - D5 - - . | C5 - A4 - F4 - . . | Bb4 - A4 - G4 - D4 - | E4 - - - Db4 - . .
        D4 - . F4 - . Bb4 - | C5 - Bb4 - G4 - . . | A4 - - - F4 E4 D4 - | . . . . A3 - D4 -
        G4 - Bb4 - D5 - - . | C5 - Bb4 - F4 - . . | E4 - A4 - Db5 - - - | A4 - - - . . . .
    """, 0.12)
    tr.save(s.name, 0.42, folder)  # explorar é mais baixo que lutar

    # camada de tensão: entra conforme um bug chega perto
    tr = s.layer("_tension")
    s.arp(tr, "0020", 0.16, octave=3, div=2, duty=0.25)
    s.drums(tr, kick="x.x.x.x.", hat=".x.x.x.x")
    tr.save(s.name + "_tension", 0.38, folder)


def arena(folder: Path) -> None:
    s = Song("music_arena", 152, "Em Em C D Em G Am B")
    tr = s.layer()
    s.bass(tr, "00800080", 0.28)
    s.arp(tr, "0121", 0.07, div=2)
    s.drums(tr, kick="x...x.x.", snare="..x...x.", hat="xxxxxxxx")
    s.melody(tr, """
        E5 . B4 . G4 A4 B4 - | E5 . G5 . Gb5 E5 D5 - | C5 . G4 . E4 G4 C5 - | D5 - A4 - Gb4 - A4 .
        B4 . E5 . B4 A4 G4 - | B4 . D5 . G5 - D5 - | C5 B4 A4 - E5 - C5 - | B4 - Eb5 - Gb5 - - .
    """, 0.13)
    tr.save(s.name, 0.82, folder)


def boss(folder: Path) -> None:
    s = Song("music_boss", 144, "Cm Cm Ab G Cm Cm Fm G Ab Ab Fm Fm Db Db G G")
    tr = s.layer()
    s.bass(tr, "0080.050", 0.30)
    s.arp(tr, "2.10.1..", 0.08)
    s.drums(tr, kick="x..x..x.", snare="....x...", hat="x.x.x.x.")
    s.melody(tr, """
        C5 - - Eb5 - - D5 - | C5 - G4 - . . . . | C5 - - Eb5 - - Ab4 - | G4 - B4 - D5 - . .
        G5 - - Eb5 - - C5 - | D5 - Eb5 - C5 - . . | F5 - - Eb5 - - C5 - | B4 - - - G4 - . .
        Ab4 - C5 - Eb5 - - - | G5 - Gb5 - Eb5 - . . | F5 - C5 - Ab4 - - - | F4 - Ab4 - C5 - . .
        Db5 - - - F5 - - - | Ab5 - F5 - Db5 - . . | D5 - B4 - G4 - B4 - | D5 - F5 - G5 - - .
    """, 0.12)
    tr.save(s.name, 0.8, folder)

    # segunda fase: as "cópias" entram na música
    tr = s.layer("_copies")
    s.arp(tr, "0123", 0.15, octave=4, div=2)
    s.drums(tr, kick=".x...x..", snare=".......x", vol=0.8)
    tr.save(s.name + "_copies", 0.38, folder)


def ambience(folder: Path) -> None:
    seconds = 4.0
    tr = Track(seconds, "ambience", loop=True)
    # ciclos inteiros em 4 s, para a emenda não aparecer
    for f, amp in ((60, 0.30), (120, 0.16), (180.25, 0.06), (241, 0.03)):
        for i in range(tr.n):
            t = i / RATE
            tr.buf[i] += amp * (1 + 0.2 * math.sin(math.tau * 0.5 * t)) * math.sin(math.tau * f * t)
    for at in (0.7, 0.82, 0.88, 2.3, 2.36, 3.5):  # o HD lendo
        tr.tone(at, 0.025, 3000, 1500, vol=0.12, wave="noise", decay=0.008)
    tr.save("music_ambience", 0.07, folder)  # fundo, bem abaixo da música


# ---------------------------------------------------------------- efeitos
# nome: (pico, [(início, duração, f0, f1, volume, onda, opções), ...])

def notes(names: str, gap: float, dur: float, duty: float = 0.5, vol: float = 0.3):
    return [(i * gap, dur, hz(midi(n)), None, vol, "pulse", {"duty": duty, "decay": dur})
            for i, n in enumerate(names.split())]


P, T, N, L, S = "pulse", "tri", "noise", "low", "sine"
Q = {"duty": 0.25}
THIN = {"duty": 0.125}

SFX = {
    # cão
    "jump": (0.35, [(0, 0.11, 260, 620, 0.3, P, Q)]),
    "land": (0.3, [(0, 0.07, 160, 70, 0.4, T, {}), (0, 0.04, 2000, 900, 0.15, L, {})]),
    "shoot": (0.3, [(0, 0.07, 980, 300, 0.3, P, THIN), (0, 0.025, 6000, None, 0.15, N, {})]),
    "spark": (0.18, [(0, 0.035, 7000, 3000, 0.3, N, {})]),
    "dash": (0.45, [(0, 0.17, 1500, 8000, 0.25, L, {}), (0, 0.15, 220, 700, 0.15, T, {})]),
    "hurt": (0.65, [(0, 0.22, 420, 110, 0.35, P, {}), (0, 0.1, 2500, 900, 0.3, N, {})]),
    "death": (0.7, [(i * 0.17, 0.16, f, f * 0.8, 0.3, P, Q) for i, f in enumerate((392, 311, 247, 147))]
              + [(0.68, 0.5, 98, 49, 0.4, T, {})]),
    # faro: a fungada e um cheiro com timbre próprio para cada coisa
    "sniff": (0.4, [(0, 0.09, 2200, 4200, 0.3, L, {"attack": 0.03}), (0.14, 0.11, 2600, 5000, 0.3, L, {"attack": 0.04})]),
    "scent_secret": (0.3, notes("A5 E6", 0.05, 0.08, 0.5)),
    "scent_walker": (0.3, [(0, 0.04, 330, None, 0.3, P, THIN), (0.06, 0.04, 330, None, 0.3, P, THIN)]),
    "scent_turret": (0.3, [(0, 0.1, 180, 190, 0.3, P, Q)]),
    "scent_ghost": (0.3, [(0, 0.16, 660, 600, 0.3, S, {"vibrato": 0.05}), (0, 0.16, 672, 590, 0.2, S, {})]),
    # andador: estalo seco de casca
    "walker_hit": (0.4, [(0, 0.06, 420, 260, 0.3, P, THIN), (0, 0.03, 4000, None, 0.25, N, {})]),
    "walker_die": (0.6, [(i * 0.045, 0.05, f, f * 0.6, 0.3, P, THIN) for i, f in enumerate((520, 400, 300, 190))]
                   + [(0, 0.2, 3500, 800, 0.3, N, {})]),
    # torreta: metal grave
    "turret_fire": (0.4, [(0, 0.12, 300, 140, 0.3, P, Q)]),
    "turret_hit": (0.4, [(0, 0.09, 160, 130, 0.3, P, {}), (0, 0.09, 1210, None, 0.1, S, {})]),
    "turret_die": (0.65, [(0, 0.35, 190, 45, 0.35, P, {}), (0, 0.3, 1500, 300, 0.35, N, {})]),
    # perseguidor: guincho agudo
    "chaser_hit": (0.35, [(0, 0.05, 1300, 1700, 0.3, T, {})]),
    "chaser_die": (0.5, [(0, 0.13, 1900, 500, 0.3, T, {}), (0, 0.08, 5000, 2000, 0.2, N, {})]),
    # fantasma: papel e seno trêmulo
    "ghost_fire": (0.4, [(0, 0.2, 700, 350, 0.3, S, {"vibrato": 0.06})]),
    "ghost_warn": (0.6, [(i * 0.16, 0.1, 880, None, 0.3, P, Q) for i in range(3)]),
    "ghost_charge": (0.55, [(0, 0.45, 800, 3500, 0.3, L, {"attack": 0.04}), (0, 0.4, 150, 420, 0.2, T, {})]),
    "ghost_stun": (0.75, [(0, 0.3, 120, 40, 0.5, S, {}), (0, 0.2, 1800, 300, 0.4, N, {})]),
    "ghost_hit": (0.4, [(0, 0.05, 3000, 6000, 0.25, L, {}), (0, 0.07, 540, 470, 0.2, S, {})]),
    "ghost_phase": (0.65, [(i * 0.07, 0.3, f, f * 1.3, 0.2, P, THIN) for i, f in enumerate((220, 233, 247, 262))]),
    "ghost_die": (0.8, [(0, 0.9, 900, 60, 0.3, S, {"vibrato": 0.08}), (0, 0.7, 4000, 250, 0.35, L, {}),
                        (0.6, 0.4, 110, 36, 0.4, T, {})]),
    # mundo
    "pickup": (0.5, notes("E5 A5 Db6", 0.07, 0.12)),
    "chip": (0.6, notes("D4 F4 A4 D5 F5 A5 D6", 0.075, 0.2, 0.25)),
    "restore": (0.55, notes("F4 C5 A5", 0.11, 0.35, 0.5)),
    "door": (0.5, [(0, 0.3, 200, 800, 0.25, T, {}), (0, 0.25, 900, 3000, 0.1, L, {})]),
    "wave": (0.45, notes("B4 F5", 0.1, 0.12, 0.125)),
    "victory": (0.65, notes("D4 A4 D5 Gb5 A5", 0.13, 0.45, 0.25)),
    # menus
    "ui_move": (0.25, [(0, 0.03, 720, None, 0.3, P, Q)]),
    "ui_ok": (0.35, notes("A4 E5", 0.04, 0.07)),
    "pause": (0.35, notes("E5 A4", 0.06, 0.09)),
}


def effects(folder: Path) -> None:
    for name, (peak, parts) in SFX.items():
        tr = Track(max(at + dur for at, dur, *_ in parts) + 0.01, name)
        for at, dur, f0, f1, vol, wave, opts in parts:
            tr.tone(at, dur, f0, f1, vol=vol, wave=wave, **opts)
        tr.save(name, peak, folder)


def main() -> None:
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    folder.mkdir(parents=True, exist_ok=True)
    for build in (title, desktop, arena, boss, ambience, effects):
        build(folder)
    files = sorted(folder.glob("*.wav"))
    print(f"{len(files)} arquivos, {sum(f.stat().st_size for f in files) / 1e6:.1f} MB em {folder}")


if __name__ == "__main__":
    main()

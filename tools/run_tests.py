#!/usr/bin/env python3
"""Roda as provas em qualquer sistema, sempre numa pasta de usuário descartável:
o save de verdade nem fica ao alcance.

    python3 tools/run_tests.py                     tudo
    python3 tools/run_tests.py save steam          só estas
    python3 tools/run_tests.py --boot <executável> o build exportado abre no título
    python3 tools/run_tests.py --boot <executável> --render   idem, desenhando

O Godot vem de $GODOT ou do PATH.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REAL_TIME = {"audio", "stats"}  # sem --fixed-fps
RUNS = {
    "campaign": [["0"], ["3"], ["16"]],  # sem morte, com uma, com duas
}
SUITES = ["campaign", "region", "stats", "art", "steam", "smoke", "route", "arena", "boss", "save", "finish", "audio", "exploits"]
LIMIT = 1500


def sandbox(home: Path) -> dict[str, str]:
    env = dict(os.environ)
    for key, sub in (("HOME", ""), ("APPDATA", "AppData"), ("LOCALAPPDATA", "Local"),
                     ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        path = home / sub if sub else home
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env["PYTHON"] = sys.executable
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    return env


def run(cmd: list[str], env: dict[str, str], cwd: Path = ROOT) -> tuple[int, str]:
    try:
        done = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, timeout=LIMIT)
    except subprocess.TimeoutExpired as late:
        return 124, (late.output or b"").decode("utf-8", "replace") + "\nTEMPO ESGOTADO"
    except OSError as error:
        return 127, f"não abriu {cmd[0]}: {error}"
    return done.returncode, (done.stdout + done.stderr).decode("utf-8", "replace")


def boot(binary: Path, env: dict[str, str], home: Path, render: bool) -> int:
    log = home / "boot.log"
    cmd = [str(binary.resolve()), "--verbose", "--log-file", str(log), "--audio-driver", "Dummy", "--quit-after", "300"]
    cmd += ["--windowed"] if render else ["--headless"]
    code, out = run(cmd, env, home)
    if log.exists():  # no Windows o executável sem console pode não escrever no pipe
        out += log.read_text(encoding="utf-8", errors="replace")
    problems = [word for word in ("SCRIPT ERROR", "Failed loading resource", "Failed to load script", "Couldn't load project") if word in out]
    if "title.tscn" not in out:
        problems.append("não chegou ao título")
    if code != 0:
        problems.append(f"saiu com {code}")
    if problems:
        print(out[-6000:])
        print("BOOT FALHOU:", ", ".join(problems))
        return 1
    print(f"BOOT OK: {binary.name} abre no título{' desenhando' if render else ''}")
    return 0


def tests(godot: str, env: dict[str, str], names: list[str]) -> int:
    unknown = [name for name in names if name != "rooms" and name not in SUITES]
    if unknown:
        print("não conheço:", ", ".join(unknown))
        return 2
    run([godot, "--headless", "--path", str(ROOT), "--import"], env)
    failed = []
    for name in names:
        if name == "rooms":
            jobs = [("rooms", [sys.executable, "-B", str(ROOT / "tools" / "check_rooms.py")])]
        else:
            pace = [] if name in REAL_TIME else ["--fixed-fps", "60"]
            base = [godot, "--headless", *pace, "--path", str(ROOT), "-s", f"tests/{name}.gd"]
            extras = RUNS.get(name, [[]])
            jobs = [(" ".join([name, *extra]), base + (["--", *extra] if extra else [])) for extra in extras]
        for label, cmd in jobs:
            began = time.monotonic()
            code, out = run(cmd, env)
            good = code == 0 and "ERROR:" not in out and "FALHOU" not in out
            print(f"{'ok    ' if good else 'FALHOU'} {label:14} {time.monotonic() - began:6.1f}s", flush=True)
            if not good:
                failed.append(label)
                print(f"--- saída de {label} (código {code})\n{out[-8000:]}\n---", flush=True)
    print("TESTES OK" if not failed else f"TESTES FALHARAM: {', '.join(failed)}")
    return 1 if failed else 0


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    # ignore_cleanup_errors: no Windows um processo morto ainda pode segurar um arquivo
    with tempfile.TemporaryDirectory(prefix="houndexe-", ignore_cleanup_errors=True) as tmp:
        home = Path(tmp)
        env = sandbox(home)
        if args and args[0] == "--boot" and len(args) > 1:
            return boot(Path(args[1]), env, home, "--render" in args)
        godot = os.environ.get("GODOT") or shutil.which("godot")
        if not godot:
            print("não achei o Godot: defina GODOT")
            return 2
        return tests(godot, env, args or ["rooms", *SUITES])


if __name__ == "__main__":
    sys.exit(main())

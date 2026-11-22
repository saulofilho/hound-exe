#!/usr/bin/env python3
"""Gera os scripts do SteamPipe em steam/scripts/. Não envia nada.

    python3 tools/steam_build.py --app 1234560 --windows 1234561 --linux 1234562 --macos 1234563

Omita um depot para não publicar naquela plataforma. Por padrão o build é de
prévia; --upload gera o script de envio real. Nunca põe nada no branch default.
"""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BINARY = {"windows": "HoundExe.exe", "linux": "HoundExe.x86_64", "macos": "HoundExe.app"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", type=int, required=True)
    for name in BINARY:
        ap.add_argument(f"--{name}", type=int, metavar="DEPOT")
    ap.add_argument("--branch", default="", help="branch beta para publicar ao terminar")
    ap.add_argument("--desc", default="Hound.exe")
    ap.add_argument("--upload", action="store_true")
    args = ap.parse_args()

    depots = {n: getattr(args, n) for n in BINARY if getattr(args, n)}
    if not depots:
        ap.error("informe ao menos um depot")
    if len(set(depots.values())) != len(depots) or min(args.app, *depots.values()) <= 0:
        ap.error("os IDs precisam ser positivos e os depots, diferentes")
    if args.branch.lower() in ("default", "public"):
        ap.error("o branch default só muda à mão, no painel da Steamworks")
    if any(c in '"\\\n\r' for c in args.desc + args.branch):
        ap.error("aspas, barra invertida e quebra de linha não valem no VDF")
    for name in depots:
        if not (ROOT / "builds" / name / BINARY[name]).exists():
            ap.error(f"falta builds/{name}/{BINARY[name]}: rode tools/build.sh")

    out = ROOT / "steam" / "scripts"
    out.mkdir(parents=True, exist_ok=True)
    blocks = "".join(
        f'\t\t"{depot}"\n\t\t{{\n'
        f'\t\t\t"ContentRoot" "{ROOT / "builds" / name}"\n'
        '\t\t\t"FileMapping"\n\t\t\t{\n'
        '\t\t\t\t"LocalPath" "*"\n\t\t\t\t"DepotPath" "."\n\t\t\t\t"Recursive" "1"\n'
        '\t\t\t}\n\t\t\t"FileExclusion" "*.DS_Store"\n\t\t}\n'
        for name, depot in depots.items()
    )
    path = out / f"app_build_{args.app}.vdf"
    path.write_text(
        '"AppBuild"\n{\n'
        f'\t"AppID" "{args.app}"\n'
        f'\t"Desc" "{args.desc}"\n'
        f'\t"Preview" "{0 if args.upload else 1}"\n'
        f'\t"SetLive" "{args.branch}"\n'
        f'\t"ContentRoot" "{ROOT / "builds"}"\n'
        f'\t"BuildOutput" "{ROOT / "steam" / "output"}"\n'
        '\t"Depots"\n\t{\n'
        f"{blocks}"
        "\t}\n}\n",
        encoding="utf-8",
    )
    print(path)
    print("Envio, com a sua conta (o steamcmd pede senha e Steam Guard):")
    print(f'  steamcmd +login SUA_CONTA +run_app_build "{path}" +quit')


if __name__ == "__main__":
    main()

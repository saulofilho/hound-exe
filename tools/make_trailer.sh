#!/usr/bin/env bash
# Grava e codifica o trailer de gameplay em builds/trailer/ (só macOS).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p builds/trailer
touch builds/.gdignore
FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT
"$GODOT" --path . --windowed --write-movie "$FRAMES/f.png" --fixed-fps 60 -s tools/trailer.gd > builds/trailer/record.log 2>&1
if grep "SCRIPT ERROR" builds/trailer/record.log >&2; then exit 1; fi
swift tools/encode_trailer.swift "$FRAMES" builds/trailer/hound-exe-gameplay-en.mp4

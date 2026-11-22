#!/usr/bin/env bash
# Vídeo de divulgação em inglês, 16:9 e 9:16, em builds/promo/ (só macOS).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=builds/promo
mkdir -p "$OUT"
touch builds/.gdignore
FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT
"$GODOT" --path . --windowed --write-movie "$FRAMES/f.png" --fixed-fps 60 -s tools/promo.gd > "$OUT/record.log" 2>&1
if grep -E "SCRIPT ERROR|PROMO FALHOU" "$OUT/record.log" >&2; then exit 1; fi
swift tools/encode_trailer.swift "$FRAMES" "$OUT/hound-exe-promo-en-16x9.mp4"
swift tools/encode_trailer.swift "$FRAMES" "$OUT/hound-exe-promo-en-9x16.mp4" steam/assets/library_logo_1280.png steam/assets/community_icon_184x184.png

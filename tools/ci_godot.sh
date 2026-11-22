#!/usr/bin/env bash
# Só para o CI: baixa o Godot oficial, confere o sha256 fixado aqui e exporta GODOT.
#
#   tools/ci_godot.sh linux|windows|templates
set -euo pipefail

VERSION="4.7.2-stable"
case "${1:-}" in
  linux)
    FILE="Godot_v${VERSION}_linux.x86_64.zip"
    SUM="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4" ;;
  windows)
    FILE="Godot_v${VERSION}_win64.exe.zip"
    SUM="731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953" ;;
  templates)
    FILE="Godot_v${VERSION}_export_templates.tpz"
    SUM="f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011" ;;
  *) echo "uso: $0 linux|windows|templates" >&2; exit 2 ;;
esac

DIR="${RUNNER_TEMP:?só roda no GitHub Actions}/godot-$1"
DIR="${DIR//\\//}"
mkdir -p "$DIR"
cd "$DIR"
curl --fail --silent --show-error --location --retry 3 --output "$FILE" \
  "https://github.com/godotengine/godot-builds/releases/download/$VERSION/$FILE"
echo "$SUM  $FILE" | sha256sum --check --strict -

case "$1" in
  linux)
    unzip -q "$FILE"
    echo "GODOT=$DIR/Godot_v${VERSION}_linux.x86_64" >> "$GITHUB_ENV" ;;
  windows)
    unzip -q "$FILE"
    echo "GODOT=$DIR/Godot_v${VERSION}_win64_console.exe" >> "$GITHUB_ENV" ;;
  templates)
    TARGET="$HOME/.local/share/godot/export_templates/${VERSION/-/.}"
    mkdir -p "$TARGET"
    unzip -q -j "$FILE" templates/version.txt templates/linux_release.x86_64 \
      templates/linux_debug.x86_64 templates/windows_release_x86_64.exe \
      templates/windows_debug_x86_64.exe -d "$TARGET"
    rm "$FILE" ;;
esac

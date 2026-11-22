#!/usr/bin/env bash
# Exporta Windows, Linux e macOS para builds/ (o conteúdo dos depots da Steam).
#
#   tools/build.sh            exporta e cria os .zip para testadores
#   MAC_IDENTITY="Developer ID Application: ..." NOTARY_PROFILE=perfil tools/build.sh
#                             também assina e notariza o app de macOS
#
# O perfil de notarização é criado por você, com `xcrun notarytool store-credentials`.
# Este script não recebe nem guarda senha.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
EXPECTED="4.7.2.stable"
OUT="builds"

"$GODOT" --version | grep -q "^$EXPECTED" || { echo "preciso do Godot $EXPECTED" >&2; exit 1; }
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ "$(grep -c "_version=\"$VERSION" export_presets.cfg)" -ge 2 ] || {
  echo "a versão de project.godot ($VERSION) não bate com export_presets.cfg" >&2; exit 1; }

for dir in windows linux macos testers; do
  rm -rf "${OUT:?}/$dir"
  mkdir -p "$OUT/$dir"
done
touch "$OUT/.gdignore"

"$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1

export_one() {
  echo "== $1"
  "$GODOT" --headless --path . --export-release "$1" "$2" > "$OUT/export-$1.log" 2>&1 || {
    cat "$OUT/export-$1.log" >&2; exit 1; }
  if grep -E "^ERROR|SCRIPT ERROR" "$OUT/export-$1.log" >&2; then exit 1; fi
  [ -e "$2" ] || { echo "nada exportado em $2" >&2; exit 1; }
}
export_one Windows "$OUT/windows/HoundExe.exe"
export_one Linux "$OUT/linux/HoundExe.x86_64"
export_one macOS "$OUT/macos/HoundExe.app"
chmod +x "$OUT/linux/HoundExe.x86_64"

if [ -n "${MAC_IDENTITY:-}" ]; then
  codesign --force --deep --timestamp --options runtime \
    --entitlements tools/macos.entitlements --sign "$MAC_IDENTITY" "$OUT/macos/HoundExe.app"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    ditto -c -k --keepParent "$OUT/macos/HoundExe.app" "$OUT/notarize.zip"
    xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$OUT/macos/HoundExe.app"
  fi
else
  echo "AVISO: macOS só com assinatura ad hoc. A Steam exige notarização da Apple."
fi

"$GODOT" --headless --path . -s tools/notices.gd -- "$PWD/$OUT/THIRD_PARTY_NOTICES.txt" > "$OUT/notices.log" 2>&1
[ -s "$OUT/THIRD_PARTY_NOTICES.txt" ] || { echo "faltaram as licenças" >&2; exit 1; }
for dir in windows linux macos; do
  cp "$OUT/THIRD_PARTY_NOTICES.txt" "$OUT/$dir/"
done

(cd "$OUT/windows" && zip -qr "../testers/HoundExe-$VERSION-windows.zip" .)
tar -C "$OUT/linux" -czf "$OUT/testers/HoundExe-$VERSION-linux.tar.gz" .
ditto -c -k --norsrc "$OUT/macos" "$OUT/testers/HoundExe-$VERSION-macos.zip"

echo "== pronto ($VERSION)"
du -sh "$OUT/windows" "$OUT/linux" "$OUT/macos" "$OUT"/testers/*

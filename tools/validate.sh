#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT_BIN:-$PWD/.tools/godot/godot}"
mkdir -p build/logs public
# Godot resource scanning does not read .gitignore.
for generated in build public node_modules .tools; do
  mkdir -p "$generated"
  touch "$generated/.gdignore"
done
if ! "$engine" --version | grep -q '^4\.4\.1\.'; then
  echo 'Validation requires Godot 4.4.1.' >&2
  exit 1
fi
run_engine() {
  local name="$1"
  shift
  "$engine" --headless --path . "$@" 2>&1 | tee "build/logs/$name.log"
  if grep -E '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script)' "build/logs/$name.log"; then
    echo "Godot reported errors in $name (even if its exit code was zero)." >&2
    exit 1
  fi
}
run_engine import --editor --quit
run_engine runtime --quit-after 120
if [[ -f tests/test_restaurant.gd ]]; then
  run_engine systems --script res://tests/test_restaurant.gd
fi
run_engine export --export-release Web public/index.html
test -s public/index.html
test -s public/index.wasm
test -s public/index.pck
echo 'Godot 4.4.1 import, runtime and HTML5 export passed.'

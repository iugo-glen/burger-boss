#!/usr/bin/env bash
set -euo pipefail
version=4.4.1
tool_dir="${GODOT_TOOL_DIR:-$PWD/.tools/godot}"
data_dir="${XDG_DATA_HOME:-${HOME}/.local/share}"
mkdir -p "$tool_dir" "$data_dir/godot/export_templates/$version.stable"
base="https://github.com/godotengine/godot/releases/download/$version-stable"
if [[ ! -x "$tool_dir/godot" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v${version}-stable_linux.x86_64.zip" -o "$tool_dir/engine.zip"
  unzip -qo "$tool_dir/engine.zip" -d "$tool_dir"
  mv "$tool_dir/Godot_v${version}-stable_linux.x86_64" "$tool_dir/godot"
  chmod +x "$tool_dir/godot"
  rm "$tool_dir/engine.zip"
fi
if [[ ! -f "$data_dir/godot/export_templates/$version.stable/web_nothreads_release.zip" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v${version}-stable_export_templates.tpz" -o "$tool_dir/templates.tpz"
  unzip -jo "$tool_dir/templates.tpz" 'templates/web_*.zip' 'templates/version.txt' -d "$data_dir/godot/export_templates/$version.stable"
  rm "$tool_dir/templates.tpz"
fi
"$tool_dir/godot" --version

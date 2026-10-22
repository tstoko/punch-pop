#!/usr/bin/env bash
set -eu
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot4)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
elif [[ -x /private/tmp/punch-pop-runtime/Godot.app/Contents/MacOS/Godot ]]; then
  GODOT_BIN=/private/tmp/punch-pop-runtime/Godot.app/Contents/MacOS/Godot
else
  echo 'Install Godot 4.5+ from https://godotengine.org/download/ and import project.godot.'
  exit 1
fi
# Import once on a fresh checkout so named GDScript classes and SVGs are ready.
if [[ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]]; then
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --import --quit
fi
exec "$GODOT_BIN" --path "$PROJECT_DIR" "$@"

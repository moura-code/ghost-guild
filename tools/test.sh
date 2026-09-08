#!/usr/bin/env bash
# Import class-name scripts first. Every invocation owns disposable user data.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
test_data="$(mktemp -d "${TMPDIR:-/tmp}/ghost-guild-tests.XXXXXX")"
trap 'rm -rf -- "$test_data"' EXIT
export XDG_DATA_HOME="$test_data"
"$engine" --headless --path "$project_root" --import > "$test_data/import.log" 2>&1 || { cat "$test_data/import.log"; exit 1; }
if rg -q 'SCRIPT ERROR|Parse Error' "$test_data/import.log"; then cat "$test_data/import.log"; exit 1; fi
args=()
if (($# == 0)); then set -- tests/core tests/game; fi
for suite in "$@"; do args+=(-a "$suite"); done
"$engine" --headless --path "$project_root" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c "${args[@]}"

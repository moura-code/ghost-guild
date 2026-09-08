#!/usr/bin/env bash
# Persistent profiles are separate from both historical editions' default saves.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="${GG_PROJECT_ROOT:-$project_root}"
engine="${GODOT_BIN:-godot}"
profile="${GG_PROFILE:-hybrid}"
data_root="${GG_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/ghost-guild-editions/$profile}"
mkdir -p "$data_root"
export XDG_DATA_HOME="$data_root"
exec "$engine" --path "$project_root" "$@"

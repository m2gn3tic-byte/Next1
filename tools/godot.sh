#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep writable runtime state inside this isolated task; preserve explicit overrides.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$project_root/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$project_root/.local/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$project_root/.local/config}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
cd "$project_root"
exec godot --path "$project_root" "$@"

#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
godot_version="$(godot --version)"
if [[ "$godot_version" != 4.6.3.stable* ]]; then
  printf 'This build uses Godot 4.6.3.stable; found %s\n' "$godot_version" >&2
  exit 1
fi
python3 tools/install_web_templates.py
mkdir -p build/web artifacts
touch build/.gdignore artifacts/.gdignore
./tools/godot.sh --headless --editor --import --quit
build_id="$(python3 tools/web_release.py fingerprint)"
staging_dir="$(mktemp -d "$project_root/build/web-staging.XXXXXX")"
trap 'rm -rf -- "$staging_dir"' EXIT
./tools/godot.sh --headless --export-release Web "$staging_dir/game-$build_id.html"
./tools/godot.sh --headless --script res://tools/write_notices.gd -- "$staging_dir/THIRD_PARTY_NOTICES.txt"
python3 tools/web_release.py assemble --staging "$staging_dir" --version "$build_id"

#!/usr/bin/env python3
"""Fingerprint game inputs and assemble a clean, cache-safe static web release."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(root=ROOT):
    files = [root / name for name in ["project.godot", "export_presets.cfg", ".godot-version"]]
    for folder in ["assets", "scenes", "scripts", "web"]:
        files.extend(path for path in (root / folder).rglob("*") if path.is_file())
    result = hashlib.sha256()
    for path in sorted(files):
        result.update(path.relative_to(root).as_posix().encode() + b"\0")
        result.update(path.read_bytes())
        result.update(b"\0")
    return result.hexdigest()[:16]


def assemble(staging, build_id):
    staging = staging.resolve()
    build_root = (ROOT / "build").resolve()
    if staging.parent != build_root or not staging.name.startswith("web-staging."):
        raise ValueError("Release staging must be a dedicated build/web-staging.* directory")
    prefix = "game-" + build_id
    for name in [prefix + suffix for suffix in [".html", ".js", ".pck", ".wasm"]]:
        if not (staging / name).is_file():
            raise ValueError("Export missing: " + name)
    (staging / (prefix + ".html")).rename(staging / "index.html")
    (staging / ".nojekyll").touch()
    shutil.copy2(ROOT / "docs/PLAY.txt", staging / "PLAY.txt")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    (staging / "version.json").write_text(json.dumps({
        "version": build_id,
        "commit": commit,
        "uncommitted_changes": dirty,
        "built_at": datetime.now(timezone.utc).isoformat(),
    }, indent=2) + "\n")
    target = build_root / "web"
    if target.exists():
        if target.is_symlink():
            raise ValueError("Refusing to replace a symlinked build directory")
        shutil.rmtree(target)
    staging.rename(target)
    archive_path = ROOT / "artifacts/kosmosekuller-web.zip"
    archive_path.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(target.iterdir()):
            if path.is_file():
                archive.write(path, path.name)
    print("Web release:", build_id)
    print("Built:", target / "index.html")
    print("Downloadable build:", archive_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["fingerprint", "assemble"])
    parser.add_argument("--staging", type=Path)
    parser.add_argument("--version")
    args = parser.parse_args()
    if args.command == "fingerprint":
        print(fingerprint())
    else:
        if not args.staging or not args.version:
            parser.error("assemble requires --staging and --version")
        if args.version != fingerprint():
            parser.error("Game inputs changed during export; rebuild before publishing")
        assemble(args.staging, args.version)


if __name__ == "__main__":
    main()

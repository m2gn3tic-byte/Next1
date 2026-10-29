#!/usr/bin/env python3
"""Install the pinned official Godot web templates with SHA512/SHA256 checks.

Only the first setup needs network access. A previously downloaded official TPZ
can be reused with --archive /path/to/templates.tpz. No global tool changes.
"""
import argparse
import hashlib
from pathlib import Path
import tempfile
import urllib.request
import zipfile

VERSION = "4.6.3"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
ARCHIVE_SHA512 = "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68"
TEMPLATES = {
    "web_nothreads_release.zip": "1446f79dc12f60ce5d244c39fb6628ec298337ca5c4f91a16491feea72aa1bc9",
    "web_nothreads_debug.zip": "4a8a8ef7519637f7898fad25f09d3e466965e99c04e441682e1bc2d97a548922",
}
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / ".tools/godot/4.6.3.stable"


def digest(path, algorithm):
    value = hashlib.new(algorithm)
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def install(archive):
    if digest(archive, "sha512") != ARCHIVE_SHA512:
        raise ValueError("Official Godot archive SHA512 mismatch; no templates installed")
    DEST.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        for name, expected in TEMPLATES.items():
            data = package.read("templates/" + name)
            if hashlib.sha256(data).hexdigest() != expected:
                raise ValueError(f"Template checksum mismatch: {name}")
            temporary = DEST / (name + ".tmp")
            temporary.write_bytes(data)
            temporary.replace(DEST / name)
            print("Installed and verified:", name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if all((DEST / name).is_file() and digest(DEST / name, "sha256") == expected for name, expected in TEMPLATES.items()):
        print(f"Godot {VERSION} web templates verified and ready")
        return
    if args.archive:
        install(args.archive)
    else:
        print("Downloading official export templates (approximately 1.26 GB, one-time setup).", flush=True)
        with tempfile.TemporaryDirectory(prefix="courier-templates-") as folder:
            archive = Path(folder) / "templates.tpz"
            # Standard HTTPS/proxy/CA verification stays enabled.
            with urllib.request.urlopen(URL, timeout=120) as response, archive.open("wb") as target:
                while block := response.read(1024 * 1024):
                    target.write(block)
            install(archive)


if __name__ == "__main__":
    main()

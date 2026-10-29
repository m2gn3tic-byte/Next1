#!/usr/bin/env python3
"""Build the renamed CJK UI subset from the pinned upstream font.

Development-only dependency: fonttools. All game translations and native language
names are included; rerun when adding CJK text. The game uses the bundled result.
"""
import argparse
import hashlib
from pathlib import Path
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    assert hashlib.sha256(args.source.read_bytes()).hexdigest() == SOURCE_SHA256, "Unexpected upstream font"
    text = (ROOT / "assets/i18n/strings.json").read_text()
    for path in (ROOT / "scripts").glob("*.gd"):
        text += path.read_text()
    points = {ord(c) for c in text if 0x2E80 <= ord(c) <= 0x9FFF or 0xAC00 <= ord(c) <= 0xD7AF or 0xF900 <= ord(c) <= 0xFAFF or 0xFF00 <= ord(c) <= 0xFFEF}
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    font = subset.load_font(str(args.source), options)
    cutter = subset.Subsetter(options=options)
    cutter.populate(unicodes=points)
    cutter.subset(font)
    for record in font["name"].names:
        if record.nameID in [1, 3, 4, 6, 16]:
            record.string = ("CourierCJKUI" if record.nameID == 6 else "Courier CJK UI").encode(record.getEncoding())
    cff = font["CFF "].cff
    cff.fontNames = ["CourierCJKUI"]
    cff.topDictIndex[0].FamilyName = "Courier CJK UI"
    cff.topDictIndex[0].FullName = "Courier CJK UI"
    target = ROOT / "assets/fonts/CourierCJKUI.otf"
    font.save(target)
    print(f"Bundled CJK subset: {len(points)} requested characters, {target.stat().st_size} bytes")


if __name__ == "__main__":
    main()

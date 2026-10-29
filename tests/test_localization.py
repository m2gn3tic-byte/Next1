"""Validate the data contract that dynamic and canvas-translated UI depends on."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.packs = json.loads((ROOT / "assets/i18n/strings.json").read_text())

    def test_complete_packs_and_placeholders(self):
        base = self.packs["en"]
        self.assertEqual(len(self.packs), 24)
        for locale, values in self.packs.items():
            self.assertEqual(set(values), set(base), locale)
            for key, text in values.items():
                with self.subTest(locale=locale, key=key):
                    self.assertTrue(text.strip())
                    self.assertEqual(re.findall(r"%[0-9]*[sd]", text), re.findall(r"%[0-9]*[sd]", base[key]))
                    self.assertNotIn("\ufffd", text)
                    self.assertNotIn("\\n", text)

    def test_every_literal_ui_key_exists(self):
        source = (ROOT / "scripts/main.gd").read_text()
        explicit = set(re.findall(r'_t\("([a-z_]+)"(?=\s*[,)])', source))
        controls = set(re.findall(r'_(?:label|button)\([^,\n]+, "([a-z_]+)"(?=\s*,)', source))
        self.assertTrue(explicit)
        self.assertLessEqual(explicit | controls, set(self.packs["en"]))

    def test_noto_sources_are_pinned_and_licenses_shipped(self):
        sources = json.loads((ROOT / "assets/fonts/Noto-SOURCES.json").read_text())
        for name, metadata in sources.items():
            self.assertRegex(metadata["sha256"], r"^[0-9a-f]{64}$")
            self.assertTrue(metadata["url"].startswith("https://raw.githubusercontent.com/"))
        for name in ["OFL-CJK.txt", "OFL-Devanagari.txt", "OFL-Thai.txt"]:
            self.assertIn("SIL OPEN FONT LICENSE", (ROOT / "assets/fonts" / name).read_text())
            self.assertIn(name, (ROOT / "tools/write_notices.gd").read_text())

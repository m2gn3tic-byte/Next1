"""Check that real game updates invalidate browser caches without cache churn."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("web_release", Path(__file__).resolve().parents[1] / "tools/web_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class WebVersionTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        for name in ["project.godot", "export_presets.cfg", ".godot-version"]:
            (self.root / name).write_text("initial content")
        for name in ["assets", "scenes", "scripts", "web"]:
            (self.root / name).mkdir()

    def test_gameplay_update_gets_a_new_release(self):
        script = self.root / "scripts/run_state.gd"
        script.write_text("const SHIELDS = 3")
        before = release.fingerprint(self.root)
        script.write_text("const SHIELDS = 4")
        self.assertNotEqual(before, release.fingerprint(self.root))

    def test_artwork_and_web_shell_updates_get_new_releases(self):
        previous = release.fingerprint(self.root)
        for name in ["assets/ship.svg", "web/shell.html"]:
            (self.root / name).write_text("new appearance")
            current = release.fingerprint(self.root)
            self.assertNotEqual(previous, current)
            previous = current

    def test_generated_files_do_not_change_the_version(self):
        before = release.fingerprint(self.root)
        for name in ["build", ".local", "artifacts"]:
            directory = self.root / name
            directory.mkdir()
            (directory / "generated.txt").write_text("runtime state")
        self.assertEqual(before, release.fingerprint(self.root))


if __name__ == "__main__":
    unittest.main()

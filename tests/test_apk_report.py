import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("apk_report", ROOT / "tools/apk-report.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ApkReportTests(unittest.TestCase):
    def test_classification_and_diff_use_actual_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            before = Path(temporary) / "before.apk"
            after = Path(temporary) / "after.apk"
            with zipfile.ZipFile(before, "w") as archive:
                archive.writestr("lib/arm64-v8a/libgodot_android.so", b"runtime")
                archive.writestr("classes.dex", b"one")
            with zipfile.ZipFile(after, "w") as archive:
                archive.writestr("lib/arm64-v8a/libgodot_android.so", b"runtime")
                archive.writestr("classes.dex", b"two")
                archive.writestr("assets/scenes/map.scn", b"map")
            first, second = module.inspect(before), module.inspect(after)
            self.assertEqual(second["native_by_abi_compressed_bytes"]["arm64-v8a"], 7)
            self.assertNotEqual(first["entries"]["classes.dex"]["sha256"], second["entries"]["classes.dex"]["sha256"])
            self.assertIn("assets/scenes/map.scn", set(second["entries"]) - set(first["entries"]))

    def test_forbidden_entry_detected(self):
        with tempfile.TemporaryDirectory() as temporary:
            apk = Path(temporary) / "bad.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/docs/private.txt", b"secret")
            self.assertEqual(module.inspect(apk)["forbidden_entries"], ["assets/docs/private.txt"])


if __name__ == "__main__":
    unittest.main()

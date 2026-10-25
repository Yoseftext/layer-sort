#!/usr/bin/env python3
"""Local G1.5 oracle regression tests; never access the phone."""
import argparse
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import qa


class QAOracles(unittest.TestCase):
    def test_strict_report_states(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            out = Path(directory)
            self.assertEqual(qa.report("test", "PASS", [], out), 0)
            self.assertEqual(qa.report("test", "FAIL", [], out), 1)
            self.assertEqual(qa.report("test", "UNVERIFIED", [], out), 1)
            self.assertEqual(qa.report("test", "SKIP", [], out), 0)
            self.assertIn('"status": "SKIP"', (out / "report.json").read_text())

    def test_missing_apk_fails_without_device(self):
        args = argparse.Namespace(apk=Path("/nonexistent-g15-apk.apk"), out=None)
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(qa.provenance(args), 1)
        self.assertIn('"status": "FAIL"', output.getvalue())

    def test_oracle_rejects_wrong_expected_hash_package_orientation(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "fake.apk"
            with zipfile.ZipFile(apk, "w") as z:
                z.writestr("AndroidManifest.xml", b"binary fixture")
                z.writestr("lib/arm64-v8a/libgodot_android.so", b"fixture")
            badging = ("package: name='com.yoseftext.layersort.dev' versionCode='1' "
                       "versionName='0.1.0-g1'\nnative-code: 'arm64-v8a'\n")
            manifest = ('screenOrientation(0x0101001e)=1\n'
                        'name(0x01010003)="com.godot.game.GodotAppLauncher"\n')
            signing = f"Signer #1 certificate SHA-256 digest: {qa.CERT}\n"

            def fake_run(*command, **kwargs):
                if command[0] == "aapt2":
                    return subprocess.CompletedProcess(command, 0, manifest if "xmltree" in command else badging, "")
                if command[0] == "apksigner":
                    return subprocess.CompletedProcess(command, 0, signing, "")
                raise AssertionError(f"unexpected external call: {command}")

            for field, value in (("sha256", "0" * 64), ("package", "com.wrong"), ("orientation", "LANDSCAPE")):
                defaults = dict(apk=apk, sha256=None, package=qa.PKG, orientation="PORTRAIT", artifact_name="layer-sort-g1-debug-apk",
                                run_id=None, commit=None, installed=False, out=None)
                defaults[field] = value
                with patch.object(qa, "run", side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(qa.provenance(argparse.Namespace(**defaults)), 1)
                self.assertIn(f'"id": "{ {"sha256": "NEG-03", "package": "NEG-01", "orientation": "NEG-02"}[field]}"', output.getvalue())
                self.assertIn('"status": "FAIL"', output.getvalue())

    def test_device_lock_timeout_is_bounded(self):
        self.assertTrue(callable(qa.device_lock))


if __name__ == "__main__":
    unittest.main()

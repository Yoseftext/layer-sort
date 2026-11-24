from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import artifact_qa as artifact
import device_qa as device
import install_qa as install

COMMIT = "a" * 40
APK_SHA = "b" * 64
OLD_SHA = "c" * 64


def args(*extra: str) -> argparse.Namespace:
    return install.parser().parse_args(["install-build", "--run-id", "12345", "--commit", COMMIT,
                                        "--apk-sha256", APK_SHA, "--installed-sha256", OLD_SHA, *extra])


@contextlib.contextmanager
def candidate(*_args):
    yield Path("/temporary/verified.apk"), {"version_code": 5}


class InstallerTests(unittest.TestCase):
    def test_missing_approval_does_not_reach_github_or_device(self) -> None:
        with (patch.object(artifact, "verified_cached_build") as verify,
              patch.object(device, "phone_lock") as lock, contextlib.redirect_stdout(io.StringIO())):
            self.assertEqual(install.install(args()), 3)
        verify.assert_not_called()
        lock.assert_not_called()

    def test_dry_run_does_not_reach_github_or_device(self) -> None:
        with (patch.object(artifact, "verified_cached_build") as verify,
              patch.object(device, "phone_lock") as lock, contextlib.redirect_stdout(io.StringIO())):
            self.assertEqual(install.install(args("--dry-run")), 3)
        verify.assert_not_called()
        lock.assert_not_called()

    def test_current_hash_and_downgrade_must_match_approval(self) -> None:
        valid = {"sha256": OLD_SHA, "version_code": 5, "version_name": "old"}
        install.check_previous(valid, expect_absent=False, installed_sha256=OLD_SHA, candidate_version=5)
        for actual, absent, expected, version in ((valid, True, None, 6), (None, False, OLD_SHA, 6),
                                                  (valid, False, "d" * 64, 6),
                                                  (valid, False, OLD_SHA, 4)):
            with self.subTest(actual=actual, absent=absent, version=version):
                with self.assertRaises(device.DeviceQaFailure):
                    install.check_previous(actual, expect_absent=absent, installed_sha256=expected,
                                           candidate_version=version)
        install.check_previous(None, expect_absent=True, installed_sha256=None, candidate_version=1)

    def test_inspection_rejects_unexpected_or_multiple_base_paths(self) -> None:
        for paths in ("package:/data/app/x/base.apk\npackage:/data/app/x/split_config.apk",
                      "package:/data/app/x/../../shell/base.apk", "package:/tmp/base.apk"):
            with self.subTest(paths=paths), tempfile.TemporaryDirectory() as temporary:
                with (patch.object(device, "shell_text", side_effect=[f"package:{install.PACKAGE}", paths]),
                      patch.object(device, "adb_call") as adb):
                    with self.assertRaises(device.DeviceQaUnknown):
                        install.installed_apk("device", Path(temporary) / "base.apk")
                    adb.assert_not_called()

    def test_inspection_does_not_treat_package_manager_error_as_absent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(device, "shell_text", return_value="Error: package manager unavailable"):
                with self.assertRaises(device.DeviceQaUnknown):
                    install.installed_apk("device", Path(temporary) / "base.apk")
            with patch.object(device, "shell_text", return_value=""):
                self.assertIsNone(install.installed_apk("device", Path(temporary) / "base.apk"))

    def test_success_checks_same_apk_and_only_installs_in_place(self) -> None:
        before = {"sha256": OLD_SHA, "version_code": 4, "version_name": "old"}
        after = {"sha256": APK_SHA, "version_code": 5, "version_name": "new"}
        output = io.StringIO()
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device") as connected,
              patch.object(install, "installed_apk", side_effect=[before, after]),
              patch.object(install, "save_report", side_effect=["preflight.json", "result.json"]) as report,
              patch.object(device, "adb_call", return_value="Performing Streamed Install\nSuccess") as adb,
              contextlib.redirect_stdout(output)):
            self.assertEqual(install.install(args("--owner-approved", "--approval-id", "OWNER-123")), 0)
        connected.assert_called_once_with(require_installed=False)
        adb.assert_called_once_with("approved-device", ["install", "-r", "/temporary/verified.apk"], timeout=180)
        self.assertEqual(report.call_count, 2)
        result = json.loads(output.getvalue())
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["installed_apk"]["sha256"], APK_SHA)

    def test_mismatched_installed_hash_never_mutates(self) -> None:
        before = {"sha256": "d" * 64, "version_code": 4, "version_name": "other"}
        output = io.StringIO()
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device"),
              patch.object(install, "installed_apk", return_value=before),
              patch.object(install, "save_report", return_value="result.json"),
              patch.object(device, "adb_call") as adb, contextlib.redirect_stdout(output)):
            self.assertEqual(install.install(args("--owner-approved", "--approval-id", "OWNER-123")), 1)
        adb.assert_not_called()
        self.assertFalse(json.loads(output.getvalue())["mutation_attempted"])

    def test_first_install_accepts_absent_package_and_verifies_result(self) -> None:
        after = {"sha256": APK_SHA, "version_code": 5, "version_name": "new"}
        request = install.parser().parse_args(["install-build", "--run-id", "12345", "--commit", COMMIT,
                                               "--apk-sha256", APK_SHA, "--expect-absent", "--owner-approved",
                                               "--approval-id", "OWNER-123"])
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device"),
              patch.object(install, "installed_apk", side_effect=[None, after]),
              patch.object(install, "save_report", side_effect=["preflight.json", "result.json"]),
              patch.object(device, "adb_call", return_value="Success"), contextlib.redirect_stdout(io.StringIO())):
            self.assertEqual(install.install(request), 0)

    def test_post_install_hash_mismatch_is_failure(self) -> None:
        before = {"sha256": OLD_SHA, "version_code": 4, "version_name": "old"}
        after = {"sha256": "d" * 64, "version_code": 5, "version_name": "other"}
        output = io.StringIO()
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device"),
              patch.object(install, "installed_apk", side_effect=[before, after]),
              patch.object(install, "save_report", side_effect=["preflight.json", "result.json"]),
              patch.object(device, "adb_call", return_value="Success"), contextlib.redirect_stdout(output)):
            self.assertEqual(install.install(args("--owner-approved", "--approval-id", "OWNER-123")), 1)
        result = json.loads(output.getvalue())
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["mutation_attempted"])

    def test_timeout_is_unknown_and_never_retried(self) -> None:
        before = {"sha256": OLD_SHA, "version_code": 4, "version_name": "old"}
        output = io.StringIO()
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device"),
              patch.object(install, "installed_apk", return_value=before),
              patch.object(install, "save_report", side_effect=["preflight.json", "result.json"]),
              patch.object(device, "adb_call", side_effect=device.DeviceQaUnknown("ADB_TIMEOUT")) as adb,
              contextlib.redirect_stdout(output)):
            self.assertEqual(install.install(args("--owner-approved", "--approval-id", "OWNER-123")), 2)
        adb.assert_called_once()
        result = json.loads(output.getvalue())
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertTrue(result["mutation_attempted"])

    def test_report_failure_prevents_install(self) -> None:
        before = {"sha256": OLD_SHA, "version_code": 4, "version_name": "old"}
        output = io.StringIO()
        with (patch.object(artifact, "verified_cached_build", side_effect=candidate),
              patch.object(device, "phone_lock", side_effect=contextlib.nullcontext),
              patch.object(device, "connected_serial", return_value="approved-device"),
              patch.object(install, "installed_apk", return_value=before),
              patch.object(install, "save_report", side_effect=OSError("disk unavailable")),
              patch.object(device, "adb_call") as adb, contextlib.redirect_stdout(output)):
            self.assertEqual(install.install(args("--owner-approved", "--approval-id", "OWNER-123")), 2)
        adb.assert_not_called()
        self.assertEqual(json.loads(output.getvalue())["status"], "UNKNOWN")

    def test_real_report_is_private_and_never_overwrites(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.object(artifact, "ROOT", root), patch.object(artifact, "CACHE_ROOT", root / ".runtime/artifacts"):
                first = Path(install.save_report({"status": "UNKNOWN"}))
                second = Path(install.save_report({"status": "PASS"}))
            self.assertNotEqual(first, second)
            self.assertEqual(first.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(first.read_text())["status"], "UNKNOWN")


if __name__ == "__main__":
    unittest.main()

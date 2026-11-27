import os
import sys
import tempfile
import unittest
from contextlib import contextmanager, nullcontext
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_capture_run as run


class CaptureRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.pin = Path(self.temp.name)
        self.grant = {"runId": "123", "commit": "a"*40, "apkSha256": "b"*64}

    @contextmanager
    def verified(self, *args):
        yield (Path("/fake.apk"), {})

    def invoke(self, installed=None):
        installed = {"sha256": "b"*64} if installed is None else installed
        with (patch.dict(os.environ, {"LS_POLICY_SNAPSHOT": str(self.pin)}),
              patch.object(run, "current_grant", return_value=self.grant),
              patch.object(run.artifact, "verified_cached_build", side_effect=self.verified),
              patch.object(run.device, "phone_lock", return_value=nullcontext()),
              patch.object(run.device, "connected_serial", return_value="phone"),
              patch.object(run.device, "validate_device"),
              patch.object(run.install, "installed_apk", return_value=installed),
              patch.object(run.session_capture, "capture_restore_locked",
                           return_value={"status": "PASS"}) as capture):
            result = run.execute()
            return result, capture.call_count

    def test_grant_is_consumed_once_before_capture(self):
        result, calls = self.invoke()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(calls, 1)
        self.assertTrue((self.pin / "CAPTURE_CONSUMED").exists())
        with self.assertRaises(FileExistsError):
            self.invoke()

    def test_wrong_installed_apk_prevents_capture(self):
        with self.assertRaises(run.device.DeviceQaFailure):
            self.invoke({"sha256": "c"*64})
        self.assertFalse((self.pin / "CAPTURE_CONSUMED").exists())

    def test_missing_grant_refuses_action(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                run.execute()


if __name__ == "__main__":
    unittest.main()

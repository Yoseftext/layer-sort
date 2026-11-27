import sys
import tempfile
import unittest
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_observe as observer
import session_plan as plans


class ObserveTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 27, 12, tzinfo=timezone.utc)
        self.plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1",
            "source_commit": "a"*40, "run_id": "123", "apk_sha256": "b"*64,
            "installed_sha256": "b"*64, "package_id": plans.PACKAGE,
            "device": dict(plans.DEVICE),
            "expires_at": (self.now + timedelta(minutes=30)).isoformat(),
            "operations": [{"action": "launch"}]}
        self.events = []
        self.installed = {"sha256": "b"*64}
        self.screen = (720, 1600)

    @contextmanager
    def verified(self, *args):
        self.events.append(("verify", args))
        yield (Path("/verified.apk"), {})

    @contextmanager
    def locked(self):
        self.events.append("lock")
        try:
            yield
        finally:
            self.events.append("unlock")

    def collect(self):
        def installed(serial, destination):
            self.assertIn("lock", self.events)
            self.assertNotIn("unlock", self.events)
            return self.installed
        with (patch.object(observer.artifact, "verified_cached_build", side_effect=self.verified),
              patch.object(observer.device, "phone_lock", side_effect=self.locked),
              patch.object(observer.device, "connected_serial", return_value="phone") as select,
              patch.object(observer.device, "validate_device", return_value=dict(plans.DEVICE)),
              patch.object(observer.install, "installed_apk", side_effect=installed),
              patch.object(observer.device, "screen_size", return_value=self.screen)):
            result = observer.observe(self.plan, self.now)
            select.assert_called_once_with(require_installed=False)
            return result

    def test_verified_build_and_locked_device_are_observed(self):
        result = self.collect()
        self.assertEqual(result["installed_sha256"], self.plan["installed_sha256"])
        self.assertEqual(self.events[0], ("verify", ("123", "a"*40, "b"*64)))
        self.assertEqual(self.events[1:], ["lock", "unlock"])

    def test_wrong_installed_hash_rejected(self):
        self.installed = {"sha256": "c"*64}
        with self.assertRaises(plans.PlanError):
            self.collect()
        self.assertEqual(self.events[-1], "unlock")

    def test_missing_game_rejected(self):
        self.installed = None
        with self.assertRaises(observer.device.DeviceQaFailure):
            self.collect()
        self.assertEqual(self.events[-1], "unlock")

    def test_wrong_display_rejected(self):
        self.screen = (1080, 2400)
        with self.assertRaises(plans.PlanError):
            self.collect()

    def test_expired_plan_does_not_contact_build_or_device(self):
        self.plan["expires_at"] = self.now.isoformat()
        with self.assertRaises(plans.PlanError):
            self.collect()
        self.assertEqual(self.events, [])


if __name__ == "__main__":
    unittest.main()

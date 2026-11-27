import sys
import tempfile
import unittest
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_dispatch
import session_locked
import session_plan
import session_sequence


class IntegrationTests(unittest.TestCase):
    def test_broker_dispatches_reviewed_tap_under_one_lock(self):
        now = datetime(2026, 11, 27, 12, tzinfo=timezone.utc)
        plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1",
            "source_commit": "a"*40, "run_id": "123", "apk_sha256": "b"*64,
            "installed_sha256": "b"*64, "package_id": session_plan.PACKAGE,
            "device": dict(session_plan.DEVICE),
            "expires_at": (now + timedelta(minutes=30)).isoformat(),
            "operations": [{"action": "tap", "x": 24, "y": 123}]}
        evidence = {k: plan[k] for k in ("source_commit", "run_id", "apk_sha256",
                    "installed_sha256", "package_id", "device")}
        evidence.update(status="PASS", width=720, height=1600)
        in_lock = []
        @contextmanager
        def lock():
            in_lock.append(True)
            try:
                yield
            finally:
                in_lock.pop()
        @contextmanager
        def verify(*args):
            yield (Path("/fake.apk"), {})
        def observe(*args):
            self.assertEqual(in_lock, [True])
            return dict(evidence)
        def adb(serial, command, **kwargs):
            self.assertEqual(in_lock, [True])
            self.assertEqual(command, ["shell", "input", "tap", "24", "123"])
            return ""
        device = session_dispatch.device
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "state.sqlite"
            digest = session_plan.plan_hash(plan)
            session_sequence.create_state(db, plan, digest, now)
            with (patch.object(session_locked.artifact, "verified_cached_build", side_effect=verify),
                  patch.object(device, "phone_lock", side_effect=lock),
                  patch.object(session_locked.session_observe, "observe_locked", side_effect=observe),
                  patch.object(device, "connected_serial", return_value="phone"),
                  patch.object(device, "validate_device", return_value=dict(device.EXPECTED_DEVICE)),
                  patch.object(device, "ensure_game_installed"),
                  patch.object(device, "focused_package", return_value=device.PACKAGE_ID),
                  patch.object(device, "screen_size", return_value=(720, 1600)),
                  patch.object(device, "adb_call", side_effect=adb) as dispatched):
                result = session_locked.run_locked_step(db, plan, digest, 0,
                    plan["operations"][0], session_dispatch.dispatch_locked, now)
                self.assertEqual(result["status"], "PASS")
                self.assertEqual(dispatched.call_count, 1)
                with self.assertRaises(session_sequence.SequenceError):
                    session_locked.run_locked_step(db, plan, digest, 0,
                        plan["operations"][0], session_dispatch.dispatch_locked, now)
                self.assertEqual(dispatched.call_count, 1)
        self.assertEqual(in_lock, [])


if __name__ == "__main__":
    unittest.main()

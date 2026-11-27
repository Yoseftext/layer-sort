import sys
import tempfile
import unittest
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_locked as locked
import session_plan as plans
import session_sequence as sequence


class LockedTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = Path(self.tmp.name) / "session.sqlite"
        self.now = datetime(2026, 11, 27, 12, tzinfo=timezone.utc)
        self.plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1",
            "source_commit": "a"*40, "run_id": "123", "apk_sha256": "b"*64,
            "installed_sha256": "b"*64, "package_id": plans.PACKAGE,
            "device": dict(plans.DEVICE),
            "expires_at": (self.now + timedelta(minutes=30)).isoformat(),
            "operations": [{"action": "launch"}]}
        self.digest = plans.plan_hash(self.plan)
        self.evidence = {k: self.plan[k] for k in ("source_commit", "run_id",
            "apk_sha256", "installed_sha256", "package_id", "device")}
        self.evidence.update(status="PASS", width=720, height=1600)
        self.events = []
        sequence.create_state(self.db, self.plan, self.digest, self.now)

    @contextmanager
    def verified(self, *args):
        self.events.append("verify")
        try:
            yield (Path("/fake.apk"), {})
        finally:
            self.events.append("unverify")

    @contextmanager
    def phone_lock(self):
        self.events.append("lock")
        try:
            yield
        finally:
            self.events.append("unlock")

    def run_step(self, observe=None, dispatch=None):
        def observe_default(*args):
            self.events.append("observe")
            return dict(self.evidence)
        def dispatch_default(action):
            self.events.append("dispatch")
            return {"status": "PASS", "action": action["action"]}
        with (patch.object(locked.artifact, "verified_cached_build", side_effect=self.verified),
              patch.object(locked.device, "phone_lock", side_effect=self.phone_lock),
              patch.object(locked.session_observe, "observe_locked", side_effect=observe or observe_default)):
            return locked.run_locked_step(self.db, self.plan, self.digest, 0,
                self.plan["operations"][0], dispatch or dispatch_default, self.now)

    def test_lock_and_verified_build_cover_both_observations_and_dispatch(self):
        self.run_step()
        self.assertEqual(self.events, ["verify", "lock", "observe", "observe",
                                       "dispatch", "unlock", "unverify"])

    def test_observation_failure_after_claim_blocks_and_releases_lock(self):
        calls = []
        def observe(*args):
            calls.append(True)
            if len(calls) == 2:
                raise RuntimeError("device lost")
            return dict(self.evidence)
        with self.assertRaises(RuntimeError):
            self.run_step(observe=observe)
        self.assertEqual(self.events[-2:], ["unlock", "unverify"])
        with self.assertRaises(sequence.SequenceError):
            self.run_step()

    def test_dispatch_timeout_blocks_retry_and_releases_lock(self):
        def dispatch(_):
            self.events.append("dispatch")
            raise TimeoutError("unknown outcome")
        with self.assertRaises(TimeoutError):
            self.run_step(dispatch=dispatch)
        self.assertEqual(self.events[-3:], ["dispatch", "unlock", "unverify"])
        with self.assertRaises(sequence.SequenceError):
            self.run_step()

    def test_expired_plan_never_contacts_build_or_phone(self):
        self.plan["expires_at"] = self.now.isoformat()
        with self.assertRaises(plans.PlanError):
            self.run_step()
        self.assertEqual(self.events, [])


if __name__ == "__main__":
    unittest.main()

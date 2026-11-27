from __future__ import annotations

import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_plan as planlib
import session_sequence as seq


class SequenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / "state.sqlite"
        self.now = datetime(2026, 11, 26, 12, 0, tzinfo=timezone.utc)
        self.plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1", "source_commit": "a"*40,
                     "run_id": "123", "apk_sha256": "b"*64, "installed_sha256": "b"*64,
                     "package_id": planlib.PACKAGE, "device": dict(planlib.DEVICE),
                     "expires_at": (self.now + timedelta(minutes=30)).isoformat(),
                     "operations": [{"action": "launch"}, {"action": "screenshot"}]}
        self.digest = planlib.plan_hash(self.plan)
        seq.create_state(self.db, self.plan, self.digest, self.now)

    def claim(self, index):
        seq.begin_step(self.db, self.plan, index, self.plan["operations"][index], self.digest, self.now)

    def test_must_run_in_order_and_cannot_replay(self):
        with self.assertRaises(seq.SequenceError):
            self.claim(1)
        self.claim(0)
        with self.assertRaises(seq.SequenceError):
            self.claim(0)
        seq.finish_step(self.db, 0, "PASS")
        with self.assertRaises(seq.SequenceError):
            self.claim(0)
        self.claim(1)
        seq.finish_step(self.db, 1, "PASS")

    def test_interrupted_and_unknown_step_remain_blocked(self):
        self.claim(0)
        with self.assertRaises(seq.SequenceError):
            self.claim(0)
        seq.finish_step(self.db, 0, "UNKNOWN")
        with self.assertRaises(seq.SequenceError):
            self.claim(0)

    def test_two_simultaneous_claims_allow_only_one(self):
        def attempt(_):
            try:
                self.claim(0)
                return "claimed"
            except seq.SequenceError:
                return "rejected"
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertCountEqual(list(pool.map(attempt, range(2))), ["claimed", "rejected"])

    def test_missing_state_is_not_silently_created(self):
        missing = self.db.parent / "missing.sqlite"
        with self.assertRaises(seq.SequenceError):
            seq.finish_step(missing, 0, "PASS")
        self.assertFalse(missing.exists())

    def test_state_cannot_be_reinitialized_and_digest_must_match(self):
        with self.assertRaises(FileExistsError):
            seq.create_state(self.db, self.plan, self.digest, self.now)
        with self.assertRaises(seq.SequenceError):
            seq.begin_step(self.db, self.plan, 0, self.plan["operations"][0], "c"*64, self.now)


if __name__ == "__main__":
    unittest.main()

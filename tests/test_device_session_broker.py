import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_broker as broker
import session_plan as plans
import session_sequence as seq


class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = Path(self.tmp.name) / "state.sqlite"
        self.now = datetime(2026, 11, 26, 12, tzinfo=timezone.utc)
        self.plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1",
            "source_commit": "a"*40, "run_id": "123", "apk_sha256": "b"*64,
            "installed_sha256": "b"*64, "package_id": plans.PACKAGE,
            "device": dict(plans.DEVICE),
            "expires_at": (self.now + timedelta(minutes=30)).isoformat(),
            "operations": [{"action": "launch"}, {"action": "tap", "x": 50, "y": 80}]}
        self.digest = plans.plan_hash(self.plan)
        self.evidence = {k: self.plan[k] for k in ("source_commit", "run_id", "apk_sha256", "installed_sha256", "package_id", "device")}
        self.evidence.update(status="PASS", width=720, height=1600)
        self.calls = []
        seq.create_state(self.db, self.plan, self.digest, self.now)

    def run_step(self, index=0, observe=None, dispatch=None, requested=None):
        def execute(action):
            self.calls.append(action)
            return {"status": "PASS", "action": action["action"]}
        return broker.run_step(self.db, self.plan, self.digest, index,
            requested if requested is not None else self.plan["operations"][index],
            observe or (lambda: dict(self.evidence)), dispatch or execute, self.now)

    def test_order_and_replay(self):
        self.run_step()
        with self.assertRaises(seq.SequenceError):
            self.run_step()
        self.run_step(1)
        self.assertEqual(self.calls, self.plan["operations"])

    def test_wrong_action_never_dispatches(self):
        with self.assertRaises(plans.PlanError):
            self.run_step(requested={"action": "tap", "x": 50, "y": 80})
        self.assertEqual(self.calls, [])

    def test_changed_evidence_after_claim_blocks(self):
        count = 0
        def observe():
            nonlocal count
            count += 1
            return dict(self.evidence, width=1 if count == 2 else 720)
        with self.assertRaises(plans.PlanError):
            self.run_step(observe=observe)
        with self.assertRaises(seq.SequenceError):
            self.run_step()
        self.assertEqual(self.calls, [])

    def test_unknown_result_cannot_advance(self):
        self.run_step(dispatch=lambda _: {"status": "UNKNOWN", "action": "launch"})
        with self.assertRaises(seq.SequenceError):
            self.run_step(1)

    def test_exception_after_dispatch_blocks_retry(self):
        def interrupted(action):
            self.calls.append(action)
            raise TimeoutError("outcome unknown")
        with self.assertRaises(TimeoutError):
            self.run_step(dispatch=interrupted)
        with self.assertRaises(seq.SequenceError):
            self.run_step()
        self.assertEqual(len(self.calls), 1)

    def test_wrong_result_action_blocks(self):
        with self.assertRaises(broker.BrokerError):
            self.run_step(dispatch=lambda _: {"status": "PASS", "action": "tap"})
        with self.assertRaises(seq.SequenceError):
            self.run_step()


if __name__ == "__main__":
    unittest.main()

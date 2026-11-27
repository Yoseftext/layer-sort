from __future__ import annotations

import copy
import importlib.util
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "tools/device-tests/session_plan.py"
spec = importlib.util.spec_from_file_location("session_plan", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class SessionPlanTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 26, 12, 0, tzinfo=timezone.utc)
        self.plan = {"schema_version": 1, "task_id": "LS-DEVICE-TEST-1", "source_commit": "a"*40,
                     "run_id": "123", "apk_sha256": "b"*64, "installed_sha256": "b"*64,
                     "package_id": module.PACKAGE, "device": dict(module.DEVICE),
                     "expires_at": (self.now + timedelta(minutes=30)).isoformat(),
                     "operations": [{"action": "launch"}, {"action": "tap", "x": 360, "y": 800},
                                    {"action": "screenshot"}]}

    def test_exact_reviewed_step_and_stable_hash(self):
        digest = module.plan_hash(self.plan)
        module.check_step(self.plan, 1, {"action": "tap", "x": 360, "y": 800}, digest, self.now)
        self.assertEqual(digest, module.plan_hash(copy.deepcopy(self.plan)))

    def test_changed_action_or_approval_hash_rejected(self):
        digest = module.plan_hash(self.plan)
        with self.assertRaises(module.PlanError):
            module.check_step(self.plan, 1, {"action": "tap", "x": 361, "y": 800}, digest, self.now)
        changed = copy.deepcopy(self.plan)
        changed["apk_sha256"] = "c"*64
        with self.assertRaises(module.PlanError):
            module.check_step(changed, 1, changed["operations"][1], digest, self.now)

    def test_boolean_cannot_match_integer_coordinate(self):
        self.plan["operations"][1]["x"] = 1
        digest = module.plan_hash(self.plan)
        with self.assertRaises(module.PlanError):
            module.check_step(self.plan, 1, {"action": "tap", "x": True, "y": 800}, digest, self.now)

    def test_verified_live_evidence_must_match_every_planned_identity(self):
        observed = {key: copy.deepcopy(self.plan[key]) for key in (
            "source_commit", "run_id", "apk_sha256", "installed_sha256", "package_id", "device")}
        observed.update(status="PASS", width=720, height=1600)
        module.check_preconditions(self.plan, observed, self.now)
        for change in ({"status": "UNKNOWN"}, {"installed_sha256": "c"*64},
                       {"run_id": "124"}, {"width": 1080},
                       {"device": dict(module.DEVICE, model="another")}):
            with self.subTest(change=change), self.assertRaises(module.PlanError):
                module.check_preconditions(self.plan, observed | change, self.now)
        incomplete = dict(observed)
        del incomplete["height"]
        with self.assertRaises(module.PlanError):
            module.check_preconditions(self.plan, incomplete, self.now)

    def test_expiry_and_device_mismatch_rejected(self):
        for change in ({"expires_at": (self.now - timedelta(seconds=1)).isoformat()},
                       {"expires_at": (self.now + timedelta(hours=3)).isoformat()},
                       {"package_id": "other.app"}, {"device": dict(module.DEVICE, model="other")}):
            with self.subTest(change=change), self.assertRaises(module.PlanError):
                module.validate(self.plan | change, self.now)

    def test_unsupported_and_unsafe_actions_rejected(self):
        for operation in ({"action": "install"}, {"action": "tap", "x": -1, "y": 2},
                          {"action": "tap", "x": True, "y": 2},
                          {"action": "launch", "extra": "anything"}):
            with self.subTest(operation=operation), self.assertRaises(module.PlanError):
                module.validate(self.plan | {"operations": [operation]}, self.now)

if __name__ == "__main__":
    unittest.main()

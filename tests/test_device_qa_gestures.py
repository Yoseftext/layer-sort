from __future__ import annotations

import importlib.util
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("gesture_plan", ROOT / "tools/device-tests/gesture_plan.py")
assert SPEC and SPEC.loader
planner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(planner)


class GesturePlanTests(unittest.TestCase):
    def test_rapid_taps_are_in_one_touch_source_with_bounded_duration(self) -> None:
        plan = planner.build_plan("rapid", "720x1600", "100,200:300,200:400,200:500,200")
        self.assertEqual(plan["planned_duration_ms"], 160)
        self.assertFalse(plan["device_contacted"])
        self.assertFalse(plan["input_executed"])
        sources = plan["w3c_request"]["actions"]
        self.assertEqual(len(sources), 1)
        self.assertEqual(sources[0]["parameters"], {"pointerType": "touch"})
        self.assertEqual(sum(action["type"] == "pointerDown" for action in sources[0]["actions"]), 4)
        self.assertEqual(sum(action["type"] == "pointerUp" for action in sources[0]["actions"]), 4)

    def test_simultaneous_touches_share_same_w3c_ticks(self) -> None:
        plan = planner.build_plan("simultaneous", "720x1600", "100,200:300,400")
        left, right = plan["w3c_request"]["actions"]
        self.assertNotEqual(left["id"], right["id"])
        self.assertEqual([item["type"] for item in left["actions"]],
                         [item["type"] for item in right["actions"]])
        self.assertEqual([item.get("duration", 0) for item in left["actions"]],
                         [item.get("duration", 0) for item in right["actions"]])
        self.assertEqual([item["type"] for item in left["actions"]],
                         ["pointerMove", "pointerDown", "pause", "pointerUp"])

    def test_drag_and_hold_are_bounded_and_release_touch(self) -> None:
        for mode, points, duration in (("drag", "1,2:30,40", 200), ("hold", "1,2", 600)):
            with self.subTest(mode=mode):
                plan = planner.build_plan(mode, "720x1600", points)
                self.assertEqual(plan["planned_duration_ms"], duration)
                self.assertEqual(plan["w3c_request"]["actions"][0]["actions"][-1]["type"], "pointerUp")

    def test_rejects_invalid_modes_out_of_bounds_points_and_unbounded_lists(self) -> None:
        for mode, size, points in (("execute", "720x1600", "1,2"), ("hold", "0x1600", "1,2"),
                                   ("hold", "9000x1600", "1,2"), ("hold", "720x1600", "720,2"),
                                   ("hold", "720x1600", "1,1600"), ("rapid", "720x1600", "1,2"),
                                   ("simultaneous", "720x1600", "1,2:3,4:5,6"),
                                   ("hold", "720x1600", "1,2;id"),
                                   ("rapid", "720x1600", ":".join(["1,2"] * 9))):
            with self.subTest(mode=mode, size=size, points=points), self.assertRaises(planner.PlanError):
                planner.build_plan(mode, size, points)

    def test_wrapper_returns_plan_only_and_never_needs_adb(self) -> None:
        cmd = [str(ROOT / "tools/device-tests/agentctl"), "plan-gesture", "simultaneous",
               "--size", "720x1600", "--points", "10,20:30,40"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertFalse(payload["device_contacted"])
        self.assertFalse(payload["input_executed"])
        self.assertIn("PLAN_ONLY", payload["evidence"])


if __name__ == "__main__":
    unittest.main()

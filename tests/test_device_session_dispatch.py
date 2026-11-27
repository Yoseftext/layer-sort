import contextlib
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_dispatch as dispatch


class DispatchTests(unittest.TestCase):
    def run_device(self, step, focus=None, adb=None):
        device = dispatch.device
        with (patch.object(device, "connected_serial", return_value="phone"),
              patch.object(device, "validate_device", return_value=dict(device.EXPECTED_DEVICE)),
              patch.object(device, "ensure_game_installed"),
              patch.object(device, "focused_package", side_effect=focus or [device.PACKAGE_ID]*2),
              patch.object(device, "screen_size", return_value=(720, 1600)),
              patch.object(device, "adb_call", side_effect=adb or (lambda *a, **k: "")) as call):
            result = dispatch.dispatch_locked(step)
            return result, call.call_args_list

    def test_tap_sends_only_reviewed_coordinates(self):
        result, calls = self.run_device({"action": "tap", "x": 24, "y": 123})
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(calls[0].args, ("phone", ["shell", "input", "tap", "24", "123"]))
        self.assertFalse(result["touch_accuracy_measured"])

    def test_different_foreground_skips_input(self):
        result, calls = self.run_device({"action": "tap", "x": 24, "y": 123}, focus=["another.app"])
        self.assertEqual(result["status"], "SKIP")
        self.assertEqual(calls, [])

    def test_foreground_change_before_dispatch_skips_input(self):
        device = dispatch.device
        result, calls = self.run_device({"action": "tap", "x": 24, "y": 123},
                                        focus=[device.PACKAGE_ID, "another.app"])
        self.assertEqual(result["status"], "SKIP")
        self.assertEqual(calls, [])

    def test_invalid_operations_are_rejected_without_device(self):
        for step in ({"action": "tap", "x": True, "y": 1},
                     {"action": "tap", "x": 720, "y": 1},
                     {"action": "tap", "x": 1, "y": 2, "extra": 3},
                     {"action": "stop"}, {"action": "install"}):
            with self.subTest(step=step), self.assertRaises(dispatch.DispatchError):
                dispatch.dispatch_locked(step)

    def test_launch_requires_verified_foreground(self):
        device = dispatch.device
        with (patch.object(device, "connected_serial", return_value="phone"),
              patch.object(device, "validate_device", return_value=dict(device.EXPECTED_DEVICE)),
              patch.object(device, "ensure_game_installed"),
              patch.object(device, "adb_call", return_value="") as call,
              patch.object(device, "wait_for_foreground", return_value=False)):
            result = dispatch.dispatch_locked({"action": "launch"})
        self.assertEqual(result["status"], "UNKNOWN")
        call.assert_called_once()

    def test_device_result_must_match_exit_code(self):
        def fake(*args, **kwargs):
            print(json.dumps({"status": "PASS", "action": "screenshot"}))
            return 3
        with patch.object(dispatch.device, "_execute_locked", side_effect=fake):
            with self.assertRaises(dispatch.DispatchError):
                dispatch.dispatch_locked({"action": "screenshot"})


if __name__ == "__main__":
    unittest.main()

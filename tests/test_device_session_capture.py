import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_capture as capture


class CaptureTests(unittest.TestCase):
    def test_unknown_foreground_never_launches(self):
        with (patch.object(capture, "focused_component", return_value=None),
              patch.object(capture.session_dispatch, "dispatch_locked") as dispatch):
            with self.assertRaises(capture.CaptureError):
                capture.capture_restore_locked("phone")
            dispatch.assert_not_called()

    def test_launch_capture_restore_once(self):
        original = "com.example.app/.MainActivity"
        def dispatch(step, **kwargs):
            return {"status": "PASS", "action": step["action"], "visible_export": {"status": "PASS"}}
        with (patch.object(capture, "focused_component", side_effect=[original, original]),
              patch.object(capture.session_dispatch, "dispatch_locked", side_effect=dispatch) as run,
              patch.object(capture.device, "adb_call", return_value="") as adb):
            result = capture.capture_restore_locked("phone")
        self.assertEqual(result["status"], "PASS")
        self.assertFalse(result["same_screen_contents_verified"])
        self.assertEqual([c.args[0]["action"] for c in run.call_args_list], ["launch", "screenshot"])
        adb.assert_called_once_with("phone", ["shell", "am", "start",
            "--activity-reorder-to-front", "-n", original], timeout=15.0)

    def test_launch_timeout_still_attempts_restore(self):
        original = "com.example.app/.MainActivity"
        with (patch.object(capture, "focused_component", side_effect=[original, original]),
              patch.object(capture.session_dispatch, "dispatch_locked", side_effect=TimeoutError),
              patch.object(capture.device, "adb_call", return_value="") as adb):
            result = capture.capture_restore_locked("phone")
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["restore_activity"], "PASS")
        adb.assert_called_once()

    def test_restore_failure_is_unknown_even_when_capture_passes(self):
        original = "com.example.app/.MainActivity"
        with (patch.object(capture, "focused_component", return_value=original),
              patch.object(capture.session_dispatch, "dispatch_locked",
                side_effect=lambda step, **kwargs: {"status": "PASS", "action": step["action"], "visible_export": {"status": "PASS"}}),
              patch.object(capture.device, "adb_call", side_effect=TimeoutError)):
            result = capture.capture_restore_locked("phone")
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["restore_activity"], "UNKNOWN")

    def test_game_already_foreground_does_not_launch_or_restore(self):
        original = capture.device.PACKAGE_ID + "/.MainActivity"
        with (patch.object(capture, "focused_component", return_value=original),
              patch.object(capture.session_dispatch, "dispatch_locked",
                return_value={"status": "PASS", "action": "screenshot", "visible_export": {"status": "PASS"}}) as dispatch,
              patch.object(capture.device, "adb_call") as adb):
            result = capture.capture_restore_locked("phone")
        self.assertEqual(result["status"], "PASS")
        dispatch.assert_called_once_with({"action": "screenshot"}, expected_serial="phone")
        adb.assert_not_called()

    def test_parsing_does_not_accept_arbitrary_shell_text(self):
        with patch.object(capture.device, "shell_text", return_value="mCurrentFocus=Window{a u0 com.example.app/.MainActivity}"):
            self.assertEqual(capture.focused_component("phone"), "com.example.app/.MainActivity")
        with patch.object(capture.device, "shell_text", return_value="mCurrentFocus=null"):
            self.assertIsNone(capture.focused_component("phone"))


if __name__ == "__main__":
    unittest.main()

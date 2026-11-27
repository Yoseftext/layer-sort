import sys
import tempfile
import unittest
from contextlib import contextmanager, nullcontext
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import session_play as play


class PlayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.pin = Path(self.temp.name)
        self.cap = {"runId": "123", "commit": "a"*40, "apkSha256": "b"*64}
        self.origin = "com.example.app/.MainActivity"
        self.game = play.device.PACKAGE_ID + "/.Main"
        self.focus = self.origin
        self.calls = []
        self.locked = False

    @contextmanager
    def verify(self, *args):
        yield (Path("/fake.apk"), {})

    @contextmanager
    def phone_lock(self):
        self.assertFalse(self.locked)
        self.locked = True
        try:
            yield
        finally:
            self.locked = False

    def dispatcher(self, step, **kwargs):
        self.assertTrue(self.locked)
        self.calls.append(step)
        if step["action"] == "launch":
            self.focus = self.game
        return {"status": "PASS", "action": step["action"],
                "visible_export": {"status": "PASS"}}

    def adb(self, serial, command, **kwargs):
        self.assertTrue(self.locked)
        self.focus = self.origin
        return ""

    def patches(self):
        return (patch.object(play.artifact, "verified_cached_build", side_effect=self.verify),
                patch.object(play.device, "phone_lock", side_effect=self.phone_lock),
                patch.object(play.device, "connected_serial", return_value="phone"),
                patch.object(play.device, "validate_device"),
                patch.object(play.device, "screen_size", return_value=(720,1600)),
                patch.object(play.device, "focused_package", side_effect=lambda s: self.focus.split("/")[0]),
                patch.object(play.device, "adb_call", side_effect=self.adb),
                patch.object(play.install, "installed_apk", return_value={"sha256":"b"*64}),
                patch.object(play, "grant", return_value=self.cap),
                patch.object(play.session_capture, "focused_component", side_effect=lambda s: self.focus),
                patch.object(play.session_dispatch, "dispatch_locked", side_effect=self.dispatcher))

    def test_full_session_dispatches_and_restores(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for p in self.patches(): stack.enter_context(p)
            self.assertEqual(play.open_game(self.pin,self.cap)["status"],"PASS")
            self.assertEqual(play.capture(self.pin,self.cap)["status"],"PASS")
            self.assertEqual(play.tap(self.pin,self.cap,24,123)["status"],"PASS")
            self.assertEqual(play.finish(self.pin,self.cap)["restore_activity"],"PASS")
            self.assertEqual(self.focus,self.origin)
            self.assertEqual([c["action"] for c in self.calls],["launch","screenshot","tap"])
            with self.assertRaises(play.PlayError): play.tap(self.pin,self.cap,24,123)

    def test_interrupted_tap_blocks_next_but_finish_restores(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for p in self.patches(): stack.enter_context(p)
            play.open_game(self.pin,self.cap)
            with patch.object(play.session_dispatch, "dispatch_locked", side_effect=TimeoutError):
                with self.assertRaises(TimeoutError): play.tap(self.pin,self.cap,24,123)
            with self.assertRaises(play.PlayError): play.tap(self.pin,self.cap,24,123)
            self.assertEqual(play.finish(self.pin,self.cap)["restore_activity"],"PASS")

    def test_does_not_steal_foreground_if_user_switched(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for p in self.patches(): stack.enter_context(p)
            play.open_game(self.pin,self.cap)
            self.focus="com.example.other/.Main"
            self.assertEqual(play.finish(self.pin,self.cap)["status"],"UNKNOWN")
            self.assertEqual(self.focus,"com.example.other/.Main")

    def test_incorrect_apk_never_launches(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for p in self.patches(): stack.enter_context(p)
            with patch.object(play.install, "installed_apk", return_value={"sha256":"c"*64}):
                with self.assertRaises(play.PlayError): play.open_game(self.pin,self.cap)
            self.assertFalse(self.calls)

    def test_second_open_does_not_launch_again(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for p in self.patches(): stack.enter_context(p)
            play.open_game(self.pin,self.cap)
            with self.assertRaises(FileExistsError): play.open_game(self.pin,self.cap)
            self.assertEqual(len(self.calls),1)


if __name__ == "__main__":
    unittest.main()

"""Internal game capture with a best-effort return to the prior activity.

Caller must independently establish authorization and hold the phone lock.
There is deliberately no CLI or Antigravity permission in this module yet.
Same-user code can bypass application-level controls.
"""
from __future__ import annotations

import re
import time
from typing import Any

import device_qa as device
import session_dispatch


class CaptureError(ValueError):
    pass


# Accept Android component syntax only: never interpolate arbitrary shell text.
COMPONENT = re.compile(r"([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)/([A-Za-z0-9_.$]+)")


def focused_component(serial: str) -> str | None:
    output = device.shell_text(serial, "dumpsys", "window")
    for line in output.splitlines():
        if "mCurrentFocus=" in line:
            match = COMPONENT.search(line)
            if match:
                return match.group(0)
    return None


def capture_restore_locked(serial: str) -> dict[str, Any]:
    """Capture game and attempt to restore prior activity while lock is held.

    Restoring an activity cannot guarantee identical UI, keyboard or scroll state.
    A lost process after launch can prevent cleanup; caller must report UNKNOWN.
    """
    original = focused_component(serial)
    if not original or not COMPONENT.fullmatch(original):
        raise CaptureError("Current foreground activity cannot be identified")
    original_package = original.split("/", 1)[0]
    if original_package == "com.android.systemui":
        raise CaptureError("System UI is foreground; original app cannot be restored safely")
    already_game = original_package == device.PACKAGE_ID
    launch_attempted = False
    capture: dict[str, Any] | None = None
    error: str | None = None
    restore = "NOT_NEEDED" if already_game else "UNKNOWN"
    try:
        if not already_game:
            # Set before dispatch; a timeout can still have launched the game.
            launch_attempted = True
            launched = session_dispatch.dispatch_locked({"action": "launch"}, expected_serial=serial)
            if launched.get("status") != "PASS":
                error = "Game launch did not confirm foreground"
        if error is None:
            capture = session_dispatch.dispatch_locked({"action": "screenshot"}, expected_serial=serial)
            if capture.get("status") != "PASS" or capture.get("visible_export", {}).get("status") != "PASS":
                error = "Game screenshot or visible export was not confirmed"
    except Exception as exc:
        error = type(exc).__name__
    finally:
        if launch_attempted:
            try:
                device.adb_call(serial, ["shell", "am", "start",
                    "--activity-reorder-to-front", "-n", original], timeout=15.0)
                deadline = time.monotonic() + 5.0
                while time.monotonic() < deadline:
                    if focused_component(serial) == original:
                        restore = "PASS"
                        break
                    time.sleep(0.25)
            except Exception:
                restore = "UNKNOWN"
    status = "PASS" if error is None and restore in {"PASS", "NOT_NEEDED"} else "UNKNOWN"
    return {"status": status, "action": "capture-restore", "capture": capture,
            "restore_activity": restore, "same_screen_contents_verified": False,
            "error": error}

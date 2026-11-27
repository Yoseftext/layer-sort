#!/usr/bin/env python3
"""Interactive agent gameplay, scoped to a prepared Layer Sort session.

This is cooperative application policy, not OS isolation. An interrupted
input is UNKNOWN and is never automatically repeated. The previous Android
activity is restored best-effort; its internal visual state is not verified.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import artifact_qa as artifact
import device_qa as device
import install_qa as install
import session_capture
import session_dispatch

ROOT = Path(__file__).resolve().parents[2]
MAX_TAPS = 60


class PlayError(ValueError):
    pass


def grant(pin: Path) -> dict[str, str]:
    node = shutil.which("node")
    if not node:
        raise PlayError("Node is unavailable")
    result = subprocess.run([node, str(ROOT / "tools/agent-guard/runtime-config.mjs"),
                             "play-grant", str(pin), str(ROOT)],
                            capture_output=True, text=True, timeout=20, check=False)
    if result.returncode != 0:
        raise PlayError("Play session grant is missing, expired or revoked")
    cap = json.loads(result.stdout)
    if set(cap) != {"runId", "commit", "apkSha256"}:
        raise PlayError("Invalid play session grant")
    return cap


def write_state(pin: Path, state: dict[str, Any], *, create: bool = False) -> None:
    target = pin / "GAME_SESSION.json"
    if create:
        with target.open("x", encoding="utf-8") as out:
            json.dump(state, out, sort_keys=True)
            out.flush()
            os.fsync(out.fileno())
        return
    fd, name = tempfile.mkstemp(prefix="game-state-", dir=pin)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            json.dump(state, out, sort_keys=True)
            out.flush()
            os.fsync(out.fileno())
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_state(pin: Path, cap: dict[str, str]) -> dict[str, Any]:
    path = pin / "GAME_SESSION.json"
    if path.is_symlink() or not path.is_file():
        raise PlayError("Game session is not open")
    state = json.loads(path.read_text(encoding="utf-8"))
    if (state.get("cap") != cap or not isinstance(state.get("origin"), str) or
            not session_capture.COMPONENT.fullmatch(state["origin"]) or
            not isinstance(state.get("serial"), str) or not state["serial"] or
            state.get("phase") not in {"STARTING", "OPEN", "BLOCKED", "CLOSED", "CLOSED_UNKNOWN"} or
            type(state.get("tap_count")) is not int or not 0 <= state["tap_count"] <= MAX_TAPS or
            type(state.get("inflight")) is not bool):
        raise PlayError("Game session data do not match the grant")
    return state


def open_game(pin: Path, cap: dict[str, str]) -> dict[str, Any]:
    with artifact.verified_cached_build(cap["runId"], cap["commit"], cap["apkSha256"]):
        with device.phone_lock(), tempfile.TemporaryDirectory(prefix="layer-sort-play-") as tmp:
            serial = device.connected_serial(require_installed=False)
            device.validate_device(serial)
            info = install.installed_apk(serial, Path(tmp) / "installed.apk")
            if info is None or info["sha256"] != cap["apkSha256"]:
                raise PlayError("Installed game differs from the requested build")
            if device.screen_size(serial) != (720, 1600):
                raise PlayError("Screen dimensions changed")
            if grant(pin) != cap:
                raise PlayError("Play grant changed")
            origin = session_capture.focused_component(serial)
            if not origin or not session_capture.COMPONENT.fullmatch(origin) or origin.startswith("com.android.systemui/"):
                raise PlayError("Previous foreground activity cannot be restored reliably")
            state = {"cap": cap, "serial": serial, "origin": origin, "phase": "STARTING",
                     "tap_count": 0, "inflight": True}
            write_state(pin, state, create=True)
            try:
                result = ({"status": "PASS"} if origin.split("/", 1)[0] == device.PACKAGE_ID else
                          session_dispatch.dispatch_locked({"action": "launch"}, expected_serial=serial))
                state["phase"] = "OPEN" if result["status"] == "PASS" else "BLOCKED"
                state["inflight"] = False
                write_state(pin, state)
                return {"action": "game-open", "status": result["status"],
                        "game_ready_verified": False}
            except Exception:
                state["phase"] = "BLOCKED"
                write_state(pin, state)
                raise


def current_device(state: dict[str, Any]) -> str:
    serial = device.connected_serial(require_installed=False)
    if serial != state["serial"]:
        raise PlayError("Device connection changed")
    device.validate_device(serial)
    return serial


def capture(pin: Path, cap: dict[str, str]) -> dict[str, Any]:
    with device.phone_lock():
        state = read_state(pin, cap)
        if state["phase"] != "OPEN" or state["inflight"]:
            raise PlayError("Session cannot capture in its current state")
        serial = current_device(state)
        if grant(pin) != cap:
            raise PlayError("Play grant changed")
        result = session_dispatch.dispatch_locked({"action": "screenshot"}, expected_serial=serial)
        return {"action": "game-capture", "status": result["status"], "capture": result}


def tap(pin: Path, cap: dict[str, str], x: int, y: int) -> dict[str, Any]:
    if type(x) is not int or type(y) is not int or not (0 <= x < 720 and 0 <= y < 1600):
        raise PlayError("Invalid tap coordinates")
    with device.phone_lock():
        state = read_state(pin, cap)
        if state["phase"] != "OPEN" or state["inflight"] or state["tap_count"] >= MAX_TAPS:
            raise PlayError("Session is blocked or its input limit was reached")
        serial = current_device(state)
        if grant(pin) != cap:
            raise PlayError("Play grant changed")
        if device.screen_size(serial) != (720, 1600):
            raise PlayError("Screen dimensions changed")
        if device.focused_package(serial) != device.PACKAGE_ID:
            raise PlayError("Layer Sort is not in foreground")
        # Persist before input; a crash or timeout blocks further input.
        state["inflight"] = True
        state["tap_count"] += 1
        write_state(pin, state)
        try:
            result = session_dispatch.dispatch_locked({"action": "tap", "x": x, "y": y}, expected_serial=serial)
            state["inflight"] = False
            if result["status"] != "PASS":
                state["phase"] = "BLOCKED"
            write_state(pin, state)
            return {"action": "game-tap", "status": result["status"], "tap_count": state["tap_count"],
                    "input_dispatched": result["status"] == "PASS", "game_response_verified": False}
        except Exception:
            state["phase"] = "BLOCKED"
            write_state(pin, state)
            raise


def move(pin: Path, cap: dict[str, str], x1: int, y1: int, x2: int, y2: int) -> dict[str, Any]:
    """Dispatch one source/destination pair under one lock; verify game state separately."""
    coords = (x1, y1, x2, y2)
    if any(type(n) is not int for n in coords) or not (0 <= x1 < 720 and 0 <= x2 < 720 and 0 <= y1 < 1600 and 0 <= y2 < 1600):
        raise PlayError("Invalid move coordinates")
    with device.phone_lock():
        state = read_state(pin, cap)
        if state["phase"] != "OPEN" or state["inflight"] or state["tap_count"] + 2 > MAX_TAPS:
            raise PlayError("Session is blocked or its input limit was reached")
        serial = current_device(state)
        if grant(pin) != cap or device.screen_size(serial) != (720, 1600) or device.focused_package(serial) != device.PACKAGE_ID:
            raise PlayError("Play session or foreground changed")
        state["inflight"] = True
        state["tap_count"] += 2
        write_state(pin, state)
        try:
            first = session_dispatch.dispatch_locked({"action":"tap","x":x1,"y":y1}, expected_serial=serial)
            if first["status"] != "PASS":
                state["phase"] = "BLOCKED"
                write_state(pin, state)
                return {"action":"game-move","status":"UNKNOWN","reason":"Source tap not confirmed; do not retry"}
            second = session_dispatch.dispatch_locked({"action":"tap","x":x2,"y":y2}, expected_serial=serial)
            if second["status"] != "PASS":
                state["phase"] = "BLOCKED"
                write_state(pin, state)
                return {"action":"game-move","status":"UNKNOWN","reason":"Destination tap not confirmed; do not retry"}
            state["inflight"] = False
            write_state(pin, state)
            return {"action":"game-move","status":"PASS","tap_count":state["tap_count"],
                    "input_dispatched":True,"game_response_verified":False}
        except Exception:
            state["phase"] = "BLOCKED"
            write_state(pin, state)
            raise


def finish(pin: Path, cap: dict[str, str]) -> dict[str, Any]:
    with device.phone_lock():
        state = read_state(pin, cap)
        if state["phase"] in {"CLOSED", "CLOSED_UNKNOWN"}:
            return {"action": "game-finish", "status": "PASS" if state["phase"] == "CLOSED" else "UNKNOWN",
                    "restore_activity": state.get("restore", "UNKNOWN"), "already_finished": True,
                    "same_screen_contents_verified": False}
        serial = current_device(state)
        origin = state["origin"]
        current = session_capture.focused_component(serial)
        if current == origin:
            restored = "PASS"
        elif origin.split("/", 1)[0] == device.PACKAGE_ID:
            restored = "NOT_NEEDED" if current and current.split("/", 1)[0] == device.PACKAGE_ID else "UNKNOWN"
        elif current and current.split("/", 1)[0] == device.PACKAGE_ID:
            restored = "UNKNOWN"
            try:
                device.adb_call(serial, ["shell", "am", "start", "--activity-reorder-to-front",
                                         "-n", origin], timeout=15.0)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if session_capture.focused_component(serial) == origin:
                        restored = "PASS"
                        break
                    time.sleep(0.25)
            except Exception:
                pass
        else:
            # The user has moved elsewhere. Do not take over their current screen.
            restored = "UNKNOWN"
        state["restore"] = restored
        state["phase"] = "CLOSED" if restored in {"PASS", "NOT_NEEDED"} else "CLOSED_UNKNOWN"
        write_state(pin, state)
        return {"action": "game-finish", "status": "PASS" if state["phase"] == "CLOSED" else "UNKNOWN",
                "restore_activity": restored, "tap_count": state["tap_count"],
                "input_outcome_unknown": state["inflight"],
                "same_screen_contents_verified": False}


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    action = args[0] if args else ""
    try:
        pin_raw = os.environ.get("LS_POLICY_SNAPSHOT")
        if not pin_raw:
            raise PlayError("A prepared Antigravity session is required")
        pin = Path(pin_raw)
        cap = grant(pin)
        if action == "game-open" and len(args) == 1:
            result = open_game(pin, cap)
        elif action == "game-capture" and len(args) == 1:
            result = capture(pin, cap)
        elif action == "game-tap" and len(args) == 3 and re.fullmatch(r"0|[1-9][0-9]{0,2}", args[1]) and re.fullmatch(r"0|[1-9][0-9]{0,3}", args[2]):
            result = tap(pin, cap, int(args[1]), int(args[2]))
        elif action == "game-move" and len(args) == 5 and all(re.fullmatch(r"0|[1-9][0-9]{0,3}", v) for v in args[1:]):
            result = move(pin, cap, *(int(v) for v in args[1:]))
        elif action in {"game-finish", "game-cleanup"} and len(args) == 1:
            if action == "game-cleanup" and not (pin / "GAME_SESSION.json").exists():
                result = {"action": action, "status": "PASS", "reason": "No session started"}
            else:
                result = finish(pin, cap)
        else:
            raise PlayError("Unsupported game operation")
    except Exception as error:
        result = {"action": action, "status": "UNKNOWN", "reason": str(error)}
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())

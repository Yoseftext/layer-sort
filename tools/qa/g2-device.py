#!/usr/bin/env python3
"""One bounded G2 Appium attempt. Invoke ONLY via `agentctl phone` (shared lock).

No retry and no non-project package action. Evidence stays in an untracked
private run directory; an external overlay is UNVERIFIED, never a device PASS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from appium import webdriver
from PIL import Image, ImageChops

sys.path.insert(0, "/root/device-tests")
import device_common as dc  # existing, owner-approved Appium options and ADB

PACKAGE = "com.yoseftext.layersort.dev"
SOLUTION = [(0, 3), (2, 0), (1, 2), (1, 3), (0, 1), (2, 0), (2, 3), (1, 2), (0, 1), (0, 3)]


class Interrupted(Exception):
    pass


def adb(*args: str) -> str:
    p = subprocess.run(["adb", *args], text=True, capture_output=True, timeout=30, check=False)
    if p.returncode:
        raise RuntimeError(f"adb {args[:2]} exit={p.returncode}")
    return p.stdout


def log(pid: str) -> str:
    return adb("logcat", "-d", "--pid=" + pid, "-v", "threadtime")


def check_focus(driver: webdriver.Remote) -> None:
    # Appium package alone does not detect incoming-call overlays.
    if driver.current_package != PACKAGE or str(driver.orientation).upper() != "PORTRAIT":
        raise Interrupted("external focus or orientation interruption")
    window = adb("shell", "dumpsys", "window", "displays")
    focus = next((line.strip() for line in window.splitlines() if "mCurrentFocus=" in line), "")
    if not focus or PACKAGE not in focus:
        raise Interrupted("external overlay or unknown focused window; raw title redacted")


def marker(pid: str, expected: str, previous: int, out: Path, seconds: float = 8) -> int:
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        captured = log(pid)
        amount = captured.count(expected)
        if amount > previous:
            hits = [line for line in captured.splitlines() if expected in line]
            with (out / "markers.log").open("a") as evidence:
                evidence.write(hits[-1] + "\n")
            return amount
        time.sleep(0.4)
    raise RuntimeError(f"missing logcat marker {expected} after {seconds}s")


def board_difference(out: Path, a: str, b: str) -> int:
    with Image.open(out / (a + ".png")) as left, Image.open(out / (b + ".png")) as right:
        if left.size != right.size:
            raise RuntimeError("screenshots have different sizes")
        total = 0
        # Centre strips of five tube interiors; excludes selection borders/text.
        for index in range(5):
            x = int((left.width - 548) / 2 + 50 + 112 * index)
            area = (x - 15, 610, x + 15, 980)
            pixels = ImageChops.difference(left.convert("RGB").crop(area), right.convert("RGB").crop(area))
            total += sum(1 for px in pixels.get_flattened_data() if px != (0, 0, 0))
        return total


def tap(driver: webdriver.Remote, index: int) -> None:
    check_focus(driver)
    size = driver.get_window_size()
    if size["height"] <= size["width"]:
        raise Interrupted("screen no longer portrait")
    # Exact G2 fixture: five 100px-wide views, 12px gaps, centred in 720px.
    x = int((size["width"] - 548) / 2 + 50 + 112 * index)
    y = int(size["height"] * 0.50)
    driver.execute_script("mobile: clickGesture", {"x": x, "y": y})


def run(out: Path, expected_sha256: str, ci_run: str, commit: str) -> int:
    out.mkdir(parents=True, exist_ok=True)
    report: dict = {"track": "B — Real Android Device QA", "status": "UNVERIFIED", "checks": [],
                    "workflow_run": ci_run, "commit": commit, "expected_apk_sha256": expected_sha256,
                    "issue": "G15-QA-001 remains OPEN; no external-overlay retry"}
    driver = None
    pid = ""
    try:
        devices = dc.ensure_device()
        report["device_model"] = adb("shell", "getprop", "ro.product.model").strip()
        report["android_api"] = adb("shell", "getprop", "ro.build.version.sdk").strip()
        paths = adb("shell", "pm", "path", PACKAGE)
        base = next((line.removeprefix("package:") for line in paths.splitlines() if line.startswith("package:") and line.endswith("base.apk")), "")
        if not base:
            raise RuntimeError("installed base.apk path missing")
        with tempfile.TemporaryDirectory(prefix="g2-installed-", dir=out) as folder:
            apk = Path(folder) / "base.apk"
            proc = subprocess.run(["adb", "pull", base, str(apk)], capture_output=True, text=True, timeout=90, check=False)
            if proc.returncode or not apk.is_file():
                raise RuntimeError("installed APK pull failed")
            digest = hashlib.sha256(apk.read_bytes()).hexdigest()
        report["installed_apk_sha256"] = digest
        if digest != expected_sha256:
            raise RuntimeError("installed APK SHA-256 does not match CI artifact")
        report["checks"].append({"test": "installed APK SHA-256", "status": "PASS"})
        # Project package only: ensure READY belongs to this attempt's PID.
        dc.force_stop(PACKAGE)
        driver = webdriver.Remote("http://127.0.0.1:4723", options=dc.appium_options(devices[0]))
        driver.update_settings({"waitForIdleTimeout": 0})
        driver.activate_app(PACKAGE)
        for _ in range(20):
            pid = dc.pid_of(PACKAGE).strip().split(" ")[0]
            if pid and "LAYER_SORT_G2_READY" in log(pid):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("G2 ready marker absent")
        check_focus(driver)
        driver.get_screenshot_as_file(str(out / "initial.png"))
        report["checks"].append({"test": "launch/foreground/portrait/READY", "status": "PASS"})
        # Initially tubes 0..2 are full; establish a valid pour first.
        tap(driver, 0)
        tap(driver, 3)
        marker(pid, "LAYER_SORT_G2_MOVE 0 3 1", 0, out)
        driver.get_screenshot_as_file(str(out / "valid.png"))
        if board_difference(out, "initial", "valid") == 0:
            raise RuntimeError("valid move did not visibly change board")
        report["checks"].append({"test": "valid move", "status": "PASS"})
        time.sleep(0.4)
        # Source 0 now tops with colour 2; target 3 tops with colour 0.
        tap(driver, 0)
        tap(driver, 3)
        marker(pid, "LAYER_SORT_G2_REJECT COLOUR_MISMATCH", 0, out)
        driver.get_screenshot_as_file(str(out / "invalid.png"))
        if board_difference(out, "valid", "invalid") != 0:
            raise RuntimeError("invalid move changed tube interiors")
        report["checks"].append({"test": "invalid colour", "status": "PASS"})
        check_focus(driver)
        driver.execute_script("mobile: clickGesture", {"x": 263, "y": 1360})
        marker(pid, "LAYER_SORT_G2_UNDO", 0, out)
        driver.get_screenshot_as_file(str(out / "undo.png"))
        if board_difference(out, "initial", "undo") != 0:
            raise RuntimeError("Undo did not visually restore initial board")
        report["checks"].append({"test": "Undo", "status": "PASS"})
        check_focus(driver)
        driver.execute_script("mobile: clickGesture", {"x": 457, "y": 1360})
        marker(pid, "LAYER_SORT_G2_RESTART", 0, out)
        driver.get_screenshot_as_file(str(out / "restart.png"))
        if board_difference(out, "initial", "restart") != 0:
            raise RuntimeError("Restart did not visually restore initial board")
        report["checks"].append({"test": "Restart", "status": "PASS"})
        # One real rapid sequence in a single W3C request (<280ms total), not
        # separately queued Appium commands whose latency masks lock defects.
        check_focus(driver)
        prior_moves = log(pid).count("LAYER_SORT_G2_MOVE")
        actions = []
        for index in (0, 3, 1, 4):
            actions += [{"type": "pointerMove", "duration": 0,
                         "x": 136 + 112 * index, "y": 800},
                        {"type": "pointerDown", "button": 0},
                        {"type": "pause", "duration": 20},
                        {"type": "pointerUp", "button": 0}]
        driver.execute("actions", {"actions": [{"type": "pointer", "id": "rapid-finger",
                       "parameters": {"pointerType": "touch"}, "actions": actions}]})
        time.sleep(0.4)
        captured = log(pid)
        if captured.count("LAYER_SORT_G2_MOVE") != prior_moves + 1:
            raise RuntimeError("rapid taps did not commit exactly one move")
        driver.get_screenshot_as_file(str(out / "rapid.png"))
        if board_difference(out, "valid", "rapid") != 0:
            raise RuntimeError("rapid taps produced unexpected board")
        report["checks"].append({"test": "rapid 4-tap single-request input lock", "status": "PASS"})
        check_focus(driver)
        prior_restarts = log(pid).count("LAYER_SORT_G2_RESTART")
        driver.execute_script("mobile: clickGesture", {"x": 457, "y": 1360})
        marker(pid, "LAYER_SORT_G2_RESTART", prior_restarts, out)
        for source, destination in SOLUTION:
            check_focus(driver)
            tap(driver, source)
            tap(driver, destination)
            time.sleep(0.38)
        marker(pid, "LAYER_SORT_G2_WIN", 0, out, 12)
        check_focus(driver)
        driver.get_screenshot_as_file(str(out / "win.png"))
        if board_difference(out, "initial", "win") == 0:
            raise RuntimeError("Win board did not change")
        report["checks"].append({"test": "solution/Win", "status": "PASS"})
        report["screenshots"] = {name: str(out / (name + ".png")) for name in
                                 ("initial", "valid", "invalid", "undo", "restart", "rapid", "win")}
        report["marker_evidence"] = str(out / "markers.log")
        report["status"] = "PASS"
    except Interrupted as e:
        report.update(status="UNVERIFIED", reason="EXTERNAL_OVERLAY_OR_FOCUS_INTERRUPTION: " + str(e))
    except Exception as e:
        report.update(status="FAIL", reason=f"{type(e).__name__}: {str(e)[:200]}")
    finally:
        if pid:
            try:
                captured = log(pid)
                (out / "logcat.txt").write_text(captured)
                fatals = [line for line in captured.splitlines() if any(s in line for s in ("SCRIPT ERROR", "FATAL EXCEPTION", "Fatal signal"))]
                report["fatal_line_count"] = len(fatals)
                if fatals and report["status"] == "PASS":
                    report.update(status="FAIL", reason="fatal/script errors in logcat")
            except Exception:
                report.update(status="UNVERIFIED" if report["status"] == "PASS" else report["status"], reason="logcat collection unavailable")
        if driver:
            try:
                driver.quit()
            except Exception:
                pass
        (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--sha256", required=True, help="verified CI APK SHA-256")
    parser.add_argument("--run-id", required=True, help="CI run that produced the verified APK")
    parser.add_argument("--commit", required=True, help="CI head commit prefix")
    args = parser.parse_args()
    raise SystemExit(run(args.out, args.sha256, args.run_id, args.commit))

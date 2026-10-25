#!/usr/bin/env python3
"""One bounded G2 Appium attempt. Invoke ONLY via `agentctl phone` (shared lock).

No retry and no non-project package action. Evidence stays in an untracked
private run directory; an external overlay is UNVERIFIED, never a device PASS.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

from appium import webdriver

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


def marker(pid: str, expected: str, previous: int, seconds: float = 8) -> int:
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        amount = log(pid).count(expected)
        if amount > previous:
            return amount
        time.sleep(0.4)
    raise RuntimeError(f"missing logcat marker {expected} after {seconds}s")


def tap(driver: webdriver.Remote, index: int) -> None:
    check_focus(driver)
    size = driver.get_window_size()
    if size["height"] <= size["width"]:
        raise Interrupted("screen no longer portrait")
    # Exact G2 fixture: five 100px-wide views, 12px gaps, centred in 720px.
    x = int((size["width"] - 548) / 2 + 50 + 112 * index)
    y = int(size["height"] * 0.50)
    driver.execute_script("mobile: clickGesture", {"x": x, "y": y})


def run(out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    report: dict = {"track": "B — Real Android Device QA", "status": "UNVERIFIED", "checks": [],
                    "issue": "G15-QA-001 remains OPEN; no external-overlay retry"}
    driver = None
    pid = ""
    try:
        devices = dc.ensure_device()
        report["device_model"] = adb("shell", "getprop", "ro.product.model").strip()
        report["android_api"] = adb("shell", "getprop", "ro.build.version.sdk").strip()
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
        # Invalid colour: source 0 has top 0; target 1 has top 1.
        tap(driver, 0)
        tap(driver, 1)
        marker(pid, "LAYER_SORT_G2_REJECT COLOUR_MISMATCH", 0)
        report["checks"].append({"test": "invalid colour", "status": "PASS"})
        # Invalid destination deliberately retains selection in this G2 scene.
        tap(driver, 3)
        marker(pid, "LAYER_SORT_G2_MOVE 0 3 1", 0)
        driver.get_screenshot_as_file(str(out / "valid.png"))
        report["checks"].append({"test": "valid move", "status": "PASS"})
        time.sleep(0.4)
        check_focus(driver)
        check_focus(driver)
        driver.execute_script("mobile: clickGesture", {"x": 263, "y": 1360})
        marker(pid, "LAYER_SORT_G2_UNDO", 0)
        report["checks"].append({"test": "Undo", "status": "PASS"})
        check_focus(driver)
        driver.execute_script("mobile: clickGesture", {"x": 457, "y": 1360})
        marker(pid, "LAYER_SORT_G2_RESTART", 0)
        driver.get_screenshot_as_file(str(out / "restart.png"))
        report["checks"].append({"test": "Restart", "status": "PASS"})
        for source, destination in SOLUTION:
            check_focus(driver)
            tap(driver, source)
            tap(driver, destination)
            time.sleep(0.38)
        marker(pid, "LAYER_SORT_G2_WIN", 0, 12)
        check_focus(driver)
        driver.get_screenshot_as_file(str(out / "win.png"))
        report["checks"].append({"test": "solution/Win", "status": "PASS"})
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
    args = parser.parse_args()
    raise SystemExit(run(args.out))

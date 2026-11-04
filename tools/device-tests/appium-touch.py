#!/usr/bin/env python3
"""G1 Appium touch check.

Taps the centre of the portrait scene (the large on-screen button), then
requires both the GDScript touch marker and a visible change in the screenshot
region that contains the status labels.
"""

from __future__ import annotations

import time
import traceback
from pathlib import Path

import device_common as dc
from appium import webdriver

KIND = "touch"
result: dict = {
    "status": "FAIL",
    "kind": KIND,
    "package": dc.PKG,
    "reason": "",
}
driver = None
log = ""
before: Path | None = None
after: Path | None = None


def capture_evidence() -> None:
    try:
        dc.save_text("device.txt", dc.device_info_text())
    except Exception as exc:
        print(f"DEVICE_INFO_WARNING: {exc}", flush=True)
    try:
        dc.save_text("package.txt", dc.package_info_text())
    except Exception as exc:
        print(f"PACKAGE_INFO_WARNING: {exc}", flush=True)


try:
    devices = dc.ensure_device()
    result["device"] = devices[0]

    dc.force_stop()
    dc.clear_logcat()

    print("CREATING_APPIUM_SESSION", flush=True)
    driver = webdriver.Remote(
        "http://127.0.0.1:4723",
        options=dc.appium_options(devices[0]),
    )
    print(f"SESSION_ID: {driver.session_id}", flush=True)
    try:
        driver.update_settings({"waitForIdleTimeout": 0})
    except Exception as exc:
        print(f"APPIUM_SETTINGS_WARNING: {exc}", flush=True)

    driver.activate_app(dc.PKG)
    log = dc.wait_for_marker(dc.READY_MARKER, timeout=45)
    time.sleep(1.0)

    before = dc.save_screenshot(driver, "before.png", KIND)
    dc.save_legacy(KIND, "before.png", before)
    before_stats = dc.screenshot_stats(before)

    size = driver.get_window_size()
    x = int(size["width"]) // 2
    y = int(size["height"]) // 2
    result["tap_coordinates"] = {"x": x, "y": y}
    print(f"TAPPING_GAME: {x}, {y}", flush=True)
    driver.execute_script("mobile: clickGesture", {"x": x, "y": y})

    log = dc.wait_for_marker(dc.TAP_MARKER, timeout=20, minimum=1)
    time.sleep(1.0)

    after = dc.save_screenshot(driver, "after.png", KIND)
    log = dc.logcat()

    result.update(dc.verify_common(driver, log, after, require_tap=True, tap_count=1))

    width, height = before_stats["width"], before_stats["height"]
    crop = (
        int(width * 0.10),
        int(height * 0.50),
        int(width * 0.90),
        int(height * 0.70),
    )
    before_digest = dc.image_digest(before, crop)
    after_digest = dc.image_digest(after, crop)
    if before_digest == after_digest:
        raise RuntimeError(
            "Touch marker was logged, but the status region did not change visually"
        )

    result["screenshot_change"] = {
        "crop": list(crop),
        "before_sha256": before_digest,
        "after_sha256": after_digest,
        "changed": True,
        "before": before_stats,
        "after": dc.screenshot_stats(after),
    }
    result["package_info"] = dc.parse_package_info(dc.package_info_text())
    result["status"] = "PASS"
    print("TOUCH_TEST_PASS", flush=True)

except Exception as exc:
    result["reason"] = str(exc)
    traceback.print_exc()
    try:
        log = dc.logcat()
    except Exception as log_exc:
        print(f"LOGCAT_WARNING: {log_exc}", flush=True)

finally:
    capture_evidence()
    dc.finish(KIND, result, driver=driver, log=log, screenshot=after)

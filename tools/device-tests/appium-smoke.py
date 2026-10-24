#!/usr/bin/env python3
"""G1 Appium smoke check.

Launches the GDScript APK, waits for the scene-ready marker, verifies package,
portrait orientation, a non-black portrait screenshot, and clean logcat.
"""

from __future__ import annotations

import time
import traceback
from pathlib import Path

import device_common as dc
from appium import webdriver

KIND = "smoke"
result: dict = {
    "status": "FAIL",
    "kind": KIND,
    "package": dc.PKG,
    "reason": "",
}
driver = None
log = ""
screenshot: Path | None = None


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
    time.sleep(1.5)

    screenshot = dc.save_screenshot(driver, "screenshot.png", KIND)
    log = dc.logcat()

    result.update(dc.verify_common(driver, log, screenshot))

    package_text = dc.package_info_text()
    result["package_info"] = dc.parse_package_info(package_text)
    result["status"] = "PASS"
    print("APPIUM_SMOKE_PASS", flush=True)

except Exception as exc:
    result["reason"] = str(exc)
    traceback.print_exc()
    try:
        log = dc.logcat()
    except Exception as log_exc:
        print(f"LOGCAT_WARNING: {log_exc}", flush=True)

finally:
    capture_evidence()
    dc.finish(KIND, result, driver=driver, log=log, screenshot=screenshot)

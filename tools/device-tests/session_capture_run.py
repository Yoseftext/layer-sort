#!/usr/bin/env python3
"""One scoped Antigravity capture; its task grant is prepared by the operator.

The task grant is application policy, not isolation against a same-user process.
On interruption, return-to-activity cannot be guaranteed; do not auto-retry.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import artifact_qa as artifact
import device_qa as device
import install_qa as install
import session_capture


ROOT = Path(__file__).resolve().parents[2]


def current_grant(pin: Path) -> dict:
    node = shutil.which("node")
    if not node:
        raise RuntimeError("Node is unavailable")
    result = subprocess.run([node, str(ROOT / "tools/agent-guard/runtime-config.mjs"),
                             "device-grant", str(pin), str(ROOT)],
                            capture_output=True, text=True, timeout=20, check=False)
    if result.returncode != 0:
        raise RuntimeError("Capture session grant is unavailable or expired")
    data = json.loads(result.stdout)
    if set(data) != {"runId", "commit", "apkSha256"}:
        raise RuntimeError("Invalid capture grant")
    return data


def execute() -> dict:
    raw_pin = os.environ.get("LS_POLICY_SNAPSHOT")
    if not raw_pin:
        raise RuntimeError("Capture requires a prepared Antigravity session")
    pin = Path(raw_pin)
    grant = current_grant(pin)
    with artifact.verified_cached_build(grant["runId"], grant["commit"], grant["apkSha256"]):
        with device.phone_lock(), tempfile.TemporaryDirectory(prefix="layer-sort-capture-") as temporary:
            serial = device.connected_serial(require_installed=False)
            device.validate_device(serial)
            installed = install.installed_apk(serial, Path(temporary) / "installed.apk")
            if installed is None or installed["sha256"] != grant["apkSha256"]:
                raise device.DeviceQaFailure("Installed APK differs from the reviewed build")
            if current_grant(pin) != grant:
                raise RuntimeError("Capture grant changed during preflight")
            # Written before any app launch. An interrupted session stays consumed.
            fd = os.open(pin / "CAPTURE_CONSUMED", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            try:
                os.write(fd, b"UNKNOWN; do not retry automatically\n")
                os.fsync(fd)
            finally:
                os.close(fd)
            return session_capture.capture_restore_locked(serial)


def main() -> int:
    try:
        result = execute()
    except Exception as error:
        result = {"action": "capture-restore", "status": "UNKNOWN",
                  "reason": str(error), "same_screen_contents_verified": False}
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())

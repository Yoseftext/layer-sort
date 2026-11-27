"""Read-only evidence collection for session plans.

This module does not authorize or execute a plan. Observations are a snapshot;
they must be freshly rechecked under the phone lock at dispatch in any future
live integration. Do not treat JSON supplied by an agent as trusted evidence.
"""
from __future__ import annotations

import tempfile
from pathlib import Path
from typing import Any

import artifact_qa as artifact
import device_qa as device
import install_qa as install
import session_plan


def observe(plan: dict[str, Any], now=None) -> dict[str, Any]:
    """Revalidate the cached build and read the actual device under its lock."""
    session_plan.validate(plan, now)
    with artifact.verified_cached_build(plan["run_id"], plan["source_commit"],
                                        plan["apk_sha256"]):
        with device.phone_lock(), tempfile.TemporaryDirectory(prefix="layer-sort-session-observe-") as tmp:
            serial = device.connected_serial(require_installed=False)
            properties = device.validate_device(serial)
            installed = install.installed_apk(serial, Path(tmp) / "installed.apk")
            if installed is None:
                raise device.DeviceQaFailure("Layer Sort is not installed.")
            width, height = device.screen_size(serial)
            evidence = {
                "status": "PASS",
                "source_commit": plan["source_commit"],
                "run_id": plan["run_id"],
                "apk_sha256": plan["apk_sha256"],
                "installed_sha256": installed["sha256"],
                "package_id": device.PACKAGE_ID,
                "device": {key: properties[key] for key in session_plan.DEVICE},
                "width": width,
                "height": height,
            }
            session_plan.check_preconditions(plan, evidence, now)
            return evidence

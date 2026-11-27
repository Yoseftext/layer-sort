"""Internal, package-scoped dispatcher for a reviewed session step.

Caller must hold the existing phone lock, verify provenance/device and establish
owner authorization independently. This module has no CLI and is not an agent
permission or proof of consent. It must not be exposed before integration review.
"""
from __future__ import annotations

import contextlib
import io
import json
from typing import Any

import device_qa as device


class DispatchError(ValueError):
    pass


def dispatch_locked(step: dict[str, Any], *, expected_serial: str | None = None) -> dict[str, Any]:
    """Use the existing device implementation; the caller must hold its lock."""
    if not isinstance(step, dict):
        raise DispatchError("Invalid session operation")
    action = step.get("action")
    if action in {"launch", "screenshot"} and set(step) == {"action"}:
        args = device.build_parser().parse_args([action])
    elif (action == "tap" and set(step) == {"action", "x", "y"} and
          type(step["x"]) is int and type(step["y"]) is int and
          0 <= step["x"] < 720 and 0 <= step["y"] < 1600):
        args = device.build_parser().parse_args(["tap", str(step["x"]), str(step["y"])])
    else:
        raise DispatchError("Unsupported or malformed session operation")
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        # This is an internal audit label, not evidence of owner authorization.
        exit_code = device._execute_locked(args, approval="session-reviewed", expected_serial=expected_serial)
    try:
        result = json.loads(output.getvalue())
    except (TypeError, json.JSONDecodeError) as error:
        raise DispatchError("Device returned invalid structured output") from error
    codes = {"PASS": 0, "FAIL": 1, "UNKNOWN": 2, "UNVERIFIED": 2, "SKIP": 3}
    if (not isinstance(result, dict) or result.get("action") != action or
            result.get("status") not in codes or codes[result["status"]] != exit_code):
        raise DispatchError("Device result and exit code do not match")
    return result

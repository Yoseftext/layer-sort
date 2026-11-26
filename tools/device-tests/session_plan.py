#!/usr/bin/env python3
"""Prepare a reviewable device-test plan. This module does not grant authority.

The operator must independently record approval of the exact plan hash. This
module neither launches agents nor calls ADB, and cannot enforce single use.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

PACKAGE = "com.yoseftext.layersort.dev"
DEVICE = {"manufacturer": "OPPO", "model": "CPH1937", "product": "OP4B80L1", "android_api": "30"}
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
TASK = re.compile(r"[A-Z0-9][A-Z0-9_-]{5,63}")


class PlanError(ValueError):
    pass


def validate(plan: Any, now: datetime | None = None) -> dict[str, Any]:
    now = now or datetime.now(timezone.utc)
    fields = {"schema_version", "task_id", "source_commit", "run_id", "apk_sha256",
              "installed_sha256", "package_id", "device", "expires_at", "operations"}
    if not isinstance(plan, dict) or set(plan) != fields or type(plan["schema_version"]) is not int or plan["schema_version"] != 1:
        raise PlanError("Invalid plan fields")
    if not isinstance(plan["task_id"], str) or not TASK.fullmatch(plan["task_id"]):
        raise PlanError("Invalid task ID")
    if not isinstance(plan["source_commit"], str) or not HEX40.fullmatch(plan["source_commit"]):
        raise PlanError("Invalid source commit")
    if not isinstance(plan["run_id"], str) or not re.fullmatch(r"[1-9][0-9]{0,19}", plan["run_id"]):
        raise PlanError("Invalid build run ID")
    for name in ("apk_sha256", "installed_sha256"):
        if not isinstance(plan[name], str) or not HEX64.fullmatch(plan[name]):
            raise PlanError("Invalid " + name)
    if plan["package_id"] != PACKAGE or plan["device"] != DEVICE:
        raise PlanError("Device or package mismatch")
    try:
        expiry = datetime.fromisoformat(plan["expires_at"].replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        raise PlanError("Invalid expiry") from None
    if expiry.tzinfo is None or now.tzinfo is None or expiry <= now or expiry > now + timedelta(hours=2):
        raise PlanError("Expired or excessively long session")
    operations = plan["operations"]
    if not isinstance(operations, list) or not 1 <= len(operations) <= 30:
        raise PlanError("Invalid operation count")
    for step in operations:
        if not isinstance(step, dict) or step.get("action") not in {"launch", "screenshot", "tap"}:
            raise PlanError("Unsupported operation")
        if step["action"] in {"launch", "screenshot"}:
            if set(step) != {"action"}:
                raise PlanError("Unexpected operation parameters")
        else:
            if set(step) != {"action", "x", "y"} or type(step["x"]) is not int or type(step["y"]) is not int:
                raise PlanError("Invalid tap")
            if not 0 <= step["x"] < 720 or not 0 <= step["y"] < 1600:
                raise PlanError("Tap outside reviewed 720x1600 display")
    return plan


def plan_hash(plan: dict[str, Any]) -> str:
    payload = json.dumps(plan, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def check_step(plan: dict[str, Any], index: int, requested: dict[str, Any],
               expected_hash: str, now: datetime | None = None) -> None:
    validate(plan, now)
    if not isinstance(expected_hash, str) or not HEX64.fullmatch(expected_hash) or plan_hash(plan) != expected_hash:
        raise PlanError("Plan does not match the separately approved hash")
    if type(index) is not int or not 0 <= index < len(plan["operations"]):
        raise PlanError("Operation index is invalid")
    # Python equates True and 1; compare JSON encodings so a boolean cannot
    # masquerade as a reviewed integer coordinate.
    try:
        actual = json.dumps(requested, sort_keys=True, separators=(",", ":"), allow_nan=False)
        expected = json.dumps(plan["operations"][index], sort_keys=True, separators=(",", ":"), allow_nan=False)
    except (TypeError, ValueError):
        raise PlanError("Invalid requested operation") from None
    if actual != expected:
        raise PlanError("Operation does not match the reviewed plan")



def check_preconditions(plan: dict[str, Any], observed: Any, now: datetime | None = None) -> None:
    """Compare a plan to independently collected evidence; does not collect it."""
    validate(plan, now)
    required = {"status", "source_commit", "run_id", "apk_sha256",
                "installed_sha256", "package_id", "device", "width", "height"}
    if not isinstance(observed, dict) or set(observed) != required or observed["status"] != "PASS":
        raise PlanError("Observed evidence is incomplete or not PASS")
    for field in ("source_commit", "run_id", "apk_sha256", "installed_sha256", "package_id", "device"):
        if observed[field] != plan[field]:
            raise PlanError("Observed " + field + " differs from the plan")
    if type(observed["width"]) is not int or type(observed["height"]) is not int or (observed["width"], observed["height"]) != (720, 1600):
        raise PlanError("Observed display differs from reviewed dimensions")


def main() -> int:
    parser = argparse.ArgumentParser(description="Review a bounded Layer Sort device test plan (no phone actions)")
    parser.add_argument("plan", help="JSON plan file")
    args = parser.parse_args()
    try:
        with open(args.plan, encoding="utf-8") as source:
            plan = json.load(source)
        validate(plan)
        print(json.dumps({"status": "READY_FOR_REVIEW", "plan_sha256": plan_hash(plan),
                          "operations": len(plan["operations"]), "phone_mutated": False,
                          "authorization_created": False}))
        return 0
    except (OSError, json.JSONDecodeError, PlanError) as error:
        print(json.dumps({"status": "FAIL", "reason": str(error), "phone_mutated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

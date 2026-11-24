#!/usr/bin/env python3
"""Create bounded W3C touch action plans without contacting a device.

The returned JSON is a proposal only. Execution requires a separately reviewed,
scoped device runner, exact device/build evidence and owner authorization.
"""
from __future__ import annotations

import argparse
import json
import re
from typing import Any, Sequence

SIZE = re.compile(r"([1-9][0-9]{0,3})x([1-9][0-9]{0,3})")
POINTS = re.compile(r"[0-9]{1,4},[0-9]{1,4}(?::[0-9]{1,4},[0-9]{1,4}){0,7}")
MAX_DIMENSION = 8192
PRESS_MS = 20
GAP_MS = 20
HOLD_MS = 600
DRAG_MS = 200


class PlanError(ValueError):
    pass


def pointer(name: str, actions: list[dict[str, Any]]) -> dict[str, Any]:
    return {"type": "pointer", "id": name, "parameters": {"pointerType": "touch"}, "actions": actions}


def move(point: tuple[int, int], duration: int = 0) -> dict[str, Any]:
    return {"type": "pointerMove", "duration": duration, "origin": "viewport", "x": point[0], "y": point[1]}


def pause(duration: int) -> dict[str, Any]:
    return {"type": "pause", "duration": duration}


def build_plan(mode: str, screen: str, raw_points: str) -> dict[str, Any]:
    match = SIZE.fullmatch(screen)
    if match is None or not POINTS.fullmatch(raw_points):
        raise PlanError("Use <width>x<height> and colon-separated <x>,<y> points.")
    width, height = (int(value) for value in match.groups())
    if max(width, height) > MAX_DIMENSION:
        raise PlanError("Screen dimensions exceed the supported bound.")
    points = [tuple(int(value) for value in point.split(",")) for point in raw_points.split(":")]
    if any(x >= width or y >= height for x, y in points):
        raise PlanError("A point is outside the declared viewport.")
    down = {"type": "pointerDown", "button": 0}
    up = {"type": "pointerUp", "button": 0}
    if mode == "rapid":
        if not 2 <= len(points) <= 8:
            raise PlanError("Rapid input requires 2 to 8 points.")
        actions: list[dict[str, Any]] = []
        for point in points:
            actions.extend([move(point), dict(down), pause(PRESS_MS), dict(up), pause(GAP_MS)])
        sources = [pointer("rapid-finger", actions)]
        duration = len(points) * (PRESS_MS + GAP_MS)
    elif mode == "simultaneous":
        if len(points) != 2:
            raise PlanError("Simultaneous input requires exactly two points.")
        # Identical tick counts synchronize both virtual fingers in a single
        # W3C actions request. Actual timing is a device measurement, not this plan.
        sources = [pointer(f"finger-{index}", [move(point), dict(down), pause(PRESS_MS), dict(up)])
                   for index, point in enumerate(points, 1)]
        duration = PRESS_MS
    elif mode == "drag":
        if len(points) != 2:
            raise PlanError("A drag requires a start and end point.")
        sources = [pointer("drag-finger", [move(points[0]), dict(down), move(points[1], DRAG_MS), dict(up)])]
        duration = DRAG_MS
    elif mode == "hold":
        if len(points) != 1:
            raise PlanError("A hold requires exactly one point.")
        sources = [pointer("hold-finger", [move(points[0]), dict(down), pause(HOLD_MS), dict(up)])]
        duration = HOLD_MS
    else:
        raise PlanError("Unknown gesture mode.")
    return {"status": "PASS", "action": "plan-gesture", "mode": mode,
            "viewport": {"width": width, "height": height},
            "planned_duration_ms": duration, "w3c_request": {"actions": sources},
            "device_contacted": False, "input_executed": False,
            "evidence": "PLAN_ONLY; timing, gameplay behavior and touch accuracy are unverified"}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("rapid", "simultaneous", "drag", "hold"))
    parser.add_argument("--size", required=True)
    parser.add_argument("--points", required=True)
    args = parser.parse_args(argv)
    try:
        result = build_plan(args.mode, args.size, args.points)
    except PlanError as error:
        print(json.dumps({"status": "FAIL", "action": "plan-gesture", "reason": str(error),
                          "device_contacted": False, "input_executed": False}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

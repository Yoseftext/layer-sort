#!/usr/bin/python3.13 -I
"""Allowlisted Layer Sort Android QA. No arbitrary ADB shell is exposed."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Sequence

PACKAGE_ID = "com.yoseftext.layersort.dev"
EXPECTED_DEVICE = {
    "manufacturer": "OPPO",
    "model": "CPH1937",
    "product": "OP4B80L1",
    "android_api": "30",
}
ADB = Path("/usr/lib/android-sdk/platform-tools/adb")
ADB_HOST = "127.0.0.1"
ADB_PORT = "5037"
PHONE_LOCK = Path("/root/device-tests/test.lock")
EVIDENCE_ROOT = Path(__file__).resolve().parents[2] / ".runtime" / "device-qa"
THERMAL_NAMES = {
    0: "NONE", 1: "LIGHT", 2: "MODERATE", 3: "SEVERE",
    4: "CRITICAL", 5: "EMERGENCY", 6: "SHUTDOWN",
}


class DeviceQaUnknown(Exception):
    """A required fact or device result could not be established."""


class DeviceQaFailure(Exception):
    """A verified precondition or operation failed."""


def emit(status: str, action: str, **fields: object) -> int:
    result = {
        "schema_version": 1,
        "status": status,
        "action": action,
        "package_id": PACKAGE_ID,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        **fields,
    }
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return {"PASS": 0, "FAIL": 1, "UNKNOWN": 2, "UNVERIFIED": 2, "SKIP": 3}[status]


@contextmanager
def phone_lock() -> Iterator[None]:
    if not PHONE_LOCK.is_file():
        raise DeviceQaUnknown("Shared phone lock is missing.")
    try:
        fd = os.open(PHONE_LOCK, os.O_RDWR | getattr(os, "O_CLOEXEC", 0))
    except OSError as error:
        raise DeviceQaUnknown("Shared phone lock cannot be opened.") from error
    acquired = False
    try:
        deadline = time.monotonic() + 10.0
        while time.monotonic() < deadline:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                acquired = True
                break
            except BlockingIOError:
                time.sleep(0.1)
        if not acquired:
            raise DeviceQaUnknown("Phone lock timed out; device is busy.")
        yield
    finally:
        if acquired:
            fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def adb_call(
    serial: str | None,
    arguments: Sequence[str],
    *,
    timeout: float = 12.0,
    binary: bool = False,
) -> str | bytes:
    if not ADB.is_file() or not os.access(ADB, os.X_OK):
        raise DeviceQaUnknown("ADB executable is unavailable.")
    command = [str(ADB), "-H", ADB_HOST, "-P", ADB_PORT]
    if serial is not None:
        command.extend(["-s", serial])
    command.extend(arguments)
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        raise DeviceQaUnknown("ADB_TIMEOUT: result is UNKNOWN.") from error
    except OSError as error:
        raise DeviceQaUnknown("ADB could not be started.") from error
    if result.returncode != 0:
        raise DeviceQaUnknown("ADB operation failed; device state is UNKNOWN.")
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace").strip()


def parse_connected_serials(output: str) -> list[str]:
    return [
        fields[0]
        for line in output.splitlines()[1:]
        if len(fields := line.split()) >= 2 and fields[1] == "device"
    ]


def connected_serial() -> str:
    output = adb_call(None, ["devices", "-l"])
    if not isinstance(output, str):
        raise DeviceQaUnknown("Invalid ADB device listing.")
    serials = parse_connected_serials(output)
    if not serials:
        raise DeviceQaUnknown("No online ADB devices are available.")

    approved: list[str] = []
    for serial in serials:
        if serial.lower().startswith("emulator-"):
            continue
        try:
            validate_device(serial)
            ensure_game_installed(serial)
        except DeviceQaFailure:
            continue
        approved.append(serial)

    if len(approved) != 1:
        raise DeviceQaUnknown(
            "Expected exactly one approved OPPO CPH1937 device; "
            f"found {len(approved)} among {len(serials)} online ADB devices."
        )
    return approved[0]


def shell_text(serial: str, *args: str, timeout: float = 12.0) -> str:
    output = adb_call(serial, ["shell", *args], timeout=timeout)
    if not isinstance(output, str):
        raise DeviceQaUnknown("Invalid ADB shell result.")
    return output


def validate_device(serial: str) -> dict[str, str]:
    properties = {
        "manufacturer": shell_text(serial, "getprop", "ro.product.manufacturer"),
        "model": shell_text(serial, "getprop", "ro.product.model"),
        "product": shell_text(serial, "getprop", "ro.product.device"),
        "android_release": shell_text(serial, "getprop", "ro.build.version.release"),
        "android_api": shell_text(serial, "getprop", "ro.build.version.sdk"),
    }
    if any(properties.get(key) != value for key, value in EXPECTED_DEVICE.items()):
        raise DeviceQaFailure("Connected device does not match the approved OPPO target.")
    return properties


def ensure_game_installed(serial: str) -> None:
    if not shell_text(serial, "pm", "path", PACKAGE_ID).startswith("package:"):
        raise DeviceQaFailure("Approved Layer Sort package is not installed.")


def parse_focused_package(output: str) -> str | None:
    for line in output.splitlines():
        if "mCurrentFocus=" in line or "mFocusedApp=" in line:
            match = re.search(r"\b([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)/", line)
            return match.group(1) if match else None
    return None


def focused_package(serial: str) -> str | None:
    return parse_focused_package(shell_text(serial, "dumpsys", "window"))


def parse_screen_size(output: str) -> tuple[int, int]:
    physical: tuple[int, int] | None = None
    override: tuple[int, int] | None = None
    for line in output.splitlines():
        match = re.search(r"(Physical|Override) size:\s*(\d+)x(\d+)", line)
        if match:
            size = (int(match.group(2)), int(match.group(3)))
            if match.group(1) == "Override":
                override = size
            else:
                physical = size
    result = override or physical
    if result is None or min(result) <= 0:
        raise DeviceQaUnknown("Display dimensions are unavailable.")
    return result


def screen_size(serial: str) -> tuple[int, int]:
    return parse_screen_size(shell_text(serial, "wm", "size"))


def parse_battery(output: str) -> dict[str, object]:
    level = re.search(r"(?m)^\s*level:\s*(\d+)\s*$", output)
    temperature = re.search(r"(?m)^\s*temperature:\s*(-?\d+)\s*$", output)
    status = re.search(r"(?m)^\s*status:\s*(\d+)\s*$", output)
    if level is None or temperature is None:
        raise DeviceQaUnknown("Battery level or temperature is unavailable.")
    result: dict[str, object] = {
        "battery_level_percent": int(level.group(1)),
        "battery_temperature_c": int(temperature.group(1)) / 10.0,
    }
    if status:
        result["battery_status_code"] = int(status.group(1))
    return result


def parse_thermal(output: str) -> dict[str, object]:
    match = re.search(r"Thermal Status:\s*(\d+)", output)
    if match is None:
        raise DeviceQaUnknown("Thermal service did not report a status.")
    code = int(match.group(1))
    sensors: list[dict[str, object]] = []
    section = "unknown"
    diagnostic_pattern = re.compile(
        r"thermal|temperature|sensor|severity|status|CPU|GPU|battery|skin|SoC|HAL|mName|mValue",
        re.IGNORECASE,
    )
    diagnostic_lines: list[str] = []
    for line in output.splitlines():
        if "Cached temperatures:" in line:
            section = "cached"
        elif "Current temperatures from HAL:" in line:
            section = "hal"
        elif "Current cooling devices from HAL:" in line:
            section = "cooling"
        if line.lstrip().startswith("Temperature{"):
            value = re.search(r"mValue\s*=\s*(-?\d+(?:\.\d+)?)", line)
            name = re.search(r"mName\s*=\s*([^,}\s]+)", line)
            sensor_type = re.search(r"mType\s*=\s*(\d+)", line)
            sensor_status = re.search(r"mStatus\s*=\s*(\d+)", line)
            if value and name:
                status_code = int(sensor_status.group(1)) if sensor_status else None
                sensor_name = name.group(1)
                is_soc = sensor_name.lower() == "soc"
                reported_status_name = (
                    THERMAL_NAMES.get(status_code, "UNKNOWN")
                    if status_code is not None else "UNKNOWN"
                )
                sensors.append({
                    "name": sensor_name,
                    "value_c": float(value.group(1)),
                    "type_code": int(sensor_type.group(1)) if sensor_type else None,
                    "status_code": status_code,
                    "reported_status_name": reported_status_name,
                    "status_name": "UNVERIFIED" if is_soc else reported_status_name,
                    "verification": "UNVERIFIED" if is_soc else "REPORTED",
                    "source": section,
                })
        if diagnostic_pattern.search(line):
            diagnostic_lines.append(line.strip()[:240])
    current_hal_sensors = [
        sensor for sensor in sensors
        if sensor.get("source") == "hal" and sensor.get("verification") != "UNVERIFIED"
    ]
    cached_sensors = [
        sensor for sensor in sensors
        if sensor.get("source") == "cached" and sensor.get("verification") != "UNVERIFIED"
    ]
    current_hal_severe_sensors = [
        sensor for sensor in current_hal_sensors
        if isinstance(sensor.get("status_code"), int) and int(sensor["status_code"]) >= 3
    ]
    cached_severe_sensor_count = sum(
        1
        for sensor in cached_sensors
        if isinstance(sensor.get("status_code"), int) and int(sensor["status_code"]) >= 3
    )
    soc_unverified_count = sum(
        1 for sensor in sensors if sensor.get("verification") == "UNVERIFIED"
    )
    framework_severe = code >= 3
    hal_non_soc_severe = bool(current_hal_severe_sensors)
    performance_gate = "BLOCK" if framework_severe and hal_non_soc_severe else "ALLOW"
    thermal_warning = (
        code >= 1
        or bool(current_hal_severe_sensors)
        or cached_severe_sensor_count > 0
        or soc_unverified_count > 0
    )
    return {
        "thermal_status_code": code,
        "thermal_status_name": THERMAL_NAMES.get(code, f"UNKNOWN_{code}"),
        "sensors": sensors,
        "current_hal_severe_sensor_count": len(current_hal_severe_sensors),
        "current_hal_severe_sensor_names": [
            str(sensor["name"]) for sensor in current_hal_severe_sensors
        ],
        "cached_severe_sensor_count": cached_severe_sensor_count,
        "soc_verification": "UNVERIFIED",
        "thermal_warning": thermal_warning,
        "performance_gate": performance_gate,
        "performance_gate_sources": {
            "android_framework_global_severe": framework_severe,
            "current_hal_non_soc_sensor_severe": hal_non_soc_severe,
            "soc_sensor_used": False,
        },
        "diagnostic_lines": diagnostic_lines[:50],
    }


def validate_coordinates(
    action: str, coordinates: Sequence[int], width: int, height: int,
    duration_ms: int | None = None,
) -> None:
    if any(value < 0 for value in coordinates):
        raise DeviceQaFailure("Coordinates must be non-negative.")
    pairs = list(zip(coordinates[::2], coordinates[1::2]))
    if any(x >= width or y >= height for x, y in pairs):
        raise DeviceQaFailure("Coordinates exceed display bounds.")
    if action == "swipe" and (duration_ms is None or not 50 <= duration_ms <= 1500):
        raise DeviceQaFailure("Swipe duration must be 50..1500 ms.")


def require_approval(args: argparse.Namespace, action: str) -> str | None:
    if args.dry_run:
        return None
    approval_id = args.approval_id
    if not args.owner_approved or not approval_id:
        emit("SKIP", action, reason="Exact owner approval is required for device mutation.")
        return "SKIP"
    if re.fullmatch(r"[A-Z0-9][A-Z0-9_-]{5,63}", approval_id) is None:
        emit("FAIL", action, reason="Approval ID format is invalid.")
        return "FAIL"
    return approval_id


def evidence_directory() -> Path:
    path = EVIDENCE_ROOT / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    path.mkdir(parents=True, exist_ok=False, mode=0o700)
    return path


def wait_for_foreground(serial: str, timeout: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if focused_package(serial) == PACKAGE_ID:
            return True
        time.sleep(0.25)
    return focused_package(serial) == PACKAGE_ID


def execute(args: argparse.Namespace) -> int:
    action = args.action
    approval: str | None = None
    if action in {"launch", "stop", "tap", "swipe"}:
        approval = require_approval(args, action)
        if approval == "SKIP":
            return 3
        if approval == "FAIL":
            return 1
        if args.dry_run:
            fields: dict[str, object] = {"dry_run": True, "mutation_executed": False}
            if action in {"tap", "swipe"}:
                fields["input_semantics"] = "ADB_SYNTHETIC_INPUT; in-game hit-testing only"
            return emit("SKIP", action, reason="Dry run; no device command executed.", **fields)

    with phone_lock():
        serial = connected_serial()
        device = validate_device(serial)
        ensure_game_installed(serial)

        if action == "status":
            return emit(
                "PASS", action, device=device, approved_device_count=1,
                package_installed=True, adb_server="existing_local_server_only",
                appium="NOT_USED",
            )
        if action == "battery":
            return emit(
                "PASS", action, device=device,
                **parse_battery(shell_text(serial, "dumpsys", "battery")),
            )
        if action in {"thermal", "performance-check"}:
            data = parse_thermal(
                shell_text(serial, "dumpsys", "thermalservice", timeout=15.0)
            )
            performance_gate = str(data["performance_gate"])
            if action == "performance-check" and performance_gate == "BLOCK":
                return emit(
                    "FAIL", action, device=device,
                    reason=(
                        "Performance test blocked: Android framework thermal status "
                        "and a current non-SoC HAL sensor both report SEVERE."
                    ),
                    **data,
                )
            return emit(
                "PASS", action, device=device,
                **data,
            )
        if action == "screenshot":
            if focused_package(serial) != PACKAGE_ID:
                return emit("SKIP", action, reason="Layer Sort is not verified in foreground.")
            image = adb_call(
                serial, ["exec-out", "screencap", "-p"],
                timeout=15.0, binary=True,
            )
            if not isinstance(image, bytes) or not image.startswith(b"\x89PNG\r\n\x1a\n"):
                raise DeviceQaUnknown("Screenshot is not a valid PNG.")
            if len(image) > 16 * 1024 * 1024 or len(image) < 24:
                raise DeviceQaFailure("Screenshot size is outside accepted bounds.")
            width, height = struct.unpack(">II", image[16:24])
            path = evidence_directory() / "screen.png"
            path.write_bytes(image)
            return emit(
                "PASS", action, device=device, foreground_package=PACKAGE_ID,
                path=str(path), sha256=hashlib.sha256(image).hexdigest(),
                width=width, height=height, touch_accuracy_measured=False,
            )
        if action == "logcat":
            pid = re.search(r"\b(\d+)\b", shell_text(serial, "pidof", PACKAGE_ID))
            if pid is None:
                return emit("SKIP", action, reason="Layer Sort process is not running.")
            output = adb_call(
                serial,
                ["logcat", "-d", "-v", "threadtime", f"--pid={pid.group(1)}", "-t", "500"],
                timeout=15.0,
            )
            if not isinstance(output, str):
                raise DeviceQaUnknown("Game logcat returned an invalid result.")
            markers = (
                "LAYER_SORT_G1_READY", "LAYER_SORT_G1_TICK", "LAYER_SORT_G1_TAP",
                "FATAL EXCEPTION", "Fatal signal", "SCRIPT ERROR", "Parse Error",
                "Failed to load scene",
            )
            selected = [line for line in output.splitlines() if any(x in line for x in markers)]
            path = evidence_directory() / "game-markers.log"
            path.write_text("\n".join(selected[-500:]) + "\n", encoding="utf-8")
            return emit(
                "PASS", action, device=device, game_pid=pid.group(1),
                filtered_lines=len(selected), path=str(path), raw_logcat_saved=False,
            )
        if action == "launch":
            adb_call(
                serial,
                ["shell", "monkey", "-p", PACKAGE_ID, "-c",
                 "android.intent.category.LAUNCHER", "1"],
                timeout=15.0,
            )
            if not wait_for_foreground(serial):
                return emit(
                    "UNKNOWN", action, device=device, approval_id=approval,
                    reason="Launch returned but foreground state was not verified.",
                )
            return emit("PASS", action, device=device, approval_id=approval, target_package=PACKAGE_ID)
        if action == "stop":
            adb_call(serial, ["shell", "am", "force-stop", PACKAGE_ID], timeout=10.0)
            deadline = time.monotonic() + 2.0
            while time.monotonic() < deadline:
                if not shell_text(serial, "pidof", PACKAGE_ID):
                    return emit("PASS", action, device=device, approval_id=approval, target_package=PACKAGE_ID)
                time.sleep(0.2)
            return emit(
                "UNKNOWN", action, device=device, approval_id=approval,
                reason="Force-stop returned but process termination was not verified.",
            )
        if action in {"tap", "swipe"}:
            if focused_package(serial) != PACKAGE_ID:
                return emit("SKIP", action, reason="Layer Sort is not verified in foreground.")
            width, height = screen_size(serial)
            if action == "tap":
                coordinates = (args.x, args.y)
                adb_args = ["shell", "input", "tap", str(args.x), str(args.y)]
            else:
                coordinates = (args.x1, args.y1, args.x2, args.y2)
                adb_args = [
                    "shell", "input", "swipe", str(args.x1), str(args.y1),
                    str(args.x2), str(args.y2), str(args.duration_ms),
                ]
            validate_coordinates(
                action, coordinates, width, height,
                getattr(args, "duration_ms", None),
            )
            if focused_package(serial) != PACKAGE_ID:
                return emit("SKIP", action, reason="Foreground changed before input dispatch.")
            adb_call(serial, adb_args, timeout=8.0)
            return emit(
                "PASS", action, device=device, approval_id=approval,
                target_package=PACKAGE_ID, input_semantics="ADB_SYNTHETIC_INPUT",
                measured_property="in_game_hit_testing", touch_accuracy_measured=False,
            )
    raise DeviceQaFailure("Unsupported device action.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Allowlisted Layer Sort device QA; no arbitrary ADB shell."
    )
    commands = parser.add_subparsers(dest="action", required=True)
    for name in ("status", "battery", "thermal", "performance-check", "screenshot", "logcat"):
        commands.add_parser(name)
    for name in ("launch", "stop", "tap", "swipe"):
        command = commands.add_parser(name)
        command.add_argument("--owner-approved", action="store_true")
        command.add_argument("--approval-id")
        command.add_argument("--dry-run", action="store_true")
        if name == "tap":
            command.add_argument("x", type=int)
            command.add_argument("y", type=int)
        elif name == "swipe":
            for coord in ("x1", "y1", "x2", "y2"):
                command.add_argument(coord, type=int)
            command.add_argument("--duration-ms", type=int, default=250)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return execute(args)
    except DeviceQaUnknown as error:
        return emit("UNKNOWN", args.action, reason=str(error))
    except DeviceQaFailure as error:
        return emit("FAIL", args.action, reason=str(error))
    except (OSError, ValueError, struct.error) as error:
        return emit("FAIL", args.action, reason=f"Local QA error: {type(error).__name__}.")


if __name__ == "__main__":
    sys.exit(main())

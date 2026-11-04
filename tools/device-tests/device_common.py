#!/usr/bin/env python3
"""Shared helpers for Layer Sort G1 Android device checks.

All device access goes through the existing ADB/Appium environment. The
caller (agentctl / phone-queue) owns the exclusive phone reservation.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Iterable

BASE = Path(os.environ.get("LAYER_SORT_DEVICE_TEST_BASE", "/root/device-tests"))
OUT = Path(os.environ.get("LAYER_SORT_RUN_DIR", str(BASE)))
PKG = os.environ.get("LAYER_SORT_PACKAGE", "com.yoseftext.layersort.dev")
READY_MARKER = os.environ.get("LAYER_SORT_READY_MARKER", "LAYER_SORT_G1_READY")
TAP_MARKER = os.environ.get("LAYER_SORT_TAP_MARKER", "LAYER_SORT_G1_TAP")
TICK_MARKER = os.environ.get("LAYER_SORT_TICK_MARKER", "LAYER_SORT_G1_TICK")
EXPECTED_GODOT = os.environ.get(
    "LAYER_SORT_GODOT_VERSION", "4.7.2.stable.official"
)
TERMUX_NOTIFY = Path("/data/data/com.termux/files/usr/bin/termux-notification")
PYTHON = Path(os.environ.get("LAYER_SORT_TEST_PYTHON", "/root/device-tests/.venv/bin/python"))

FATAL_PATTERNS = (
    "FATAL EXCEPTION",
    "Fatal signal",
    "libc: Fatal",
    "SCRIPT ERROR",
    "Parse Error",
    "Failed to load scene",
)


def adb(*args: str, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    """Run an adb command without raising on a non-zero status."""
    return subprocess.run(
        ["adb", *args],
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def adb_text(*args: str, timeout: int = 60) -> str:
    proc = adb(*args, timeout=timeout)
    return (proc.stdout or "") + (proc.stderr or "")


def connected_devices() -> list[str]:
    result: list[str] = []
    for line in adb("devices").stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            result.append(parts[0])
    return result


def ensure_device() -> list[str]:
    devices = connected_devices()
    if not devices:
        connector = shutil.which("phone-connect") or "/usr/local/bin/phone-connect"
        if Path(connector).exists():
            subprocess.run(
                [connector],
                text=True,
                capture_output=True,
                timeout=90,
                check=False,
            )
            devices = connected_devices()
    if len(devices) != 1:
        raise RuntimeError(f"Expected one connected phone, found {devices}")
    return devices


def clear_logcat() -> None:
    adb("logcat", "-c", timeout=30)


def logcat() -> str:
    return adb_text("logcat", "-d", "-v", "threadtime", timeout=60)


def wait_for_marker(
    marker: str,
    timeout: int = 30,
    minimum: int = 1,
) -> str:
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        text = logcat()
        last = text
        if text.count(marker) >= minimum:
            return text
        time.sleep(1)
    excerpt = "\n".join(last.splitlines()[-40:])
    raise RuntimeError(
        f"Timed out after {timeout}s waiting for {marker!r} "
        f"(minimum {minimum}). Last logcat:\n{excerpt}"
    )


def fatal_lines(text: str) -> list[str]:
    return [
        line
        for line in text.splitlines()
        if any(pattern in line for pattern in FATAL_PATTERNS)
    ]


def renderer_lines(text: str) -> list[str]:
    return [
        line
        for line in text.splitlines()
        if re.search(r"OpenGL|GLES|Vulkan|Compatibility", line, re.IGNORECASE)
        and "godot" in line.lower()
    ]


def godot_version_present(text: str) -> bool:
    return EXPECTED_GODOT in text


def force_stop(package: str = PKG) -> None:
    adb("shell", "am", "force-stop", package, timeout=30)


def close_app(package: str = PKG) -> None:
    try:
        force_stop(package)
    except Exception as exc:  # best-effort cleanup, always logged by caller
        print(f"GAME_CLOSE_WARNING: {exc}", flush=True)


def launch_via_monkey(package: str = PKG) -> None:
    adb(
        "shell",
        "monkey",
        "-p",
        package,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
        timeout=60,
    )


def pid_of(package: str = PKG) -> str:
    return adb_text("shell", "pidof", package, timeout=30).strip()


def device_info_text(package: str = PKG) -> str:
    commands: list[tuple[str, list[str]]] = [
        ("adb devices -l", ["devices", "-l"]),
        ("ro.product.model", ["shell", "getprop", "ro.product.model"]),
        ("ro.product.device", ["shell", "getprop", "ro.product.device"]),
        ("ro.build.version.release", ["shell", "getprop", "ro.build.version.release"]),
        ("ro.build.version.sdk", ["shell", "getprop", "ro.build.version.sdk"]),
        ("wm size", ["shell", "wm", "size"]),
        ("wm density", ["shell", "wm", "density"]),
        (
            "SurfaceOrientation",
            ["shell", "dumpsys", "input"],
        ),
        (
            "window focus",
            ["shell", "dumpsys", "window", "displays"],
        ),
        ("pm path", ["shell", "pm", "path", package]),
    ]
    chunks: list[str] = []
    for label, args in commands:
        text = adb_text(*args, timeout=60)
        if label in {"SurfaceOrientation", "window focus"}:
            lines = [
                line
                for line in text.splitlines()
                if re.search(r"SurfaceOrientation|mCurrentFocus|mFocusedApp|cur=", line)
            ]
            text = "\n".join(lines[:8])
        chunks.append(f"===== {label} =====\n{text.strip()}")
    return "\n\n".join(chunks) + "\n"


def package_info_text(package: str = PKG) -> str:
    return adb_text("shell", "dumpsys", "package", package, timeout=60)


def parse_package_info(text: str) -> dict[str, str]:
    fields = {
        "versionName": r"versionName=(\S+)",
        "versionCode": r"versionCode=(\d+)",
        "minSdk": r"minSdk=(\d+)",
        "targetSdk": r"targetSdk=(\d+)",
        "firstInstallTime": r"firstInstallTime=(.+)",
        "lastUpdateTime": r"lastUpdateTime=(.+)",
    }
    parsed: dict[str, str] = {}
    for name, pattern in fields.items():
        match = re.search(pattern, text)
        if match:
            parsed[name] = match.group(1).strip()
    return parsed


def screenshot_stats(path: Path) -> dict[str, Any]:
    """Return dimensions and coarse image statistics (requires Pillow)."""
    from PIL import Image, ImageStat

    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        mean = round(sum(ImageStat.Stat(rgb).mean) / 3.0, 2)
        small = rgb.resize((64, 64))
        colors = small.getcolors(maxcolors=4096) or []
        return {
            "width": width,
            "height": height,
            "mean_brightness": mean,
            "sampled_colors": len(colors),
        }


def image_digest(path: Path, crop: tuple[int, int, int, int] | None = None) -> str:
    from PIL import Image

    with Image.open(path) as image:
        rgb = image.convert("RGB")
        if crop is not None:
            rgb = rgb.crop(crop)
        return hashlib.sha256(rgb.tobytes()).hexdigest()


def save_text(name: str, text: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    path.write_text(text, encoding="utf-8")
    return path


def save_json(name: str, value: Any) -> Path:
    return save_text(name, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def save_legacy(kind: str, suffix: str, source: Path) -> None:
    """Keep the historical appium-<kind>-<suffix> filenames in BASE."""
    try:
        BASE.mkdir(parents=True, exist_ok=True)
        target = BASE / f"appium-{kind}-{suffix}"
        if source.resolve() != target.resolve():
            target.write_bytes(source.read_bytes())
    except Exception as exc:
        print(f"LEGACY_EVIDENCE_WARNING: {exc}", flush=True)


def save_screenshot(driver: Any, name: str, kind: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    if not driver.save_screenshot(str(path)):
        raise RuntimeError(f"Screenshot failed: {path}")
    save_legacy(kind, name, path)
    return path


def notify(title: str, content: str) -> None:
    if not TERMUX_NOTIFY.exists():
        print("NOTIFICATION_WARNING: termux-notification not available", flush=True)
        return
    try:
        subprocess.run(
            [
                str(TERMUX_NOTIFY),
                "--id",
                "4403" if "Smoke" in title else "4404",
                "--title",
                title,
                "--content",
                content,
                "--sound",
            ],
            text=True,
            capture_output=True,
            timeout=12,
            check=False,
        )
    except Exception as exc:
        print(f"NOTIFICATION_WARNING: {exc}", flush=True)


def appium_options(udid: str) -> Any:
    from appium.options.android import UiAutomator2Options

    return UiAutomator2Options().load_capabilities(
        {
            "platformName": "Android",
            "appium:automationName": "UiAutomator2",
            "appium:udid": udid,
            "appium:noReset": True,
            "appium:suppressKillServer": True,
            "appium:adbExecTimeout": 60000,
            "appium:newCommandTimeout": 180,
        }
    )


def orientation_from_adb() -> str:
    text = adb_text("shell", "dumpsys", "input", timeout=60)
    match = re.search(r"SurfaceOrientation:\s*(\d+)", text)
    if not match:
        return "UNKNOWN"
    return {
        "0": "PORTRAIT",
        "1": "LANDSCAPE",
        "2": "REVERSE_PORTRAIT",
        "3": "REVERSE_LANDSCAPE",
    }.get(match.group(1), f"ROTATION_{match.group(1)}")


def verify_common(
    driver: Any,
    log: str,
    screenshot: Path,
    *,
    require_tap: bool = False,
    tap_count: int = 0,
) -> dict[str, Any]:
    fatals = fatal_lines(log)
    if fatals:
        raise RuntimeError("Fatal log lines found: " + " | ".join(fatals[:5]))
    if not godot_version_present(log):
        raise RuntimeError(f"Godot {EXPECTED_GODOT} startup line is missing")

    if driver.current_package != PKG:
        raise RuntimeError(f"Foreground package is {driver.current_package!r}, not {PKG!r}")

    size = driver.get_window_size()
    if size["width"] >= size["height"]:
        raise RuntimeError(f"Window is not portrait: {size}")

    appium_orientation = str(driver.orientation).upper()
    adb_orientation = orientation_from_adb()
    if appium_orientation != "PORTRAIT":
        raise RuntimeError(f"Appium orientation is {appium_orientation}, not PORTRAIT")
    if adb_orientation not in {"PORTRAIT", "REVERSE_PORTRAIT"}:
        raise RuntimeError(f"ADB orientation is {adb_orientation}, not portrait")

    stats = screenshot_stats(screenshot)
    if stats["width"] >= stats["height"]:
        raise RuntimeError(f"Screenshot is not portrait: {stats}")
    if stats["mean_brightness"] < 5.0 or stats["sampled_colors"] < 4:
        raise RuntimeError(f"Screenshot looks blank/black: {stats}")

    result: dict[str, Any] = {
        "package": PKG,
        "foreground_package": driver.current_package,
        "appium_orientation": appium_orientation,
        "adb_orientation": adb_orientation,
        "window_size": size,
        "screenshot": stats,
        "godot_version": EXPECTED_GODOT,
        "renderer_evidence": renderer_lines(log)[:5],
        "tap_marker_count": log.count(TAP_MARKER),
        "tick_marker_count": log.count(TICK_MARKER),
        "ready_marker_count": log.count(READY_MARKER),
    }
    if require_tap and result["tap_marker_count"] < tap_count:
        raise RuntimeError(
            f"Touch marker {TAP_MARKER!r} count {result['tap_marker_count']} "
            f"is below required {tap_count}"
        )
    return result


def result_path(kind: str) -> Path:
    return BASE / f"appium-{kind}-status.json"


def finish(
    kind: str,
    result: dict[str, Any],
    *,
    driver: Any = None,
    log: str = "",
    screenshot: Path | None = None,
) -> None:
    """Persist evidence, close the app, notify, and exit."""
    if log:
        path = save_text("logcat.txt", log)
        save_legacy(kind, "logcat.txt", path)
    if screenshot is not None and screenshot.exists():
        save_legacy(kind, screenshot.name, screenshot)
    save_json("status.json", result)
    result_path(kind).write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        if driver is not None:
            driver.quit()
    except Exception as exc:
        print(f"SESSION_CLEANUP_WARNING: {exc}", flush=True)
    close_app()
    notify(
        f"Layer Sort {kind.title()} - {result.get('status', 'FAIL')}",
        result.get("reason") or f"Package {PKG}; see {OUT}",
    )
    raise SystemExit(0 if result.get("status") == "PASS" else 1)

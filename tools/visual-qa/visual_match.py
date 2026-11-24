#!/usr/bin/env python3
"""Find an approved template in a saved screenshot; never operate the phone."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import stat
import struct
from pathlib import Path
from typing import Any, Sequence

ROOT = Path(__file__).resolve().parents[2]
SCREENSHOTS = ROOT / ".runtime/device-qa"
TEMPLATES = ROOT / "tools/visual-qa/templates"
RUN = re.compile(r"[0-9]{8}T[0-9]{6}\.[0-9]{6}Z")
NAME = re.compile(r"[a-z0-9][a-z0-9_-]{0,39}")
MAX_BYTES = 16 * 1024 * 1024
MAX_PIXELS = 4 * 1024 * 1024
MAX_DIMENSION = 8192


class VisualError(ValueError):
    pass


def safe_png(root: Path, filename: Path) -> tuple[bytes, int, int]:
    """Read a bounded non-symlink PNG under the project, with a bounded header."""
    project = ROOT.resolve(strict=True)
    try:
        relative = filename.relative_to(project)
    except ValueError as error:
        raise VisualError("Image path escapes the project.") from error
    if not filename.is_relative_to(root):
        raise VisualError("Image path escapes its approved evidence directory.")
    current = project
    for part in relative.parts[:-1]:
        current = current / part
        if current.is_symlink() or not current.is_dir() or current.resolve(strict=True) != current:
            raise VisualError("Image parent directory is missing or unsafe.")
    try:
        fd = os.open(filename, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0))
        with os.fdopen(fd, "rb") as source:
            info = os.fstat(source.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or not 24 <= info.st_size <= MAX_BYTES:
                raise VisualError("Image is not a bounded regular file.")
            data = source.read(MAX_BYTES + 1)
    except OSError as error:
        raise VisualError("Image is missing or inaccessible.") from error
    if (len(data) > MAX_BYTES or len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or
            data[12:16] != b"IHDR"):
        raise VisualError("Image is not a bounded PNG.")
    width, height = struct.unpack(">II", data[16:24])
    if min(width, height) < 1 or max(width, height) > MAX_DIMENSION or width * height > MAX_PIXELS:
        raise VisualError("PNG dimensions exceed the supported bound.")
    return data, width, height


def match(run: str, template: str) -> dict[str, Any]:
    if not RUN.fullmatch(run) or not NAME.fullmatch(template):
        raise VisualError("Use an exact screenshot run ID and a simple approved template name.")
    screenshot, width, height = safe_png(SCREENSHOTS, SCREENSHOTS / run / "screen.png")
    sample, tw, th = safe_png(TEMPLATES, TEMPLATES / (template + ".png"))
    if tw > width or th > height:
        raise VisualError("Template is larger than the screenshot.")
    try:
        import cv2
        import numpy as np
    except ImportError as error:
        raise RuntimeError("Optional OpenCV/NumPy environment is unavailable.") from error
    if cv2.__version__ != "4.12.0" or np.__version__ != "2.2.6":
        raise RuntimeError("OpenCV/NumPy versions do not match the tested lockfile.")
    cv2.setNumThreads(1)
    try:
        image = cv2.imdecode(np.frombuffer(screenshot, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
        target = cv2.imdecode(np.frombuffer(sample, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
    except cv2.error as error:
        raise VisualError("PNG decoding failed.") from error
    if image is None or target is None or image.shape != (height, width) or target.shape != (th, tw):
        raise VisualError("PNG decoder could not establish the declared dimensions.")
    if float(target.std()) < 1.0:
        raise VisualError("Template is too uniform for reliable normalized matching.")
    try:
        scores = cv2.matchTemplate(image, target, cv2.TM_CCOEFF_NORMED)
        _, score, _, (x, y) = cv2.minMaxLoc(scores)
    except cv2.error as error:
        raise VisualError("Template comparison could not be completed.") from error
    if not math.isfinite(score):
        raise VisualError("Template match did not produce a finite score.")
    return {"status": "PASS", "action": "visual-match", "input_executed": False,
            "device_contacted": False, "source": "SAVED_SCREENSHOT_ORIGIN_UNVERIFIED",
            "screenshot_sha256": hashlib.sha256(screenshot).hexdigest(),
            "template_sha256": hashlib.sha256(sample).hexdigest(),
            "viewport": {"width": width, "height": height},
            "best_match": {"x": int(x), "y": int(y), "width": tw, "height": th, "score": round(float(score), 6)},
            "visual_verdict": "UNVERIFIED", "warning": "A best match is not proof of game state or a click target."}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--template", required=True)
    args = parser.parse_args(argv)
    try:
        result = match(args.run, args.template)
    except VisualError as error:
        result = {"status": "FAIL", "action": "visual-match", "reason": str(error), "device_contacted": False}
        print(json.dumps(result, sort_keys=True))
        return 1
    except RuntimeError as error:
        result = {"status": "UNVERIFIED", "action": "visual-match", "reason": str(error), "device_contacted": False}
        print(json.dumps(result, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

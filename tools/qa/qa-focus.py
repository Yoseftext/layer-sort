#!/usr/bin/env python3
"""Fail closed if an Appium touch run started on another app's screen.

Compares the stable G1 title crop, not the dynamic touch counter. This is a
project-local evidence guard, not a substitute for the Appium foreground check.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--before", type=Path, required=True)
p.add_argument("--reference", type=Path, required=True)
p.add_argument("--max-changed-fraction", type=float, default=0.02)
a = p.parse_args()
try:
    if not 0 <= a.max_changed_fraction <= 1:
        raise ValueError("fraction must be 0..1")
    with Image.open(a.before) as before, Image.open(a.reference) as reference:
        if before.size != reference.size:
            raise ValueError(f"size mismatch: before={before.size}, reference={reference.size}")
        crop = (100, 120, 620, 310)  # G1 title/subtitle, not button/counter
        diff = ImageChops.difference(before.convert("RGB").crop(crop), reference.convert("RGB").crop(crop))
        changed = sum(1 for px in diff.get_flattened_data() if max(px) > 20)
        fraction = changed / (diff.width * diff.height)
        ok = fraction <= a.max_changed_fraction
        detail = f"title crop changed fraction={fraction:.4f}; allowed={a.max_changed_fraction:.4f}"
except (OSError, ValueError) as exc:
    ok, detail = False, f"foreground evidence unavailable: {exc}"
print(json.dumps({"status": "PASS" if ok else "FAIL", "test": "G15-QA-001",
                  "detail": detail, "before": str(a.before), "reference": str(a.reference)}))
raise SystemExit(0 if ok else 1)

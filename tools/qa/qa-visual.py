#!/usr/bin/env python3
"""Deterministic screenshot checks; qualitative review requires image-read tool."""
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
python = Path(os.environ.get("LAYER_SORT_TEST_PYTHON", "/root/device-tests/.venv/bin/python"))
if len(sys.argv) == 1:
    sys.argv.append("--help")
args = [str(python), str(root / "tools/qa/qa.py"), "visual", *sys.argv[1:]]
raise SystemExit(subprocess.call(args))

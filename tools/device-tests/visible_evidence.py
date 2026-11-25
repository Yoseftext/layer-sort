"""Copy already-verified project evidence to the owner's visible phone folder."""
from __future__ import annotations

import hashlib
import os
import re
import uuid
from pathlib import Path

VISIBLE_ROOT = Path("/sdcard/Download/LayerSort")
CATEGORIES = {"apk": ("APKs", ".apk"), "screenshot": ("Screenshots", ".png"),
              "log": ("Reports", ".log")}


def publish(source: Path, kind: str, expected_sha256: str) -> dict[str, str]:
    """Preserve the source and never overwrite a previous visible file.

    This reports the separate copy outcome, not the validity of the underlying
    capture or build. Call only after the caller has verified its own evidence.
    """
    try:
        if kind not in CATEGORIES or not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
            raise ValueError("Invalid evidence type or digest")
        if source.is_symlink() or not source.is_file():
            raise ValueError("Evidence source is not a regular file")
        directory_name, extension = CATEGORIES[kind]
        VISIBLE_ROOT.mkdir(parents=True, exist_ok=True)
        if VISIBLE_ROOT.is_symlink() or not VISIBLE_ROOT.is_dir():
            raise ValueError("Visible evidence root is not a real directory")
        directory = VISIBLE_ROOT / directory_name
        directory.mkdir(exist_ok=True)
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError("Visible evidence category is not a real directory")
        destination = directory / (kind + "-" + expected_sha256[:12] + "-" + uuid.uuid4().hex[:12] + extension)
        digest = hashlib.sha256()
        with source.open("rb") as input_file, destination.open("xb") as output:
            for chunk in iter(lambda: input_file.read(1024 * 1024), b""):
                digest.update(chunk)
                output.write(chunk)
            output.flush()
            os.fsync(output.fileno())
        if digest.hexdigest() != expected_sha256:
            raise ValueError("Source digest changed while copying; retain copy for inspection")
        verify = hashlib.sha256()
        with destination.open("rb") as check:
            for chunk in iter(lambda: check.read(1024 * 1024), b""):
                verify.update(chunk)
        if verify.hexdigest() != expected_sha256:
            raise ValueError("Visible copy digest mismatch; retain copy for inspection")
        return {"status": "PASS", "path": str(destination), "sha256": expected_sha256}
    except (OSError, ValueError) as error:
        return {"status": "UNKNOWN", "reason": str(error)}

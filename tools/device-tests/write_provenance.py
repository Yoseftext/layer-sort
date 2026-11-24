#!/usr/bin/env python3
"""Create a build manifest only after the existing APK verification succeeds."""

import json
import os
import sys
from pathlib import Path

from artifact_qa import ArtifactError, build_manifest, expected_cert


def main() -> int:
    apk = Path("build/layer-sort-g3b-debug.apk")
    verification = Path("logs/apk-verification.txt")
    output = Path("build/apk-provenance.json")
    try:
        manifest = build_manifest(
            apk, verification.read_text(encoding="utf-8"),
            source_commit=os.environ.get("GITHUB_SHA", ""),
            run_id=os.environ.get("GITHUB_RUN_ID", ""),
            run_attempt=os.environ.get("GITHUB_RUN_ATTEMPT", ""),
            godot_version=os.environ.get("GODOT_VERSION_STRING", ""),
            cert=expected_cert(),
        )
        with output.open("x", encoding="utf-8") as target:
            json.dump(manifest, target, sort_keys=True, indent=2)
            target.write("\n")
    except (ArtifactError, OSError) as error:
        print("APK_PROVENANCE_FAIL: " + str(error), file=sys.stderr)
        return 1
    print("APK_PROVENANCE_PASS: " + manifest["source_commit"] + " " + manifest["apk_sha256"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

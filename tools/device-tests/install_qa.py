#!/usr/bin/env python3
"""Owner-operated, package-scoped debug APK hand-off. No arbitrary ADB entrypoint.

This proposed extension remains blocked by the Antigravity Hook. A local CLI
flag records an approval; it cannot establish that the owner actually approved
an operation. Review, tests, and exact owner authorization are prerequisites to
any real device run.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

import artifact_qa as artifact
import device_qa as device

PACKAGE = artifact.PACKAGE
# Android package-manager paths only, with no whitespace or shell metacharacters.
APK_PATH = re.compile(r"/data/app/[A-Za-z0-9_+./=~\-]+/base\.apk")


def installed_apk(serial: str, destination: Path) -> dict[str, Any] | None:
    """Read this package's base APK; no other package or phone state is changed."""
    packages = device.shell_text(serial, "pm", "list", "packages", PACKAGE)
    lines = [line.strip() for line in packages.splitlines() if line.strip()]
    if any(not re.fullmatch(r"package:[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+", line) for line in lines):
        raise device.DeviceQaUnknown("Installed package listing could not be interpreted.")
    matches = [line for line in lines if line == f"package:{PACKAGE}"]
    if not matches:
        return None
    if len(matches) != 1:
        raise device.DeviceQaUnknown("Installed package listing is ambiguous.")
    paths = device.shell_text(serial, "pm", "path", PACKAGE).splitlines()
    if len(paths) != 1 or not paths[0].startswith("package:"):
        raise device.DeviceQaUnknown("Installed package must have one readable base APK; splits are unsupported.")
    remote_path = paths[0][len("package:"):]
    if not APK_PATH.fullmatch(remote_path) or ".." in remote_path.split("/"):
        raise device.DeviceQaUnknown("Installed APK path is outside the supported package-manager format.")
    device.adb_call(serial, ["pull", remote_path, str(destination)], timeout=120)
    if not destination.is_file() or not 0 < destination.stat().st_size <= artifact.MAX_APK:
        raise device.DeviceQaUnknown("Installed APK could not be read or has an invalid size.")
    badging = artifact.command_output([artifact.AAPT, "dump", "badging", str(destination)])
    line = next((line for line in badging.splitlines() if line.startswith("package: ")), "")
    match = re.search(r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']*)'", line)
    if not match or match.group(1) != PACKAGE:
        raise device.DeviceQaFailure("Installed APK package identity differs from the approved debug package.")
    manifest = {"version_code": int(match.group(2)), "version_name": match.group(3)}
    # Also checks debug flag, fixed arm64 ABI, and one expected project signer.
    artifact.verify_apk(destination, manifest, artifact.expected_cert())
    return {"sha256": artifact.sha256_file(destination), **manifest}


def check_previous(actual: dict[str, Any] | None, *, expect_absent: bool,
                   installed_sha256: str | None, candidate_version: int) -> None:
    if expect_absent:
        if actual is not None:
            raise device.DeviceQaFailure("Package is already installed; the approved initial-install state differs.")
    else:
        if actual is None or actual["sha256"] != installed_sha256:
            raise device.DeviceQaFailure("Installed APK does not match the exact approved previous hash.")
        if actual["version_code"] > candidate_version:
            raise device.DeviceQaFailure("The requested APK would downgrade the installed version.")


def save_report(data: dict[str, Any]) -> str:
    """Write one private, append-only result under the existing evidence root."""
    artifact.prepare_cache_root()
    directory = artifact.CACHE_ROOT / "install-reports"
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.is_symlink() or not directory.is_dir() or directory.resolve(strict=True) != directory:
        raise device.DeviceQaUnknown("Installation report directory is unsafe.")
    fd, path = tempfile.mkstemp(prefix="install-", suffix=".json", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            json.dump(data, output, sort_keys=True)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
    except BaseException:
        # Retain an incomplete record for investigation; never overwrite a report.
        raise
    return path


def inspect_installed() -> int:
    with device.phone_lock(), tempfile.TemporaryDirectory(prefix="layer-sort-installed-") as temporary:
        serial = device.connected_serial(require_installed=False)
        info = installed_apk(serial, Path(temporary) / "installed.apk")
    return device.emit("PASS", "inspect-installed", installed=info is not None, installed_apk=info,
                       device_model=device.EXPECTED_DEVICE["model"], device_api=device.EXPECTED_DEVICE["android_api"])


def install(args: argparse.Namespace) -> int:
    action = "install-build"
    approval = device.require_approval(args, action)
    if approval == "SKIP":
        return 3
    if approval == "FAIL":
        return 1
    if args.dry_run:
        return device.emit("SKIP", action, reason="Dry run; no GitHub or device command executed.",
                           dry_run=True, mutation_executed=False)
    if not artifact.HEX64.fullmatch(args.apk_sha256):
        return device.emit("FAIL", action, reason="Expected APK SHA-256 must contain 64 lowercase hex digits.")
    if args.installed_sha256 is not None and not artifact.HEX64.fullmatch(args.installed_sha256):
        return device.emit("FAIL", action, reason="Previous APK SHA-256 must contain 64 lowercase hex digits.")
    record: dict[str, Any] = {
        "schema_version": 1, "action": action, "package_id": PACKAGE,
        "run_id": args.run_id, "source_commit": args.commit, "apk_sha256": args.apk_sha256,
        "approval_id": approval, "expect_absent": args.expect_absent,
        "expected_previous_sha256": args.installed_sha256,
        "device_model": device.EXPECTED_DEVICE["model"], "device_api": device.EXPECTED_DEVICE["android_api"],
        "mutation_attempted": False, "status": "UNKNOWN",
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
    }
    try:
        with artifact.verified_cached_build(args.run_id, args.commit, args.apk_sha256) as (apk, manifest):
            with device.phone_lock(), tempfile.TemporaryDirectory(prefix="layer-sort-install-check-") as temporary:
                serial = device.connected_serial(require_installed=False)
                before = installed_apk(serial, Path(temporary) / "before.apk")
                check_previous(before, expect_absent=args.expect_absent, installed_sha256=args.installed_sha256,
                               candidate_version=manifest["version_code"])
                record["previous_apk"] = before
                record["candidate_version_code"] = manifest["version_code"]
                # A timeout after this point has an UNKNOWN result: do not retry,
                # uninstall, clear data, or assume the operation did not happen.
                record["mutation_attempted"] = True
                # Persist an UNKNOWN preflight marker before the device call. If
                # the process is interrupted, there is still an audit trail.
                record["preflight_report_path"] = save_report(record)
                output = device.adb_call(serial, ["install", "-r", str(apk)], timeout=180)
                lines = output.strip().splitlines() if isinstance(output, str) else []
                if (not lines or lines[-1] != "Success" or
                        any(line not in {"Success", "Performing Streamed Install", "Performing Push Install"}
                            for line in lines)):
                    raise device.DeviceQaUnknown("Android did not confirm a successful install; inspect the device.")
                after = installed_apk(serial, Path(temporary) / "after.apk")
                if after is None or after["sha256"] != args.apk_sha256 or after["version_code"] != manifest["version_code"]:
                    raise device.DeviceQaFailure("Installed APK does not match the approved candidate after installation.")
                record["installed_apk"] = after
                record["status"] = "PASS"
    except (device.DeviceQaFailure, artifact.ArtifactError) as error:
        record.update(status="FAIL", reason=str(error))
    except (device.DeviceQaUnknown, OSError, zipfile.BadZipFile) as error:
        record.update(status="UNKNOWN", reason=str(error) if isinstance(error, device.DeviceQaUnknown)
                      else "Verification or installation could not be completed.")
    try:
        path = save_report(record)
    except OSError:
        return device.emit("UNKNOWN", action, reason="Could not save installation evidence; inspect the device.",
                           mutation_attempted=record["mutation_attempted"])
    except (device.DeviceQaUnknown, artifact.ArtifactError) as error:
        return device.emit("UNKNOWN", action, reason=str(error), mutation_attempted=record["mutation_attempted"])
    return device.emit(record["status"], action, **{key: value for key, value in record.items()
                       if key not in {"status", "action", "package_id", "timestamp_utc", "schema_version"}},
                       report_path=path)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Proposed owner-operated Layer Sort debug APK hand-off")
    sub = result.add_subparsers(dest="action", required=True)
    sub.add_parser("inspect-installed", help="Read the current debug APK identity on the approved device")
    command = sub.add_parser("install-build", help="Install the exact verified candidate after owner authorization")
    command.add_argument("--run-id", required=True)
    command.add_argument("--commit", required=True)
    command.add_argument("--apk-sha256", required=True)
    state = command.add_mutually_exclusive_group(required=True)
    state.add_argument("--expect-absent", action="store_true")
    state.add_argument("--installed-sha256")
    command.add_argument("--owner-approved", action="store_true")
    command.add_argument("--approval-id")
    command.add_argument("--dry-run", action="store_true")
    return result


def main(argv: Sequence[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        return inspect_installed() if args.action == "inspect-installed" else install(args)
    except (device.DeviceQaFailure, artifact.ArtifactError) as error:
        return device.emit("FAIL", args.action, reason=str(error))
    except (device.DeviceQaUnknown, OSError, zipfile.BadZipFile) as error:
        return device.emit("UNKNOWN", args.action, reason=str(error) if isinstance(error, device.DeviceQaUnknown)
                           else "Device inspection could not be completed.")


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify the exact GitHub Actions debug APK before any phone operation.

The downloaded artifact and its manifest are evidence, not authorization to
install. Only completed successful push/dispatch runs from this repository and
workflow are eligible. No phone command is executed by this module.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import selectors
import shutil
import stat
import subprocess
import tempfile
import time
import zipfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import visible_evidence

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "Yoseftext/layer-sort"
WORKFLOW = ".github/workflows/android-build-g3b.yml"
PACKAGE = "com.yoseftext.layersort.dev"
ARTIFACT = "layer-sort-g3b-debug-apk"
APK_NAME = "layer-sort-g3b-debug.apk"
MANIFEST_NAME = "apk-provenance.json"
ARCHIVE_NAME = "artifact.zip"
EXPECTED_CERT_FILE = ROOT / "tools/device-tests/expected-debug-cert.sha256"
CACHE_ROOT = ROOT / ".runtime/device-qa/artifacts"
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
MAX_ARCHIVE = 128 * 1024 * 1024
MAX_APK = 128 * 1024 * 1024
MAX_MANIFEST = 32 * 1024
GH = "/usr/bin/gh"
AAPT = "/usr/bin/aapt"
APKSIGNER = "/usr/bin/apksigner"


class ArtifactError(Exception):
    """Artifact evidence failed a verifiable requirement."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_cert(path: Path = EXPECTED_CERT_FILE) -> str:
    value = path.read_text(encoding="ascii").strip().replace(":", "").lower()
    if not HEX64.fullmatch(value):
        raise ArtifactError("The project's expected signing certificate is invalid.")
    return value


def parse_verification(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if lines.count("APK_VERIFY_PASS") != 1:
        raise ArtifactError("APK verification did not produce exactly one PASS marker.")
    wanted = {"apk_sha256", "package", "version_name", "version_code", "signing_cert_sha256"}
    fields: dict[str, str] = {}
    for line in lines:
        key, separator, value = line.partition("=")
        if separator and key in wanted:
            if key in fields:
                raise ArtifactError("APK verification contains duplicate identity fields.")
            fields[key] = value.strip()
    if set(fields) != wanted:
        raise ArtifactError("APK verification is missing identity fields.")
    return fields


def build_manifest(apk: Path, verification: str, *, source_commit: str,
                   run_id: str, run_attempt: str, godot_version: str,
                   cert: str) -> dict[str, Any]:
    fields = parse_verification(verification)
    digest = sha256_file(apk)
    if not HEX40.fullmatch(source_commit) or not re.fullmatch(r"[1-9][0-9]{0,19}", run_id):
        raise ArtifactError("Invalid source commit or run ID.")
    if not re.fullmatch(r"[1-9][0-9]{0,5}", run_attempt):
        raise ArtifactError("Invalid run attempt.")
    if fields["package"] != PACKAGE or fields["apk_sha256"] != digest:
        raise ArtifactError("APK identity or hash does not match verified output.")
    if fields["signing_cert_sha256"].lower() != cert or not HEX64.fullmatch(cert):
        raise ArtifactError("APK certificate does not match the project certificate.")
    if not re.fullmatch(r"[1-9][0-9]{0,9}", fields["version_code"]):
        raise ArtifactError("APK version code is invalid.")
    if not re.fullmatch(r"[A-Za-z0-9._+-]{1,64}", fields["version_name"]):
        raise ArtifactError("APK version name is invalid.")
    if not re.fullmatch(r"[A-Za-z0-9._+-]{1,64}", godot_version):
        raise ArtifactError("Godot version is invalid.")
    size = apk.stat().st_size
    if not 0 < size <= MAX_APK:
        raise ArtifactError("APK size is outside the accepted range.")
    return {
        "schema_version": 1, "repository": REPOSITORY, "workflow": WORKFLOW,
        "source_commit": source_commit, "run_id": int(run_id), "run_attempt": int(run_attempt),
        "package_id": PACKAGE, "version_code": int(fields["version_code"]),
        "version_name": fields["version_name"], "signing_cert_sha256": cert,
        "apk_sha256": digest, "apk_size_bytes": size, "apk_name": APK_NAME,
        "godot_version": godot_version, "abi": "arm64-v8a", "variant": "debug",
    }


def inspect_run(run: dict[str, Any], run_id: str, commit: str) -> None:
    if not re.fullmatch(r"[1-9][0-9]{0,19}", run_id) or not HEX40.fullmatch(commit):
        raise ArtifactError("Invalid run ID or commit SHA.")
    if (type(run.get("id")) is not int or run["id"] != int(run_id) or run.get("status") != "completed" or
            run.get("conclusion") != "success" or run.get("event") not in {"push", "workflow_dispatch"} or
            run.get("head_sha") != commit or run.get("path") != WORKFLOW or
            (run.get("repository") or {}).get("full_name", "").lower() != REPOSITORY.lower()):
        raise ArtifactError("GitHub run is not a successful exact-commit build from the approved workflow.")
    if type(run.get("run_attempt")) is not int or run["run_attempt"] < 1:
        raise ArtifactError("GitHub did not provide a valid run attempt.")


def select_artifact(data: dict[str, Any]) -> dict[str, Any]:
    artifacts = data.get("artifacts")
    if not isinstance(artifacts, list):
        raise ArtifactError("GitHub artifact list is unavailable.")
    matches = [item for item in artifacts if isinstance(item, dict) and item.get("name") == ARTIFACT]
    if len(matches) != 1:
        raise ArtifactError("Expected exactly one debug APK artifact.")
    item = matches[0]
    digest = item.get("digest")
    if (item.get("expired") is not False or type(item.get("id")) is not int or item["id"] < 1 or
            type(item.get("size_in_bytes")) is not int or not 0 < item["size_in_bytes"] <= MAX_ARCHIVE or
            not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest)):
        raise ArtifactError("Artifact is expired, oversized, or missing its GitHub SHA-256 digest.")
    return item


def extract_artifact(archive_path: Path, destination: Path) -> None:
    """Extract only the two expected flat files; never use extractall."""
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        if len(entries) != 2 or {entry.filename for entry in entries} != {APK_NAME, MANIFEST_NAME}:
            raise ArtifactError("Artifact must contain exactly the debug APK and provenance manifest.")
        for entry in entries:
            limit = MAX_APK if entry.filename == APK_NAME else MAX_MANIFEST
            mode = (entry.external_attr >> 16) & 0xFFFF
            if entry.is_dir() or (mode and stat.S_ISLNK(mode)) or not 0 < entry.file_size <= limit:
                raise ArtifactError("Artifact contains an invalid or oversized file.")
            with archive.open(entry) as source, (destination / entry.filename).open("xb") as target:
                shutil.copyfileobj(source, target, length=1024 * 1024)


def inspect_manifest(manifest: Any, *, run: dict[str, Any], run_id: str,
                     commit: str, apk: Path, cert: str) -> None:
    if not isinstance(manifest, dict):
        raise ArtifactError("Provenance manifest is not an object.")
    expected = {
        "schema_version": 1, "repository": REPOSITORY, "workflow": WORKFLOW,
        "source_commit": commit, "run_id": int(run_id), "run_attempt": run["run_attempt"],
        "package_id": PACKAGE, "signing_cert_sha256": cert, "apk_name": APK_NAME,
        "abi": "arm64-v8a", "variant": "debug", "apk_size_bytes": apk.stat().st_size,
        "apk_sha256": sha256_file(apk),
    }
    if (any(type(manifest.get(key)) is not int for key in ("schema_version", "run_id", "run_attempt", "apk_size_bytes")) or
            any(manifest.get(key) != value for key, value in expected.items())):
        raise ArtifactError("Provenance does not match the selected run, source, APK, or certificate.")
    if (type(manifest.get("version_code")) is not int or manifest["version_code"] < 1 or
            not isinstance(manifest.get("version_name"), str) or
            not re.fullmatch(r"[A-Za-z0-9._+-]{1,64}", manifest["version_name"]) or
            not isinstance(manifest.get("godot_version"), str) or
            not re.fullmatch(r"[A-Za-z0-9._+-]{1,64}", manifest["godot_version"])):
        raise ArtifactError("Provenance version fields are invalid.")


def command_output(arguments: list[str], *, timeout: int = 30) -> str:
    try:
        result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ArtifactError("A required verification tool was unavailable or timed out.") from error
    if result.returncode != 0 or len(result.stdout) > 1024 * 1024:
        raise ArtifactError("A required verification tool did not succeed.")
    return result.stdout.decode("utf-8", errors="replace")


def verify_apk(apk: Path, manifest: dict[str, Any], cert: str) -> None:
    badging = command_output([AAPT, "dump", "badging", str(apk)])
    first = next((line for line in badging.splitlines() if line.startswith("package: ")), "")
    match = re.search(r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']*)'", first)
    if (not match or match.group(1) != PACKAGE or int(match.group(2)) != manifest["version_code"] or
            match.group(3) != manifest["version_name"] or
            not any(line.strip() == "application-debuggable" for line in badging.splitlines()) or
            not any(line.strip() == "native-code: 'arm64-v8a'" for line in badging.splitlines())):
        raise ArtifactError("APK package, version, ABI, or debug flag does not match provenance.")
    signing = command_output([APKSIGNER, "verify", "--verbose", "--print-certs", str(apk)])
    digests = re.findall(r"(?im)^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-f:]+)\s*$", signing)
    if "Verifies" not in signing or len(digests) != 1 or digests[0].replace(":", "").lower() != cert:
        raise ArtifactError("APK signature verification or signing certificate did not match.")


def gh_json(endpoint: str) -> dict[str, Any]:
    try:
        value = json.loads(command_output([GH, "api", "--method", "GET", endpoint]))
    except json.JSONDecodeError as error:
        raise ArtifactError("GitHub returned invalid JSON.") from error
    if not isinstance(value, dict):
        raise ArtifactError("GitHub returned an invalid object.")
    return value


def download_archive(artifact_id: int, output_path: Path, *, timeout: int = 600) -> None:
    """Bound both time and bytes while streaming, including when GitHub stalls."""
    command = [GH, "api", "--method", "GET", f"repos/{REPOSITORY}/actions/artifacts/{artifact_id}/zip"]
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as error:
        raise ArtifactError("Artifact download was unavailable.") from error
    deadline = time.monotonic() + timeout
    count = 0
    try:
        assert process.stdout is not None
        with selectors.DefaultSelector() as selector, output_path.open("xb") as output:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ArtifactError("Artifact download timed out.")
                if not selector.select(timeout=remaining):
                    raise ArtifactError("Artifact download timed out.")
                chunk = os.read(process.stdout.fileno(), 1024 * 1024)
                if not chunk:
                    break
                count += len(chunk)
                if count > MAX_ARCHIVE:
                    raise ArtifactError("Artifact download exceeds the size limit.")
                output.write(chunk)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ArtifactError("Artifact download timed out.")
        try:
            status = process.wait(timeout=remaining)
        except subprocess.TimeoutExpired as error:
            raise ArtifactError("Artifact download timed out.") from error
        if status != 0 or count == 0:
            raise ArtifactError("Artifact download did not succeed.")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        if process.stdout is not None:
            process.stdout.close()


def prepare_cache_root() -> None:
    """Reject symlinked parents before creating any nested evidence directory."""
    root = ROOT.resolve(strict=True)
    try:
        parts = CACHE_ROOT.relative_to(root).parts
    except ValueError as error:
        raise ArtifactError("Artifact evidence directory escapes the worktree.") from error
    if not parts:
        raise ArtifactError("Artifact evidence directory cannot be the worktree root.")
    current = root
    for part in parts:
        current = current / part
        try:
            current.mkdir(mode=0o700)
        except FileExistsError:
            pass
        if current.is_symlink() or not current.is_dir() or current.resolve(strict=True) != current:
            raise ArtifactError("Artifact evidence directory contains a symlink or non-directory.")


def download_artifact(run_id: str, commit: str) -> dict[str, Any]:
    if not re.fullmatch(r"[1-9][0-9]{0,19}", run_id) or not HEX40.fullmatch(commit):
        raise ArtifactError("Invalid run ID or commit SHA.")
    run = gh_json(f"repos/{REPOSITORY}/actions/runs/{run_id}")
    inspect_run(run, run_id, commit)
    artifact = select_artifact(gh_json(f"repos/{REPOSITORY}/actions/runs/{run_id}/artifacts?per_page=100"))
    cert = expected_cert()
    prepare_cache_root()
    destination = CACHE_ROOT / f"run-{run_id}-attempt-{run['run_attempt']}"
    if os.path.lexists(destination):
        raise ArtifactError("Artifact evidence already exists; refusing to overwrite it.")
    with tempfile.TemporaryDirectory(prefix="fetch-", dir=CACHE_ROOT) as temporary:
        stage = Path(temporary)
        archive_path = stage / "artifact.zip"
        download_archive(artifact["id"], archive_path)
        if "sha256:" + sha256_file(archive_path) != artifact["digest"]:
            raise ArtifactError("Downloaded artifact archive digest does not match GitHub.")
        extracted = stage / "verified"
        extracted.mkdir(mode=0o700)
        extract_artifact(archive_path, extracted)
        try:
            manifest = json.loads((extracted / MANIFEST_NAME).read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as error:
            raise ArtifactError("Provenance manifest is invalid JSON.") from error
        apk = extracted / APK_NAME
        inspect_manifest(manifest, run=run, run_id=run_id, commit=commit, apk=apk, cert=cert)
        verify_apk(apk, manifest, cert)
        # Reserve the final name exclusively, so parallel runs never overwrite
        # one another's evidence. An interrupted partial directory is retained.
        try:
            destination.mkdir(mode=0o700)
        except FileExistsError as error:
            raise ArtifactError("Artifact evidence already exists; refusing to overwrite it.") from error
        for name in (APK_NAME, MANIFEST_NAME):
            os.rename(extracted / name, destination / name)
        # Retain the authenticated archive so a later, separately authorized
        # device hand-off can verify the GitHub digest again immediately before
        # use rather than trusting mutable, locally extracted evidence.
        os.rename(archive_path, destination / ARCHIVE_NAME)
    return {"status": "PASS", "action": "fetch-build", "run_id": int(run_id),
            "run_attempt": run["run_attempt"], "source_commit": commit,
            "apk_path": str(destination / APK_NAME), "apk_sha256": manifest["apk_sha256"],
            "package_id": PACKAGE, "version_code": manifest["version_code"],
            "version_name": manifest["version_name"], "signing_cert_sha256": cert,
            "installed": False, "device_tested": False,
            "visible_export": visible_evidence.publish(destination / APK_NAME, "apk", manifest["apk_sha256"])}


@contextmanager
def verified_cached_build(run_id: str, commit: str, apk_sha256: str) -> Iterator[tuple[Path, dict[str, Any]]]:
    """Revalidate one cached archive against GitHub and yield a private APK copy.

    The caller must not use the cached extracted APK: the archive digest is the
    remote authenticated evidence. The temporary copy is verified independently
    and exists only for the duration of the hand-off.
    """
    if (not re.fullmatch(r"[1-9][0-9]{0,19}", run_id) or not HEX40.fullmatch(commit) or
            not HEX64.fullmatch(apk_sha256)):
        raise ArtifactError("Invalid run ID, commit, or expected APK SHA-256.")
    run = gh_json(f"repos/{REPOSITORY}/actions/runs/{run_id}")
    inspect_run(run, run_id, commit)
    artifact = select_artifact(gh_json(f"repos/{REPOSITORY}/actions/runs/{run_id}/artifacts?per_page=100"))
    cert = expected_cert()
    prepare_cache_root()
    directory = CACHE_ROOT / f"run-{run_id}-attempt-{run['run_attempt']}"
    if directory.is_symlink() or not directory.is_dir() or directory.resolve(strict=True) != directory:
        raise ArtifactError("Verified artifact cache is absent or unsafe; fetch this exact run first.")
    archive_path = directory / ARCHIVE_NAME
    try:
        info = archive_path.lstat()
    except FileNotFoundError as error:
        raise ArtifactError("Verified archive is absent; fetch a new build with archive retention.") from error
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or not 0 < info.st_size <= MAX_ARCHIVE:
        raise ArtifactError("Verified artifact archive is not a safe regular file.")
    with tempfile.TemporaryDirectory(prefix="handoff-", dir=CACHE_ROOT) as temporary:
        stage = Path(temporary)
        private_archive = stage / ARCHIVE_NAME
        # Bound the copy even if a same-user process changes the source file.
        fd = os.open(archive_path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0))
        with os.fdopen(fd, "rb") as source, private_archive.open("xb") as target:
            source_info = os.fstat(source.fileno())
            if not stat.S_ISREG(source_info.st_mode) or source_info.st_nlink != 1:
                raise ArtifactError("Cached artifact archive changed during verification.")
            size = 0
            while chunk := source.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_ARCHIVE:
                    raise ArtifactError("Cached artifact archive exceeds the size limit.")
                target.write(chunk)
        if "sha256:" + sha256_file(private_archive) != artifact["digest"]:
            raise ArtifactError("Cached artifact archive no longer matches GitHub.")
        extracted = stage / "verified"
        extracted.mkdir(mode=0o700)
        extract_artifact(private_archive, extracted)
        try:
            manifest = json.loads((extracted / MANIFEST_NAME).read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as error:
            raise ArtifactError("Provenance manifest is invalid JSON.") from error
        apk = extracted / APK_NAME
        inspect_manifest(manifest, run=run, run_id=run_id, commit=commit, apk=apk, cert=cert)
        if manifest["apk_sha256"] != apk_sha256:
            raise ArtifactError("APK SHA-256 does not match the approved exact build.")
        verify_apk(apk, manifest, cert)
        yield apk, manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch and verify one exact Layer Sort debug APK build.")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    try:
        result = download_artifact(args.run_id, args.commit)
    except (ArtifactError, OSError, zipfile.BadZipFile) as error:
        # Do not print subprocess output, credentials, device details or tracebacks.
        message = str(error) if isinstance(error, ArtifactError) else "Artifact verification could not complete."
        print(json.dumps({"status": "FAIL", "action": "fetch-build", "reason": message}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

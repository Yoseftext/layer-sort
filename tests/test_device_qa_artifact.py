from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("artifact_qa", ROOT / "tools/device-tests/artifact_qa.py")
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)

COMMIT = "a" * 40
CERT = "b" * 64
RUN_ID = "12345"


def verification(apk: Path) -> str:
    return ("APK_VERIFY_PASS\n"
            f"apk_sha256={hashlib.sha256(apk.read_bytes()).hexdigest()}\n"
            f"package={module.PACKAGE}\nversion_name=0.3.2-g3b\nversion_code=5\n"
            f"signing_cert_sha256={CERT}\n")


def run_info() -> dict:
    return {"id": int(RUN_ID), "run_attempt": 1, "status": "completed", "conclusion": "success",
            "event": "push", "head_sha": COMMIT, "path": module.WORKFLOW,
            "repository": {"full_name": module.REPOSITORY}}


class ArtifactQaTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / module.APK_NAME
        self.apk.write_bytes(b"test apk bytes")

    def manifest(self) -> dict:
        return module.build_manifest(self.apk, verification(self.apk), source_commit=COMMIT,
                                     run_id=RUN_ID, run_attempt="1", godot_version="4.7.2.stable.official",
                                     cert=CERT)

    def archive(self, manifest: dict | None = None) -> bytes:
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(module.APK_NAME, self.apk.read_bytes())
            archive.writestr(module.MANIFEST_NAME, json.dumps(manifest or self.manifest()))
        return output.getvalue()

    def test_manifest_uses_verified_bytes_and_identity(self) -> None:
        manifest = self.manifest()
        self.assertEqual(manifest["apk_sha256"], hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(manifest["package_id"], module.PACKAGE)
        self.assertEqual(manifest["version_code"], 5)
        module.inspect_manifest(manifest, run=run_info(), run_id=RUN_ID, commit=COMMIT, apk=self.apk, cert=CERT)
        for changed in ({"source_commit": "c" * 40}, {"run_attempt": 2},
                        {"apk_sha256": "d" * 64}, {"package_id": "other.app"},
                        {"signing_cert_sha256": "c" * 64}, {"variant": "release"},
                        {"version_code": True}, {"run_id": True}):
            with self.subTest(changed=changed), self.assertRaises(module.ArtifactError):
                module.inspect_manifest(manifest | changed, run=run_info(), run_id=RUN_ID,
                                        commit=COMMIT, apk=self.apk, cert=CERT)

    def test_manifest_rejects_unverified_or_duplicate_fields(self) -> None:
        for data in (verification(self.apk).replace("APK_VERIFY_PASS", "FAIL"),
                     verification(self.apk) + "package=other.app\n",
                     verification(self.apk).replace(CERT, "c" * 64)):
            with self.subTest(data=data), self.assertRaises(module.ArtifactError):
                module.build_manifest(self.apk, data, source_commit=COMMIT, run_id=RUN_ID,
                                      run_attempt="1", godot_version="4.7.2", cert=CERT)

    def test_ci_writer_produces_manifest_only_from_verified_output(self) -> None:
        build = self.root / "build"
        logs = self.root / "logs"
        build.mkdir()
        logs.mkdir()
        apk = build / module.APK_NAME
        apk.write_bytes(self.apk.read_bytes())
        project_cert = (ROOT / "tools/device-tests/expected-debug-cert.sha256").read_text().strip().lower()
        verified = verification(apk).replace(CERT, project_cert)
        (logs / "apk-verification.txt").write_text(verified)
        env = {**os.environ, "GITHUB_SHA": COMMIT, "GITHUB_RUN_ID": RUN_ID,
               "GITHUB_RUN_ATTEMPT": "1", "GODOT_VERSION_STRING": "4.7.2.stable.official"}
        script = ROOT / "tools/device-tests/write_provenance.py"
        result = subprocess.run(["/usr/bin/python3", str(script)], cwd=self.root, env=env,
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads((build / module.MANIFEST_NAME).read_text())
        self.assertEqual(manifest["apk_sha256"], hashlib.sha256(apk.read_bytes()).hexdigest())
        self.assertEqual(manifest["signing_cert_sha256"], project_cert)
        second = subprocess.run(["/usr/bin/python3", str(script)], cwd=self.root, env=env,
                                capture_output=True, text=True, check=False)
        self.assertNotEqual(second.returncode, 0, "existing provenance must not be overwritten")

    def test_run_requires_exact_successful_source_and_workflow(self) -> None:
        module.inspect_run(run_info(), RUN_ID, COMMIT)
        for changes in ({"status": "in_progress"}, {"conclusion": "failure"},
                        {"event": "pull_request"}, {"head_sha": "c" * 40},
                        {"path": ".github/workflows/other.yml"}, {"run_attempt": True},
                        {"repository": {"full_name": "other/repo"}}):
            with self.subTest(changes=changes), self.assertRaises(module.ArtifactError):
                module.inspect_run(run_info() | changes, RUN_ID, COMMIT)

    def test_archive_rejects_extra_or_unsafe_entries(self) -> None:
        for name in ("../elsewhere", "unexpected.txt", "/tmp/other"):
            archive_path = self.root / "artifact.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr(module.APK_NAME, b"apk")
                archive.writestr(name, b"unwanted")
            out = self.root / "out"
            out.mkdir(exist_ok=True)
            with self.subTest(name=name), self.assertRaises(module.ArtifactError):
                module.extract_artifact(archive_path, out)
            self.assertFalse((self.root / "elsewhere").exists())

    def test_signature_and_debug_package_are_independently_verified(self) -> None:
        manifest = self.manifest()
        badging = (f"package: name='{module.PACKAGE}' versionCode='5' versionName='0.3.2-g3b'\n"
                   "application-debuggable\nnative-code: 'arm64-v8a'\n")
        signing = f"Verifies\nSigner #1 certificate SHA-256 digest: {CERT}\n"
        with patch.object(module, "command_output", side_effect=[badging, signing]):
            module.verify_apk(self.apk, manifest, CERT)
        for badging_value, signing_value in (
            (badging.replace(module.PACKAGE, "other.app"), signing),
            (badging.replace("application-debuggable\n", ""), signing),
            (badging.replace("arm64-v8a", "x86_64"), signing),
            (badging, signing.replace(CERT, "c" * 64)),
            (badging, signing + f"Signer #2 certificate SHA-256 digest: {CERT}\n"),
        ):
            with self.subTest(badging=badging_value, signing=signing_value):
                with patch.object(module, "command_output", side_effect=[badging_value, signing_value]):
                    with self.assertRaises(module.ArtifactError):
                        module.verify_apk(self.apk, manifest, CERT)

    def test_artifact_selection_rejects_ambiguous_or_unverified_archive(self) -> None:
        good = {"id": 1, "name": module.ARTIFACT, "expired": False, "size_in_bytes": 4,
                "digest": "sha256:" + "d" * 64}
        self.assertEqual(module.select_artifact({"artifacts": [good]}), good)
        for entries in ([], [good, good], [good | {"expired": True}], [good | {"digest": None}],
                        [good | {"size_in_bytes": module.MAX_ARCHIVE + 1}]):
            with self.subTest(entries=entries), self.assertRaises(module.ArtifactError):
                module.select_artifact({"artifacts": entries})

    def test_download_stream_is_bounded_by_size_and_time(self) -> None:
        fake_gh = self.root / "fake-gh"
        fake_gh.write_text("#!/usr/bin/python3\nimport sys\nsys.stdout.buffer.write(b'0123456789')\n")
        fake_gh.chmod(0o700)
        with patch.object(module, "GH", str(fake_gh)), patch.object(module, "MAX_ARCHIVE", 4):
            with self.assertRaisesRegex(module.ArtifactError, "size limit"):
                module.download_archive(77, self.root / "too-large.zip", timeout=3)
        fake_gh.write_text("#!/usr/bin/python3\nimport time\ntime.sleep(3)\n")
        with patch.object(module, "GH", str(fake_gh)):
            with self.assertRaisesRegex(module.ArtifactError, "timed out"):
                module.download_archive(77, self.root / "stalled.zip", timeout=0.2)

    def test_cache_rejects_symlink_before_creating_outside_directory(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        project = self.root / "project"
        project.mkdir()
        (project / ".runtime").symlink_to(outside, target_is_directory=True)
        with patch.object(module, "ROOT", project), patch.object(module, "CACHE_ROOT", project / ".runtime/qa/artifacts"):
            with self.assertRaises(module.ArtifactError):
                module.prepare_cache_root()
        self.assertEqual(list(outside.iterdir()), [])

    def test_fetch_verifies_full_chain_and_never_overwrites(self) -> None:
        zip_bytes = self.archive()
        artifact = {"id": 77, "name": module.ARTIFACT, "expired": False,
                    "size_in_bytes": len(zip_bytes), "digest": "sha256:" + hashlib.sha256(zip_bytes).hexdigest()}

        def fake_gh(endpoint: str) -> dict:
            return {"artifacts": [artifact]} if "artifacts?" in endpoint else run_info()

        def fake_download(artifact_id, output_path):
            self.assertEqual(artifact_id, 77)
            output_path.write_bytes(zip_bytes)

        badging = (f"package: name='{module.PACKAGE}' versionCode='5' versionName='0.3.2-g3b'\n"
                   "application-debuggable\nnative-code: 'arm64-v8a'\n")
        signing = f"Verifies\nSigner #1 certificate SHA-256 digest: {CERT}\n"
        cache = self.root / "cache"
        with (patch.object(module, "ROOT", self.root), patch.object(module, "CACHE_ROOT", cache),
              patch.object(module, "expected_cert", return_value=CERT), patch.object(module, "gh_json", side_effect=fake_gh),
              patch.object(module, "download_archive", side_effect=fake_download),
              patch.object(module, "command_output", side_effect=[badging, signing])):
            result = module.download_artifact(RUN_ID, COMMIT)
            self.assertEqual(result["status"], "PASS")
            self.assertFalse(result["installed"])
            self.assertFalse(result["device_tested"])
            self.assertEqual(Path(result["apk_path"]).read_bytes(), self.apk.read_bytes())
            with self.assertRaises(module.ArtifactError):
                module.download_artifact(RUN_ID, COMMIT)

    def test_fetch_rejects_archive_digest_mismatch_before_extraction(self) -> None:
        zip_bytes = self.archive()
        artifact = {"id": 77, "name": module.ARTIFACT, "expired": False,
                    "size_in_bytes": len(zip_bytes), "digest": "sha256:" + "0" * 64}

        def fake_gh(endpoint: str) -> dict:
            return {"artifacts": [artifact]} if "artifacts?" in endpoint else run_info()

        def fake_download(artifact_id, output_path):
            self.assertEqual(artifact_id, 77)
            output_path.write_bytes(zip_bytes)

        cache = self.root / "cache"
        with (patch.object(module, "ROOT", self.root), patch.object(module, "CACHE_ROOT", cache),
              patch.object(module, "expected_cert", return_value=CERT), patch.object(module, "gh_json", side_effect=fake_gh),
              patch.object(module, "download_archive", side_effect=fake_download)):
            with self.assertRaisesRegex(module.ArtifactError, "archive digest"):
                module.download_artifact(RUN_ID, COMMIT)
        self.assertFalse((cache / f"run-{RUN_ID}-attempt-1").exists())


if __name__ == "__main__":
    unittest.main()

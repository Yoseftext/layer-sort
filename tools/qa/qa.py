#!/usr/bin/env python3
"""G1.5 read-only QA oracles. Stdlib only; never changes phone settings."""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

PKG = "com.yoseftext.layersort.dev"
CERT = "de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e"
LOCK = Path("/root/device-tests/test.lock")
STATES = {"PASS", "FAIL", "SKIP", "UNVERIFIED"}


def run(*args: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


@contextlib.contextmanager
def device_lock():
    """Same advisory lock as agentctl/phone-queue; bounded and held for all ADB reads."""
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as lock:
        deadline = dt.datetime.now().timestamp() + 20
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if dt.datetime.now().timestamp() >= deadline:
                    raise TimeoutError("device lock busy for 20s")
                import time
                time.sleep(0.2)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def adb(*args: str, timeout: int = 30) -> str:
    p = run("adb", *args, timeout=timeout)
    if p.returncode:
        raise RuntimeError(f"adb {' '.join(args[:2])}: exit {p.returncode}: {p.stderr.strip()[:240]}")
    return p.stdout.strip()


def report(name: str, status: str, checks: list[dict], out: Path | None, **fields: object) -> int:
    assert status in STATES
    doc = {"workflow": name, "gate": "G1.5", "status": status,
           "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
           "checks": checks, **fields}
    text = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    print(text, end="")
    if out:
        out.mkdir(parents=True, exist_ok=True)
        (out / "report.json").write_text(text)
        lines = [f"# {name}: {status}", "", f"UTC: {doc['timestamp_utc']}", ""]
        lines += [f"- **{c['id']} {c['status']}** — {c['detail']}" for c in checks]
        lines += ["", "See `report.json` for structured fields."]
        (out / "report.md").write_text("\n".join(lines) + "\n")
    return 0 if status in ("PASS", "SKIP") else 1


def check(ident: str, ok: bool | None, detail: str) -> dict:
    return {"id": ident, "status": "UNVERIFIED" if ok is None else ("PASS" if ok else "FAIL"), "detail": detail}


def env(args: argparse.Namespace) -> int:
    checks = []
    versions = {}
    for name, cmd in (("opencode", ["opencode", "--version"]), ("git", ["git", "--version"]),
                      ("python", ["python3", "--version"]), ("adb", ["adb", "version"]),
                      ("aapt2", ["aapt2", "version"]), ("apksigner", ["apksigner", "--version"])):
        try:
            p = run(*cmd, timeout=10)
            versions[name] = (p.stdout or p.stderr).splitlines()[0] if p.returncode == 0 else "unavailable"
        except (OSError, subprocess.TimeoutExpired):
            versions[name] = "unavailable"
    checks.append(check("ENV-01", all(v != "unavailable" for v in versions.values()), str(versions)))
    branch = run("git", "branch", "--show-current").stdout.strip()
    commit = run("git", "rev-parse", "HEAD").stdout.strip()
    refs = {r: run("git", "rev-parse", r).stdout.strip() for r in
            ("main", "origin/main", "spike/godot-csharp-android", "origin/spike/godot-csharp-android")}
    checks.append(check("SEC-04", refs["main"] == refs["origin/main"] and
                        refs["spike/godot-csharp-android"] == refs["origin/spike/godot-csharp-android"],
                        f"protected refs local/origin match: {refs['main'][:8]}, {refs['spike/godot-csharp-android'][:8]}"))
    usage = shutil.disk_usage(".")
    checks.append(check("ENV-04", usage.free > 1024**3, f"free disk {usage.free} bytes"))
    # No setting changes; status only. Avoid logging raw serials or user data.
    try:
        with device_lock():
            dev = adb("devices")
            model = adb("shell", "getprop", "ro.product.model")
            api = adb("shell", "getprop", "ro.build.version.sdk")
        checks.append(check("ENV-02", "\tdevice" in dev, f"ADB attached; model={model}; API={api}; serial redacted"))
    except (RuntimeError, TimeoutError, subprocess.TimeoutExpired) as e:
        checks.append(check("ENV-02", None, str(e)))
    try:
        svc = run("agentctl", "status", timeout=25)
        # Never persist raw status output: it includes the Wi-Fi ADB endpoint.
        healthy = svc.returncode == 0 and "appium" in svc.stdout and "RUNNING" in svc.stdout and "true" in svc.stdout
        checks.append(check("ENV-03", healthy, f"agentctl status exit={svc.returncode}; Appium health={healthy}; endpoint redacted"))
    except (OSError, subprocess.TimeoutExpired):
        checks.append(check("ENV-03", None, "agentctl status unavailable/timed out"))
    checks.append(check("ENV-05", None, "Shizuku Termux rish id unverified; owner must authorize manually"))
    state = "FAIL" if any(c["status"] == "FAIL" for c in checks) else (
        "UNVERIFIED" if any(c["status"] == "UNVERIFIED" for c in checks) else "PASS")
    return report("qa-env", state, checks, args.out, commit=commit, branch=branch, versions=versions,
                  shizuku="NEEDS_OWNER_AUTH")


def provenance(args: argparse.Namespace) -> int:
    checks: list[dict] = []
    apk = args.apk
    if not apk or not apk.is_file():
        return report("qa-apk-provenance", "FAIL", [check("ENV-05", False, "APK path missing or nonexistent")], args.out)
    digest = sha(apk)
    checks.append(check("NEG-03", not args.sha256 or digest.lower() == args.sha256.lower(),
                        f"expected hash={args.sha256 or digest}; actual={digest}"))
    try:
        with zipfile.ZipFile(apk) as z:
            entries = z.namelist()
            valid = z.testzip() is None and "AndroidManifest.xml" in entries
            no_csharp = not any("libmonosgen" in x or x.endswith(".dll") or "/mono/" in x for x in entries)
        checks.append(check("ENV-05", valid and no_csharp, f"valid APK={valid}; C# payload absent={no_csharp}"))
        b = run("aapt2", "dump", "badging", str(apk), timeout=30)
        m = run("aapt2", "dump", "xmltree", "--file", "AndroidManifest.xml", str(apk), timeout=30)
        s = run("apksigner", "verify", "--print-certs", str(apk), timeout=30)
        if any(p.returncode for p in (b, m, s)):
            raise RuntimeError("aapt2/apksigner exit nonzero")
        package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", b.stdout, re.M)
        cert = re.search(r"certificate SHA-256 digest: ([0-9a-fA-F:]+)", s.stdout)
        cert_hash = cert.group(1).replace(":", "").lower() if cert else "missing"
        checks.append(check("NEG-01", bool(package) and package.group(1) == args.package,
                            f"expected package={args.package}; actual={package.group(1) if package else 'missing'}"))
        checks.append(check("SEC-01", cert_hash == CERT, f"certificate SHA-256={cert_hash}"))
        orient = re.search(r"screenOrientation\([^)]*\)=(\d+)", m.stdout)
        actual_orientation = "PORTRAIT" if orient and orient.group(1) == "1" else "OTHER/UNKNOWN"
        checks.append(check("NEG-02", actual_orientation == args.orientation,
                            f"expected orientation={args.orientation}; actual={actual_orientation}"))
        checks.append(check("ENV-05", "GodotAppLauncher" in m.stdout and "arm64-v8a" in b.stdout,
                            "launcher alias and arm64-v8a present"))
        if args.run_id:
            ci = run("gh", "run", "view", args.run_id, "--repo", "Yoseftext/layer-sort", "--json", "conclusion,headSha", timeout=25)
            try:
                d = json.loads(ci.stdout)
                checks.append(check("DEV-06", ci.returncode == 0 and d.get("conclusion") == "success" and
                                    (not args.commit or d.get("headSha", "").startswith(args.commit)),
                                    f"run={args.run_id} conclusion={d.get('conclusion')} commit={d.get('headSha')}"))
            except json.JSONDecodeError:
                checks.append(check("DEV-06", False, f"CI run {args.run_id} unavailable"))
            # Run metadata alone does not authenticate *this APK*. Download the
            # actual CI artifact and compare bytes, not just an asserted hash.
            with tempfile.TemporaryDirectory(prefix="qa-ci-") as temp:
                result = run("gh", "run", "download", args.run_id, "--repo", "Yoseftext/layer-sort",
                             "-n", args.artifact_name, "-D", temp, timeout=120)
                artifacts = list(Path(temp).glob("*.apk"))
                actual = sha(artifacts[0]) if result.returncode == 0 and len(artifacts) == 1 else "unavailable"
                checks.append(check("DEV-06", actual == digest,
                                    f"CI artifact SHA-256={actual}; supplied APK SHA-256={digest}"))
        if args.installed:
            with device_lock():
                paths = adb("shell", "pm", "path", args.package)
                path = next((line.removeprefix("package:") for line in paths.splitlines() if line.startswith("package:")), "")
                if not path:
                    raise RuntimeError("installed package path missing")
                with tempfile.TemporaryDirectory(prefix="qa-installed-") as temp:
                    local = Path(temp) / "base.apk"
                    pull = run("adb", "pull", path, str(local), timeout=90)
                    if pull.returncode != 0 or not local.is_file():
                        raise RuntimeError("adb pull installed APK failed")
                    installed_sha = sha(local)
            checks.append(check("DEV-01", installed_sha == digest,
                                f"installed APK SHA-256={installed_sha}; expected={digest}"))
    except (OSError, RuntimeError, TimeoutError, zipfile.BadZipFile, subprocess.TimeoutExpired) as e:
        checks.append(check("ENV-05", False, f"provenance inspection failed: {e}"))
    state = "FAIL" if any(c["status"] == "FAIL" for c in checks) else "PASS"
    return report("qa-apk-provenance", state, checks, args.out, APK_sha256=digest, APK_size=apk.stat().st_size,
                  expected_package=args.package, workflow_run=args.run_id, commit=args.commit)


def visual(args: argparse.Namespace) -> int:
    try:
        from PIL import Image, ImageStat, ImageChops
    except ImportError:
        return report("qa-visual", "UNVERIFIED", [check("VIS-01", None, "Pillow unavailable; install in isolated venv")], args.out)
    if not args.image.is_file():
        return report("qa-visual", "FAIL", [check("VIS-01", False, "screenshot missing")], args.out)
    with Image.open(args.image) as im:
        rgb = im.convert("RGB")
        width, height = rgb.size
        mean = sum(ImageStat.Stat(rgb).mean) / 3
        colors = len(rgb.resize((64, 64)).getcolors(maxcolors=4096) or [])
        checks = [check("VIS-01", height > width, f"size={width}x{height}"),
                  check("VIS-02", mean >= 5 and colors >= 4, f"mean brightness={mean:.2f}; sampled colours={colors}")]
        diff_pixels = None
        if args.golden:
            with Image.open(args.golden) as golden:
                if golden.size != im.size:
                    checks.append(check("VIS-09", False, f"golden size={golden.size}; actual={im.size}"))
                else:
                    difference = ImageChops.difference(rgb, golden.convert("RGB"))
                    diff_pixels = sum(1 for px in difference.get_flattened_data() if px != (0, 0, 0))
                    checks.append(check("VIS-09", diff_pixels <= args.max_diff_pixels,
                                        f"changed pixels={diff_pixels}; allowed={args.max_diff_pixels}; animated regions need reviewed masks"))
    state = "FAIL" if any(c["status"] == "FAIL" for c in checks) else "PASS"
    return report("qa-visual", state, checks, args.out, screenshot=str(args.image), screenshot_sha256=sha(args.image),
                  width=width, height=height, mean_brightness=round(mean, 2), sampled_colors=colors,
                  changed_pixels=diff_pixels, qualitative_review="UNVERIFIED: requires image-capable read of actual screenshot")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="workflow", required=True)
    for name in ("env", "provenance", "visual"):
        q = sub.add_parser(name)
        q.add_argument("--out", type=Path, help="write report.json and report.md in this directory")
    q = sub.choices["provenance"]
    q.add_argument("--apk", type=Path, required=True)
    q.add_argument("--sha256", help="expected APK SHA-256")
    q.add_argument("--package", default=PKG)
    q.add_argument("--orientation", choices=("PORTRAIT", "LANDSCAPE"), default="PORTRAIT")
    q.add_argument("--run-id", help="GitHub Actions run ID; downloads and compares artifact bytes")
    q.add_argument("--artifact-name", default="layer-sort-g1-debug-apk", help="named CI APK artifact (G2: layer-sort-g2-debug-apk)")
    q.add_argument("--commit", help="expected CI head SHA prefix")
    q.add_argument("--installed", action="store_true", help="pull installed APK under device lock and compare exact bytes")
    q = sub.choices["visual"]
    q.add_argument("--image", type=Path, required=True)
    q.add_argument("--golden", type=Path)
    q.add_argument("--max-diff-pixels", type=int, default=0)
    args = p.parse_args()
    return {"env": env, "provenance": provenance, "visual": visual}[args.workflow](args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"status": "FAIL", "error": str(error)}))
        sys.exit(1)

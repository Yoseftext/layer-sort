#!/usr/bin/env python3
"""Inspect an APK as a ZIP; byte budgets apply to the exact APK on disk."""
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

BANNED = re.compile(r"(^|/)(docs|tests|tools|\.env|secrets)(/|$)|\.(keystore|jks)$", re.I)


def inspect(path):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    entries = {}
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("invalid ZIP entry")
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = info.filename
            if name in entries or name.startswith("/") or ".." in Path(name).parts:
                raise ValueError("duplicate or unsafe APK path: " + name)
            data = archive.read(info)
            entries[name] = {"compressed": info.compress_size, "uncompressed": info.file_size,
                             "sha256": hashlib.sha256(data).hexdigest()}
    groups = {"native": 0, "dex": 0, "resources": 0, "textures": 0,
              "audio": 0, "scenes": 0, "other": 0}
    native_abi = {}
    for name, value in entries.items():
        if name.startswith("lib/"):
            group = "native"
            abi = name.split("/", 2)[1]
            native_abi[abi] = native_abi.get(abi, 0) + value["compressed"]
        elif name.endswith(".dex"):
            group = "dex"
        elif name == "resources.arsc" or name.startswith("res/") or name == "AndroidManifest.xml":
            group = "resources"
        elif name.lower().endswith((".png", ".webp", ".jpg", ".svg")):
            group = "textures"
        elif name.lower().endswith((".ogg", ".wav", ".mp3")):
            group = "audio"
        elif name.lower().endswith((".tscn", ".scn", ".pck")):
            group = "scenes"
        else:
            group = "other"
        groups[group] += value["compressed"]
    size = path.stat().st_size
    return {"path": str(path), "bytes": size, "mib": round(size / 1048576, 3),
            "sha256": digest, "entry_compressed_bytes": sum(v["compressed"] for v in entries.values()),
            "entry_uncompressed_bytes": sum(v["uncompressed"] for v in entries.values()),
            "groups_compressed_bytes": groups, "native_by_abi_compressed_bytes": native_abi,
            "largest_entries": [{"path": name, **value} for name, value in
                                sorted(entries.items(), key=lambda item: item[1]["compressed"], reverse=True)[:20]],
            "forbidden_entries": [name for name in entries if BANNED.search(name)], "entries": entries}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--budget-mib", type=float, default=32.0)
    parser.add_argument("--verification", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    current = inspect(args.apk)
    baseline = inspect(args.baseline) if args.baseline else None
    report = {k: v for k, v in current.items() if k != "entries"}
    report["budget_mib"] = args.budget_mib
    if args.verification:
        fields = {}
        for line in args.verification.read_text(encoding="utf-8").splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                if key in {"package", "version_name", "version_code", "orientation", "signing_cert_sha256", "native-code"}:
                    fields[key] = value
        report["verified_identity"] = fields
    report["budget_pass"] = current["bytes"] <= args.budget_mib * 1048576
    if baseline:
        before, after = baseline["entries"], current["entries"]
        report["baseline"] = {"path": str(args.baseline), "bytes": baseline["bytes"], "sha256": baseline["sha256"]}
        report["delta_bytes"] = current["bytes"] - baseline["bytes"]
        report["added"] = sorted(set(after) - set(before))
        report["removed"] = sorted(set(before) - set(after))
        report["changed"] = sorted(name for name in set(before) & set(after) if before[name]["sha256"] != after[name]["sha256"])
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0 if report["budget_pass"] and not report["forbidden_entries"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print("APK_REPORT_FAIL: " + str(exc), file=sys.stderr)
        sys.exit(2)

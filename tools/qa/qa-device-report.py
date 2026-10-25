#!/usr/bin/env python3
"""Summarize a bounded qa-smoke run without hiding failed phase evidence."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--out", type=Path, required=True, help="qa-smoke output directory")
p.add_argument("--exit", type=int, required=True, dest="exit_code")
a = p.parse_args()
phases = {}
for name in ("preflight", "install", "provenance", "smoke", "touch"):
    log = a.out / (name + (".json" if name in ("preflight", "provenance") else ".log"))
    if not log.exists():
        phases[name] = {"status": "UNVERIFIED", "evidence": str(log)}
        continue
    text = log.read_text(errors="replace")
    saved = re.search(r"Saved to: (.+)", text)
    target = Path(saved.group(1)) / "status.json" if saved else None
    if name in ("preflight", "provenance"):
        try:
            status = json.loads(text)["status"]
        except (json.JSONDecodeError, KeyError):
            status = "FAIL"
    elif target and target.is_file():
        try:
            status = json.loads(target.read_text())["status"]
        except (json.JSONDecodeError, KeyError):
            status = "FAIL"
    else:
        status = "PASS" if name == "install" and "\nSuccess\n" in text else "FAIL"
    phases[name] = {"status": status, "evidence": str(target or log),
                    "screenshot": str(target.parent / ("screenshot.png" if name == "smoke" else "after.png")) if target else None,
                    "logcat": str(target.parent / "logcat.txt") if target else None}
overall = "FAIL" if a.exit_code or any(v["status"] == "FAIL" for v in phases.values()) else (
    "UNVERIFIED" if any(v["status"] == "UNVERIFIED" for v in phases.values()) else "PASS")
doc = {"workflow": "qa-smoke", "gate": "G1.5", "status": overall,
       "timestamp_utc": datetime.now(timezone.utc).isoformat(), "phases": phases}
(a.out / "report.json").write_text(json.dumps(doc, indent=2) + "\n")
lines = [f"# qa-smoke: {overall}", "", "| Phase | Status | Evidence |", "|---|---|---|"]
lines += [f"| {name} | {data['status']} | `{data['evidence']}` |" for name, data in phases.items()]
(a.out / "report.md").write_text("\n".join(lines) + "\n")
print(f"qa-smoke {overall}; structured report: {a.out / 'report.json'}")
raise SystemExit(0 if overall == "PASS" else 1)

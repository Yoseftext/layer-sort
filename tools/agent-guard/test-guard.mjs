import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createFixture } from "./fakes/create-fixture.mjs";
const fakes = path.join(path.dirname(fileURLToPath(import.meta.url)), "fakes");
let passed = 0;
function check(name, actual, expected) { assert.equal(actual, expected, name); console.log("PASS " + name + " (got " + actual + ")"); passed += 1; }
function run(name, before = () => {}, env = {}) {
  const f = createFixture();
  before(f);
  const result = f.runArgs(["-p", path.join(fakes, name)], { env });
  return { ...f, result };
}
check("allowlisted write passes", run("fake-ok.sh").result.status, 0);
check("out-of-scope write is flagged", run("fake-bad.sh").result.status, 2);
check("agent commit is flagged", run("fake-commit.sh").result.status, 2);
check(".agents write is flagged", run("fake-agents.sh").result.status, 2);
const missing = run("fake-ok.sh", () => {}, { SNAP_DIR: "/nonexistent/snapshot" });
check("missing snapshot blocks start", missing.result.status, 3);
check("agent not executed when blocked", fs.existsSync(path.join(missing.root, "allowed.txt")), false);
check("tampered snapshot blocks start", run("fake-ok.sh", (f) => fs.appendFileSync(path.join(f.pin, "scripts/policy.mjs"), "//tampered")).result.status, 3);
check("unwired Hook blocks start", run("fake-ok.sh", (f) => fs.writeFileSync(path.join(f.root, ".agents/hooks.json"), "{}")).result.status, 3);
check("valid task snapshot passes startup", run("fake-ok.sh").result.status, 0);
console.log("RESULT: pass=" + passed + " fail=0\nGUARD_TESTS_PASS");

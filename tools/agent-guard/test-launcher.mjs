import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawnSync, execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const launcher = path.join(path.dirname(fileURLToPath(import.meta.url)), "safe-agy.sh");
function fixture() {
  const base = fs.mkdtempSync(path.join(process.env.GUARD_TEST_ROOT ?? os.tmpdir(), "guard-launcher-"));
  const root = path.join(base, "repo"), snapshot = path.join(base, "snapshot");
  fs.mkdirSync(root);
  fs.mkdirSync(path.join(snapshot, "scripts"), { recursive: true });
  execFileSync("git", ["init", "-q", root]);
  fs.writeFileSync(path.join(root, "base"), "base");
  execFileSync("git", ["-C", root, "add", "base"]);
  execFileSync("git", ["-C", root, "-c", "user.name=Guard Test", "-c",
    "user.email=guard@example.invalid", "commit", "-qm", "base"]);
  let manifest = "";
  for (const name of ["policy.sh", "policy.mjs"]) {
    const data = "fixture";
    fs.writeFileSync(path.join(snapshot, "scripts", name), data);
    manifest += createHash("sha256").update(data).digest("hex") + "  scripts/" + name + "\n";
  }
  fs.writeFileSync(path.join(snapshot, "MANIFEST.sha256"), manifest);
  const hooks = path.join(snapshot, "hooks.json");
  fs.writeFileSync(hooks, JSON.stringify({ guard: { enabled: true, PreToolUse: [
    { matcher: ".*", hooks: [{ type: "command",
      command: "/usr/bin/bash " + snapshot + "/scripts/policy.sh", timeout: 10 }] }
  ] } }));
  const allow = path.join(base, "allow");
  fs.writeFileSync(allow, "allowed.txt\n");
  const run = (code, entry = launcher) => spawnSync("bash", [entry, root, allow, "--", "-e", code], {
    encoding: "utf8", timeout: 30000, env: { ...process.env, SAFE_TOGGLE: "0",
      AGY_BIN: process.execPath, SNAP_DIR: snapshot, INST_DIR: snapshot, PLUGIN_HOOKS: hooks }
  });
  return { root, allow, run };
}

test("before-state failure prevents agent execution", () => {
  const { root, run } = fixture();
  fs.writeFileSync(path.join(root, "bad\nname"), "existing");
  const result = run('require("fs").writeFileSync("ran", "yes")');
  assert.equal(result.status, 3, result.stderr);
  assert.equal(fs.existsSync(path.join(root, "ran")), false);
  assert.doesNotMatch(result.stdout, /GUARD_OK/);
});

test("after-state failure never reports successful verification", () => {
  const { run } = fixture();
  const result = run('require("fs").writeFileSync("bad\\nname", "new")');
  assert.equal(result.status, 3, result.stderr);
  assert.match(result.stderr, /after-state collection failed/);
  assert.doesNotMatch(result.stdout, /GUARD_OK/);
});

test("agent cannot broaden the post-check by modifying the original allowlist", () => {
  const { allow, run } = fixture();
  const result = run('const fs=require("fs");fs.appendFileSync(' +
    JSON.stringify(allow) + ',"outside.txt\\n");fs.writeFileSync("outside.txt","new")');
  assert.equal(result.status, 2, result.stderr);
  assert.match(result.stderr, /out of scope: outside.txt/);
});

test("replacing a worktree verifier cannot execute injected code or hide an out-of-scope write", () => {
  const { root, allow, run } = fixture();
  const guard = path.join(root, "guard");
  fs.mkdirSync(guard);
  for (const name of ["safe-agy.sh", "guard-lib.sh", "guard-state.mjs"]) {
    fs.writeFileSync(path.join(guard, name), fs.readFileSync(path.join(path.dirname(launcher), name)));
  }
  fs.writeFileSync(allow, "guard/guard-state.mjs\n");
  const injection = 'require("fs").writeFileSync("injected-ran","yes")';
  const code = 'const fs=require("fs");fs.writeFileSync("guard/guard-state.mjs",' +
    JSON.stringify(injection) + ');fs.writeFileSync("outside.txt","new")';
  const result = run(code, path.join(guard, "safe-agy.sh"));
  assert.equal(result.status, 2, result.stderr);
  assert.match(result.stderr, /out of scope: outside.txt/);
  assert.equal(fs.existsSync(path.join(root, "injected-ran")), false);
});

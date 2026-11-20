import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { createFixture, launcher } from "./fakes/create-fixture.mjs";
import { WORKSPACE_HOOK_COMMAND, verifySnapshot, godotBin, freezeCli, verifyFrozenCli } from "./runtime-config.mjs";

test("before-state failure prevents agent execution and closes the grant", () => {
  const f = createFixture();
  fs.writeFileSync(path.join(f.root, "bad\nname"), "existing");
  const r = f.run('require("fs").writeFileSync("ran","yes")');
  assert.equal(r.status, 3, r.stderr);
  assert.equal(fs.existsSync(path.join(f.root, "ran")), false);
  assert.equal(fs.existsSync(path.join(f.pin, "REVOKED")), true);
  assert.doesNotMatch(r.stdout, /GUARD_OK/);
});

test("after-state failure never reports successful verification", () => {
  const f = createFixture(), r = f.run('require("fs").writeFileSync("bad\\nname","new")');
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /after-state collection failed/);
  assert.doesNotMatch(r.stdout, /GUARD_OK/);
});

test("changing snapshot grant data is detected and the grant closes", () => {
  const f = createFixture();
  const code = 'const fs=require("fs");fs.appendFileSync(' + JSON.stringify(path.join(f.pin, "scripts/task-grants.json")) +
    '," ");fs.writeFileSync("outside.txt","new")';
  const r = f.run(code);
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /policy changed during the session/);
  assert.equal(fs.existsSync(path.join(f.pin, "REVOKED")), true);
  assert.doesNotMatch(r.stdout, /GUARD_OK/);
});

test("replacing either worktree helper cannot run injected code or hide an outside write", () => {
  const f = createFixture(["guard/guard-state.mjs", "guard/runtime-config.mjs"]);
  const guard = path.join(f.root, "guard");
  fs.mkdirSync(guard);
  for (const name of ["safe-agy.sh", "guard-lib.sh", "guard-state.mjs", "runtime-config.mjs"]) {
    fs.writeFileSync(path.join(guard, name), fs.readFileSync(path.join(path.dirname(launcher), name)));
  }
  const injected = 'require("fs").writeFileSync("injected-ran","yes")';
  const code = 'const fs=require("fs");for(const n of ["guard-state.mjs","runtime-config.mjs"])fs.writeFileSync("guard/"+n,' +
    JSON.stringify(injected) + ');fs.writeFileSync("outside.txt","new")';
  const r = f.run(code, path.join(guard, "safe-agy.sh"));
  assert.equal(r.status, 2, r.stderr);
  assert.match(r.stderr, /out of scope: outside.txt/);
  assert.equal(fs.existsSync(path.join(f.root, "injected-ran")), false);
});

test("workspace dispatcher denies when snapshot is missing or policy process fails", () => {
  const env = { ...process.env };
  delete env.LS_POLICY_SNAPSHOT;
  const run = (extra = {}) => spawnSync("bash", ["-c", WORKSPACE_HOOK_COMMAND], {
    encoding: "utf8", timeout: 10000, env: { ...env, ...extra }
  });
  assert.equal(JSON.parse(run().stdout).decision, "deny");
  const f = createFixture();
  fs.writeFileSync(path.join(f.pin, "scripts/policy.sh"), "exit 1\n");
  assert.equal(JSON.parse(run({ LS_POLICY_SNAPSHOT: f.pin }).stdout).decision, "deny");
});

test("a real prepared policy authorizes the task, closes after delivery and rejects reuse", () => {
  const f = createFixture(["base"]);
  const prepare = path.join(path.dirname(fileURLToPath(import.meta.url)), "prepare-task.mjs");
  fs.writeFileSync(path.join(f.pin, "REVOKED"), "closed fixture");
  const p = spawnSync(process.execPath, [prepare, f.root, "PREPARE-TEST", "base"], { encoding: "utf8", timeout: 30000 });
  assert.equal(p.status, 0, p.stderr);
  const pin = JSON.parse(p.stdout).snapshot;
  assert.doesNotThrow(() => verifySnapshot(pin));
  const event = JSON.stringify({ toolCall: { name: "edit_file", args: { Path: path.join(f.root, "base") } }, workspacePaths: [f.root] });
  const hook = () => spawnSync("bash", ["-c", WORKSPACE_HOOK_COMMAND], {
    encoding: "utf8", input: event, timeout: 10000,
    env: { ...process.env, LS_PROJECT_ROOT: f.project, LS_POLICY_SNAPSHOT: pin }
  });
  assert.equal(JSON.parse(hook().stdout).decision, "allow");
  const r = f.run('require("fs").writeFileSync("base","changed")', launcher, { SNAP_DIR: pin });
  assert.equal(r.status, 0, r.stderr);
  assert.equal(JSON.parse(hook().stdout).decision, "deny");
  const reuse = f.run('throw Error("must not run")', launcher, { SNAP_DIR: pin });
  assert.equal(reuse.status, 3, reuse.stderr);
  assert.match(reuse.stderr, /revoked/);
  const invalid = spawnSync(process.execPath, [prepare, f.root, "PREPARE-TEST", "../outside"], { encoding: "utf8", timeout: 30000 });
  assert.equal(invalid.status, 3);
});

test("callers cannot disable trust or override session authority", () => {
  const f = createFixture();
  const r = f.runArgs(["--settings", "{}"]);
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /authority override/i);
});

test("an expired grant cannot launch a command", () => {
  const f = createFixture(["allowed.txt"], { expiresAt: new Date(0).toISOString() });
  const r = f.run('require("fs").writeFileSync("ran","yes")');
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /expired/);
  assert.equal(fs.existsSync(path.join(f.root, "ran")), false);
});

test("alternate CLI names still require version and plugin compatibility", () => {
  for (const env of [{ TEST_CLI_VERSION: "1.6.0" }, { TEST_PLUGIN_STATE: "enabled" }]) {
    const f = createFixture(), r = f.run('require("fs").writeFileSync("ran","yes")', launcher, env);
    assert.equal(r.status, 3, r.stderr);
    assert.equal(fs.existsSync(path.join(f.root, "ran")), false);
  }
});

test("single-dash and compound authority overrides cannot enter a session", () => {
  for (const args of [["-settings", "{}"], ["-dangerously-skip-permissions"], ["--settings={}"]]) {
    const r = createFixture().runArgs(args);
    assert.equal(r.status, 3, r.stderr);
  }
});

test("preparation cannot replace a live grant and launch rejects an inactive snapshot", () => {
  const f = createFixture();
  const prepare = path.join(path.dirname(launcher), "prepare-task.mjs");
  const r = spawnSync(process.execPath, [prepare, f.root, "OTHER-TASK", "base"], { encoding: "utf8", timeout: 30000 });
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /Previous task is still open/);
  const pointer = path.join(f.project, ".git/agent-runtime-policy/tasks/task.json");
  fs.writeFileSync(pointer, JSON.stringify({ worktree: f.root, snapshot: path.join(path.dirname(f.pin), "other") }));
  const run = f.run('require("fs").writeFileSync("ran","yes")');
  assert.equal(run.status, 3, run.stderr);
  assert.match(run.stderr, /not the active/);
  assert.equal(fs.existsSync(path.join(f.root, "ran")), false);
});

test("private Godot binding rejects runtime tampering and extra PATH executables", () => {
  const f = createFixture();
  assert.equal(godotBin(f.project), "");
  const base = path.join(f.project, ".git/agent-runtime-tools");
  const bin = path.join(base, "godot47-fixture/bin");
  fs.mkdirSync(bin, { recursive: true });
  const executable = path.join(bin, "godot");
  fs.writeFileSync(executable, "reviewed fixture", { mode: 0o700 });
  const digest = createHash("sha256").update(fs.readFileSync(executable)).digest("hex");
  fs.writeFileSync(path.join(base, "godot-runtime.json"), JSON.stringify({ bin, runnerHash: digest }));
  assert.equal(godotBin(f.project), bin);
  fs.appendFileSync(executable, "modified");
  assert.throws(() => godotBin(f.project), /integrity mismatch/);
  fs.writeFileSync(path.join(bin, "node"), "unexpected executable");
  assert.throws(() => godotBin(f.project), /only Godot/);
});

test("CLI snapshots survive installed updates and detect changed session executables", async () => {
  const f = createFixture(), source = path.join(f.base, "installed-cli");
  fs.writeFileSync(source, "original CLI", { mode: 0o700 });
  const temporary = path.join(f.base, "session");
  fs.mkdirSync(temporary);
  const frozen = await freezeCli(source, temporary);
  fs.writeFileSync(source, "installed auto-update");
  await assert.doesNotReject(() => verifyFrozenCli(temporary));
  assert.equal(fs.readFileSync(frozen, "utf8"), "original CLI");
  fs.appendFileSync(frozen, "tampered");
  await assert.rejects(() => verifyFrozenCli(temporary), /Pinned CLI changed/);
});

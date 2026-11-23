import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { createFixture } from "./fakes/create-fixture.mjs";
import { activeSnapshot, revoke, taskGrant, verifySnapshot } from "./runtime-config.mjs";

const runtimeConfig = path.join(path.dirname(fileURLToPath(import.meta.url)), "runtime-config.mjs");

test("task pointer traversal cannot revoke outside the private policy snapshot", () => {
  const f = createFixture();
  const policyRoot = path.join(f.project, ".git/agent-runtime-policy");
  const pointer = path.join(policyRoot, "tasks/task.json");
  const traversalPath = policyRoot + "/..";
  fs.writeFileSync(pointer, JSON.stringify({ worktree: f.root, snapshot: traversalPath }));
  assert.throws(() => activeSnapshot(f.root), /Snapshot/);
  const close = spawnSync(process.execPath, [runtimeConfig, "close", f.root], { encoding: "utf8", timeout: 10000 });
  assert.equal(close.status, 3, close.stderr);
  assert.equal(fs.existsSync(path.join(f.project, ".git", "REVOKED")), false);
  assert.throws(() => revoke(traversalPath), /Snapshot/);
});

test("snapshot verification supports an existing 0755 policy directory but rejects writable modes", () => {
  const f = createFixture();
  const policyRoot = path.join(f.project, ".git/agent-runtime-policy");
  fs.chmodSync(policyRoot, 0o755);
  assert.doesNotThrow(() => verifySnapshot(f.pin));
  fs.chmodSync(policyRoot, 0o777);
  assert.throws(() => verifySnapshot(f.pin), /Unsafe agent-runtime-policy directory/);
});

test("snapshot verification rejects a symlinked manifest", () => {
  const f = createFixture();
  const manifest = path.join(f.pin, "MANIFEST.sha256");
  const external = path.join(f.base, "external-manifest");
  fs.writeFileSync(external, fs.readFileSync(manifest), { mode: 0o600 });
  fs.unlinkSync(manifest);
  fs.symlinkSync(external, manifest);
  assert.throws(() => verifySnapshot(f.pin), /ELOOP|symbolic|Unsafe/);
});

test("revocation is private, idempotent and prevents snapshot reuse", () => {
  const f = createFixture();
  revoke(f.pin);
  assert.throws(() => verifySnapshot(f.pin), /revoked/);
  revoke(f.pin);
  const marker = fs.lstatSync(path.join(f.pin, "REVOKED"));
  assert.equal(marker.isFile(), true);
  assert.equal(marker.mode & 0o777, 0o600);
});

test("session output rejects unsafe directories and never follows an existing symlink", () => {
  const f = createFixture();
  const unsafeSession = path.join(f.base, "unsafe-session");
  fs.mkdirSync(unsafeSession, { mode: 0o755 });
  fs.chmodSync(unsafeSession, 0o755);
  const rejected = spawnSync(process.execPath, [runtimeConfig, "session", f.pin, f.root, unsafeSession], {
    encoding: "utf8", timeout: 10000, env: { ...process.env, LS_PROJECT_ROOT: f.project }
  });
  assert.equal(rejected.status, 3, rejected.stderr);
  assert.equal(fs.existsSync(path.join(unsafeSession, "settings.json")), false);

  const session = path.join(f.base, "session");
  fs.mkdirSync(session, { mode: 0o700 });
  const external = path.join(f.base, "external-allow");
  fs.writeFileSync(external, "do-not-overwrite", { mode: 0o600 });
  fs.symlinkSync(external, path.join(session, "allow"));
  const symlinked = spawnSync(process.execPath, [runtimeConfig, "session", f.pin, f.root, session], {
    encoding: "utf8", timeout: 10000, env: { ...process.env, LS_PROJECT_ROOT: f.project }
  });
  assert.equal(symlinked.status, 3, symlinked.stderr);
  assert.equal(fs.readFileSync(external, "utf8"), "do-not-overwrite");
});

test("valid session material is private, complete and derived from the active grant", () => {
  const f = createFixture();
  const session = path.join(f.base, "valid-session");
  fs.mkdirSync(session, { mode: 0o700 });
  const result = spawnSync(process.execPath, [runtimeConfig, "session", f.pin, f.root, session], {
    encoding: "utf8", timeout: 10000, env: { ...process.env, LS_PROJECT_ROOT: f.project }
  });
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.taskId, f.grant.taskId);
  assert.deepEqual(output.files, f.grant.files);
  for (const name of ["allow", "settings.json", "timeout"]) {
    const stat = fs.lstatSync(path.join(session, name));
    assert.equal(stat.isFile(), true);
    assert.equal(stat.isSymbolicLink(), false);
    assert.equal(stat.nlink, 1);
    assert.equal(stat.uid, process.getuid());
    assert.equal(stat.mode & 0o777, 0o600);
  }
  const settings = JSON.parse(fs.readFileSync(path.join(session, "settings.json"), "utf8"));
  assert.deepEqual(settings.trustedWorkspaces, [f.root]);
});

test("task grant rejects a valid but inactive snapshot", async () => {
  const f = createFixture();
  const inactiveSnapshot = path.join(path.dirname(f.pin), "b".repeat(64));
  fs.mkdirSync(inactiveSnapshot, { mode: 0o700 });
  fs.writeFileSync(path.join(f.project, ".git/agent-runtime-policy/tasks/task.json"),
    JSON.stringify({ worktree: f.root, snapshot: inactiveSnapshot }));
  await assert.rejects(taskGrant(f.pin, f.root), /Snapshot is not the active task grant/);
});

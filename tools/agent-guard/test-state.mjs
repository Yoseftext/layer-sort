import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { captureState, changedPaths, hashFile } from "./guard-state.mjs";
import { validateHook } from "./runtime-config.mjs";

// Retain bounded fixtures for diagnosis; no device/runtime configuration is touched.
const base = fs.mkdtempSync(path.join(process.env.GUARD_TEST_ROOT ?? os.tmpdir(), "guard-state-"));
function fixture() {
  const root = fs.mkdtempSync(path.join(base, "repo-"));
  const git = (...args) => execFileSync("git", ["-C", root, ...args], { stdio: "pipe" });
  git("init", "-q");
  fs.writeFileSync(path.join(root, "base.txt"), "base");
  git("add", "base.txt");
  git("-c", "user.name=Guard Test", "-c", "user.email=guard@example.invalid", "commit", "-qm", "base");
  return { root, git };
}

test("detects content changes in a pre-existing quoted untracked filename", () => {
  const { root } = fixture();
  const name = 'quoted"file.txt';
  fs.writeFileSync(path.join(root, name), "before");
  const before = captureState(root);
  fs.writeFileSync(path.join(root, name), "after");
  assert.deepEqual(changedPaths(before, captureState(root)), [name]);
});

test("detects chmod and a staged rename without parsing display quoting", () => {
  const { root, git } = fixture();
  const before = captureState(root);
  fs.chmodSync(path.join(root, "base.txt"), 0o755);
  assert.ok(changedPaths(before, captureState(root)).includes("base.txt"));
  git("mv", "base.txt", 'renamed"file.txt');
  const changed = changedPaths(before, captureState(root));
  assert.ok(changed.includes("INDEX"));
  assert.ok(changed.includes("base.txt"));
  assert.ok(changed.includes('renamed"file.txt'));
});

test("detects symlink retargeting without following its contents", () => {
  const { root } = fixture();
  fs.symlinkSync("base.txt", path.join(root, "link"));
  const before = captureState(root);
  // Rename replaces only this isolated fixture's link.
  fs.symlinkSync("missing", path.join(root, "replacement"));
  fs.renameSync(path.join(root, "replacement"), path.join(root, "link"));
  assert.ok(changedPaths(before, captureState(root)).includes("link"));
});

test("refuses unsupported line-based allowlist names and invalid repositories", () => {
  const { root } = fixture();
  fs.writeFileSync(path.join(root, "line\nbreak"), "content");
  assert.throws(() => captureState(root), /control character/);
  assert.throws(() => captureState(base));
  assert.throws(() => changedPaths({}, {}), /Invalid state/);
});

test("validates active hook structure, rejecting disabled and ambiguous wiring", () => {
  const command = "/usr/bin/bash /pin/scripts/policy.sh";
  const hooks = { guard: { enabled: true, PreToolUse: [
    { matcher: ".*", hooks: [{ type: "command", command, timeout: 10 }] }
  ] } };
  assert.doesNotThrow(() => validateHook(hooks, command));
  assert.throws(() => validateHook({ guard: { ...hooks.guard, enabled: false }, note: command }, "/pin"));
  assert.throws(() => validateHook({ ...hooks, duplicate: hooks.guard }, "/pin"));
  assert.throws(() => validateHook(hooks, "/other"));
});

test("hashes multi-megabyte files with bounded buffers matching expected SHA-256", () => {
  const { root } = fixture();
  const filePath = path.join(root, "large-file.bin");
  const size = 2 * 1024 * 1024 + 4 * 1024;
  const chunk = Buffer.from("LayerSortBoundedChunkDeterministicData1234!\n");
  const buffer = Buffer.alloc(size);
  for (let offset = 0; offset < size; offset += chunk.length) {
    chunk.copy(buffer, offset, 0, Math.min(chunk.length, size - offset));
  }
  fs.writeFileSync(filePath, buffer);

  const expectedSha256 = createHash("sha256").update(buffer).digest("hex");
  const directHash = hashFile(filePath);
  assert.equal(directHash, expectedSha256);

  const directSmallBufferHash = hashFile(filePath, 1024);
  assert.equal(directSmallBufferHash, expectedSha256);

  const state = captureState(root);
  assert.equal(state.files["large-file.bin"]?.[4], expectedSha256);
});

test("hashFile rejects invalid buffer sizes with RangeError before opening file", () => {
  const nonExistentPath = path.join(base, "non-existent-file-" + Date.now() + ".bin");
  assert.ok(!fs.existsSync(nonExistentPath), "Fixture file must not exist");

  const invalidSizes = [0, -1, 1.5, NaN, Infinity, -Infinity];
  for (const invalidSize of invalidSizes) {
    assert.throws(
      () => hashFile(nonExistentPath, invalidSize),
      {
        name: "RangeError",
        message: "bufferSize must be a positive integer",
      },
      `Expected RangeError for invalid bufferSize: ${invalidSize}`
    );
  }
});

test("hashFile correctly computes SHA-256 with small streaming chunk sizes", () => {
  const { root } = fixture();
  const filePath = path.join(root, "small-chunks.bin");
  const content = Buffer.from("LayerSort test content for streaming chunks across various buffer sizes.");
  fs.writeFileSync(filePath, content);
  const expectedHash = createHash("sha256").update(content).digest("hex");

  for (const chunkSize of [1, 7, 64]) {
    assert.equal(
      hashFile(filePath, chunkSize),
      expectedHash,
      `Hash mismatch for buffer size ${chunkSize}`
    );
  }
});

console.log("Guard fixture directory: " + base);

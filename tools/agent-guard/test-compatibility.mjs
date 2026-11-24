import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { test } from "node:test";
import {
  appendAudit,
  canRetryQuotaFailure,
  classifyProbeFailure,
  diagnoseSuiteFailure,
  discoverGeminiModels,
  retryableProbeFailure,
  runProbeWithRecovery,
  classifyAntigravityWarnings,
  classifySuiteStatus,
  describeProbeFailure,
  diffSummary,
  extractSoftWarnings,
  extractWarningLines,
  findCacheEntry,
  assertSafeExecutionEnvironment,
  ensureStateDirectory,
  fingerprintCli,
  fingerprintPolicy,
  hashOpenFile,
  readCache,
  redactEvidenceText,
  resolveExecutable,
  selectGeminiModel,
  sessionCliIdentity,
  spawnVerifiedDescriptor,
  writeCacheAtomic
} from "./compatibility.mjs";

function tempRoot(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "safe-agy-compat-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

test("runtime environment rejects dynamic-loader and Node startup injection", () => {
  assert.throws(() => assertSafeExecutionEnvironment({ PATH: "/usr/bin", LD_PRELOAD: "/tmp/evil.so" }), /LD_PRELOAD/);
  assert.throws(() => assertSafeExecutionEnvironment({ PATH: "/usr/bin", NODE_OPTIONS: "--require=/tmp/evil.cjs" }), /NODE_OPTIONS/);
  assert.throws(() => assertSafeExecutionEnvironment({ PATH: "/usr/bin", BASH_ENV: "/tmp/evil.sh" }), /BASH_ENV/);
  assert.doesNotThrow(() => assertSafeExecutionEnvironment({ PATH: "/usr/bin" }));
});

test("hashOpenFile hashes the opened inode and reports stable identity", (t) => {
  const root = tempRoot(t);
  const file = path.join(root, "sample.bin");
  const data = Buffer.from("safe-agy-fingerprint");
  fs.writeFileSync(file, data, { mode: 0o600 });
  const result = hashOpenFile(file);
  assert.equal(result.sha256, crypto.createHash("sha256").update(data).digest("hex"));
  assert.equal(result.size, data.length);
  assert.ok(result.ino);
  assert.ok(result.dev);
});

test("session executable must match the compatible binary hash", (t) => {
  const root = tempRoot(t);
  const file = path.join(root, "session-cli");
  fs.writeFileSync(file, "compatible CLI", { mode: 0o700 });
  const hash = crypto.createHash("sha256").update("compatible CLI").digest("hex");
  assert.equal(sessionCliIdentity(file, hash).sha256, hash);
  fs.writeFileSync(file, "different CLI");
  assert.throws(() => sessionCliIdentity(file, hash), /differs from the compatible executable/);
});

test("hashOpenFile rejects a final symlink", (t) => {
  const root = tempRoot(t);
  const target = path.join(root, "target");
  const alias = path.join(root, "alias");
  fs.writeFileSync(target, "x");
  fs.symlinkSync(target, alias);
  assert.throws(() => hashOpenFile(alias));
});

test("resolveExecutable ignores relative PATH entries and resolves an absolute executable", (t) => {
  const root = tempRoot(t);
  const bin = path.join(root, "bin");
  fs.mkdirSync(bin);
  const executable = path.join(bin, "probe");
  fs.writeFileSync(executable, "#!/bin/sh\nexit 0\n", { mode: 0o700 });
  fs.chmodSync(executable, 0o700);
  const result = resolveExecutable("probe", { PATH: "relative:" + bin });
  assert.equal(result.path, executable);
  assert.equal(result.realpath, executable);
  assert.equal(result.symlink, false);
});

test("resolveExecutable rejects ambiguous absolute PATH matches for the Antigravity CLI", (t) => {
  const root = tempRoot(t);
  const first = path.join(root, "first");
  const second = path.join(root, "second");
  fs.mkdirSync(first);
  fs.mkdirSync(second);
  for (const directory of [first, second]) {
    const executable = path.join(directory, "agy");
    fs.writeFileSync(executable, "#!/bin/sh\nexit 0\n", { mode: 0o700 });
    fs.chmodSync(executable, 0o700);
  }
  assert.throws(
    () => resolveExecutable("agy", { PATH: first + path.delimiter + second }, { requireUnique: true }),
    /ambiguous/
  );
});

test("fingerprintCli captures the current native Antigravity ELF identity through an open descriptor", () => {
  const result = fingerprintCli(process.env.AGY_BIN || "agy", process.env);
  assert.equal(typeof result.version, "string");
  assert.ok(result.version.length > 0 && result.version.length <= 128);
  assert.equal(result.elf.format, "ELF");
  assert.match(result.elf.machine, /AArch64/i);
  assert.ok(result.elf.buildId);
  assert.ok(result.elf.loader.sha256);
  assert.ok(result.elf.dependencies.length >= 1);
  assert.equal(result.sha256.length, 64);
});

test("spawnVerifiedDescriptor executes the verified inode without a path lookup", (t) => {
  const executable = resolveExecutable("echo");
  const file = hashOpenFile(executable.realpath);
  const result = spawnVerifiedDescriptor(executable.realpath, {
    sha256: file.sha256,
    device: file.dev,
    inode: file.ino
  }, ["SAFE_AGY_DESCRIPTOR_EXEC_OK"], { capture: true });
  assert.equal(result.status, 0);
  assert.equal(result.stdout.trim(), "SAFE_AGY_DESCRIPTOR_EXEC_OK");
});

test("spawnVerifiedDescriptor rejects a mismatched executable hash before execution", (t) => {
  const executable = resolveExecutable("echo");
  const file = hashOpenFile(executable.realpath);
  assert.throws(() => spawnVerifiedDescriptor(executable.realpath, {
    sha256: "0".repeat(64),
    device: file.dev,
    inode: file.ino
  }, ["must-not-run"], { capture: true }), /does not match the approved fingerprint/);
});

test("policy fingerprint changes when a policy or test input changes", (t) => {
  const root = tempRoot(t);
  const infra = path.join(root, "infra");
  const project = path.join(root, "project");
  const files = [
    "AGENTS.md",
    "docs/adr/ADR-0008-dynamic-antigravity-compatibility.md",
    "docs/adr/ADR-0009-godot-prroot-runtime-launcher.md",
    "docs/adr/INDEX.md",
    "docs/current/00-START-HERE.md",
    "docs/current/04-AGENT-OPERATIONS.md",
    ".agents/hooks.json",
    ".agents/agents/implementer.md",
    ".agents/skills/example.md",
    ".agents/plugins/layer-sort-agent-kit/scripts/policy.mjs",
    "tools/device-tests/agentctl",
    "tools/device-tests/device_qa.py",
    "tools/device-tests/artifact_qa.py",
    "tools/device-tests/install_qa.py",
    "tools/device-tests/gesture_plan.py",
    "tools/visual-qa/visual_match.py",
    "tools/visual-qa/requirements-py313-linux.txt",
    "tools/device-tests/expected-debug-cert.sha256",
    "tools/agent-guard/test-compatibility.mjs"
  ];
  for (const relative of files) {
    const file = path.join(project, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, "baseline:" + relative);
  }
  const infraFile = path.join(infra, "tools/agent-guard/safe-agy.sh");
  fs.mkdirSync(path.dirname(infraFile), { recursive: true });
  fs.writeFileSync(infraFile, "launcher-v1");
  const first = fingerprintPolicy(project, infra).sha256;
  fs.writeFileSync(path.join(project, "docs/current/00-START-HERE.md"), "updated project documentation");
  fs.writeFileSync(path.join(project, ".agents/skills/example.md"), "updated skill guidance");
  fs.writeFileSync(path.join(project, "tools/agent-guard/README.md"), "updated operating guide");
  assert.equal(fingerprintPolicy(project, infra).sha256, first);
  fs.writeFileSync(path.join(project, ".agents/hooks.json"), "changed-hook");
  const second = fingerprintPolicy(project, infra).sha256;
  assert.notEqual(first, second);
  fs.writeFileSync(infraFile, "launcher-v2");
  const third = fingerprintPolicy(project, infra).sha256;
  assert.notEqual(second, third);
  fs.writeFileSync(path.join(project, "tools/device-tests/artifact_qa.py"), "changed-verifier");
  const fourth = fingerprintPolicy(project, infra).sha256;
  assert.notEqual(fourth, third);
  fs.writeFileSync(path.join(project, "tools/device-tests/install_qa.py"), "changed-installer");
  const fifth = fingerprintPolicy(project, infra).sha256;
  assert.notEqual(fifth, fourth);
  fs.writeFileSync(path.join(project, "tools/device-tests/gesture_plan.py"), "changed-gesture-planner");
  const sixth = fingerprintPolicy(project, infra).sha256;
  assert.notEqual(sixth, fifth);
  fs.writeFileSync(path.join(project, "tools/visual-qa/requirements-py313-linux.txt"), "changed-visual-lockfile");
  assert.notEqual(fingerprintPolicy(project, infra).sha256, sixth);
});

test("state directory requires exact owner and mode 0700", (t) => {
  const root = tempRoot(t);
  const state = path.join(root, "state");
  const result = ensureStateDirectory(state);
  assert.equal(result, state);
  assert.equal(fs.statSync(state).mode & 0o777, 0o700);
  const unsafe = path.join(root, "unsafe");
  fs.mkdirSync(unsafe, { mode: 0o755 });
  fs.chmodSync(unsafe, 0o755);
  assert.throws(() => ensureStateDirectory(unsafe), /Unsafe safe-agy state directory/);
});

test("state directory rejects symlink aliases", (t) => {
  const root = tempRoot(t);
  const actual = path.join(root, "actual");
  const alias = path.join(root, "alias");
  fs.mkdirSync(actual, { mode: 0o700 });
  fs.symlinkSync(actual, alias);
  assert.throws(() => ensureStateDirectory(alias), /symlink/);
});

test("cache writes are atomic, private, schema-checked and limited to five entries", (t) => {
  const root = tempRoot(t);
  const state = ensureStateDirectory(path.join(root, "state"));
  writeCacheAtomic(state, { entries: Array.from({ length: 7 }, (_, i) => ({ key: String(i), verdict: "PASS" })) });
  const cache = readCache(state);
  assert.equal(cache.entries.length, 5);
  assert.equal(fs.statSync(path.join(state, "compatibility-cache.json")).mode & 0o777, 0o600);
  assert.deepEqual(cache.entries.map((entry) => entry.key), ["0", "1", "2", "3", "4"]);
});

test("audit log appends JSONL and rotates at the configured bound", (t) => {
  const root = tempRoot(t);
  const state = ensureStateDirectory(path.join(root, "state"));
  appendAudit(state, { event: "CHECK_PASSED", reason: "x".repeat(1024 * 1024) });
  appendAudit(state, { event: "CACHE_HIT" });
  const current = fs.readFileSync(path.join(state, "audit.jsonl"), "utf8");
  const previous = fs.readFileSync(path.join(state, "audit.jsonl.1"), "utf8");
  assert.match(current, /CACHE_HIT/);
  assert.match(previous, /CHECK_PASSED/);
  assert.equal(fs.statSync(path.join(state, "audit.jsonl")).mode & 0o777, 0o600);
});

test("cache refuses symlinked state files", (t) => {
  const root = tempRoot(t);
  const state = ensureStateDirectory(path.join(root, "state"));
  const target = path.join(root, "outside.json");
  fs.writeFileSync(target, JSON.stringify({ schema: 1, entries: [] }), { mode: 0o600 });
  fs.symlinkSync(target, path.join(state, "compatibility-cache.json"));
  assert.throws(() => readCache(state), /Unsafe safe-agy state file/);
});


test("cache lookup supports rollback to any prior PASS fingerprint only", () => {
  const cache = { entries: [
    { key: "newer", verdict: "PASS" },
    { key: "previously-approved", verdict: "PASS" },
    { key: "rejected", verdict: "HARD_FAIL" }
  ] };
  assert.equal(findCacheEntry(cache, { key: "previously-approved" })?.key, "previously-approved");
  assert.equal(findCacheEntry(cache, { key: "rejected" }), null);
  assert.equal(findCacheEntry(cache, { key: "missing" }), null);
});

test("fingerprint diagnostics distinguish cache hit, CLI identity and dependency drift", () => {
  const cli = {
    realpath: "/opt/agy", version: "1.5.9", sha256: "a".repeat(64),
    device: "10", inode: "20", size: 4096, mode: "755",
    elf: {
      class: "ELF64", machine: "AArch64", buildId: "build-1", interpreter: "/lib/ld.so",
      loader: { sha256: "b".repeat(64) },
      dependencies: [{ name: "libc.so.6", sha256: "c".repeat(64) }],
      readelf: { sha256: "d".repeat(64) }, ldconfig: { sha256: "e".repeat(64) }
    }
  };
  const host = { platform: "linux", arch: "arm64" };
  const fingerprint = { key: "same-key", cli, policy: { sha256: "f".repeat(64) }, host };
  const cache = { entries: [{
    key: "same-key", cli, policySha256: fingerprint.policy.sha256, host, verdict: "PASS"
  }] };
  assert.match(diffSummary(cache, fingerprint), /matches the latest/);

  const replaced = { ...fingerprint, key: "new-key", cli: { ...cli, inode: "21" } };
  assert.match(diffSummary(cache, replaced), /CLI file identity changed/);

  const changedDependency = {
    ...fingerprint,
    key: "dependency-key",
    cli: { ...cli, elf: { ...cli.elf, dependencies: [{ name: "libc.so.6", sha256: "9".repeat(64) }] } }
  };
  assert.match(diffSummary(cache, changedDependency), /ELF dependency fingerprint changed/);

  const changedPolicy = { ...fingerprint, key: "policy-key", policy: { sha256: "1".repeat(64) } };
  assert.match(diffSummary(cache, changedPolicy), /launcher\/policy\/test fingerprint changed/);
});

test("selects available Gemini models without fixing their version", () => {
  const models = "claude-sonnet-9 Claude\ngemini-9.1-flash-medium Gemini\ngemini-9.2-flash-low Gemini";
  assert.equal(selectGeminiModel(models), "gemini-9.2-flash-low");
  assert.equal(selectGeminiModel(models, "gemini-9.2-flash-low"), "gemini-9.1-flash-medium");
  assert.equal(selectGeminiModel("gemini-10.0-pro-high Gemini"), "gemini-10.0-pro-high");
  assert.equal(selectGeminiModel("claude-sonnet-9 Claude"), null);
  assert.equal(selectGeminiModel(""), null);
});

function failedStream(error, middle = [], id = "probe-1") {
  return [
    { event: "init", conversation_id: id },
    ...middle,
    { event: "result", result: { conversation_id: id, status: "ERROR", error } }
  ].map((entry) => JSON.stringify(entry)).join("\n");
}

test("model discovery retries transient failures with backoff but stops on authentication", () => {
  const delays = [];
  let calls = 0;
  const found = discoverGeminiModels({
    listModels: () => ++calls === 1 ? { status: 1, stderr: "UNAVAILABLE" } :
      { status: 0, stdout: "gemini-3.8-flash-low Gemini\ngemini-3.8-flash-medium Gemini" },
    wait: (ms) => delays.push(ms), random: () => 0.5
  });
  assert.equal(found.model, "gemini-3.8-flash-low");
  assert.equal(found.backup, "gemini-3.8-flash-medium");
  assert.equal(found.attempts, 2);
  assert.deepEqual(delays, [1500]);
  let authCalls = 0;
  const auth = discoverGeminiModels({ listModels: () => { authCalls++; return { status: 1, stderr: "UNAUTHENTICATED" }; },
    wait: () => { throw Error("must not retry authentication"); } });
  assert.equal(authCalls, 1);
  assert.equal(auth.reason, "authentication");
  let emptyCalls = 0;
  const empty = discoverGeminiModels({ listModels: () => { emptyCalls++; return { status: 0, stdout: "" }; }, wait: () => {} });
  assert.equal(emptyCalls, 3);
  assert.equal(empty.reason, "model_unavailable");
  const unsafe = discoverGeminiModels({ listModels: () => { throw Error("unsafe executable"); }, wait: () => { throw Error("must not retry"); } });
  assert.equal(unsafe.attempts, 1);
  assert.equal(unsafe.reason, "unknown");
});

test("retries quota failures only with a complete stream before a tool has run", () => {
  const quota = failedStream("Individual quota reached.");
  const tool = { event: "step_update", step_update: { tool_name: "invoke_subagent" } };
  assert.equal(selectGeminiModel("gemini-3.8-flash-low Gemini", "gemini-3.8-flash-low"), null);
  assert.equal(selectGeminiModel("gpt-oss-120b-medium GPT\nclaude-sonnet-4-6 Claude"), null);
  assert.equal(canRetryQuotaFailure(3, quota), true);
  assert.equal(canRetryQuotaFailure(3, failedStream("Individual quota reached.", [tool])), false);
  assert.equal(canRetryQuotaFailure(3, failedStream("Individual quota reached.", [{ event: "step_update", step_update: { step_type: "subagent" } }])), false);
  assert.equal(canRetryQuotaFailure(0, quota), false);
  assert.equal(canRetryQuotaFailure(3, "not-json"), false);
  assert.equal(canRetryQuotaFailure(3, failedStream("other error")), false);
  assert.equal(canRetryQuotaFailure(3, JSON.stringify({ event: "result", result: { error: "Individual quota reached" } })), false);
  assert.equal(canRetryQuotaFailure(3, quota + "\n" + quota), false);
  assert.equal(canRetryQuotaFailure(null, quota), false);
});

test("diagnoses sanitized quota, authentication, network, timeout and unknown failures", () => {
  assert.equal(classifyProbeFailure("RESOURCE_EXHAUSTED"), "quota");
  assert.equal(classifyProbeFailure("UNAUTHENTICATED"), "authentication");
  assert.equal(classifyProbeFailure("ECONNRESET secret@example.invalid"), "network");
  assert.equal(classifyProbeFailure("DEADLINE_EXCEEDED"), "timeout");
  assert.equal(classifyProbeFailure("unexpected failure"), "unknown");
  assert.equal(describeProbeFailure(1, "ECONNRESET secret@example.invalid"), "Antigravity network or service temporarily unavailable");
  assert.equal(describeProbeFailure(1, "UNAUTHENTICATED"), "Antigravity authentication required");
  assert.equal(diagnoseSuiteFailure({ status: 78, stderr: "Antigravity authentication required" }).category, "authentication");
  assert.equal(diagnoseSuiteFailure({ status: 78, stderr: "No available Gemini model could be discovered" }).category, "model_unavailable");
  assert.equal(diagnoseSuiteFailure({ status: 78, stderr: "Antigravity usage quota reached" }).category, "quota");
  assert.equal(diagnoseSuiteFailure({ status: 78, stderr: "Antigravity network or service temporarily unavailable" }).category, "network");
  assert.equal(diagnoseSuiteFailure({ status: 78, reason: "Compatibility suite timed out; verdict UNKNOWN" }).category, "timeout");
  assert.equal(diagnoseSuiteFailure({ status: 1, stderr: "Antigravity usage quota reached" }).category, "test_failure");
});

test("one recovery retry keeps the chosen model for transient failures and switches Gemini for quota", () => {
  for (const [error, expectedModel, kind] of [
    ["ECONNRESET", "gemini-primary", "network"],
    ["DEADLINE_EXCEEDED", "gemini-primary", "timeout"],
    ["individual quota reached", "gemini-backup", "quota"]
  ]) {
    const calls = [];
    const delays = [];
    const out = runProbeWithRecovery({
      primaryModel: "gemini-primary", backupModel: "gemini-backup",
      runProbe: (model, attempt) => {
        calls.push([model, attempt]);
        return attempt === 0 ? { status: 1, stdout: failedStream(error) } : { status: 0, stdout: "ok" };
      },
      isPristine: () => true,
      wait: (ms) => delays.push(ms),
      random: () => 0.5
    });
    assert.deepEqual(delays, [1500]);
    assert.deepEqual(calls, [["gemini-primary", 0], [expectedModel, 1]]);
    assert.equal(out.model, expectedModel);
    assert.equal(out.retryKind, kind);
    assert.equal(out.result.status, 0);
  }
});

test("never retries after a tool call, fixture change, missing backup, malformed stream or authentication failure", () => {
  for (const [stream, pristine, backup] of [
    [failedStream("ECONNRESET", [{ event: "step_update", step_update: { tool_name: "write_file" } }]), true, "gemini-backup"],
    [failedStream("ECONNRESET"), false, "gemini-backup"],
    [failedStream("individual quota reached"), true, null],
    ["truncated", true, "gemini-backup"],
    [failedStream("UNAUTHENTICATED"), true, "gemini-backup"]
  ]) {
    let calls = 0;
    const out = runProbeWithRecovery({
      primaryModel: "gemini-primary", backupModel: backup,
      runProbe: () => { calls++; return { status: 1, stdout: stream }; },
      isPristine: () => pristine
    });
    assert.equal(calls, 1);
    assert.equal(out.retryKind, null);
  }
  assert.equal(retryableProbeFailure(1, failedStream("ECONNRESET") + "\n{}"), null);
  assert.equal(retryableProbeFailure(1, failedStream("ECONNRESET").replace("probe-1\",\"status", "other-id\",\"status")), null);
  let calls = 0;
  const delays = [];
  const stillFailing = runProbeWithRecovery({
    primaryModel: "gemini-primary", backupModel: "gemini-backup",
    runProbe: () => { calls++; return { status: 1, stdout: failedStream("ECONNRESET") }; },
    isPristine: () => true,
    wait: (ms) => delays.push(ms),
    random: () => 0.5
  });
  assert.equal(calls, 3);
  assert.deepEqual(delays, [1500, 3000]);
  assert.deepEqual(stillFailing.retryKinds, ["network", "network"]);
  assert.equal(stillFailing.result.status, 1);
  let quotaCalls = 0;
  runProbeWithRecovery({
    primaryModel: "gemini-primary", backupModel: "gemini-backup",
    runProbe: () => { quotaCalls++; return { status: 1, stdout: failedStream("individual quota reached") }; },
    isPristine: () => true, wait: () => {}
  });
  assert.equal(quotaCalls, 2);
  let checks = 0;
  let retried = 0;
  const changedDuringWait = runProbeWithRecovery({
    primaryModel: "gemini-primary",
    runProbe: () => { retried++; return { status: 1, stdout: failedStream("ECONNRESET") }; },
    isPristine: () => ++checks === 1,
    wait: () => {}
  });
  assert.equal(retried, 1);
  assert.equal(changedDuringWait.retryKind, null);
  assert.throws(() => runProbeWithRecovery({
    primaryModel: "gemini-primary",
    runProbe: () => ({ status: 1, stdout: failedStream("ECONNRESET") }),
    isPristine: () => { throw new Error("snapshot integrity failed"); }
  }), /snapshot integrity failed/);
});

test("reports quota exhaustion without exposing unrelated errors", () => {
  assert.equal(describeProbeFailure(3, "Individual quota reached. Resets in 159h24m2s."), "Antigravity usage quota reached; resets in 159h24m2s");
  assert.equal(describeProbeFailure(1, "error with private details"), "Antigravity CLI returned nonzero exit code 1");
});

test("compatibility verdicts distinguish hard failure from unknown environment", () => {
  assert.equal(classifySuiteStatus(0), "PASS");
  assert.equal(classifySuiteStatus(1), "HARD_FAIL");
  assert.equal(classifySuiteStatus(78), "UNKNOWN");
  assert.equal(classifySuiteStatus(null), "UNKNOWN");
});

test("only explicitly recognized compatibility warnings may be soft", () => {
  const known = "Truncating suggested_prompts from 4 to 3 in file:///root/.gemini/config/plugins/flutter/plugin.json";
  const native = "W1114 11:04:13.063627     251 plugins.go:423] " + known;
  assert.deepEqual(extractSoftWarnings({ stdout: "SOFT_WARNING: " + known + "\n" }), [known]);
  assert.deepEqual(extractSoftWarnings({
    stderr: ["SOFT_WARNING: " + native, "SOFT_WARNING: " + native].join("\n")
  }), [known]);
  assert.throws(
    () => extractSoftWarnings({ stderr: "SOFT_WARNING: W1114 11:04:13.063627 251 plugins.go:424] " + known + "\n" }),
    /requires manual review/
  );
  assert.throws(
    () => extractSoftWarnings({ stderr: "SOFT_WARNING: Truncating suggested_prompts from 4 to 3 in file:///root/.gemini/config/plugins/unknown/plugin.json\n" }),
    /requires manual review/
  );
  assert.throws(
    () => extractSoftWarnings({ stderr: "SOFT_WARNING: unreviewed security warning\n" }),
    /requires manual review/
  );
});

test("active CLI warning extraction forwards unknown warning families to the fail-closed classifier", () => {
  const known = "W1114 12:00:00.123456     251 plugins.go:423] Truncating suggested_prompts from 4 to 3 in file:///root/.gemini/config/plugins/flutter/plugin.json";
  const unknownGo = "W1114 12:00:01.123456     252 agent.go:17] Future runtime warning";
  const conventional = "WARNING: an unreviewed runtime warning";
  const experimental = "ExperimentalWarning: an unreviewed Node warning";
  const bracketed = "[WARN] an unreviewed CLI warning";
  const unknownGoError = "E1114 12:00:02.123456     253 security.go:18] Future runtime error";
  const transcript = ["INFO: ordinary output", known, unknownGo, unknownGoError, conventional, experimental, bracketed].join("\n");
  assert.deepEqual(extractWarningLines(transcript), [known, unknownGo, unknownGoError, conventional, experimental, bracketed]);
  assert.deepEqual(extractWarningLines("INFO: ordinary output\nnormal progress"), []);
  const forwarded = extractWarningLines(transcript).map((line) => "SOFT_WARNING: " + line).join("\n");
  assert.throws(() => extractSoftWarnings({ stderr: forwarded }), /requires manual review/);
});


test("Antigravity warning classifier accepts only context-proven startup and PRoot limitations", () => {
  const transcript = [
    "W1114 15:09:39.358102 30 cache.go:157] Cache(loadCodeAssistResponse): Singleflight refresh failed: error getting token source: You are not logged into Antigravity.",
    "E1114 15:09:39.359001 30 errorreport.go:307] error getting token source: You are not logged into Antigravity.",
    "E1114 15:09:39.359100 30 errorreport.go:307] Failed to poll ListExperiments: error getting token source: You are not logged into Antigravity.",
    "W1114 15:09:39.456993 38 defaults.go:717] failed to get cs path: cs path /usr/bin/cs invalid",
    "W1114 15:09:40.070145 1 auto_updater.go:274] Directory /proc/31557/fd is not fully accessible (readable: true, writable: false), skipping update",
    "W1114 15:09:48.683760 148 connector.go:131] MCP server science_biomolecular_structure_viewer_mcp: exec: \"agy-node\": executable file not found in $PATH",
    "W1114 15:09:49.049499 147 connector.go:131] MCP server flutter_dart-mcp-server: exec: \"dart\": executable file not found in $PATH",
    "E1114 15:09:59.868813 3134 customization.go:450] Failed to discover in dir \"/tmp/project/.agents/agents/device-qa.md\": open /tmp/project/.agents/agents/device-qa.md: not a directory",
    "W1114 15:09:42.315925 463 cache.go:189] Failed to refresh cache in background: admin controls not applicable",
    "I1114 15:09:42.313819 1 server_oauth.go:226] OAuth: authenticated successfully as private@example.invalid",
    "I1114 15:09:42.313320 1 server_oauth.go:221] applyAuthResult: email=private@example.invalid, authMethod=consumer, quotaProject=",
    "I1114 15:09:45.261158 459 http_helpers.go:709] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse Trace: 0x123 ResponseID: test",
    "W1114 15:09:54.458303 2063 plugins.go:423] Truncating suggested_prompts from 4 to 3 in file:///root/.gemini/config/plugins/flutter/plugin.json",
    "W1114 15:09:59.980692 2775 registry.go:56] Tool \"wait\" is deprecated and has no effect"
  ].join("\n");
  const result = classifyAntigravityWarnings(transcript, {
    platform: "linux",
    csPathExists: false,
    delegationsVerified: true,
    projectMcpConfigured: false
  });
  assert.equal(result.authEvidence.oauthAuthenticated, true);
  assert.equal(result.authEvidence.modelStreamObserved, true);
  assert.equal(result.authEvidence.consumerAccount, true);
  assert.ok(result.warnings.includes("Transient startup auth-cache warnings resolved by successful OAuth authentication and model streaming"));
  assert.ok(result.warnings.includes("Consumer account: enterprise admin-control cache is not applicable"));
  assert.ok(result.warnings.includes("Optional /usr/bin/cs helper unavailable; optional helper feature not verified"));
  assert.ok(result.warnings.includes("PRoot host: background auto-updater skipped inaccessible /proc/<pid>/fd; use agy update manually"));
  assert.ok(result.warnings.includes("Optional global MCP server science_biomolecular_structure_viewer_mcp unavailable; missing executable agy-node"));
  assert.ok(result.warnings.includes("Optional global MCP server flutter_dart-mcp-server unavailable; missing executable dart"));
  assert.ok(result.warnings.includes("Known .agents/agents Markdown discovery fallback; active subagent delegation verified"));
  assert.ok(result.warnings.includes("Tool \"wait\" is deprecated and has no effect"));
  assert.equal(result.rawWarningCount, 11);
});

test("updated Antigravity diagnostics are accepted only after successful delegation", () => {
  const base = [
    "OAuth: authenticated successfully as private@example.invalid",
    "URL: https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse"
  ].join("\n");
  const directory = 'E1123 00:48:14.908843 1 launchsteps.go:108] Failed to resolve GeminiDir ".gemini": .gemini must be an absolute path: path is not absolute, falling back to default';
  const plugin = "W1123 00:48:15.254549 15 plugins.go:439] Truncating suggested_prompts from 5 to 3 in file:///root/.gemini/config/plugins/firebase/plugin.json";
  const analytics = 'E1123 01:06:59.000000 15 telemetry.go:20] error recording trajectory segment analytics: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:recordTrajectoryAnalytics": context canceled';
  const configFallback = 'W1123 01:06:59.000000 15 config.go:20] AICode FetchConfig failed, falling back to CCPA ListExperiments: failed to make AI Code FetchConfig request: Get "https://aicode.googleapis.com/v1alpha:fetchConfig": context deadline exceeded';
  const watcher = "E1123 01:06:59.000000 15 file_watcher.go:194] skipping empty or temp file: ";
  const shutdown = "E1123 01:06:59.000000 15 language.go:20] Language server shutdown timed out";
  const result = classifyAntigravityWarnings([base, directory, plugin, analytics, configFallback, watcher, shutdown].join("\n"), { delegationsVerified: true });
  assert.ok(result.warnings.includes("Antigravity used its default Gemini directory; agent delegation verified"));
  assert.ok(result.warnings.includes("Antigravity analytics request was canceled during agent execution"));
  assert.ok(result.warnings.includes("Antigravity configuration request timed out and used its fallback"));
  assert.ok(result.warnings.includes("Antigravity file watcher skipped an unnamed empty/temp file after the active probe completed"));
  assert.ok(result.warnings.includes("Antigravity language server shutdown timed out after the probe"));
  assert.equal(result.warnings.length, 6);
  assert.throws(() => classifyAntigravityWarnings([base, shutdown].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.throws(() => classifyAntigravityWarnings([base, watcher].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.throws(() => classifyAntigravityWarnings([base, configFallback].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.throws(() => classifyAntigravityWarnings([base, analytics].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.throws(() => classifyAntigravityWarnings([base, directory].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.throws(() => classifyAntigravityWarnings([base, plugin].join("\n"), { delegationsVerified: false }), /Unrecognized/);
  assert.deepEqual(extractSoftWarnings({ stdout: result.warnings.map((warning) => "SOFT_WARNING: " + warning).join("\n") }), result.warnings);
});

test("Antigravity warning classifier fails closed on unresolved or unverified warning contexts", () => {
  const authWarning = "W1114 15:09:39.358102 30 cache.go:157] Cache(loadCodeAssistResponse): Singleflight refresh failed: error getting token source: You are not logged into Antigravity.";
  const oauth = "I1114 15:09:42.313819 1 server_oauth.go:226] OAuth: authenticated successfully as private@example.invalid";
  const model = "I1114 15:09:45.261158 459 http_helpers.go:709] URL: https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse Trace: 0x123 ResponseID: test";
  const admin = "W1114 15:09:42.315925 463 cache.go:189] Failed to refresh cache in background: admin controls not applicable";
  const consumer = "I1114 15:09:42.313320 1 server_oauth.go:221] applyAuthResult: email=private@example.invalid, authMethod=consumer, quotaProject=";
  const base = [oauth, consumer, model, admin].join("\n");
  assert.throws(() => classifyAntigravityWarnings(authWarning + "\n" + model, { platform: "linux" }), /did not prove successful OAuth/);
  assert.throws(() => classifyAntigravityWarnings([oauth, authWarning, model].join("\n"), { platform: "linux" }), /occurred after OAuth success/);
  assert.throws(() => classifyAntigravityWarnings([oauth, "E1114 15:09:42.315925 463 errorreport.go:307] error getting token source: You are not logged into Antigravity.", model].join("\n"), { platform: "linux" }), /occurred after OAuth success/);
  assert.throws(() => classifyAntigravityWarnings([oauth, model, admin].join("\n"), { platform: "linux" }), /without verified consumer-account context/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nW1114 15:09:48.683760 148 connector.go:131] MCP server science_biomolecular_structure_viewer_mcp: exec: \"agy-node\": executable file not found in $PATH", {
    platform: "linux", projectMcpConfigured: true
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nW1114 15:09:48.683760 148 connector.go:131] MCP server unknown_mcp: exec: \"node\": executable file not found in $PATH", {
    platform: "linux"
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nW1114 15:09:48.683760 148 agent.go:17] Future runtime warning", {
    platform: "linux"
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nE1114 15:09:59.868813 3134 security.go:4] Unreviewed error", {
    platform: "linux"
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nW1114 15:09:39.456993 38 defaults.go:717] failed to get cs path: cs path /usr/bin/cs invalid", {
    platform: "linux", csPathExists: true
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nW1114 15:09:40.070145 1 auto_updater.go:274] Directory /proc/31557/fd is not fully accessible (readable: true, writable: false), skipping update", {
    platform: "darwin"
  }), /Unrecognized Antigravity runtime warning/);
  assert.throws(() => classifyAntigravityWarnings(base + "\nE1114 15:09:59.868813 3134 customization.go:450] Failed to discover in dir \"/tmp/project/.agents/agents/device-qa.md\": open /tmp/project/.agents/agents/device-qa.md: not a directory", {
    platform: "linux", delegationsVerified: false
  }), /Unrecognized Antigravity runtime warning/);
});


test("failure evidence redacts account emails, bearer tokens and API keys", () => {
  const source = "email=person@example.com Authorization: Bearer abc.def.ghi api=AIzaSyA12345678901234567890";
  const redacted = redactEvidenceText(source);
  assert.match(redacted, /<redacted-email>/);
  assert.match(redacted, /Bearer <redacted>/);
  assert.match(redacted, /<redacted-api-key>/);
  assert.doesNotMatch(redacted, /person@example\.com|abc\.def\.ghi|AIzaSyA12345678901234567890/);
});

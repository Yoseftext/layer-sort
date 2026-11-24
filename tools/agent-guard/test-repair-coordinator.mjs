import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { boundedDiagnostic, copyUntrackedFiles, hasRepairDelegation, repairCategory, repairOnFailure, repairWorkerFailure, repairFailureHighlights, selectedModel, REPAIR_FILES } from "./repair-coordinator.mjs";

const failed = "RECOVERY_DIAGNOSIS: unknown\nCOMPATIBILITY_UNKNOWN: unexpected CLI behavior\n";
const delegated = JSON.stringify({ event: "step_update", step_update: { state: "DONE", step_type: "subagent",
  subagent_info: { subagents: [{ type_name: "compatibility-repair", conversation_id: "review-1" }] } } }) + "\nGUARD_OK (agent exit 0)\n";

function fixture(t, options = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "auto-repair-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, "project");
  const infra = path.join(project, ".worktrees", "infrastructure");
  const worktree = path.join(project, ".worktrees", "task");
  fs.mkdirSync(infra, { recursive: true });
  fs.mkdirSync(worktree, { recursive: true });
  fs.mkdirSync(path.join(project, ".git"));
  if (options.untrackedFile) {
    const file = path.join(worktree, options.untrackedFile);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, "untracked user work");
  }
  const foreignGit = path.join(root, "foreign-git");
  fs.mkdirSync(foreignGit);
  const seen = [];
  let diffCount = 0;
  let candidate = "";
  const run = (command, args, runOptions = {}) => {
    seen.push({ command, args, options: runOptions });
    if (command === "git" && args.includes("--show-toplevel")) return { status: 0, stdout: args[1] + "\n" };
    if (command === "git" && args.includes("--git-common-dir")) return { status: 0, stdout: (options.foreign ? foreignGit : path.join(project, ".git")) + "\n" };
    if (command === "git" && args.includes("rev-parse") && args.includes("HEAD")) return { status: 0, stdout: "a".repeat(40) + "\n" };
    if (command === "git" && args.includes("ls-files")) return { status: 0, stdout: options.untracked || "" };
    if (command === "git" && args.includes("worktree")) {
      candidate = args.at(-2);
      fs.mkdirSync(path.join(candidate, "docs"), { recursive: true });
      fs.mkdirSync(path.join(candidate, ".agents/agents"), { recursive: true });
      fs.writeFileSync(path.join(candidate, ".agents/agents/compatibility-repair.md"), "agent");
      return { status: 0, stdout: "" };
    }
    if (command === "git" && args.includes("apply")) return { status: 0, stdout: "" };
    if (command === "git" && args.includes("diff")) {
      diffCount++;
      return { status: 0, stdout: diffCount === 1 ? "existing user patch" :
        options.noPatch ? "existing user patch" : "existing user patch + repair" };
    }
    if (command === process.execPath) return { status: 0, stdout: "{}" };
    if (command === "/usr/bin/bash" && args.includes("--check"))
      return { status: options.validationStatus ?? 0, stdout: "check" };
    if (command === "/usr/bin/bash") return { status: options.workerStatus ?? 0,
      stdout: options.noDelegation ? "GUARD_OK" : delegated };
    throw Error("Unexpected command in test: " + command + " " + args.join(" "));
  };
  const dependencies = {
    run, emit: () => {}, getProjectRoot: () => project,
    getApprovedCli: async () => options.noFallback ? "agy" : "/verified/old/agy",
    getHash: async (p) => options.sameCli ? "same" : p.includes("/verified/") ? "old" : "current",
    resolveCli: () => ({ realpath: "/current/agy" }),
    getState: () => ({}),
    compareStates: () => options.noPatch ? [] : options.outside ? ["outside.txt"] : ["tools/agent-guard/compatibility.mjs"]
  };
  return { project, infra, worktree, seen, dependencies, getCandidate: () => candidate };
}

test("repair specialist inherits the user's model and is available to the lead", () => {
  const source = process.env.SAFE_AGY_INFRA_DIR || path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
  const agent = fs.readFileSync(path.join(source, ".agents/agents/compatibility-repair.md"), "utf8");
  const lead = fs.readFileSync(path.join(source, ".agents/agents/layer-sort-lead.md"), "utf8");
  const frontmatter = agent.split("---")[1] || "";
  assert.match(frontmatter, /^model: inherit$/m);
  assert.match(frontmatter, /^subagent: true$/m);
  assert.doesNotMatch(frontmatter, /^\s+- run_command$/m);
  assert.match(lead, /^\s+- compatibility-repair\.md$/m);
});

test("only unknown and technical test failures may trigger the repair worker", () => {
  assert.equal(repairCategory(failed), "unknown");
  assert.equal(repairCategory("RECOVERY_DIAGNOSIS: test_failure"), "test_failure");
  assert.equal(repairCategory("SAFE_AGY_COMPATIBILITY_UNKNOWN: Antigravity is not an ELF executable"), "identity");
  assert.equal(repairCategory("SAFE_AGY_COMPATIBILITY_UNKNOWN: Unsafe executable permissions"), null);
  for (const category of ["quota", "network", "authentication", "timeout", "model_unavailable"]) {
    assert.equal(repairCategory("RECOVERY_DIAGNOSIS: " + category), null);
  }
  assert.equal(repairCategory("RECOVERY_DIAGNOSIS: unknown\nRECOVERY_DIAGNOSIS: test_failure"), null);
});

test("model selection preserves the user's explicit model and ignores prompt text", () => {
  assert.equal(selectedModel(["--agent", "lead", "-p", "--model", "--model", "gemini-flash"]), "gemini-flash");
  assert.equal(selectedModel(["--agent", "lead", "-p", "--model"]), null);
  assert.equal(selectedModel(["--model", "first", "--disable-slash-commands", "--model", "last"]), "last");
});

test("reports only bounded sanitized diagnostics", () => {
  const result = boundedDiagnostic("COMPATIBILITY_UNKNOWN: token=abc user@example.invalid\nnoise with private text");
  assert.match(result, /token=<redacted>/);
  assert.match(result, /<redacted-email>/);
  assert.doesNotMatch(result, /abc|user@example|noise/);
  assert.ok(boundedDiagnostic("COMPATIBILITY_UNKNOWN: " + "x".repeat(9000)).length <= 4000);
});

test("categorizes worker failure without returning private provider messages", () => {
  const result = JSON.stringify({ event: "result", result: { error: "UNAVAILABLE token=private" } });
  assert.equal(repairWorkerFailure({ stdout: result }), "network");
  assert.equal(repairWorkerFailure({ stderr: "UNAUTHENTICATED" }), "authentication");
  assert.equal(repairWorkerFailure({ stderr: "RECOVERY_DIAGNOSIS: test_failure" }), "fallback_test_failure");
  assert.equal(repairWorkerFailure({ stderr: "unrecognized private details" }), "worker_failed");
  const highlights = repairFailureHighlights("noise token=secret\n✖ bad test token=abc user@example.invalid");
  assert.equal(highlights.length, 1);
  assert.doesNotMatch(highlights[0], /abc|user@example/);
});

test("delegation requires a completed real named subagent record", () => {
  assert.equal(hasRepairDelegation(delegated), true);
  assert.equal(hasRepairDelegation('{"event":"result","result":{"response":"compatibility-repair"}}'), false);
  assert.equal(hasRepairDelegation('{"event":"step_update","step_update":{"state":"ACTIVE","step_type":"subagent"}}'), false);
});

test("preserves user changes and selected model in an isolated repair candidate", async (t) => {
  const f = fixture(t);
  const result = await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
    args: ["--agent", "lead", "--model", "gemini-selected", "-p", "private prompt"],
    env: { PATH: "/usr/bin", AGY_BIN: "/current/agy" } }, f.dependencies);
  assert.equal(result.status, "CANDIDATE_TESTED");
  assert.match(result.candidate, /auto-repair-/);
  assert.ok(fs.readdirSync(path.join(result.candidate, "docs")).some((name) => /^auto-repair-report-.*\.txt$/.test(name)));
  const created = f.seen.find((item) => item.args.includes("worktree"));
  assert.equal(created.args[1], f.worktree);
  assert.equal(created.args.at(-1), "a".repeat(40));
  const applied = f.seen.find((item) => item.args.includes("apply"));
  assert.equal(applied.options.input, "existing user patch");
  const prepare = f.seen.find((item) => item.command === process.execPath);
  for (const file of REPAIR_FILES) assert.ok(prepare.args.includes(file));
  const worker = f.seen.find((item) => item.command === "/usr/bin/bash" && !item.args.includes("--check"));
  assert.equal(worker.options.env.AGY_BIN, "/verified/old/agy");
  assert.equal(worker.options.env.SAFE_AGY_REPAIR_CHILD, "1");
  assert.equal(worker.options.env.SAFE_AGY_REPAIR_VERBOSE_FAILURE, "1");
  assert.equal(worker.args[worker.args.indexOf("--model") + 1], "gemini-selected");
  assert.ok(!worker.args.includes("private prompt"));
  const validation = f.seen.find((item) => item.args.includes("--check"));
  assert.equal(validation.options.env.AGY_BIN, "/current/agy");
});

test("no repair for environmental errors, child recursion or missing fallback", async (t) => {
  const f = fixture(t);
  for (const stderr of ["RECOVERY_DIAGNOSIS: network", "RECOVERY_DIAGNOSIS: quota"]) {
    const result = await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr }, f.dependencies);
    assert.equal(result.status, "SKIPPED");
  }
  assert.equal((await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
    env: { SAFE_AGY_REPAIR_CHILD: "1" } }, f.dependencies)).status, "SKIPPED");
  assert.ok(!f.seen.some((item) => item.args.includes("worktree")));
  const noFallback = fixture(t, { noFallback: true });
  assert.equal((await repairOnFailure({ infra: noFallback.infra, worktree: noFallback.worktree, stderr: failed,
    env: { PATH: "/usr/bin" } }, noFallback.dependencies)).status, "BLOCKED");
});

test("copies untracked user improvements to the isolated candidate", async (t) => {
  const file = "docs/new-note.md";
  const f = fixture(t, { untracked: file + "\0", untrackedFile: file });
  const result = await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
    env: { PATH: "/usr/bin" } }, f.dependencies);
  assert.equal(result.status, "CANDIDATE_TESTED");
  assert.equal(fs.readFileSync(path.join(f.worktree, file), "utf8"), "untracked user work");
  assert.equal(fs.readFileSync(path.join(result.candidate, file), "utf8"), "untracked user work");
});

test("rejects unsafe untracked paths and symlinks without touching originals", (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "repair-copy-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const source = path.join(root, "source"), candidate = path.join(root, "candidate");
  fs.mkdirSync(source); fs.mkdirSync(candidate);
  fs.writeFileSync(path.join(source, ".env"), "private");
  assert.throws(() => copyUntrackedFiles(source, candidate, [".env"]), /Unsafe/);
  assert.throws(() => copyUntrackedFiles(source, candidate, ["../outside"]), /Unsafe/);
  fs.symlinkSync(path.join(source, ".env"), path.join(source, "link.txt"));
  assert.throws(() => copyUntrackedFiles(source, candidate, ["link.txt"]), /Unsupported/);
  assert.equal(fs.readFileSync(path.join(source, ".env"), "utf8"), "private");
  assert.deepEqual(fs.readdirSync(candidate), []);
});

test("rejects an infrastructure checkout from another Git repository", async (t) => {
  const f = fixture(t, { foreign: true });
  await assert.rejects(() => repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
    env: { PATH: "/usr/bin" } }, f.dependencies), /same project/);
  assert.ok(!f.seen.some((item) => item.args.includes("worktree")));
});

test("keeps incomplete or failed candidates and never reports them tested", async (t) => {
  for (const option of [{ noDelegation: true }, { noPatch: true }, { outside: true }, { workerStatus: 1 }]) {
    const f = fixture(t, option);
    const result = await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
      env: { PATH: "/usr/bin" } }, f.dependencies);
    assert.equal(result.status, "BLOCKED");
    assert.ok(result.candidate);
    assert.ok(!f.seen.some((item) => item.args.includes("--check")));
  }
  const f = fixture(t, { validationStatus: 78 });
  const result = await repairOnFailure({ infra: f.infra, worktree: f.worktree, stderr: failed,
    env: { PATH: "/usr/bin" } }, f.dependencies);
  assert.equal(result.status, "CANDIDATE_UNVERIFIED");
});

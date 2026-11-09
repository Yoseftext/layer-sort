import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { evaluate } from "./policy.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../..");
const event = (name, command, cwd = root) => ({
  toolCall: {
    name,
    args: command === undefined ? {} : { CommandLine: command, Cwd: cwd }
  },
  workspacePaths: [root]
});

assert.equal(evaluate(event("run_command", "tools/device-tests/agentctl status")).decision, "allow");
assert.equal(evaluate(event("run_command", "tools/device-tests/agentctl thermal")).decision, "allow");
assert.equal(evaluate(event("run_command", "tools/device-tests/agentctl tap 10 20 --owner-approved")).decision, "deny");
assert.equal(evaluate(event("run_command", "tools/device-tests/device_qa.py status")).decision, "deny");
assert.equal(evaluate(event("run_command", "adb devices -l")).decision, "deny");
assert.equal(evaluate(event("run_command", "/usr/bin/adb devices -l")).decision, "deny");
assert.equal(evaluate(event("run_command", "python3 -c print(1)")).decision, "deny");
assert.equal(evaluate(event("run_command", "git status --short")).decision, "allow");
assert.equal(evaluate(event("run_command", "git push origin main")).decision, "deny");
assert.equal(evaluate(event("run_command", "git worktree add .worktrees/x HEAD")).decision, "deny");
assert.equal(evaluate(event("run_command", "bash tools/device-tests/test-wrapper.sh")).decision, "allow");
assert.equal(evaluate(event("run_command", "bash -c echo")).decision, "deny");
assert.equal(evaluate(event("run_command", "godot --headless --path . --script res://tests/g5/circuit_test.gd")).decision, "allow");
assert.equal(evaluate(event("run_command", "godot --headless --export-release Android out.apk")).decision, "deny");
assert.equal(evaluate(event("run_command", "cat AGENTS.md")).decision, "allow");
assert.equal(evaluate(event("run_command", "cat /etc/passwd")).decision, "deny");
assert.equal(evaluate(event("run_command", "cat .env")).decision, "deny");
assert.equal(evaluate(event("run_command", "sed -i s/a/b/ README.md")).decision, "deny");
assert.equal(evaluate(event("run_command", "find . -delete")).decision, "deny");
assert.equal(evaluate(event("run_command", "ls /root/device-tests")).decision, "deny");
assert.equal(evaluate(event("run_command", "git status", "/root")).decision, "deny");
assert.equal(evaluate(event("write_file")).decision, "deny");
assert.equal(evaluate(event("edit_file")).decision, "deny");
assert.equal(evaluate(event("write_to_file")).decision, "deny");
assert.equal(evaluate(event("mcp__Remote_Desktop_Commander__write_file")).decision, "deny");
assert.equal(evaluate(event("mcp__Remote_Desktop_Commander__start_process")).decision, "deny");
const fileEvent = (name, args) => ({
  toolCall: { name, args },
  workspacePaths: [root]
});
assert.equal(
  evaluate(fileEvent("view_file", { AbsolutePath: path.join(root, "AGENTS.md") })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("view_file", { AbsolutePath: "/etc/passwd" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("view_file", { AbsolutePath: path.join(root, ".env") })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("view_file", { AbsolutePath: "AGENTS.md" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("list_dir", { DirectoryPath: "/root/device-tests" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("find_by_name", { SearchDirectory: "/root" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("grep_search", { SearchPath: path.join(root, "src") })).decision,
  "allow"
);
assert.equal(evaluate(event("multi_replace_file_content")).decision, "deny");
assert.equal(evaluate({ toolCall: { name: "run_command", args: {} }, workspacePaths: [] }).decision, "deny");
assert.equal(evaluate({ toolCall: {}, workspacePaths: [root] }).decision, "deny");

const script = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "policy.mjs");
const allowed = spawnSync(process.execPath, [script], {
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(allowed.status, 0);
assert.equal(JSON.parse(allowed.stdout).decision, "allow");

const denied = spawnSync(process.execPath, [script], {
  input: JSON.stringify(event("run_command", "adb devices -l")),
  encoding: "utf8"
});
assert.equal(denied.status, 0);
assert.equal(JSON.parse(denied.stdout).decision, "deny");
assert.ok(JSON.parse(denied.stdout).reason.length > 0);

const malformed = spawnSync(process.execPath, [script], {
  input: "{invalid",
  encoding: "utf8"
});
assert.equal(malformed.status, 0);
assert.equal(JSON.parse(malformed.stdout).decision, "deny");

const hookScript = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "policy.sh");
const pluginRoot = path.dirname(path.dirname(hookScript));
const hookDenied = spawnSync("bash", [hookScript], {
  cwd: pluginRoot,
  input: JSON.stringify(event("run_command", "adb devices -l")),
  encoding: "utf8"
});
assert.equal(hookDenied.status, 0);
assert.equal(JSON.parse(hookDenied.stdout).decision, "deny");

const hookAllowed = spawnSync("bash", [hookScript], {
  cwd: pluginRoot,
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(hookAllowed.status, 0);
assert.equal(JSON.parse(hookAllowed.stdout).decision, "allow");

const hookMalformed = spawnSync("bash", [hookScript], {
  cwd: pluginRoot,
  input: "{invalid",
  encoding: "utf8"
});
assert.equal(hookMalformed.status, 0);
assert.equal(JSON.parse(hookMalformed.stdout).decision, "deny");

process.stdout.write("POLICY_TESTS_PASS\n");

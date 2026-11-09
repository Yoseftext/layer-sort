import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { evaluate } from "./policy.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(scriptDirectory, "..");
const root = path.resolve(pluginRoot, "../../..");
const event = (name, command, cwd = root) => ({
  toolCall: {
    name,
    args: command === undefined ? {} : { CommandLine: command, Cwd: cwd }
  },
  workspacePaths: [root]
});
const fileEvent = (name, args) => ({
  toolCall: { name, args },
  workspacePaths: [root]
});
const decision = (name, command, cwd = root) =>
  evaluate(event(name, command, cwd)).decision;

assert.equal(decision("manage_task"), "allow");
assert.equal(decision("search_web"), "allow");
assert.equal(decision("invoke_subagent"), "allow");
assert.equal(decision("send_message"), "allow");
assert.equal(decision("manage_subagents"), "allow");
assert.equal(decision("ask_question"), "allow");

assert.equal(decision("unregistered_future_tool"), "deny");
assert.equal(decision("call_mcp_tool"), "deny");
assert.equal(decision("mcp__Remote_Desktop_Commander__write_file"), "deny");
assert.equal(decision("mcp__Remote_Desktop_Commander__start_process"), "deny");

for (const toolName of [
  "write_file", "edit_file", "write_to_file", "replace_file_content",
  "multi_replace_file_content", "apply_patch", "create_file", "delete_file",
  "remove_file", "move_file", "copy_file", "rename_file", "append_file",
  "create_directory", "make_directory", "write_pdf"
]) {
  assert.equal(decision(toolName), "deny", toolName + " must remain blocked");
}

assert.equal(decision("run_command", "tools/device-tests/agentctl status"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl battery"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl thermal"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl screenshot"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl tap 10 20 --owner-approved"), "deny");
assert.equal(decision("run_command", "tools/device-tests/device_qa.py status"), "deny");
assert.equal(decision("run_command", "adb devices -l"), "deny");
assert.equal(decision("run_command", "/usr/bin/adb devices -l"), "deny");
assert.equal(decision("run_command", "python3 -c print(1)"), "deny");

assert.equal(decision("run_command", "git status --short"), "allow");
assert.equal(decision("run_command", "git status --short --branch"), "allow");
assert.equal(decision("run_command", "git branch --show-current"), "allow");
assert.equal(decision("run_command", "git branch -vv"), "allow");
assert.equal(decision("run_command", "git rev-parse HEAD"), "allow");
assert.equal(decision("run_command", "git diff --check"), "allow");
assert.equal(decision("run_command", "git diff --stat"), "allow");
assert.equal(decision("run_command", "git ls-files --cached"), "allow");
assert.equal(decision("run_command", "git log -5 --oneline"), "allow");
assert.equal(decision("run_command", "git show --stat HEAD"), "allow");
assert.equal(decision("run_command", "git cat-file -t HEAD"), "allow");

assert.equal(decision("run_command", "git push origin main"), "deny");
assert.equal(decision("run_command", "git worktree add .worktrees/x HEAD"), "deny");
assert.equal(decision("run_command", "git diff"), "deny");
assert.equal(decision("run_command", "git diff --output=/tmp/policy.out"), "deny");
assert.equal(decision("run_command", "git diff --output /tmp/policy.out"), "deny");
assert.equal(decision("run_command", "git --output=/tmp/policy.out status"), "deny");
assert.equal(decision("run_command", "git diff --ext-diff"), "deny");
assert.equal(decision("run_command", "git diff --textconv"), "deny");
assert.equal(decision("run_command", "git show HEAD:.env"), "deny");
assert.equal(decision("run_command", "git cat-file -p HEAD"), "deny");

assert.equal(decision("run_command", "rg --line-number --fixed-strings TODO README.md"), "allow");
assert.equal(decision("run_command", "rg --pre cat README.md"), "deny");
assert.equal(decision("run_command", "rg --pre=cat TODO README.md"), "deny");
assert.equal(decision("run_command", "rg --pre-glob=*.md TODO README.md"), "deny");
assert.equal(decision("run_command", "rg --hidden TODO ."), "deny");

assert.equal(decision("run_command", "sed -n 1,10p README.md"), "allow");
assert.equal(decision("run_command", "sed -n -e 1,10p README.md"), "allow");
assert.equal(decision("run_command", "sed -i s/a/b/ README.md"), "deny");
assert.equal(decision("run_command", "sed -n 1,10w README.md"), "deny");
assert.equal(decision("run_command", "sed -n 1,10e id README.md"), "deny");
assert.equal(decision("run_command", "sed -e w README.md"), "deny");
assert.equal(decision("run_command", "sed -f policy.sed README.md"), "deny");

assert.equal(decision("run_command", "find . -maxdepth 2 -type f -print"), "allow");
assert.equal(decision("run_command", "find . -maxdepth 2 -type f -print0"), "allow");
assert.equal(decision("run_command", "find . -fprint0 /tmp/policy.out"), "deny");
assert.equal(decision("run_command", "find . -fprintf /tmp/policy.out %p"), "deny");
assert.equal(decision("run_command", "find . -exec cat README.md"), "deny");
assert.equal(decision("run_command", "find . -delete"), "deny");

assert.equal(decision("run_command", "jq . README.md"), "allow");
assert.equal(decision("run_command", "jq -r .name .agents/plugins/layer-sort-agent-kit/plugin.json"), "allow");
assert.equal(decision("run_command", "jq 'system(\"id\")' package.json"), "deny");
assert.equal(decision("run_command", "jq -f filter.jq package.json"), "deny");

assert.equal(decision("run_command", "bash tools/device-tests/test-wrapper.sh"), "allow");
assert.equal(decision("run_command", "bash -c echo"), "deny");
assert.equal(
  decision("run_command", "godot --headless --path . --script res://tests/g2/classic_rules_test.gd"),
  "allow"
);
assert.equal(
  decision("run_command", "godot --headless --path . --script res://tests/g2/classic_rules_test.gd --editor"),
  "deny"
);
assert.equal(decision("run_command", "godot --headless --export-release Android out.apk"), "deny");

assert.equal(decision("run_command", "cat AGENTS.md"), "allow");
assert.equal(decision("run_command", "cat /etc/passwd"), "deny");
assert.equal(decision("run_command", "cat .env"), "deny");
assert.equal(decision("run_command", "cat .git/config"), "deny");
assert.equal(decision("run_command", "ls"), "allow");
assert.equal(decision("run_command", "ls --output=/tmp/out"), "deny");
assert.equal(decision("run_command", "stat AGENTS.md"), "allow");
assert.equal(decision("run_command", "tail -f AGENTS.md"), "deny");
assert.equal(decision("run_command", "curl https://example.com"), "deny");
assert.equal(decision("run_command", "git status", "/root"), "deny");
assert.equal(decision("run_command", "git status; touch marker"), "deny");
assert.equal(decision("run_command", "git status\ncat AGENTS.md"), "deny");
assert.equal(decision("run_command", "git status --short", "/root"), "deny");
assert.equal(decision("run_command"), "deny");
assert.equal(
  evaluate({ toolCall: { name: "run_command", args: {} }, workspacePaths: [] }).decision,
  "deny"
);
assert.equal(evaluate({ toolCall: {}, workspacePaths: [root] }).decision, "deny");
assert.equal(
  evaluate({
    toolCall: { name: "run_command", args: { CommandLine: "ls", Cwd: "/root" } },
    workspacePaths: ["/root"]
  }).decision,
  "deny"
);
assert.equal(
  evaluate({
    toolCall: { name: "view_file", args: { AbsolutePath: "/root/device-tests/private.txt" } },
    workspacePaths: ["/root", root]
  }).decision,
  "deny"
);

assert.equal(
  evaluate(fileEvent("view_file", { AbsolutePath: path.join(root, "AGENTS.md") })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("list_dir", { DirectoryPath: root })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("find_by_name", { SearchDirectory: root })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("grep_search", { SearchPath: path.join(root, "scripts") })).decision,
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

const policyScript = path.join(pluginRoot, "scripts", "policy.mjs");
const allowed = spawnSync(process.execPath, [policyScript], {
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(allowed.status, 0);
assert.equal(JSON.parse(allowed.stdout).decision, "allow");

const denied = spawnSync(process.execPath, [policyScript], {
  input: JSON.stringify(event("run_command", "adb devices -l")),
  encoding: "utf8"
});
assert.equal(denied.status, 0);
assert.equal(JSON.parse(denied.stdout).decision, "deny");
assert.ok(JSON.parse(denied.stdout).reason.length > 0);

const malformed = spawnSync(process.execPath, [policyScript], {
  input: "{invalid",
  encoding: "utf8"
});
assert.equal(malformed.status, 0);
assert.equal(JSON.parse(malformed.stdout).decision, "deny");

const hookScript = path.join(pluginRoot, "scripts", "policy.sh");
const hookConfigPath = path.join(pluginRoot, "hooks.json");
const hookConfig = JSON.parse(fs.readFileSync(hookConfigPath, "utf8"));
const guard = hookConfig["layer-sort-agent-guard"];
assert.equal(guard.enabled, true);
assert.equal(guard.PreToolUse.length, 1);
assert.equal(guard.PreToolUse[0].matcher, ".*");
assert.equal(guard.PreToolUse[0].hooks.length, 1);
assert.equal(guard.PreToolUse[0].hooks[0].command, "/usr/bin/bash " + hookScript);

const engineeringAgentPath = path.join(pluginRoot, "agents", "engineering-auditor.md");
const engineeringAgent = fs.readFileSync(engineeringAgentPath, "utf8");
const engineeringFrontmatter = engineeringAgent.split("---")[1] ?? "";
assert.match(engineeringFrontmatter, /^name: engineering-auditor$/m);
assert.match(engineeringFrontmatter, /^subagent: true$/m);
assert.match(engineeringFrontmatter, /^commandExecutionPolicy: off$/m);
assert.match(engineeringFrontmatter, /^inheritMcp: false$/m);
const toolsBlock = engineeringFrontmatter.match(/^tools:\s*\n((?:\s+- .+\n)+)/m);
assert.ok(toolsBlock, "engineering-auditor must declare an explicit tool allowlist");
assert.deepEqual(
  [...toolsBlock[1].matchAll(/^\s+- (.+)$/gm)].map((match) => match[1]),
  ["view_file", "send_message"]
);

const leadAgent = fs.readFileSync(path.join(pluginRoot, "agents", "layer-sort-lead.md"), "utf8");
assert.match(leadAgent, /^\s+- engineering-auditor\.md$/m);

const hookAllowed = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(hookAllowed.status, 0);
assert.equal(JSON.parse(hookAllowed.stdout).decision, "allow");

const hookDenied = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  input: JSON.stringify(event("run_command", "adb devices -l")),
  encoding: "utf8"
});
assert.equal(hookDenied.status, 0);
assert.equal(JSON.parse(hookDenied.stdout).decision, "deny");

const hookMalformed = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  input: "{invalid",
  encoding: "utf8"
});
assert.equal(hookMalformed.status, 0);
assert.equal(JSON.parse(hookMalformed.stdout).decision, "deny");

const hookWithoutNode = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  env: { ...process.env, PATH: "/nonexistent" },
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(hookWithoutNode.status, 0);
assert.equal(JSON.parse(hookWithoutNode.stdout).decision, "deny");

process.stdout.write("POLICY_TESTS_PASS\n");

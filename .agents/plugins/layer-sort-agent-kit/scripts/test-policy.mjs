import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { evaluate, PROJECT_ROOT, resolveProjectRoot } from "./policy.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(scriptDirectory, "..");
const workspaceRoot = path.resolve(pluginRoot, "../../..");
const root = PROJECT_ROOT;
const policyScript = path.join(pluginRoot, "scripts", "policy.mjs");
const policyWrapperScript = path.join(pluginRoot, "scripts", "policy.sh");

assert.equal(
  resolveProjectRoot(workspaceRoot),
  root,
  "the active workspace must resolve to its Git common repository root"
);

const rootResolutionFixture = fs.mkdtempSync(
  path.join(os.tmpdir(), "layer-sort-policy-root-")
);
try {
  const fixturePluginRoot = path.join(
    rootResolutionFixture,
    ".agents",
    "plugins",
    "layer-sort-agent-kit"
  );
  const fixtureScriptsDirectory = path.join(fixturePluginRoot, "scripts");
  const fixturePolicyPath = path.join(fixtureScriptsDirectory, "policy.mjs");
  const fixturePolicyWrapperPath = path.join(fixtureScriptsDirectory, "policy.sh");
  fs.mkdirSync(fixtureScriptsDirectory, { recursive: true });
  fs.mkdirSync(path.join(rootResolutionFixture, ".git"));
  fs.writeFileSync(path.join(rootResolutionFixture, ".git", "HEAD"), "ref: refs/heads/main\n");
  fs.copyFileSync(policyScript, fixturePolicyPath);
  fs.copyFileSync(policyWrapperScript, fixturePolicyWrapperPath);

  assert.equal(
    resolveProjectRoot(rootResolutionFixture, {
      pluginRoot: fixturePluginRoot,
      policyScriptDirectory: fixtureScriptsDirectory,
      policyScriptPath: fixturePolicyPath
    }),
    rootResolutionFixture,
    "a normal CI checkout with a .git directory must resolve without a machine-specific path"
  );

  const fixtureHook = spawnSync(
    "/usr/bin/bash",
    ["plugins/layer-sort-agent-kit/scripts/policy.sh"],
    {
      cwd: path.join(rootResolutionFixture, ".agents"),
      input: JSON.stringify({
        toolCall: {
          name: "run_command",
          args: {
            CommandLine: "/usr/bin/git status --short",
            Cwd: rootResolutionFixture
          }
        },
        workspacePaths: [rootResolutionFixture]
      }),
      encoding: "utf8"
    }
  );
  assert.equal(fixtureHook.status, 0);
  assert.equal(
    JSON.parse(fixtureHook.stdout).decision,
    "allow",
    "the relative policy wrapper must work from a normal checkout with a .git directory"
  );

  const symlinkWorkspaceRoot = path.join(rootResolutionFixture, "symlink-checkout");
  const symlinkPluginRoot = path.join(
    symlinkWorkspaceRoot,
    ".agents",
    "plugins",
    "layer-sort-agent-kit"
  );
  const symlinkScriptsDirectory = path.join(symlinkPluginRoot, "scripts");
  const symlinkPolicyPath = path.join(symlinkScriptsDirectory, "policy.mjs");
  fs.mkdirSync(symlinkScriptsDirectory, { recursive: true });
  fs.symlinkSync(path.join(rootResolutionFixture, ".git"), path.join(symlinkWorkspaceRoot, ".git"), "dir");
  fs.writeFileSync(symlinkPolicyPath, "// policy-root symlink fixture\\n");

  assert.throws(
    () =>
      resolveProjectRoot(symlinkWorkspaceRoot, {
        pluginRoot: symlinkPluginRoot,
        policyScriptDirectory: symlinkScriptsDirectory,
        policyScriptPath: symlinkPolicyPath
      }),
    /must not be a symlink/,
    "a symlinked .git marker must fail closed"
  );
} finally {
  fs.rmSync(rootResolutionFixture, { recursive: true, force: true });
}

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

assert.equal(decision("manage_task"), "deny");
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
assert.equal(decision("run_command", "tools/device-tests/agentctl performance-check"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl performance-check --force"), "deny");
assert.equal(decision("run_command", "tools/device-tests/agentctl screenshot"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl tap 10 20 --owner-approved"), "deny");
assert.equal(decision("run_command", "tools/device-tests/agentctl ../device-tests/agentctl status"), "deny");
assert.equal(decision("run_command", "tools/device-tests/device_qa.py status"), "deny");
assert.equal(decision("run_command", "adb devices -l"), "deny");
assert.equal(decision("run_command", "/usr/bin/adb devices -l"), "deny");
assert.equal(decision("run_command", "python3 -c print(1)"), "deny");
assert.equal(decision("run_command", "/usr/bin/python3.13 -I -c print(1)"), "deny");

assert.equal(decision("run_command", "/usr/bin/git status --short"), "allow");
assert.equal(decision("run_command", "/usr/bin/git status --short --branch"), "allow");
assert.equal(decision("run_command", "/usr/bin/git branch --show-current"), "allow");
assert.equal(decision("run_command", "/usr/bin/git branch -vv"), "allow");
assert.equal(decision("run_command", "/usr/bin/git rev-parse HEAD"), "allow");
assert.equal(decision("run_command", "/usr/bin/git diff --check"), "allow");
assert.equal(decision("run_command", "/usr/bin/git diff --stat"), "allow");
assert.equal(decision("run_command", "/usr/bin/git ls-files --cached"), "allow");
assert.equal(decision("run_command", "/usr/bin/git log -5 --oneline"), "allow");
assert.equal(decision("run_command", "/usr/bin/git show --stat HEAD"), "allow");
assert.equal(decision("run_command", "/usr/bin/git cat-file -t HEAD"), "allow");
assert.equal(decision("run_command", "git status --short"), "deny");
assert.equal(decision("run_command", "/tmp/git status --short"), "deny");

assert.equal(decision("run_command", "/usr/bin/git push origin main"), "deny");
assert.equal(decision("run_command", "/usr/bin/git worktree add .worktrees/x HEAD"), "deny");
assert.equal(decision("run_command", "/usr/bin/git diff"), "deny");
assert.equal(decision("run_command", "/usr/bin/git diff --output=/tmp/policy.out"), "deny");
assert.equal(decision("run_command", "/usr/bin/git diff --output /tmp/policy.out"), "deny");
assert.equal(decision("run_command", "/usr/bin/git --output=/tmp/policy.out status"), "deny");
assert.equal(decision("run_command", "/usr/bin/git diff --ext-diff"), "deny");
assert.equal(decision("run_command", "/usr/bin/git diff --textconv"), "deny");
assert.equal(decision("run_command", "/usr/bin/git show HEAD:.env"), "deny");
assert.equal(decision("run_command", "/usr/bin/git cat-file -p HEAD"), "deny");

assert.equal(decision("run_command", "/usr/bin/rg --line-number --fixed-strings TODO README.md"), "allow");
assert.equal(decision("run_command", "rg --line-number --fixed-strings TODO README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/rg --pre cat README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/rg --pre=cat TODO README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/rg --pre-glob=*.md TODO README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/rg --hidden TODO ."), "deny");

assert.equal(decision("run_command", "/usr/bin/sed -n 1,10p README.md"), "allow");
assert.equal(decision("run_command", "/usr/bin/sed -n -e 1,10p README.md"), "allow");
assert.equal(decision("run_command", "/usr/bin/sed -i s/a/b/ README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/sed -n 1,10w README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/sed -n 1,10e id README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/sed -e w README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/sed -f policy.sed README.md"), "deny");

assert.equal(decision("run_command", "/usr/bin/find . -maxdepth 2 -type f -print"), "allow");
assert.equal(decision("run_command", "/usr/bin/find . -maxdepth 2 -type f -print0"), "allow");
assert.equal(decision("run_command", "/usr/bin/find . -fprint0 /tmp/policy.out"), "deny");
assert.equal(decision("run_command", "/usr/bin/find . -fprintf /tmp/policy.out %p"), "deny");
assert.equal(decision("run_command", "/usr/bin/find . -exec cat README.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/find . -delete"), "deny");

assert.equal(decision("run_command", "/usr/bin/jq . README.md"), "allow");
assert.equal(decision("run_command", "/usr/bin/jq -r .name .agents/plugins/layer-sort-agent-kit/plugin.json"), "allow");
assert.equal(decision("run_command", "/usr/bin/jq 'system(\"id\")' package.json"), "deny");
assert.equal(decision("run_command", "/usr/bin/jq -f filter.jq package.json"), "deny");

assert.equal(decision("run_command", "/usr/bin/bash tools/device-tests/test-wrapper.sh"), "allow");
assert.equal(decision("run_command", "bash tools/device-tests/test-wrapper.sh"), "deny");
assert.equal(decision("run_command", "/usr/bin/bash -c echo"), "deny");
assert.equal(decision("run_command", "godot --headless --path . --script res://tests/g2/classic_rules_test.gd"), "deny");
assert.equal(decision("run_command", "/usr/local/bin/godot --headless --path . --script res://tests/g2/classic_rules_test.gd"), "deny");
assert.equal(decision("run_command", "/usr/local/bin/godot --headless --quit --path . --script res://tests/g2/classic_rules_test.gd"), "deny");
assert.equal(
  evaluate(
    event("run_command", "/usr/local/bin/godot --headless --quit --path . --script res://tests/g2/classic_rules_test.gd"),
    undefined,
    { enableGodot: true }
  ).decision,
  "allow"
);
assert.equal(
  evaluate(
    event("run_command", "/usr/local/bin/godot --headless --path . --script res://tests/g2/classic_rules_test.gd"),
    undefined,
    { enableGodot: true }
  ).decision,
  "deny",
  "Godot headless execution must require --quit to prevent unbounded hangs"
);
assert.equal(
  evaluate(
    event("run_command", "godot --headless --quit --path . --script res://tests/g2/classic_rules_test.gd"),
    undefined,
    { enableGodot: true }
  ).decision,
  "deny",
  "Godot execution must require pinned /usr/local/bin/godot"
);
assert.equal(
  evaluate(
    event("run_command", "/usr/local/bin/godot --headless --quit --path . --script res://AGENTS.md"),
    undefined,
    { enableGodot: true }
  ).decision,
  "deny"
);

assert.equal(decision("run_command", "/usr/bin/cat AGENTS.md"), "allow");
assert.equal(decision("run_command", "/usr/bin/cat /etc/passwd"), "deny");
assert.equal(decision("run_command", "/usr/bin/cat .env"), "deny");
assert.equal(decision("run_command", "/usr/bin/cat .git/config"), "deny");
assert.equal(decision("run_command", "/usr/bin/ls"), "allow");
assert.equal(decision("run_command", "/usr/bin/ls --output=/tmp/out"), "deny");
assert.equal(decision("run_command", "/usr/bin/stat AGENTS.md"), "allow");
assert.equal(decision("run_command", "/usr/bin/tail -f AGENTS.md"), "deny");
assert.equal(decision("run_command", "curl https://example.com"), "deny");
assert.equal(decision("run_command", "/usr/bin/git status", "/root"), "deny");
assert.equal(decision("run_command", "/usr/bin/git status; touch marker"), "deny");
assert.equal(decision("run_command", "/usr/bin/git status\n/usr/bin/cat AGENTS.md"), "deny");
assert.equal(decision("run_command", "/usr/bin/git status --short", "/root"), "deny");
assert.equal(decision("run_command", "agy --version"), "deny");
assert.equal(decision("run_command", "/root/.local/bin/agy --version"), "deny");
assert.equal(
  evaluate(event("run_command", "/root/.local/bin/agy --version"), undefined, { enableAgy: true }).decision,
  "allow"
);
assert.equal(
  evaluate(event("run_command", "/root/.local/bin/agy agents"), undefined, { enableAgy: true }).decision,
  "allow"
);
assert.equal(
  evaluate(event("run_command", "/root/.local/bin/agy plugin list"), undefined, { enableAgy: true }).decision,
  "allow"
);
assert.equal(
  evaluate(
    event("run_command", "/root/.local/bin/agy plugin validate --strict .agents/plugins/layer-sort-agent-kit"),
    undefined,
    { enableAgy: true }
  ).decision,
  "allow"
);
assert.equal(
  evaluate(event("run_command", "agy --version"), undefined, { enableAgy: true }).decision,
  "deny",
  "agy inspection must require pinned /root/.local/bin/agy"
);
assert.equal(
  evaluate(event("run_command", "/root/.local/bin/agy plugin enable layer-sort-agent-kit"), undefined, { enableAgy: true }).decision,
  "deny"
);
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
  evaluate(fileEvent("read_file", { Path: path.join(root, "AGENTS.md"), StartLine: 1, EndLine: 5 })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("read_file", { Path: "/etc/passwd" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("read_file", { Path: path.join(root, ".env") })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("read_file", { Path: "AGENTS.md" })).decision,
  "deny"
);
assert.equal(decision("list_resources"), "deny");
assert.equal(decision("manage_task"), "deny", "process-control tools cannot bypass run_command");
assert.equal(
  evaluate(fileEvent("list_dir", { DirectoryPath: path.join(root, "docs") })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("find_by_name", { SearchDirectory: path.join(root, "scripts"), Pattern: "*.gd" })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("grep_search", { SearchPath: path.join(root, "scripts"), Query: "class_name" })).decision,
  "allow"
);
assert.equal(
  evaluate(fileEvent("list_dir", { DirectoryPath: "docs" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("list_dir", { DirectoryPath: "/etc" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("find_by_name", { SearchDirectory: path.join(root, ".git") })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("grep_search", { SearchPath: path.join(root, ".env") })).decision,
  "deny"
);
for (const unexposedAlias of ["list_directory", "find_file", "search_directory"]) {
  assert.equal(decision(unexposedAlias), "deny", unexposedAlias + " is not exposed to agents");
}
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
  evaluate(fileEvent("view_file", { AbsolutePath: "/root/device-tests/private.txt" })).decision,
  "deny"
);
assert.equal(
  evaluate(fileEvent("read_file", { Path: "/root/private.txt" })).decision,
  "deny"
);

const allowed = spawnSync(process.execPath, [policyScript], {
  input: JSON.stringify(event("run_command", "/usr/bin/git status --short")),
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

const hookScript = policyWrapperScript;
const hookWorkingDirectory = path.join(workspaceRoot, ".agents");
const relativeHookScript = path.relative(hookWorkingDirectory, hookScript);
const configuredHookCommand = String.raw`/usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/bash --noprofile --norc ${relativeHookScript} || printf '%s' '{"decision":"deny","reason":"Policy hook failed to start; request denied closed."}'`;
const hookConfigPath = path.join(workspaceRoot, ".agents", "hooks.json");
const hookConfig = JSON.parse(fs.readFileSync(hookConfigPath, "utf8"));
const guard = hookConfig["layer-sort-agent-guard"];
assert.equal(guard.enabled, true);
assert.equal(guard.PreToolUse.length, 1);
assert.equal(guard.PreToolUse[0].matcher, ".*");
assert.equal(guard.PreToolUse[0].hooks.length, 1);
assert.equal(
  guard.PreToolUse[0].hooks[0].command,
  configuredHookCommand,
  "Active workspace Hook must use the workspace-relative policy.sh path with a fail-closed startup fallback"
);
assert.equal(
  relativeHookScript,
  "plugins/layer-sort-agent-kit/scripts/policy.sh",
  "Hook path must be stable relative to the workspace hooks directory"
);
assert.equal(fs.readFileSync(policyScript, "utf8").includes("/root/projects/layer-sort"), false);
assert.equal(fs.readFileSync(hookScript, "utf8").includes("/root/projects/layer-sort"), false);
assert.equal(
  fs.readFileSync(path.join(pluginRoot, "scripts", "test-policy.sh"), "utf8").includes(
    "/root/projects/layer-sort"
  ),
  false
);

const engineeringAgentPath = path.join(pluginRoot, "agents", "engineering-auditor", "agent.md");
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
  ["read_file", "send_message"]
);

const implementerAgent = fs.readFileSync(
  path.join(pluginRoot, "agents", "implementer", "agent.md"),
  "utf8"
);
const implementerFrontmatter = implementerAgent.split("---")[1] ?? "";
assert.match(implementerFrontmatter, /^name: implementer$/m);
assert.match(implementerFrontmatter, /^subagent: true$/m);
assert.match(implementerFrontmatter, /^commandExecutionPolicy: auto$/m);
const implementerToolsBlock = implementerFrontmatter.match(/^tools:\s*\n((?:\s+- .+\n)+)/m);
assert.ok(implementerToolsBlock, "implementer must declare an explicit tool allowlist");
const implementerTools = [...implementerToolsBlock[1].matchAll(/^\s+- (.+)$/gm)].map((match) => match[1]);
assert.deepEqual(implementerTools, ["read_file", "write_file", "edit_file", "run_command", "send_message"]);

const leadAgent = fs.readFileSync(path.join(pluginRoot, "agents", "layer-sort-lead", "agent.md"), "utf8");
assert.match(leadAgent, /^\s+- engineering-auditor$/m);
assert.match(leadAgent, /^\s+- list_dir$/m);
assert.match(leadAgent, /^\s+- find_by_name$/m);
assert.match(leadAgent, /^\s+- grep_search$/m);
assert.doesNotMatch(leadAgent, /^\s+- manage_task$/m, "lead must not expose unscoped process-control tools");

const hookAllowed = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  input: JSON.stringify(event("run_command", "/usr/bin/git status --short")),
  encoding: "utf8"
});
assert.equal(hookAllowed.status, 0);
assert.equal(JSON.parse(hookAllowed.stdout).decision, "allow");

const hookRelativeAllowed = spawnSync("/usr/bin/bash", ["-c", configuredHookCommand], {
  cwd: hookWorkingDirectory,
  input: JSON.stringify({
    toolCall: {
      name: "run_command",
      args: {
        CommandLine: "/usr/bin/git status --short",
        Cwd: workspaceRoot
      }
    },
    workspacePaths: [workspaceRoot]
  }),
  encoding: "utf8"
});
assert.equal(hookRelativeAllowed.status, 0);
assert.equal(
  JSON.parse(hookRelativeAllowed.stdout).decision,
  "allow",
  "workspace-relative Hook invocation must resolve the active Worktree"
);

const bashEnvFixture = fs.mkdtempSync(path.join(os.tmpdir(), "layer-sort-bash-env-"));
try {
  const bashEnvPath = path.join(bashEnvFixture, "bash-env");
  const bashEnvMarker = path.join(bashEnvFixture, "executed");
  fs.writeFileSync(bashEnvPath, 'printf "executed" > "$BASH_ENV_MARKER"');

  const hookWithBashEnv = spawnSync("/bin/sh", ["-c", configuredHookCommand], {
    cwd: hookWorkingDirectory,
    env: {
      ...process.env,
      PATH: "/nonexistent",
      BASH_ENV: bashEnvPath,
      BASH_ENV_MARKER: bashEnvMarker
    },
    input: JSON.stringify({
      toolCall: {
        name: "run_command",
        args: {
          CommandLine: "/usr/bin/git status --short",
          Cwd: workspaceRoot
        }
      },
      workspacePaths: [workspaceRoot]
    }),
    encoding: "utf8"
  });

  assert.equal(hookWithBashEnv.status, 0);
  assert.equal(
    JSON.parse(hookWithBashEnv.stdout).decision,
    "allow",
    "the sanitized Hook launcher must still execute the policy"
  );
  assert.equal(
    fs.existsSync(bashEnvMarker),
    false,
    "inherited BASH_ENV must not execute before the policy wrapper"
  );
} finally {
  fs.rmSync(bashEnvFixture, { recursive: true, force: true });
}

const missingHookFallbackPayload = JSON.stringify({
  decision: "deny",
  reason: "Policy hook failed to start; request denied closed."
});
const missingHookCommand =
  `/usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/bash --noprofile --norc plugins/layer-sort-agent-kit/scripts/missing-policy.sh || printf '%s' '${missingHookFallbackPayload}'`;
const hookStartupFallback = spawnSync("/usr/bin/bash", ["-c", missingHookCommand], {
  cwd: hookWorkingDirectory,
  encoding: "utf8"
});
assert.equal(hookStartupFallback.status, 0);
assert.deepEqual(
  JSON.parse(hookStartupFallback.stdout),
  {
    decision: "deny",
    reason: "Policy hook failed to start; request denied closed."
  },
  "a missing policy script must still produce a fail-closed Hook decision"
);

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

const activePolicyWorktreeForHook = path.join(root, ".worktrees", "agent-system-access");
if (fs.existsSync(activePolicyWorktreeForHook)) {
  const hookWriteDenied = spawnSync("/usr/bin/bash", [hookScript], {
    cwd: root,
    input: JSON.stringify({
      toolCall: {
        name: "write_file",
        args: {
          Path: path.join(activePolicyWorktreeForHook, ".runtime", "policy-wrapper-deny-probe.txt"),
          Content: "must-not-be-written"
        }
      },
      workspacePaths: [activePolicyWorktreeForHook]
    }),
    encoding: "utf8"
  });
  assert.equal(hookWriteDenied.status, 0);
  assert.equal(JSON.parse(hookWriteDenied.stdout).decision, "deny");
  assert.equal(
    fs.existsSync(path.join(activePolicyWorktreeForHook, ".runtime", "policy-wrapper-deny-probe.txt")),
    false,
    "the PreToolUse wrapper denial must not create the requested file"
  );
}

const hookWithMinimalPath = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  env: { ...process.env, PATH: "/nonexistent", NODE_OPTIONS: "--require=/nonexistent/preload.cjs" },
  input: JSON.stringify(event("run_command", "/usr/bin/git status --short")),
  encoding: "utf8"
});
assert.equal(hookWithMinimalPath.status, 0);
assert.equal(JSON.parse(hookWithMinimalPath.stdout).decision, "allow");

const worktreesBase = path.join(root, ".worktrees");
fs.mkdirSync(worktreesBase, { recursive: true });
const worktreeRoot = path.join(worktreesBase, `policy-test-${process.pid}`);
const plainWorktreeRoot = path.join(worktreesBase, `not-a-worktree-${process.pid}`);
assert.equal(fs.existsSync(worktreeRoot), false, "policy test Worktree path must be fresh");
const addedWorktree = spawnSync(
  "git",
  ["worktree", "add", "--detach", worktreeRoot, "HEAD"],
  { cwd: root, encoding: "utf8" }
);
assert.equal(
  addedWorktree.status,
  0,
  "could not create temporary nested Git Worktree: " + (addedWorktree.stderr || addedWorktree.stdout)
);

try {
  const ignoredWorktreePath = path.relative(root, path.join(worktreeRoot, "README.md"));
  const ignoreCheck = spawnSync("git", ["check-ignore", "-q", ignoredWorktreePath], {
    cwd: root,
    encoding: "utf8"
  });
  assert.equal(ignoreCheck.status, 0, ".worktrees/ must be Git-ignored");

  const allowedPath = path.join(worktreeRoot, "README.md");
  const taskWriteAllowlists = Object.freeze({
    [path.basename(worktreeRoot)]: Object.freeze({
      taskId: "POLICY-TEST",
      files: Object.freeze([
        "README.md",
        "worktree-only-write.txt",
        "missing/file.txt",
        "policy-escape/outside.txt",
        "policy-safe-link/inside.txt",
        "policy-hardlink.txt",
        "policy-safe-target"
      ])
    })
  });
  const worktreeWriteEvent = (candidate, workspacePaths = [worktreeRoot]) => ({
    toolCall: {
      name: "write_file",
      args: { Path: candidate, Content: "policy-test-only" }
    },
    workspacePaths
  });

  assert.equal(
    evaluate(worktreeWriteEvent(allowedPath), taskWriteAllowlists).decision,
    "allow",
    "an exact allowlisted file must be writable from its dedicated Worktree"
  );
  assert.equal(
    evaluate(
      worktreeWriteEvent(path.join(worktreeRoot, "worktree-only-write.txt")),
      taskWriteAllowlists
    ).decision,
    "allow",
    "a second explicitly listed file must be writable"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(allowedPath)).decision,
    "deny",
    "an unregistered Worktree must not inherit a write allowlist"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(worktreeRoot, "not-allowlisted.txt")), taskWriteAllowlists).decision,
    "deny",
    "a file outside the task's exact allowlist must be denied"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(worktreeRoot, "README.md.bak")), taskWriteAllowlists).decision,
    "deny",
    "a filename prefix or suffix must not inherit an exact file grant"
  );
  assert.equal(
    evaluate(
      worktreeWriteEvent(allowedPath.replace("/README.md", "\\README.md")),
      taskWriteAllowlists
    ).decision,
    "deny",
    "backslash path aliases must be rejected on this POSIX runtime"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(allowedPath, [root]), taskWriteAllowlists).decision,
    "deny",
    "the main checkout workspace must not write into a nested Worktree"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(allowedPath, [root, worktreeRoot]), taskWriteAllowlists).decision,
    "deny",
    "multiple active workspaces must not widen the write boundary"
  );
  assert.equal(
    evaluate(
      worktreeWriteEvent(allowedPath),
      {
        [path.basename(worktreeRoot)]: {
          taskId: "POLICY-TEST",
          files: []
        }
      }
    ).decision,
    "deny",
    "an empty task allowlist must deny every write"
  );
  assert.equal(
    evaluate(
      worktreeWriteEvent(path.join(worktreeRoot, "missing", "file.txt")),
      taskWriteAllowlists
    ).decision,
    "deny",
    "a task may not create missing parent directories"
  );

  for (const invalidFiles of [
    ["../README.md"],
    ["AGENTS.md"],
    [".agents/agents/layer-sort-lead.md"],
    [".agents/agents/implementer/agent.md"],
    ["tools/device-tests/agentctl"],
    ["tools/device-tests/device_qa.py"],
    ["docs/current/00-START-HERE.md"],
    ["docs/current/04-AGENT-OPERATIONS.md"],
    ["docs/current/05-QA-TEST-CATALOG.md"],
    ["docs/adr/ADR-0007.md"],
    [".git/config"],
    ["/tmp/outside.txt"],
    ["src//game.gd"],
    ["src/./game.gd"],
    ["src/*.gd"],
    ["bad\nname.md"],
    ["README.md", "README.md"]
  ]) {
    assert.equal(
      evaluate(
        worktreeWriteEvent(allowedPath),
        {
          [path.basename(worktreeRoot)]: {
            taskId: "POLICY-TEST",
            files: invalidFiles
          }
        }
      ).decision,
      "deny",
      "invalid or duplicate allowlist entries must invalidate the entire task policy: " + JSON.stringify(invalidFiles)
    );
  }

  const activePolicyWorktree = path.join(root, ".worktrees", "agent-system-access");
  if (fs.existsSync(activePolicyWorktree)) {
    assert.equal(
      evaluate({
        toolCall: {
          name: "write_file",
          args: { Path: path.join(activePolicyWorktree, "README.md"), Content: "must-not-write" }
        },
        workspacePaths: [activePolicyWorktree]
      }).decision,
      "deny",
      "the infrastructure Worktree remains write-disabled until a task is explicitly assigned"
    );
    assert.equal(
      evaluate(
        worktreeWriteEvent(path.join(activePolicyWorktree, "README.md")),
        taskWriteAllowlists
      ).decision,
      "deny",
      "an active task cannot write into a different registered Worktree"
    );
  }
  assert.equal(
    evaluate({
      toolCall: {
        name: "view_file",
        args: { AbsolutePath: path.join(root, "README.md") }
      },
      workspacePaths: [worktreeRoot]
    }).decision,
    "deny",
    "a Worktree-only session must not read the main checkout"
  );
  assert.equal(
    evaluate({
      toolCall: { name: "write_to_file", args: { Path: allowedPath, Content: "policy-test-only" } },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "write_to_file must remain blocked"
  );

  // Partial-edit tools: allowed on existing allowlisted files with valid replacement payloads.
  assert.equal(
    evaluate({
      toolCall: {
        name: "edit_file",
        args: { Path: allowedPath, Target: "Layer Sort", Replacement: "Layer Sort Updated" }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "allow",
    "edit_file single replacement must be allowed on an existing allowlisted file"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "edit_file",
        args: {
          Path: allowedPath,
          Edits: [
            { Target: "Layer", Replacement: "Tube" },
            { Target: "Sort", Replacement: "Puzzle" }
          ]
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "allow",
    "edit_file multi-hunk Edits must be allowed on an existing allowlisted file"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "edit_file",
        args: {
          Path: allowedPath,
          Target: "Layer",
          Replacement: "Tube",
          Edits: [{ Target: "Sort", Replacement: "Puzzle" }]
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "edit_file must reject requests specifying both Target/Replacement and Edits"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "edit_file",
        args: {
          Path: path.join(worktreeRoot, "worktree-only-write.txt"),
          Target: "missing",
          Replacement: "new"
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "partial-edit tools must reject non-existent allowlisted files"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "replace_file_content",
        args: {
          TargetFile: allowedPath,
          TargetContent: "Layer Sort",
          ReplacementContent: "Layer Sort Updated"
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "allow",
    "replace_file_content must be allowed on an existing allowlisted file"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "replace_file_content",
        args: {
          TargetFile: path.join(worktreeRoot, "worktree-only-write.txt"),
          TargetContent: "missing",
          ReplacementContent: "new"
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "replace_file_content must reject non-existent allowlisted files"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "multi_replace_file_content",
        args: {
          TargetFile: allowedPath,
          ReplacementChunks: [
            { TargetContent: "Layer", ReplacementContent: "Tube" }
          ]
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "allow",
    "multi_replace_file_content must be allowed on an existing allowlisted file"
  );
  assert.equal(
    evaluate({
      toolCall: {
        name: "multi_replace_file_content",
        args: {
          TargetFile: allowedPath,
          ReplacementChunks: []
        }
      },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "multi_replace_file_content must reject empty ReplacementChunks"
  );

  assert.equal(
    evaluate(worktreeWriteEvent(path.join(root, "README.md")), taskWriteAllowlists).decision,
    "deny",
    "the main project checkout must remain read-only"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(worktreeRoot), taskWriteAllowlists).decision,
    "deny",
    "Worktree root itself is not a file target"
  );
  assert.equal(
    evaluate(worktreeWriteEvent("README.md"), taskWriteAllowlists).decision,
    "deny",
    "relative write paths must be rejected"
  );
  assert.equal(
    evaluate({
      toolCall: { name: "write_file", args: { Content: "missing path" } },
      workspacePaths: [worktreeRoot]
    }, taskWriteAllowlists).decision,
    "deny",
    "write requests without an absolute Path must be rejected"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(os.tmpdir(), "policy-outside.txt")), taskWriteAllowlists).decision,
    "deny",
    "external write paths must be rejected"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(worktreeRoot + "/../outside.txt"), taskWriteAllowlists).decision,
    "deny",
    "explicit parent traversal must be rejected"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(worktreeRoot, ".git", "config")), taskWriteAllowlists).decision,
    "deny",
    ".git paths must remain blocked inside a Worktree"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(worktreeRoot, ".agents", "agents", "probe.md")), taskWriteAllowlists).decision,
    "deny",
    ".agents paths must remain blocked inside a Worktree"
  );
  assert.equal(
    evaluate(fileEvent("delete_file", { Path: allowedPath })).decision,
    "deny",
    "destructive file tools must remain blocked even inside a Worktree"
  );
  assert.equal(
    evaluate(fileEvent("apply_patch", { Patch: "not path-scoped" })).decision,
    "deny",
    "unscoped patch tools must remain blocked"
  );

  fs.mkdirSync(plainWorktreeRoot);
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(plainWorktreeRoot, "README.md")), taskWriteAllowlists).decision,
    "deny",
    "a plain directory under .worktrees is not a registered Git Worktree"
  );

  const escapeLink = path.join(worktreeRoot, "policy-escape");
  fs.symlinkSync(os.tmpdir(), escapeLink, "dir");
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(escapeLink, "outside.txt")), taskWriteAllowlists).decision,
    "deny",
    "symlink escapes from a Worktree must be rejected even when the relative path is listed"
  );

  const safeTarget = path.join(worktreeRoot, "policy-safe-target");
  const safeLink = path.join(worktreeRoot, "policy-safe-link");
  fs.mkdirSync(safeTarget);
  fs.symlinkSync(safeTarget, safeLink, "dir");
  assert.equal(
    evaluate(worktreeWriteEvent(path.join(safeLink, "inside.txt")), taskWriteAllowlists).decision,
    "deny",
    "all symlink traversal must be rejected, even when the target remains in the same Worktree"
  );
  assert.equal(
    evaluate(worktreeWriteEvent(safeTarget), taskWriteAllowlists).decision,
    "deny",
    "an explicitly listed directory path must not be accepted as a file target"
  );

  const hardLinkPath = path.join(worktreeRoot, "policy-hardlink.txt");
  fs.linkSync(allowedPath, hardLinkPath);
  assert.equal(
    evaluate(worktreeWriteEvent(hardLinkPath), taskWriteAllowlists).decision,
    "deny",
    "hard-linked files must be rejected to prevent writes through an alias"
  );
} finally {
  fs.rmSync(plainWorktreeRoot, { recursive: true, force: true });
  const removedWorktree = spawnSync(
    "git",
    ["worktree", "remove", "--force", worktreeRoot],
    { cwd: root, encoding: "utf8" }
  );
  if (removedWorktree.status !== 0) {
    fs.rmSync(worktreeRoot, { recursive: true, force: true });
    spawnSync("git", ["worktree", "prune"], { cwd: root, encoding: "utf8" });
  }
  assert.equal(
    removedWorktree.status,
    0,
    "could not clean up temporary nested Git Worktree: " +
      (removedWorktree.stderr || removedWorktree.stdout)
  );
}

process.stdout.write("POLICY_TESTS_PASS\n");

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { evaluate } from "./policy.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(scriptDirectory, "..");
const root = process.env.LS_PROJECT_ROOT ?? "/root/projects/layer-sort";
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
assert.equal(decision("run_command", "tools/device-tests/agentctl performance-check"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl performance-check --force"), "deny");
assert.equal(decision("run_command", "tools/device-tests/agentctl screenshot"), "allow");
assert.equal(decision("run_command", "tools/device-tests/agentctl tap 10 20 --owner-approved"), "deny");
assert.equal(decision("run_command", "tools/device-tests/device_qa.py status"), "deny");
assert.equal(decision("run_command", "adb devices -l"), "deny");
assert.equal(decision("run_command", "/usr/bin/adb devices -l"), "deny");
assert.equal(decision("run_command", "python3 -c print(1)"), "deny");

// Executable identity must not be inferred from basename alone.
assert.equal(decision("run_command", "./git status --short"), "deny");
assert.equal(decision("run_command", "tools/subdir/git status --short"), "deny");
assert.equal(decision("run_command", path.join(root, "tools", "subdir", "git") + " status --short"), "deny");
assert.equal(decision("run_command", "GIT status --short"), "deny");
assert.equal(decision("run_command", "agentctl status"), "deny");
assert.equal(
  decision("run_command", path.join(root, "tools", "device-tests", "agentctl") + " status"),
  "allow"
);

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
assert.equal(guard.PreToolUse[0].hooks[0].command, "/usr/bin/bash ./scripts/policy.sh");

const pluginHookAllowed = spawnSync("/usr/bin/bash", ["./scripts/policy.sh"], {
  cwd: pluginRoot,
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(pluginHookAllowed.status, 0);
assert.equal(JSON.parse(pluginHookAllowed.stdout).decision, "allow");

if (fs.existsSync(path.join(root, ".worktrees", "agent-system-access"))) {
const activeWorktreeRoot = path.join(root, ".worktrees", "agent-system-access");
const workspaceHookConfigPath = path.join(activeWorktreeRoot, ".agents", "hooks.json");
const workspaceHookConfig = JSON.parse(fs.readFileSync(workspaceHookConfigPath, "utf8"));
const workspaceGuard = workspaceHookConfig["layer-sort-agent-guard"];
assert.equal(workspaceGuard.enabled, true);
const workspaceHookScript = path.join(
  activeWorktreeRoot,
  ".agents",
  "plugins",
  "layer-sort-agent-kit",
  "scripts",
  "policy.sh"
);
assert.equal(workspaceGuard.PreToolUse[0].hooks[0].command,
  "/usr/bin/bash " + workspaceHookScript);

const workspaceHookAllowed = spawnSync(
  "/usr/bin/bash",
  [workspaceHookScript],
  {
    cwd: os.tmpdir(),
    input: JSON.stringify({
      toolCall: {
        name: "run_command",
        args: {
          CommandLine: "git status --short",
          Cwd: activeWorktreeRoot
        }
      },
      workspacePaths: [activeWorktreeRoot]
    }),
    encoding: "utf8"
  }
);
assert.equal(workspaceHookAllowed.status, 0);
assert.equal(JSON.parse(workspaceHookAllowed.stdout).decision, "allow");
} else {
  process.stdout.write("SKIP local-fixture: .worktrees/agent-system-access not present (hermetic run)\n");
}

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

const hookWithoutNode = spawnSync("/usr/bin/bash", [hookScript], {
  cwd: os.tmpdir(),
  env: { ...process.env, PATH: "/nonexistent" },
  input: JSON.stringify(event("run_command", "git status --short")),
  encoding: "utf8"
});
assert.equal(hookWithoutNode.status, 0);
assert.equal(JSON.parse(hookWithoutNode.stdout).decision, "deny");

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

  const edit = worktreeWriteEvent(allowedPath);
  edit.toolCall.name = "edit_file";
  assert.equal(evaluate(edit, taskWriteAllowlists).decision, "allow");
  edit.toolCall.args.Path = path.join(worktreeRoot, "not-allowlisted.txt");
  assert.equal(evaluate(edit, taskWriteAllowlists).decision, "deny");
  delete edit.toolCall.args.Path;
  assert.equal(evaluate(edit, taskWriteAllowlists).decision, "deny");

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
    [".agents/agents/lead.md"],
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
  for (const toolName of ["write_to_file", "replace_file_content", "multi_replace_file_content"]) {
    assert.equal(
      evaluate({
        toolCall: { name: toolName, args: { Path: allowedPath, Content: "policy-test-only" } },
        workspacePaths: [worktreeRoot]
      }).decision,
      "deny",
      toolName + " must remain blocked until its exact path schema is verified"
    );
  }

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

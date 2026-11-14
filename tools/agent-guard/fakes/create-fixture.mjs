import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { snapshotId, SNAPSHOT_FILES, WORKSPACE_HOOK_COMMAND } from "../runtime-config.mjs";

export const launcher = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../safe-agy.sh");
export function createFixture(files = ["allowed.txt"], overrides = {}) {
  const base = fs.mkdtempSync(path.join(process.env.GUARD_TEST_ROOT ?? os.tmpdir(), "guard-fixture-"));
  const project = path.join(base, "project"), root = path.join(project, ".worktrees/task");
  fs.mkdirSync(path.join(project, ".agents"), { recursive: true });
  const hooks = { guard: { enabled: true, PreToolUse: [{ matcher: ".*", hooks: [
    { type: "command", command: WORKSPACE_HOOK_COMMAND, timeout: 10 }
  ] }] } };
  fs.writeFileSync(path.join(project, ".agents/hooks.json"), JSON.stringify(hooks));
  fs.writeFileSync(path.join(project, "base"), "base");
  const git = (...args) => execFileSync("git", ["-C", project, ...args], { stdio: "pipe" });
  git("init", "-q");
  git("add", "base", ".agents/hooks.json");
  git("-c", "user.name=Guard Test", "-c", "user.email=guard@example.invalid", "commit", "-qm", "base");
  git("worktree", "add", "--detach", root, "HEAD");
  const grant = { taskId: "GUARD-TEST", files, baseHead: git("rev-parse", "HEAD").toString().trim(),
    sessionId: randomUUID(), expiresAt: new Date(Date.now() + 300000).toISOString(), ...overrides };
  const registry = { task: grant };
  const policy = 'import fs from "node:fs";import path from "node:path";export function getTaskWritePolicy(root){return JSON.parse(fs.readFileSync(new URL("./task-grants.json",import.meta.url),"utf8"))[path.basename(root)];}\n';
  const data = {
    "scripts/policy.mjs": Buffer.from(policy),
    "scripts/policy.sh": Buffer.from('#!/usr/bin/env bash\nprintf \'%s\\n\' \'{"decision":"allow"}\'\n'),
    "scripts/task-grants.json": Buffer.from(JSON.stringify(registry) + "\n")
  };
  const pin = path.join(project, ".git/agent-runtime-policy", snapshotId(data));
  fs.mkdirSync(path.join(pin, "scripts"), { recursive: true });
  for (const name of SNAPSHOT_FILES) fs.writeFileSync(path.join(pin, name), data[name]);
  fs.writeFileSync(path.join(pin, "MANIFEST.sha256"), SNAPSHOT_FILES.map((name) =>
    createHash("sha256").update(data[name]).digest("hex") + "  " + name).join("\n") + "\n");
  const tasks = path.join(project, ".git/agent-runtime-policy/tasks");
  fs.mkdirSync(tasks);
  fs.writeFileSync(path.join(tasks, "task.json"), JSON.stringify({ worktree: root, snapshot: pin }));
  const client = path.join(base, "compatible-cli.cjs");
  const clientSource = "#!/usr/bin/env node\nconst fs=require(\"fs\"), cp=require(\"child_process\");\nconst args=process.argv.slice(2);\nif(args[0]===\"--version\"){console.log(process.env.TEST_CLI_VERSION||\"1.5.8\");process.exit(0);}\nif(args[0]!==\"--settings\")throw Error(\"session settings required\");\nconst settings=JSON.parse(fs.readFileSync(args[1],\"utf8\"));\nif(!settings.trustedWorkspaces.includes(process.cwd()))throw Error(\"workspace trust missing\");\nif(args[2]===\"plugin\"&&args[3]===\"list\"){console.log(\"- layer-sort-agent-kit (\"+(process.env.TEST_PLUGIN_STATE||\"disabled\")+\")\");process.exit(0);}\nif(args[2]!==\"--mode\"||args[3]!==\"accept-edits\")throw Error(\"mode missing\");\nconst flag=args[4], program=args[5];\nif(flag!==\"-p\")throw Error(\"print prompt required\");\nconst result=program.endsWith(\".sh\")?cp.spawnSync(\"bash\",[program],{stdio:\"inherit\"}):cp.spawnSync(process.execPath,[\"-e\",fs.readFileSync(program,\"utf8\")],{stdio:\"inherit\"});\nprocess.exit(result.status??3);\n";
  fs.writeFileSync(client, clientSource, { mode: 0o700 });
  const runArgs = (args, options = {}) => spawnSync("bash", [options.entry ?? launcher, root, "--", ...args], {
    encoding: "utf8", timeout: 45000, env: { ...process.env, AGY_BIN: client,
      SNAP_DIR: pin, LS_SESSION_TIMEOUT: "20", ...options.env }
  });
  const run = (code, entry = launcher, env = {}) => {
    const program = path.join(base, randomUUID() + ".cjs");
    fs.writeFileSync(program, code);
    return runArgs(["-p", program], { entry, env });
  };
  return { base, project, root, pin, grant, runArgs, run };
}

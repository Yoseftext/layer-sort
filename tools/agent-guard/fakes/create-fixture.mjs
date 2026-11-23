import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { snapshotId, SNAPSHOT_FILES, WORKSPACE_HOOK_COMMAND } from "../runtime-config.mjs";

const MODULE_DIR = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR_FILE = path.join(MODULE_DIR, "..", "test-source-dir");
const SOURCE_DIR = fs.existsSync(SOURCE_DIR_FILE)
  ? fs.readFileSync(SOURCE_DIR_FILE, "utf8").trim()
  : process.env.SAFE_AGY_INFRA_DIR
    ? path.join(path.resolve(process.env.SAFE_AGY_INFRA_DIR), "tools/agent-guard")
    : path.resolve(MODULE_DIR, "..");
export const launcher = path.join(SOURCE_DIR, "safe-agy.sh");

const TEST_COMPATIBILITY_HELPER = `import { spawnSync } from "node:child_process";

const [action, worktree, ...args] = process.argv.slice(2);
if (action === "--ensure") {
  const version = process.env.TEST_CLI_VERSION || "1.5.8";
  const plugin = process.env.TEST_PLUGIN_STATE || "disabled";
  if (version !== "1.5.8" || plugin !== "disabled") {
    console.error("TEST_COMPATIBILITY_REJECTED: version or plugin state mismatch");
    process.exitCode = 78;
  }
} else if (action === "--capture" || action === "--exec") {
  const executable = process.env.AGY_BIN;
  if (!executable || !worktree) {
    console.error("TEST_COMPATIBILITY_REJECTED: fixture executable or worktree missing");
    process.exitCode = 78;
  } else {
    const result = spawnSync(executable, args, { cwd: process.cwd(), stdio: "inherit", env: process.env });
    if (result.error) {
      console.error(result.error.message);
      process.exitCode = 3;
    } else {
      process.exitCode = result.status ?? 3;
    }
  }
} else {
  console.error("TEST_COMPATIBILITY_REJECTED: unsupported fixture action");
  process.exitCode = 64;
}
`;

const TEST_FILES = [
  "test-compatibility.sh",
  "test-compatibility.mjs",
  "test-state.mjs",
  "test-launcher.mjs",
  "test-runtime-config.mjs",
  "test-active-compatibility.mjs"
];

function createLauncherFixture(base) {
  const guardDir = path.join(base, "guard");
  fs.mkdirSync(guardDir, { mode: 0o700 });
  for (const name of ["safe-agy.sh", "guard-lib.sh", "guard-state.mjs", "runtime-config.mjs", ...TEST_FILES]) {
    fs.copyFileSync(path.join(SOURCE_DIR, name), path.join(guardDir, name));
  }
  const fixtureDir = path.join(guardDir, "fakes");
  fs.mkdirSync(fixtureDir, { mode: 0o700 });
  fs.copyFileSync(path.join(SOURCE_DIR, "fakes/create-fixture.mjs"), path.join(fixtureDir, "create-fixture.mjs"));
  fs.writeFileSync(path.join(guardDir, "compatibility.mjs"), TEST_COMPATIBILITY_HELPER, { mode: 0o600 });
  return { guardDir, launcher: path.join(guardDir, "safe-agy.sh") };
}

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
  const policyRoot = path.join(project, ".git/agent-runtime-policy");
  const pin = path.join(policyRoot, snapshotId(data));
  fs.mkdirSync(policyRoot, { recursive: true, mode: 0o700 });
  fs.mkdirSync(pin, { mode: 0o700 });
  fs.mkdirSync(path.join(pin, "scripts"), { mode: 0o700 });
  for (const name of SNAPSHOT_FILES) fs.writeFileSync(path.join(pin, name), data[name], { mode: 0o600 });
  fs.writeFileSync(path.join(pin, "MANIFEST.sha256"), SNAPSHOT_FILES.map((name) =>
    createHash("sha256").update(data[name]).digest("hex") + "  " + name).join("\n") + "\n", { mode: 0o600 });
  const tasks = path.join(policyRoot, "tasks");
  fs.mkdirSync(tasks, { mode: 0o700 });
  fs.writeFileSync(path.join(tasks, "task.json"), JSON.stringify({ worktree: root, snapshot: pin }), { mode: 0o600 });

  const client = path.join(base, "compatible-cli.cjs");
  const clientSource = "#!/usr/bin/env node\nconst fs=require(\"fs\"),cp=require(\"child_process\");\nconst args=process.argv.slice(2);\nif(args[0]===\"--version\"){console.log(process.env.TEST_CLI_VERSION||\"1.5.8\");process.exit(0);}\nif(args[0]!==\"--settings\")throw Error(\"session settings required\");\nconst settings=JSON.parse(fs.readFileSync(args[1],\"utf8\"));\nif(!settings.trustedWorkspaces.includes(process.cwd()))throw Error(\"workspace trust missing\");\nif(args[2]===\"plugin\"&&args[3]===\"list\"){console.log(\"- layer-sort-agent-kit (\"+(process.env.TEST_PLUGIN_STATE||\"disabled\")+\")\");process.exit(0);}\nif(args[2]!==\"--mode\"||args[3]!==\"accept-edits\")throw Error(\"mode missing\");\nconst flag=args[4], program=args[5];\nif(flag!==\"-p\")throw Error(\"print prompt required\");\nif(program.endsWith(\".sh\")){const result=cp.spawnSync(\"bash\",[program],{stdio:\"inherit\"});process.exit(result.status??3);}\nrequire(program);\n";
  fs.writeFileSync(client, clientSource, { mode: 0o700 });
  const fixture = createLauncherFixture(base);
  const runArgs = (args, options = {}) => spawnSync("bash", [options.entry ?? fixture.launcher, root, "--", ...args], {
    encoding: "utf8", timeout: 45000, env: { ...process.env, AGY_BIN: client,
      LS_SESSION_TIMEOUT: "20", ...options.env }
  });
  const run = (code, entry = fixture.launcher, env = {}) => {
    const program = path.join(base, randomUUID() + ".cjs");
    fs.writeFileSync(program, code);
    return runArgs(["-p", program], { entry, env });
  };
  return { base, project, root, pin, grant, guardDir: fixture.guardDir, launcher: fixture.launcher, runArgs, run };
}

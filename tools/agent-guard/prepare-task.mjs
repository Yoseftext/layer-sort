import fs from "node:fs";
import path from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { projectRoot, snapshotId, SNAPSHOT_FILES, validateHook, verifySnapshot, activeSnapshot } from "./runtime-config.mjs";

let lock;
try {
  const [target, taskId, ...files] = process.argv.slice(2);
  if (!target || !taskId || files.length > 64) throw Error("Usage: node prepare-task.mjs <worktree> <TASK-ID> [exact relative files...]");
  const worktree = path.resolve(target), project = projectRoot(worktree);
  process.env.LS_PROJECT_ROOT = project;
  validateHook(JSON.parse(fs.readFileSync(path.join(worktree, ".agents/hooks.json"), "utf8")));
  const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../.agents/plugins/layer-sort-agent-kit/scripts");
  const policy = await import(pathToFileURL(path.join(source, "policy.mjs")).href);
  const baseHead = execFileSync("git", ["-C", worktree, "rev-parse", "HEAD"], { encoding: "utf8", timeout: 10000 }).trim();
  const grant = { taskId, files, baseHead, sessionId: randomUUID(), expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString() };
  const registry = Object.fromEntries([[path.basename(worktree), grant]]);
  if (!policy.getTaskWritePolicy(worktree, registry)) throw Error("Invalid task ID, worktree or path grant");
  for (const name of files) {
    const result = policy.evaluate({ toolCall: { name: "write_file", args: { Path: path.join(worktree, name) } }, workspacePaths: [worktree] }, registry);
    if (result.decision !== "allow") throw Error(name + ": " + result.reason);
  }

  const data = {
    "scripts/policy.mjs": fs.readFileSync(path.join(source, "policy.mjs")),
    "scripts/policy.sh": fs.readFileSync(path.join(source, "policy.sh")),
    "scripts/task-grants.json": Buffer.from(JSON.stringify(registry, null, 2) + "\n")
  };
  const root = path.join(project, ".git/agent-runtime-policy");
  fs.mkdirSync(root, { recursive: true, mode: 0o700 });
  if (fs.realpathSync(root) !== root) throw Error("Private runtime directory must not be a symlink");
  const tasks = path.join(root, "tasks");
  fs.mkdirSync(tasks, { recursive: true, mode: 0o700 });
  if (fs.realpathSync(tasks) !== tasks) throw Error("Task pointer directory must not be a symlink");
  const candidateLock = path.join(tasks, path.basename(worktree) + ".lock");
  fs.mkdirSync(candidateLock, { mode: 0o700 });
  lock = candidateLock;
  const pointer = path.join(tasks, path.basename(worktree) + ".json");
  if (fs.existsSync(pointer)) {
    const previous = activeSnapshot(worktree);
    if (!fs.existsSync(path.join(previous, "REVOKED"))) throw Error("Previous task is still open; close it with runtime-config.mjs close <worktree>");
  }
  const pin = path.join(root, snapshotId(data));
  fs.mkdirSync(pin, { mode: 0o700 });
  fs.mkdirSync(path.join(pin, "scripts"), { mode: 0o700 });
  for (const name of SNAPSHOT_FILES) fs.writeFileSync(path.join(pin, name), data[name], { flag: "wx", mode: 0o600 });
  const manifest = SNAPSHOT_FILES.map((name) => createHash("sha256").update(data[name]).digest("hex") + "  " + name).join("\n") + "\n";
  fs.writeFileSync(path.join(pin, "MANIFEST.sha256"), manifest, { flag: "wx", mode: 0o600 });
  verifySnapshot(pin);

  const temporary = pointer + "." + randomUUID() + ".tmp";
  fs.writeFileSync(temporary, JSON.stringify({ worktree, snapshot: pin }) + "\n", { flag: "wx", mode: 0o600 });
  fs.renameSync(temporary, pointer);
  console.log(JSON.stringify({ worktree, snapshot: pin, taskId, files, baseHead, expiresAt: grant.expiresAt }, null, 2));
} catch (error) {
  console.error("PREPARE_FAIL: " + error.message);
  process.exitCode = 3;
} finally {
  if (lock) fs.rmdirSync(lock);
}

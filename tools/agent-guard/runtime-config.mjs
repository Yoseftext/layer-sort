import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const failure = JSON.stringify(JSON.stringify({ decision: "deny", reason: "Start through safe-agy; pinned policy unavailable." }));
const dispatch = 'if [ -n "${LS_POLICY_SNAPSHOT:-}" ] && [ -f "$LS_POLICY_SNAPSHOT/scripts/policy.sh" ]; then /usr/bin/bash "$LS_POLICY_SNAPSHOT/scripts/policy.sh" || printf "%s\\n" ' + failure + '; else printf "%s\\n" ' + failure + '; fi';
export const WORKSPACE_HOOK_COMMAND = "/usr/bin/bash -c '" + dispatch + "'";
export const SNAPSHOT_FILES = ["scripts/policy.mjs", "scripts/policy.sh", "scripts/task-grants.json"];
const sha = (data) => createHash("sha256").update(data).digest("hex");
const git = (root, args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8", timeout: 10000 }).trim();
const CURRENT_UID = typeof process.getuid === "function" ? process.getuid() : -1;
const NOFOLLOW = fs.constants.O_NOFOLLOW || 0;

function assertPrivateDirectory(directory, expectedMode, label) {
  if (typeof directory !== "string" || !path.isAbsolute(directory) || path.resolve(directory) !== directory) {
    throw Error(label + " path must be absolute and canonical");
  }
  const stat = fs.lstatSync(directory);
  const allowedModes = Array.isArray(expectedMode) ? expectedMode : [expectedMode];
  if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== CURRENT_UID ||
      !allowedModes.includes(stat.mode & 0o777) || fs.realpathSync(directory) !== directory) {
    throw Error("Unsafe " + label + "; expected owner " + CURRENT_UID + " and mode " + allowedModes.map((mode) => mode.toString(8)).join(" or "));
  }
  return stat;
}

function readPrivateFile(filePath, maxBytes, label) {
  const fd = fs.openSync(filePath, fs.constants.O_RDONLY | NOFOLLOW);
  try {
    const before = fs.fstatSync(fd, { bigint: true });
    if (!before.isFile() || before.nlink !== 1n || before.uid !== BigInt(CURRENT_UID) ||
        (before.mode & 0o777n) !== 0o600n || before.size > BigInt(maxBytes)) {
      throw Error("Unsafe " + label + "; expected a private regular file owned by the current user");
    }
    const data = fs.readFileSync(fd);
    const after = fs.fstatSync(fd, { bigint: true });
    if (before.dev !== after.dev || before.ino !== after.ino || before.size !== after.size ||
        before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs || BigInt(data.length) !== before.size) {
      throw Error(label + " changed while being read");
    }
    return data;
  } finally {
    fs.closeSync(fd);
  }
}

function assertSnapshotPath(pin, expectedBase) {
  if (typeof pin !== "string" || !path.isAbsolute(pin) || path.resolve(pin) !== pin ||
      !/^[a-f0-9]{64}$/.test(path.basename(pin))) {
    throw Error("Snapshot path must be a canonical SHA-256 directory");
  }
  const base = path.dirname(pin);
  if (path.basename(base) !== "agent-runtime-policy" || path.basename(path.dirname(base)) !== ".git" ||
      (expectedBase && base !== expectedBase)) {
    throw Error("Snapshot must be a direct child of this project's private agent-runtime-policy directory");
  }
  assertPrivateDirectory(base, [0o700, 0o755], "agent-runtime-policy directory");
  assertPrivateDirectory(pin, 0o700, "policy snapshot directory");
  return { base, pin };
}

function writePrivateFileExclusive(filePath, content, label) {
  const fd = fs.openSync(filePath, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | NOFOLLOW, 0o600);
  try {
    fs.writeFileSync(fd, content);
    fs.fsyncSync(fd);
    const stat = fs.fstatSync(fd);
    if (!stat.isFile() || stat.nlink !== 1 || stat.uid !== CURRENT_UID || (stat.mode & 0o777) !== 0o600) {
      throw Error("Unsafe " + label + " output");
    }
  } finally {
    fs.closeSync(fd);
  }
}

export function projectRoot(worktree) {
  const root = path.resolve(worktree);
  if (fs.realpathSync(root) !== root || git(root, ["rev-parse", "--show-toplevel"]) !== root) throw Error("Use an exact worktree root");
  const common = fs.realpathSync(path.resolve(root, git(root, ["rev-parse", "--git-common-dir"])));
  const project = path.dirname(common);
  if (path.basename(common) !== ".git" || path.dirname(root) !== path.join(project, ".worktrees")) throw Error("Task must use a registered nested worktree");
  return project;
}

export function snapshotId(files) {
  const h = createHash("sha256");
  for (const name of SNAPSHOT_FILES) h.update(name + "\0").update(files[name]).update("\0");
  return h.digest("hex");
}

export function verifySnapshot(pin) {
  assertSnapshotPath(pin);
  try {
    fs.lstatSync(path.join(pin, "REVOKED"));
    throw Error("Task grant is revoked; prepare a new task");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  assertPrivateDirectory(path.join(pin, "scripts"), 0o700, "policy snapshot scripts directory");
  const files = {};
  for (const name of SNAPSHOT_FILES) {
    files[name] = readPrivateFile(path.join(pin, name), 1024 * 1024, "snapshot file " + name);
  }
  const manifest = readPrivateFile(path.join(pin, "MANIFEST.sha256"), 4096, "snapshot manifest").toString("utf8");
  const expected = SNAPSHOT_FILES.map((name) => sha(files[name]) + "  " + name).join("\n") + "\n";
  if (manifest !== expected || path.basename(pin) !== snapshotId(files)) throw Error("Snapshot integrity mismatch");
  return files;
}

export function validateHook(hooks, expectedCommand = WORKSPACE_HOOK_COMMAND) {
  const active = Object.values(hooks).flatMap((group) => group?.enabled === true ? group.PreToolUse ?? [] : []);
  if (active.length !== 1) throw Error("Exactly one enabled PreToolUse entry required");
  const entry = active[0], hook = entry.hooks?.[0];
  if (entry.matcher !== ".*" || entry.hooks?.length !== 1 || hook.type !== "command" ||
      hook.command !== expectedCommand || !Number.isFinite(hook.timeout) || hook.timeout <= 0 || hook.timeout > 30) throw Error("Unexpected workspace Hook configuration");
}

export async function taskGrant(pin, worktree) {
  if (path.dirname(pin) !== path.join(projectRoot(worktree), ".git/agent-runtime-policy")) throw Error("Snapshot belongs to another project");
  if (activeSnapshot(worktree) !== pin) throw Error("Snapshot is not the active task grant");
  verifySnapshot(pin);
  const policy = await import(pathToFileURL(path.join(pin, "scripts/policy.mjs")).href);
  if (typeof policy.getTaskWritePolicy !== "function") throw Error("Unsupported policy snapshot");
  const grant = policy.getTaskWritePolicy(worktree);
  const seconds = Math.floor((Date.parse(grant?.expiresAt) - Date.now()) / 1000);
  if (!grant || !Array.isArray(grant.files) || !Number.isFinite(seconds) || seconds < 5) throw Error("Missing, invalid or expired task grant");
  if (grant.baseHead !== git(worktree, ["rev-parse", "HEAD"])) throw Error("Task base HEAD changed; prepare again");
  return grant;
}

export function activeSnapshot(worktree) {
  const root = projectRoot(worktree);
  const tasks = path.join(root, ".git/agent-runtime-policy/tasks");
  assertPrivateDirectory(tasks, 0o700, "task pointer directory");
  const file = path.join(tasks, path.basename(worktree) + ".json");
  const pointer = JSON.parse(readPrivateFile(file, 4096, "task pointer").toString("utf8"));
  const base = path.join(root, ".git/agent-runtime-policy");
  if (!pointer || typeof pointer !== "object" || pointer.worktree !== worktree) {
    throw Error("Task pointer does not match worktree");
  }
  assertSnapshotPath(pointer.snapshot, base);
  return pointer.snapshot;
}

export function validateLaunchArgs(args) {
  const values = new Set(["-p", "--print", "--prompt", "--prompt-interactive", "-i", "--agent", "--model", "--effort", "--output-format", "--print-timeout"]);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--disable-slash-commands") continue;
    if (!values.has(args[i]) || i + 1 >= args.length) throw Error("Runtime authority override or unsupported argument: " + args[i]);
    i++;
  }
}

export async function executableHash(file) {
  const digest = createHash("sha256");
  for await (const bytes of fs.createReadStream(file)) digest.update(bytes);
  return digest.digest("hex");
}

export async function freezeCli(command, temporary) {
  const candidate = path.isAbsolute(command) ? command : process.env.PATH.split(path.delimiter)
    .map(p => path.join(p, command)).find(p => { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch { return false; } });
  if (!candidate) throw Error("CLI executable not found");
  const source = fs.realpathSync(candidate), stat = fs.statSync(source);
  if (!stat.isFile() || stat.size > 512 * 1024 * 1024 || !(stat.mode & 0o111)) throw Error("Invalid CLI executable");
  const target = path.join(temporary, "agy");
  fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
  const metadata = { source, target, sha256: await executableHash(target) };
  fs.writeFileSync(path.join(temporary, "cli.json"), JSON.stringify(metadata), { flag: "wx", mode: 0o600 });
  return target;
}

export async function verifyFrozenCli(temporary) {
  const metadata = JSON.parse(fs.readFileSync(path.join(temporary, "cli.json"), "utf8"));
  if (metadata.target !== path.join(temporary, "agy") || await executableHash(metadata.target) !== metadata.sha256) throw Error("Pinned CLI changed during the session");
}

export async function approvedCli(project) {
  const base = path.join(project, ".git/agent-runtime-tools");
  const pointer = path.join(base, "antigravity-runtime.json");
  if (!fs.existsSync(pointer)) return "agy";
  const stat = fs.lstatSync(pointer);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || stat.size > 8192) throw Error("Invalid approved CLI pointer");
  const metadata = JSON.parse(fs.readFileSync(pointer, "utf8"));
  const executable = metadata.executable;
  if (typeof executable !== "string" || !executable.startsWith(base + "/agy-") || path.basename(executable) !== "agy" || fs.realpathSync(executable) !== executable) throw Error("Approved CLI must be in the private project runtime");
  const binary = fs.lstatSync(executable);
  if (!binary.isFile() || binary.nlink !== 1 || binary.size > 512 * 1024 * 1024 || !(binary.mode & 0o111) || await executableHash(executable) !== metadata.sha256) throw Error("Approved CLI integrity mismatch");
  return executable;
}

export async function releaseFrozenCli(project, temporary) {
  const file = path.join(temporary, "cli.json");
  if (!fs.existsSync(file)) return;
  const metadata = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!fs.existsSync(metadata.source)) return;
  if (await executableHash(metadata.source) !== metadata.sha256) return;
  await verifyFrozenCli(temporary);
  fs.unlinkSync(metadata.target); // Remove only the verified disposable copy; the source remains.
}

export function godotBin(project) {
  const base = path.join(project, ".git/agent-runtime-tools");
  const file = path.join(base, "godot-runtime.json");
  if (!fs.existsSync(file)) return "";
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || stat.size > 4096) throw Error("Invalid private Godot pointer");
  const pointer = JSON.parse(fs.readFileSync(file, "utf8"));
  const bin = pointer.bin;
  if (typeof bin !== "string" || !bin.startsWith(base + "/godot47-") || path.basename(bin) !== "bin" || fs.realpathSync(bin) !== bin) throw Error("Godot bin must be in the private project runtime");
  if (fs.readdirSync(bin).join() !== "godot") throw Error("Private bin must contain only Godot");
  const executable = path.join(bin, "godot"), binary = fs.lstatSync(executable);
  if (!binary.isFile() || binary.isSymbolicLink() || binary.nlink !== 1 || binary.size > 1024 * 1024 || !(binary.mode & 0o111) || sha(fs.readFileSync(executable)) !== pointer.runnerHash) throw Error("Godot runner integrity mismatch");
  return bin;
}

export function revoke(pin) {
  assertSnapshotPath(pin);
  const marker = path.join(pin, "REVOKED");
  try {
    writePrivateFileExclusive(marker, new Date().toISOString() + "\n", "task revocation marker");
  } catch (error) {
    if (error.code !== "EEXIST") throw error;
    const stat = fs.lstatSync(marker);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || stat.uid !== CURRENT_UID ||
        (stat.mode & 0o777) !== 0o600) {
      throw Error("Existing task revocation marker is unsafe");
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const [action, first, second, third] = process.argv.slice(2);
    if (action === "args") validateLaunchArgs(process.argv.slice(3));
    else if (action === "cli-source") console.log(await approvedCli(first));
    else if (action === "release-cli") await releaseFrozenCli(first, second);
    else if (action === "freeze-cli") console.log(await freezeCli(first, second));
    else if (action === "verify-cli") await verifyFrozenCli(first);
    else if (action === "godot-bin") console.log(godotBin(first));
    else if (action === "project") console.log(projectRoot(first));
    else if (action === "active") console.log(activeSnapshot(first));
    else if (action === "manifest") verifySnapshot(first);
    else if (action === "hook") validateHook(JSON.parse(fs.readFileSync(first, "utf8")));
    else if (action === "revoke") revoke(first);
    else if (action === "close") revoke(activeSnapshot(first));
    else if (action === "device-grant") {
      const grant = await taskGrant(first, second);
      const cap = grant.deviceCapture;
      if (!cap || !/^[1-9][0-9]{0,19}$/.test(cap.runId) || !/^[0-9a-f]{40}$/.test(cap.commit) ||
          !/^[0-9a-f]{64}$/.test(cap.apkSha256)) throw Error("Device capture is not granted");
      console.log(JSON.stringify(cap));
    } else if (action === "play-grant") {
      const grant = await taskGrant(first, second);
      const cap = grant.devicePlay;
      if (!cap || !/^[1-9][0-9]{0,19}$/.test(cap.runId) || !/^[0-9a-f]{40}$/.test(cap.commit) ||
          !/^[0-9a-f]{64}$/.test(cap.apkSha256)) throw Error("Device play is not granted");
      console.log(JSON.stringify(cap));
    } else if (action === "session") {
      assertPrivateDirectory(third, 0o700, "agent session directory");
      const grant = await taskGrant(first, second);
      const budget = Number(process.env.LS_SESSION_TIMEOUT ?? 1200);
      if (!Number.isInteger(budget) || budget < 1 || budget > 1800) throw Error("Session timeout must be 1..1800 seconds");
      const seconds = Math.min(budget, Math.floor((Date.parse(grant.expiresAt) - Date.now()) / 1000) - 1);
      const settings = { trustedWorkspaces: [second], toolPermission: "request-review", permissions: {
        allow: [...["git", "godot", "which", "rg", "grep", "sed", "find", "jq", "pwd", "ls", "stat", "file", "sha256sum", "cat", "head", "tail", "agy"].map((command) => "command(" + command + ")"), "command(node --test tools/agent-guard/test-state.mjs)", "command(node --test tools/agent-guard/test-state.mjs tools/agent-guard/test-launcher.mjs)", "command(tools/device-tests/agentctl status)", "command(tools/device-tests/agentctl battery)", "command(tools/device-tests/agentctl thermal)", "command(tools/device-tests/agentctl performance-check)", "command(tools/device-tests/agentctl inspect-installed)", "command(tools/device-tests/agentctl screenshot)", "command(tools/device-tests/agentctl logcat)", "command(tools/device-tests/agentctl fetch-build)",
          ...(grant.deviceCapture ? ["command(tools/device-tests/agentctl capture-restore)"] : []),
          ...(grant.devicePlay ? ["command(tools/device-tests/agentctl game-open)", "command(tools/device-tests/agentctl game-capture)", "command(tools/device-tests/agentctl game-tap)", "command(tools/device-tests/agentctl game-move)", "command(tools/device-tests/agentctl game-finish)"] : []),
          ...grant.files.map((name) => "write_file(" + path.join(second, name) + ")")]
      } };
      writePrivateFileExclusive(path.join(third, "allow"), grant.files.join("\n") + (grant.files.length ? "\n" : ""), "session allowlist");
      writePrivateFileExclusive(path.join(third, "settings.json"), JSON.stringify(settings), "session settings");
      writePrivateFileExclusive(path.join(third, "timeout"), String(seconds), "session timeout");
      console.log(JSON.stringify({ taskId: grant.taskId, files: grant.files, expiresAt: grant.expiresAt, timeoutSeconds: seconds }));
    } else throw Error("Unknown runtime action");
  } catch (error) { console.error("RUNTIME_FAIL: " + error.message); process.exitCode = 3; }
}

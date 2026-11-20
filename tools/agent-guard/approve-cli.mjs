import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { projectRoot, verifyFrozenCli, executableHash, approvedCli } from "./runtime-config.mjs";
try {
  const [worktree, session, evidence] = process.argv.slice(2);
  if (!worktree || !session || !/^[0-9a-f-]{36}$/.test(evidence ?? "")) throw Error("Usage: approve-cli.mjs <worktree> <completed-session-directory> <reviewed-conversation-id>");
  const project = projectRoot(worktree);
  await verifyFrozenCli(session);
  const frozen = JSON.parse(fs.readFileSync(path.join(session, "cli.json"), "utf8"));
  const state = path.join(project, ".git/agent-runtime-tools");
  fs.mkdirSync(state, { recursive: true, mode: 0o700 });
  if (fs.realpathSync(state) !== state) throw Error("Private runtime directory must not use symlinks");
  const cache = fs.mkdtempSync(path.join(state, "agy-")), executable = path.join(cache, "agy");
  fs.copyFileSync(frozen.target, executable, fs.constants.COPYFILE_EXCL);
  if (await executableHash(executable) !== frozen.sha256) throw Error("CLI changed while copying");
  const version = execFileSync(executable, ["--version"], { encoding: "utf8", timeout: 20000, env: { ...process.env, AGY_CLI_DISABLE_AUTO_UPDATE: "true" } }).trim();
  const metadata = { executable, sha256: frozen.sha256, version, evidence, approvedAt: new Date().toISOString(), sourceCommit: execFileSync("git", ["-C", worktree, "rev-parse", "HEAD"], { encoding: "utf8", timeout: 10000 }).trim() };
  const pointer = path.join(state, "antigravity-runtime.json");
  if (fs.existsSync(pointer)) {
    const stat = fs.lstatSync(pointer);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1) throw Error("Unexpected existing pointer");
    fs.copyFileSync(pointer, pointer + ".previous-" + randomUUID(), fs.constants.COPYFILE_EXCL);
  }
  const temporary = pointer + "." + randomUUID();
  fs.writeFileSync(temporary, JSON.stringify(metadata, null, 2) + "\n", { flag: "wx", mode: 0o600 });
  fs.renameSync(temporary, pointer);
  if (await approvedCli(project) !== executable) throw Error("Published CLI pointer verification failed");
  console.log(JSON.stringify({ status: "PASS", ...metadata }, null, 2));
} catch (error) { console.error("CLI_APPROVAL_FAIL: " + error.message); process.exitCode = 3; }

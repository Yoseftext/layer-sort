import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const CACHE_SCHEMA = 1;
export const MAX_CACHE_ENTRIES = 5;
export const MAX_AUDIT_BYTES = 1024 * 1024;
export const COMMAND_TIMEOUT_MS = 15000;

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const SCRIPT_DIR = path.dirname(SCRIPT_PATH);
const DEFAULT_INFRA_DIR = path.resolve(SCRIPT_DIR, "../..");
const INFRA_DIR = path.resolve(process.env.SAFE_AGY_INFRA_DIR || DEFAULT_INFRA_DIR);
const CURRENT_UID = typeof process.getuid === "function" ? process.getuid() : -1;

function fail(message, code = 3) {
  const error = new Error(message);
  error.exitCode = code;
  throw error;
}

export function assertSafeExecutionEnvironment(env = process.env) {
  const injectedLoaderVariables = Object.keys(env).filter((name) => name.startsWith("LD_") && String(env[name] || "").length > 0);
  const injectedNodeVariables = ["NODE_OPTIONS", "NODE_PATH", "BASH_ENV"].filter((name) => String(env[name] || "").length > 0);
  const unsafe = [...injectedLoaderVariables, ...injectedNodeVariables];
  if (unsafe.length) fail("Unsafe runtime environment variables are set: " + unsafe.sort().join(", "), 78);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function stableJson(value) {
  if (Array.isArray(value)) return "[" + value.map(stableJson).join(",") + "]";
  if (value && typeof value === "object") {
    return "{" + Object.keys(value).sort().map((key) => JSON.stringify(key) + ":" + stableJson(value[key])).join(",") + "}";
  }
  return JSON.stringify(value);
}

export function hashFd(fd, label = "open file descriptor") {
  const before = fs.fstatSync(fd, { bigint: true });
  if (!before.isFile() || before.nlink !== 1n) fail("Fingerprint target is not a unique regular file: " + label, 78);
  const hash = crypto.createHash("sha256");
  const buffer = Buffer.allocUnsafe(1024 * 1024);
  let position = 0;
  for (;;) {
    const count = fs.readSync(fd, buffer, 0, buffer.length, position);
    if (count === 0) break;
    hash.update(buffer.subarray(0, count));
    position += count;
  }
  const after = fs.fstatSync(fd, { bigint: true });
  if (before.dev !== after.dev || before.ino !== after.ino || before.size !== after.size ||
      before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs || BigInt(position) !== before.size) {
    fail("Fingerprint target changed while being hashed: " + label, 78);
  }
  return { sha256: hash.digest("hex"), size: Number(before.size), dev: String(before.dev), ino: String(before.ino) };
}

export function hashOpenFile(filePath) {
  const flags = fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0);
  const fd = fs.openSync(filePath, flags);
  try { return hashFd(fd, filePath); }
  finally { fs.closeSync(fd); }
}

export function resolveExecutable(command, env = process.env, options = {}) {
  if (typeof command !== "string" || command.length === 0) fail("Executable name is empty", 78);
  const candidates = [];
  if (path.isAbsolute(command)) candidates.push(command);
  else {
    for (const entry of (env.PATH || "").split(path.delimiter)) {
      if (!entry || !path.isAbsolute(entry)) continue;
      candidates.push(path.join(entry, command));
    }
  }
  const matches = [];
  for (const candidate of [...new Set(candidates)]) {
    try {
      const linkStat = fs.lstatSync(candidate);
      const realPath = fs.realpathSync.native(candidate);
      const targetStat = fs.statSync(realPath);
      if (!targetStat.isFile() || (targetStat.mode & 0o111) === 0 || (targetStat.mode & 0o022) !== 0) continue;
      matches.push({ path: path.resolve(candidate), realpath: realPath, symlink: linkStat.isSymbolicLink() });
    } catch {
      continue;
    }
  }
  if (matches.length === 0) fail("Executable not found or unsafe: " + command, 78);
  const uniqueMatches = [...new Map(matches.map((item) => [item.realpath, item])).values()];
  if (options.requireUnique === true && uniqueMatches.length !== 1) {
    fail("Executable resolution is ambiguous for " + command + ": " + uniqueMatches.map((item) => item.path).join(", "), 78);
  }
  return uniqueMatches[0];
}

function runBounded(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: "utf8",
    timeout: options.timeoutMs || COMMAND_TIMEOUT_MS,
    maxBuffer: options.maxBuffer || 4 * 1024 * 1024,
    windowsHide: true,
    stdio: options.passFd === undefined ? ["ignore", "pipe", "pipe"] : ["ignore", "pipe", "pipe", options.passFd],
    env: {
      ...process.env,
      CI: "true",
      GIT_TERMINAL_PROMPT: "0",
      GCM_INTERACTIVE: "Never",
      NO_COLOR: "1",
      TERM: "dumb",
      ...(options.env || {})
    }
  });
  if (result.error) {
    if (result.error.code === "ETIMEDOUT") fail(command + " timed out", 78);
    fail(command + " failed to start: " + result.error.message, 78);
  }
  if (result.status !== 0) {
    fail(command + " exited " + result.status + ": " + String(result.stderr || result.stdout || "").trim().slice(0, 1200), 78);
  }
  return { stdout: result.stdout || "", stderr: result.stderr || "" };
}

function toolIdentity(name, required = true) {
  try {
    const resolved = resolveExecutable(name);
    const file = hashOpenFile(resolved.realpath);
    return { name, path: resolved.path, realpath: resolved.realpath, sha256: file.sha256, size: file.size };
  } catch (error) {
    if (required) throw error;
    return { name, available: false };
  }
}

function parseElf(executablePath) {
  if (process.platform !== "linux" || process.arch !== "arm64") {
    fail("Only Linux ARM64 ELF compatibility is implemented; host is " + process.platform + "/" + process.arch, 78);
  }
  const readelf = resolveExecutable("readelf");
  const header = runBounded(readelf.realpath, ["-h", executablePath]).stdout;
  if (!header.includes("ELF Header:")) fail("Antigravity is not an ELF executable", 78);
  const elfClass = (header.match(/Class:\s*(.+)/) || [])[1]?.trim();
  const machine = (header.match(/Machine:\s*(.+)/) || [])[1]?.trim();
  const note = runBounded(readelf.realpath, ["-n", executablePath]).stdout;
  const buildId = (note.match(/Build ID:\s*([0-9a-f]+)/i) || [])[1] || null;
  const program = runBounded(readelf.realpath, ["-l", executablePath]).stdout;
  const interpreter = (program.match(/Requesting program interpreter:\s*([^\]\r\n]+)/) || [])[1]?.trim() || null;
  const dynamic = runBounded(readelf.realpath, ["-d", executablePath]).stdout;
  if (/\((?:RPATH|RUNPATH)\)/.test(dynamic)) fail("ELF RPATH/RUNPATH is not supported by the dependency resolver", 78);
  const needed = [...dynamic.matchAll(/Shared library:\s*\[([^\]]+)\]/g)].map((match) => match[1]).sort();
  const ldconfig = resolveExecutable("ldconfig", process.env);
  const cache = runBounded(ldconfig.realpath, ["-p"], { timeoutMs: 10000 }).stdout;
  const libraryMap = new Map();
  for (const line of cache.split("\n")) {
    const match = line.trim().match(/^(\S+)\s+\(([^)]*)\)\s+=>\s+(.+)$/);
    if (!match) continue;
    const name = match[1];
    const abi = match[2];
    const candidate = match[3].trim();
    if (!libraryMap.has(name)) libraryMap.set(name, []);
    libraryMap.get(name).push({ abi, path: candidate });
  }
  const dependencies = [];
  for (const name of needed) {
    const choices = libraryMap.get(name) || [];
    const selected = choices.find((item) => /aarch64|arm64/i.test(item.abi));
    if (!selected) fail("Unable to resolve an ARM64 ABI match for ELF dependency " + name, 78);
    if (!fs.existsSync(selected.path)) fail("Resolved ELF dependency does not exist: " + name, 78);
    const realpath = fs.realpathSync.native(selected.path);
    const file = hashOpenFile(realpath);
    dependencies.push({ name, path: realpath, abi: selected.abi, sha256: file.sha256, size: file.size });
  }
  let loader = null;
  if (interpreter) {
    const realpath = fs.realpathSync.native(interpreter);
    const file = hashOpenFile(realpath);
    loader = { path: realpath, sha256: file.sha256, size: file.size };
  }
  if (!elfClass || !machine || !buildId) fail("ELF identity is incomplete", 78);
  if (process.arch === "arm64" && !/AArch64/i.test(machine)) fail("ELF architecture does not match the ARM64 host", 78);
  if (process.arch === "x64" && !/X86-64/i.test(machine)) fail("ELF architecture does not match the x64 host", 78);
  return {
    format: "ELF",
    class: elfClass,
    machine,
    buildId,
    interpreter,
    loader,
    needed,
    dependencies,
    readelf: toolIdentity("readelf"),
    ldconfig: toolIdentity("ldconfig")
  };
}

export function fingerprintCli(command = "agy", env = process.env) {
  assertSafeExecutionEnvironment(process.env);
  assertSafeExecutionEnvironment(env);
  const executable = resolveExecutable(command, env, { requireUnique: true });
  const linkStat = fs.lstatSync(executable.path);
  if (linkStat.isSymbolicLink()) fail("Antigravity path must not be a symlink: " + executable.path, 78);
  if ((linkStat.uid !== 0 && linkStat.uid !== CURRENT_UID) || (linkStat.mode & 0o022) !== 0) {
    fail("Antigravity executable ownership or permissions are unsafe", 78);
  }
  const fd = fs.openSync(executable.realpath, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
  try {
    const opened = fs.fstatSync(fd, { bigint: true });
    if (!opened.isFile() || opened.nlink !== 1n || (opened.uid !== 0n && opened.uid !== BigInt(CURRENT_UID)) || (opened.mode & 0o022n) !== 0n) {
      fail("Opened Antigravity executable has unsafe identity or permissions", 78);
    }
    const file = hashFd(fd, executable.realpath);
    if (String(linkStat.dev) !== file.dev || String(linkStat.ino) !== file.ino) {
      fail("Antigravity path changed while resolving its identity", 78);
    }
    const descriptorPath = "/proc/self/fd/3";
    const versionResult = runBounded(descriptorPath, ["--version"], { passFd: fd, timeoutMs: 15000, maxBuffer: 64 * 1024 });
    const version = versionResult.stdout.trim().split(/\r?\n/)[0];
    if (!version || version.length > 128) fail("Antigravity version output is invalid", 78);
    const elf = parseElf("/proc/" + process.pid + "/fd/" + fd);
    const after = fs.fstatSync(fd, { bigint: true });
    if (opened.dev !== after.dev || opened.ino !== after.ino || opened.size !== after.size ||
        opened.mtimeNs !== after.mtimeNs || opened.ctimeNs !== after.ctimeNs) {
      fail("Antigravity executable changed during descriptor-based inspection", 78);
    }
    return {
      requestedPath: executable.path,
      realpath: executable.realpath,
      version,
      sha256: file.sha256,
      size: file.size,
      device: String(opened.dev),
      inode: String(opened.ino),
      mode: Number(opened.mode & 0o777n).toString(8),
      elf
    };
  } finally {
    fs.closeSync(fd);
  }
}

export function spawnVerifiedDescriptor(filePath, expected, args, options = {}) {
  assertSafeExecutionEnvironment(process.env);
  assertSafeExecutionEnvironment(options.env || {});
  if (process.platform !== "linux" || !fs.existsSync("/proc/self/fd")) {
    fail("Descriptor-based Antigravity execution requires Linux /proc/self/fd", 78);
  }
  const fd = fs.openSync(filePath, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
  try {
    const opened = fs.fstatSync(fd, { bigint: true });
    if (!opened.isFile() || opened.nlink !== 1n || (opened.uid !== 0n && opened.uid !== BigInt(CURRENT_UID)) ||
        (opened.mode & 0o022n) !== 0n) {
      fail("Executable descriptor has unsafe ownership, type, or permissions", 78);
    }
    const file = hashFd(fd, filePath);
    if (file.sha256 !== expected.sha256 || file.dev !== expected.device || file.ino !== expected.inode) {
      fail("Executable descriptor does not match the approved fingerprint", 78);
    }
    const capture = options.capture === true;
    const result = spawnSync("/proc/self/fd/3", args, {
      cwd: options.cwd || process.cwd(),
      encoding: capture ? "utf8" : undefined,
      timeout: options.timeoutMs,
      maxBuffer: options.maxBuffer || 8 * 1024 * 1024,
      windowsHide: true,
      stdio: capture ? ["ignore", "pipe", "pipe", fd] : ["inherit", "inherit", "inherit", fd],
      env: {
        ...process.env,
        CI: "true",
        GIT_TERMINAL_PROMPT: "0",
        GCM_INTERACTIVE: "Never",
        ...(options.env || {})
      }
    });
    if (result.error) {
      if (result.error.code === "ETIMEDOUT") fail("Descriptor-launched executable timed out", 78);
      fail("Descriptor-launched executable failed: " + result.error.message, 78);
    }
    return { status: result.status ?? 3, stdout: result.stdout || "", stderr: result.stderr || "" };
  } finally {
    fs.closeSync(fd);
  }
}

function walkFiles(root, relative, output) {
  if (relative === path.join("tools", "agent-guard", "README.md")) return;
  const target = path.join(root, relative);
  const stat = fs.lstatSync(target);
  if (stat.isSymbolicLink()) fail("Policy fingerprint refuses symlinks: " + target, 78);
  if (stat.isDirectory()) {
    for (const entry of fs.readdirSync(target, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      walkFiles(root, path.join(relative, entry.name), output);
    }
    return;
  }
  if (!stat.isFile() || stat.nlink !== 1) fail("Unexpected policy file type: " + target, 78);
  const file = hashOpenFile(target);
  output.push({ path: relative.split(path.sep).join("/"), sha256: file.sha256, size: file.size });
}

export function fingerprintPolicy(projectRoot, infraDir = INFRA_DIR) {
  const files = [];
  const required = [
    ".agents/hooks.json",
    ".agents/agents",
    ".agents/plugins/layer-sort-agent-kit/scripts",
    "tools/agent-guard"
  ];
  for (const relative of required) walkFiles(projectRoot, relative, files);
  files.sort((a, b) => a.path.localeCompare(b.path));
  const infraFiles = [];
  walkFiles(infraDir, "tools/agent-guard", infraFiles);
  infraFiles.sort((a, b) => a.path.localeCompare(b.path));
  return {
    projectRoot: fs.realpathSync.native(projectRoot),
    infraRoot: fs.realpathSync.native(infraDir),
    projectFiles: files,
    infrastructureFiles: infraFiles,
    sha256: sha256(stableJson({ files, infraFiles }))
  };
}

export function fingerprintHost() {
  const hashTool = toolIdentity("sha256sum", false).available === false
    ? toolIdentity("shasum")
    : toolIdentity("sha256sum");
  const realpathTool = toolIdentity("realpath");
  const flockTool = toolIdentity("flock", false);
  const timeoutTool = toolIdentity("/usr/bin/timeout");
  const bashTool = toolIdentity("bash");
  const bashAbsoluteTool = toolIdentity("/usr/bin/bash");
  const gitTool = toolIdentity("git");
  const launcherTools = {
    dirname: toolIdentity("dirname"),
    mktemp: toolIdentity("mktemp"),
    mkdir: toolIdentity("mkdir"),
    cat: toolIdentity("cat"),
    grep: toolIdentity("grep"),
    cmp: toolIdentity("cmp")
  };
  const nodeTool = {
    path: process.execPath,
    realpath: fs.realpathSync.native(process.execPath),
    sha256: hashOpenFile(fs.realpathSync.native(process.execPath)).sha256
  };
  const glibc = process.report?.getReport?.().header?.glibcVersionRuntime || null;
  if (!glibc) fail("Unable to identify the host C runtime", 78);
  return {
    platform: process.platform,
    arch: process.arch,
    release: os.release(),
    type: os.type(),
    glibc,
    node: process.versions.node,
    nodeExecutable: nodeTool,
    hashTool,
    realpathTool,
    flock: flockTool,
    timeout: timeoutTool,
    bash: bashTool,
    bashAbsolute: bashAbsoluteTool,
    git: gitTool,
    launcherTools,
    lockMode: flockTool.available === false ? "mkdir" : "flock"
  };
}

export function buildFingerprint(projectRoot, infraDir = INFRA_DIR, env = process.env) {
  const cli = fingerprintCli(env.AGY_BIN || "agy", env);
  const policy = fingerprintPolicy(projectRoot, infraDir);
  const host = fingerprintHost();
  const material = { schema: CACHE_SCHEMA, cli, policySha256: policy.sha256, host };
  return { key: sha256(stableJson(material)), cli, policy, host, schema: CACHE_SCHEMA };
}

function getStateDirectory(env = process.env, home = os.homedir()) {
  const base = env.XDG_STATE_HOME ? path.resolve(env.XDG_STATE_HOME) : path.join(home, ".local", "state");
  if (!path.isAbsolute(base)) fail("State directory must be absolute", 78);
  return path.join(base, "safe-agy");
}

function assertNoSymlinkComponents(target) {
  const absolute = path.resolve(target);
  const parsed = path.parse(absolute);
  let current = parsed.root;
  for (const segment of absolute.slice(parsed.root.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, segment);
    try {
      if (fs.lstatSync(current).isSymbolicLink()) fail("State path contains a symlink: " + current, 78);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
}

export function ensureStateDirectory(stateDir = getStateDirectory()) {
  assertNoSymlinkComponents(path.dirname(stateDir));
  fs.mkdirSync(stateDir, { recursive: true, mode: 0o700 });
  assertNoSymlinkComponents(stateDir);
  const stat = fs.lstatSync(stateDir);
  if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== CURRENT_UID || (stat.mode & 0o777) !== 0o700) {
    fail("Unsafe safe-agy state directory; expected current owner and mode 0700: " + stateDir, 78);
  }
  return stateDir;
}

function validateStateFile(filePath, expectedMode = 0o600) {
  let stat;
  try { stat = fs.lstatSync(filePath); }
  catch (error) { if (error.code === "ENOENT") return null; throw error; }
  if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || stat.uid !== CURRENT_UID ||
      (stat.mode & 0o777) !== expectedMode) {
    fail("Unsafe safe-agy state file: " + filePath, 78);
  }
  return stat;
}

export function readCache(stateDir) {
  ensureStateDirectory(stateDir);
  const filePath = path.join(stateDir, "compatibility-cache.json");
  if (!validateStateFile(filePath)) return { schema: CACHE_SCHEMA, entries: [] };
  const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (data.schema !== CACHE_SCHEMA || !Array.isArray(data.entries) || data.entries.length > MAX_CACHE_ENTRIES) {
    fail("Compatibility cache schema or size is invalid", 78);
  }
  return data;
}

export function writeCacheAtomic(stateDir, data) {
  ensureStateDirectory(stateDir);
  const filePath = path.join(stateDir, "compatibility-cache.json");
  validateStateFile(filePath);
  const temporary = filePath + "." + process.pid + "." + crypto.randomBytes(8).toString("hex") + ".tmp";
  const payload = JSON.stringify({ schema: CACHE_SCHEMA, entries: data.entries.slice(0, MAX_CACHE_ENTRIES) }, null, 2) + "\n";
  const flags = fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | (fs.constants.O_NOFOLLOW || 0);
  const fd = fs.openSync(temporary, flags, 0o600);
  try {
    fs.writeFileSync(fd, payload, "utf8");
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
  fs.renameSync(temporary, filePath);
  const dirFd = fs.openSync(stateDir, fs.constants.O_RDONLY);
  try { fs.fsyncSync(dirFd); } finally { fs.closeSync(dirFd); }
}

export function appendAudit(stateDir, event) {
  ensureStateDirectory(stateDir);
  const filePath = path.join(stateDir, "audit.jsonl");
  const current = validateStateFile(filePath);
  if (current && current.size >= MAX_AUDIT_BYTES) {
    const rotated = filePath + ".1";
    validateStateFile(rotated);
    try { fs.unlinkSync(rotated); } catch (error) { if (error.code !== "ENOENT") throw error; }
    fs.renameSync(filePath, rotated);
  }
  const flags = fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_APPEND | (fs.constants.O_NOFOLLOW || 0);
  const fd = fs.openSync(filePath, flags, 0o600);
  try {
    const stat = fs.fstatSync(fd);
    if (!stat.isFile() || stat.nlink !== 1 || stat.uid !== CURRENT_UID || (stat.mode & 0o777) !== 0o600) {
      fail("Unsafe audit log", 78);
    }
    fs.writeSync(fd, JSON.stringify(event) + "\n", null, "utf8");
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
}

export function findCacheEntry(cache, fingerprint) {
  return cache.entries.find((entry) => entry.key === fingerprint.key && entry.verdict === "PASS") || null;
}

export function diffSummary(cache, fingerprint) {
  const previous = cache.entries[0];
  if (!previous) return "No previous successful fingerprint is cached.";
  if (previous.key === fingerprint.key) return "Current fingerprint matches the latest successful compatibility entry.";

  const changes = [];
  const oldCli = previous.cli || {};
  const currentCli = fingerprint.cli || {};
  const oldElf = oldCli.elf || {};
  const currentElf = currentCli.elf || {};
  if (oldCli.realpath !== currentCli.realpath) changes.push("CLI path changed");
  if (oldCli.version !== currentCli.version) changes.push("CLI version changed");
  if (oldCli.sha256 !== currentCli.sha256) changes.push("CLI executable SHA-256 changed");
  if (oldCli.device !== currentCli.device || oldCli.inode !== currentCli.inode) changes.push("CLI file identity changed (device/inode)");
  if (oldCli.size !== currentCli.size || oldCli.mode !== currentCli.mode) changes.push("CLI file size or mode changed");
  if (oldElf.buildId !== currentElf.buildId) changes.push("ELF Build ID changed");
  if (oldElf.class !== currentElf.class || oldElf.machine !== currentElf.machine || oldElf.interpreter !== currentElf.interpreter) {
    changes.push("ELF format or interpreter changed");
  }
  if (stableJson(oldElf.loader) !== stableJson(currentElf.loader)) changes.push("ELF loader fingerprint changed");
  if (stableJson(oldElf.dependencies) !== stableJson(currentElf.dependencies)) changes.push("ELF dependency fingerprint changed");
  if (stableJson(oldElf.readelf) !== stableJson(currentElf.readelf) ||
      stableJson(oldElf.ldconfig) !== stableJson(currentElf.ldconfig)) changes.push("ELF inspection tool fingerprint changed");
  if (previous.policySha256 !== fingerprint.policy.sha256) changes.push("launcher/policy/test fingerprint changed");
  if (stableJson(previous.host) !== stableJson(fingerprint.host)) changes.push("host/runtime dependency fingerprint changed");
  if (stableJson(oldCli) !== stableJson(currentCli) && !changes.some((item) => item.startsWith("CLI ") || item.startsWith("ELF "))) {
    changes.push("additional CLI fingerprint metadata changed");
  }
  return changes.length ? changes.join("; ") : "Composite fingerprint differs in an unclassified field; full compatibility check required.";
}

function normalizeWarningForReview(warning) {
  const loggerPrefix = /^[WE]\d{4} \d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\S+\.go:\d+\] /;
  return warning.replace(loggerPrefix, "");
}

function isRecognizedSoftWarning(warning) {
  const normalized = normalizeWarningForReview(warning);
  const hasGoLoggerPrefix = /^[WE]\d{4} \d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\S+\.go:\d+\] /.test(warning);
  const pluginPromptWarning = hasGoLoggerPrefix
    ? /^W\d{4} \d{2}:\d{2}:\d{2}\.\d+\s+\d+ plugins\.go:423\] Truncating suggested_prompts from \d+ to 3 in file:\/\/\/.+\/\.gemini\/config\/plugins\/(?:flutter|firebase)\/plugin\.json$/.test(warning)
    : /^Truncating suggested_prompts from \d+ to 3 in file:\/\/\/.+\/\.gemini\/config\/plugins\/(?:flutter|firebase)\/plugin\.json$/.test(warning);
  return /^Tool "[^"]+" is deprecated and has no effect$/.test(normalized) ||
    pluginPromptWarning ||
    normalized === "Transient startup auth-cache warnings resolved by successful OAuth authentication and model streaming" ||
    normalized === "Consumer account: enterprise admin-control cache is not applicable" ||
    normalized === "Optional /usr/bin/cs helper unavailable; optional helper feature not verified" ||
    normalized === "PRoot host: background auto-updater skipped inaccessible /proc/<pid>/fd; use agy update manually" ||
    /^Optional global MCP server (?:science_biomolecular_structure_viewer_mcp|flutter_dart-mcp-server) unavailable; missing executable (?:agy-node|dart)$/.test(normalized) ||
    normalized === "Antigravity used its default Gemini directory; agent delegation verified" ||
    normalized === "Antigravity analytics request was canceled during agent execution" ||
    normalized === "Antigravity configuration request timed out and used its fallback" ||
    normalized === "Antigravity language server shutdown timed out after the probe" ||
    normalized === "Known .agents/agents Markdown discovery fallback; active subagent delegation verified" ||
    normalized === "Antigravity file watcher skipped an unnamed empty/temp file after the active probe completed";
}

export function extractWarningLines(transcript) {
  const goWarning = /^[WE]\d{4}\s+\d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\S+\.go:\d+\]\s*/;
  const conventionalWarning = /^\s*(?:\[(?:WARN|WARNING)\]|WARN(?:ING)?(?:\s*[:\]]|\s)|[A-Za-z][A-Za-z0-9_-]*Warning(?:\s*[:\]]|\s))/i;
  const lines = String(transcript || "").split(/\r?\n/);
  return [...new Set(lines.filter((line) => goWarning.test(line) || conventionalWarning.test(line)))];
}

export function redactEvidenceText(value) {
  return String(value || "")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "<redacted-email>")
    .replace(/\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi, "Bearer <redacted>")
    .replace(/\bAIza[0-9A-Za-z_-]{20,}\b/g, "<redacted-api-key>");
}

function isTransientAuthWarning(message) {
  return /^Cache\((?:loadCodeAssistResponse|userInfo|peopleInfo)\): Singleflight refresh failed: .*error getting token source: You are not logged into Antigravity\.$/.test(message) ||
    /^Not reloading plugin MCP servers: cannot get the signed-in user: error getting token source: You are not logged into Antigravity\.$/.test(message) ||
    /^error getting token source: You are not logged into Antigravity\.$/.test(message) ||
    /^Failed to poll ListExperiments: error getting token source: You are not logged into Antigravity\.$/.test(message);
}

export function classifyAntigravityWarnings(transcript, options = {}) {
  const source = String(transcript || "");
  const lines = source.split(/\r?\n/);
  const rawWarnings = extractWarningLines(source);
  const oauthIndex = lines.findIndex((line) => /OAuth: authenticated successfully as [^\r\n]+/.test(line));
  const oauthAuthenticated = oauthIndex >= 0;
  const modelStreamObserved = /URL: https:\/\/daily-cloudcode-pa\.googleapis\.com\/v1internal:streamGenerateContent\?alt=sse\b/.test(source);
  const consumerAccount = lines.some((line) => /applyAuthResult: .*authMethod=consumer, quotaProject=/.test(line));

  if (!oauthAuthenticated || !modelStreamObserved) {
    fail("Active compatibility probe did not prove successful OAuth authentication and model streaming", 78);
  }

  const authWarningIndexes = lines
    .map((line, index) => ({ line: normalizeWarningForReview(line), index }))
    .filter((item) => isTransientAuthWarning(item.line));
  if (authWarningIndexes.some((item) => item.index >= oauthIndex)) {
    fail("Authentication cache warning occurred after OAuth success; manual review required", 78);
  }

  const warnings = [];
  if (authWarningIndexes.length) {
    warnings.push("Transient startup auth-cache warnings resolved by successful OAuth authentication and model streaming");
  }

  for (const raw of rawWarnings) {
    const message = normalizeWarningForReview(raw);
    if (isTransientAuthWarning(message)) continue;
    if (isRecognizedSoftWarning(raw)) {
      warnings.push(message);
      continue;
    }
    if (/^W\d{4} \d{2}:\d{2}:\d{2}\.\d+\s+\d+ plugins\.go:\d+\] /.test(raw) &&
        /^Truncating suggested_prompts from \d+ to 3 in file:\/\/\/.+\/\.gemini\/config\/plugins\/(?:flutter|firebase)\/plugin\.json$/.test(message) &&
        options.delegationsVerified === true) {
      warnings.push(message);
      continue;
    }
    if (message === 'Failed to resolve GeminiDir ".gemini": .gemini must be an absolute path: path is not absolute, falling back to default' && options.delegationsVerified === true) {
      warnings.push("Antigravity used its default Gemini directory; agent delegation verified");
      continue;
    }
    if (message === 'error recording trajectory segment analytics: Post "https://daily-cloudcode-pa.googleapis.com/v1internal:recordTrajectoryAnalytics": context canceled' && options.delegationsVerified === true) {
      warnings.push("Antigravity analytics request was canceled during agent execution");
      continue;
    }
    if (message === 'AICode FetchConfig failed, falling back to CCPA ListExperiments: failed to make AI Code FetchConfig request: Get "https://aicode.googleapis.com/v1alpha:fetchConfig": context deadline exceeded' && options.delegationsVerified === true) {
      warnings.push("Antigravity configuration request timed out and used its fallback");
      continue;
    }
    if (message === "Language server shutdown timed out" && options.delegationsVerified === true) {
      warnings.push("Antigravity language server shutdown timed out after the probe");
      continue;
    }
    if (message === "Failed to refresh cache in background: admin controls not applicable") {
      if (!consumerAccount) fail("Admin-control cache warning without verified consumer-account context", 78);
      warnings.push("Consumer account: enterprise admin-control cache is not applicable");
      continue;
    }
    const csPathExists = options.csPathExists ?? fs.existsSync("/usr/bin/cs");
    if (message === "failed to get cs path: cs path /usr/bin/cs invalid" &&
        options.platform === "linux" && !csPathExists) {
      warnings.push("Optional /usr/bin/cs helper unavailable; optional helper feature not verified");
      continue;
    }
    if (/^Directory \/proc\/\d+\/fd is not fully accessible \(readable: true, writable: false\), skipping update$/.test(message) &&
        options.platform === "linux") {
      warnings.push("PRoot host: background auto-updater skipped inaccessible /proc/<pid>/fd; use agy update manually");
      continue;
    }
    if (message.trimEnd() === "skipping empty or temp file:" && options.delegationsVerified === true &&
        /^E\d{4} \d{2}:\d{2}:\d{2}\.\d+\s+\d+ file_watcher\.go:\d+\] skipping empty or temp file:\s*$/.test(raw)) {
      warnings.push("Antigravity file watcher skipped an unnamed empty/temp file after the active probe completed");
      continue;
    }
    const optionalMcp = message.match(/^MCP server (science_biomolecular_structure_viewer_mcp|flutter_dart-mcp-server): exec: "(agy-node|dart)": executable file not found in \$PATH$/);
    if (optionalMcp && !options.projectMcpConfigured &&
        ((optionalMcp[1] === "science_biomolecular_structure_viewer_mcp" && optionalMcp[2] === "agy-node") ||
         (optionalMcp[1] === "flutter_dart-mcp-server" && optionalMcp[2] === "dart"))) {
      warnings.push("Optional global MCP server " + optionalMcp[1] + " unavailable; missing executable " + optionalMcp[2]);
      continue;
    }
    const discovery = message.match(/^Failed to discover in dir "(.+\.agents\/agents\/[^"]+\.md)": open (.+): not a directory$/);
    if (discovery && discovery[1] === discovery[2] && options.delegationsVerified === true) {
      warnings.push("Known .agents/agents Markdown discovery fallback; active subagent delegation verified");
      continue;
    }
    fail("Unrecognized Antigravity runtime warning requires manual review: " + message, 78);
  }

  return {
    warnings: [...new Set(warnings)].slice(0, 30),
    authEvidence: { oauthAuthenticated, modelStreamObserved, consumerAccount },
    rawWarningCount: rawWarnings.length
  };
}

export function extractSoftWarnings(suite) {
  const combined = String(suite.stdout || "") + "\n" + String(suite.stderr || "");
  const rawWarnings = combined.split(/\r?\n/)
    .filter((line) => line.startsWith("SOFT_WARNING: "))
    .map((line) => line.slice("SOFT_WARNING: ".length));
  const warnings = [...new Set(rawWarnings.map(normalizeWarningForReview))];
  const unrecognized = rawWarnings.filter((warning) => !isRecognizedSoftWarning(warning));
  if (unrecognized.length) {
    fail("Unrecognized compatibility warning requires manual review (" + unrecognized.length + "): " +
      unrecognized.slice(0, 10).join(" | "), 78);
  }
  return warnings.slice(0, 20);
}

export function selectGeminiModel(modelList, excludedModel = null) {
  const slugs = String(modelList || "").split(/\r?\n/)
    .map((line) => line.trim().split(/\s+/)[0])
    .filter((slug) => /^gemini-[a-z0-9][a-z0-9.-]*$/.test(slug) && slug !== excludedModel);
  for (const effort of ["low", "medium", "high"]) {
    const model = slugs.find((slug) => slug.includes("-flash-") && slug.endsWith("-" + effort));
    if (model) return model;
  }
  return slugs[0] || null;
}

export function canRetryQuotaFailure(exitCode, stream) {
  if (exitCode === 0) return false;
  try {
    const records = String(stream || "").trim().split(/\r?\n/).map((line) => JSON.parse(line));
    const result = records.findLast((record) => record.event === "result");
    return /individual quota reached/i.test(String(result?.result?.error || "")) &&
      !records.some((record) => record.step_update?.tool_name);
  } catch {
    return false;
  }
}

export function describeProbeFailure(exitCode, errorMessage) {
  const message = String(errorMessage || "");
  if (/individual quota reached/i.test(message)) {
    const reset = message.match(/resets in ([0-9hms]+)/i);
    return "Antigravity usage quota reached" + (reset ? "; resets in " + reset[1] : "");
  }
  return "Antigravity CLI returned nonzero exit code " + exitCode;
}

export function classifySuiteStatus(status) {
  if (status === 0) return "PASS";
  if (status === 78 || status === null || status === undefined) return "UNKNOWN";
  return "HARD_FAIL";
}

function auditEvent(stateDir, name, fingerprint, details = {}) {
  appendAudit(stateDir, {
    at: new Date().toISOString(),
    event: name,
    key: fingerprint.key,
    version: fingerprint.cli.version,
    cliSha256: fingerprint.cli.sha256,
    policySha256: fingerprint.policy.sha256,
    verdict: details.verdict || null,
    reason: details.reason || null
  });
}

export function sessionCliIdentity(sessionCli, approvedHash) {
  const frozen = hashOpenFile(sessionCli);
  if (frozen.sha256 !== approvedHash) fail("Session CLI differs from the compatible executable", 78);
  return { sha256: frozen.sha256, device: frozen.dev, inode: frozen.ino };
}

function executeCached(projectRoot, args, capture) {
  const stateDir = ensureStateDirectory(getStateDirectory());
  const fingerprint = buildFingerprint(projectRoot, INFRA_DIR);
  const cache = readCache(stateDir);
  const entry = findCacheEntry(cache, fingerprint);
  if (!entry) {
    auditEvent(stateDir, "HASH_MISMATCH", fingerprint, { verdict: "UNKNOWN", reason: "No PASS cache entry for current fingerprint" });
    fail("Current Antigravity fingerprint has no approved compatibility record", 78);
  }
  auditEvent(stateDir, capture ? "CAPTURE_ATTEMPT" : "EXEC_ATTEMPT", fingerprint, { verdict: "PASS" });
  const sessionCli = process.env.SAFE_AGY_SESSION_CLI;
  const executable = sessionCli || fingerprint.cli.realpath;
  let identity = { sha256: fingerprint.cli.sha256, device: fingerprint.cli.device, inode: fingerprint.cli.inode };
  if (sessionCli) identity = sessionCliIdentity(sessionCli, fingerprint.cli.sha256);
  const result = spawnVerifiedDescriptor(executable, identity, args, {
    capture,
    cwd: process.cwd(),
    timeoutMs: capture ? 20000 : undefined,
    maxBuffer: 8 * 1024 * 1024
  });
  if (capture) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
  }
  auditEvent(stateDir, capture ? "CAPTURE_COMPLETED" : "EXEC_COMPLETED", fingerprint, {
    verdict: result.status === 0 ? "PASS" : "FAIL",
    reason: "exit=" + result.status
  });
  return result.status;
}

function runCompatibilitySuite(projectRoot, fingerprint) {
  const testDir = process.env.SAFE_AGY_COMPAT_TEST_DIR || path.join(INFRA_DIR, "tools/agent-guard");
  const script = path.join(testDir, "test-compatibility.sh");
  if (!fs.existsSync(script)) return { status: 78, reason: "Compatibility test wrapper is not installed; verdict UNKNOWN" };
  const bash = resolveExecutable("bash").realpath;
  const result = spawnSync(bash, [script, "--active", projectRoot], {
    cwd: projectRoot,
    encoding: "utf8",
    timeout: 17 * 60 * 1000,
    maxBuffer: 8 * 1024 * 1024,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
    env: {
      ...process.env,
      CI: "true",
      GIT_TERMINAL_PROMPT: "0",
      GCM_INTERACTIVE: "Never",
      NO_COLOR: "1",
      TERM: "dumb",
      SAFE_AGY_COMPAT_KEY: fingerprint.key,
      SAFE_AGY_INFRA_DIR: INFRA_DIR,
      SAFE_AGY_PROJECT_ROOT: projectRoot,
      SAFE_AGY_STATE_DIR: getStateDirectory()
    }
  });
  if (result.error) return { status: 78, reason: result.error.code === "ETIMEDOUT" ? "Compatibility suite timed out; verdict UNKNOWN" : result.error.message, stdout: result.stdout, stderr: result.stderr };
  return { status: result.status ?? 78, reason: result.status === 0 ? "All compatibility checks passed" : "Compatibility suite failed", stdout: result.stdout, stderr: result.stderr };
}

function runLocked(action, projectRoot) {
  const stateDir = ensureStateDirectory(getStateDirectory());
  let fingerprint;
  try {
    fingerprint = buildFingerprint(projectRoot, INFRA_DIR);
  } catch (error) {
    appendAudit(stateDir, { at: new Date().toISOString(), event: "HASH_MISMATCH", verdict: "UNKNOWN", reason: error.message });
    throw error;
  }
  const cache = readCache(stateDir);
  const entry = findCacheEntry(cache, fingerprint);
  if (action === "ensure" && entry) {
    const touched = { ...entry, lastUsedAt: new Date().toISOString() };
    const reordered = [touched, ...cache.entries.filter((item) => item.key !== fingerprint.key)];
    writeCacheAtomic(stateDir, { schema: CACHE_SCHEMA, entries: reordered });
    auditEvent(stateDir, "CACHE_HIT", fingerprint, { verdict: "PASS" });
    for (const warning of entry.warnings || []) console.error("COMPATIBILITY_SOFT_WARNING: " + warning);
    console.error("COMPATIBILITY_CACHE_HIT PASS " + fingerprint.key);
    console.log(fingerprint.cli.realpath);
    return 0;
  }
  const summary = diffSummary(cache, fingerprint);
  const suite = runCompatibilitySuite(projectRoot, fingerprint);
  if (suite.status !== 0) {
    const verdict = classifySuiteStatus(suite.status);
    const reason = suite.reason + "; Diff: " + summary;
    auditEvent(stateDir, "CHECK_FAILED", fingerprint, { verdict, reason });
    if (suite.stdout) process.stdout.write(suite.stdout);
    if (suite.stderr) process.stderr.write(suite.stderr);
    console.error("COMPATIBILITY_DIFF_SUMMARY: " + summary);
    console.error("COMPATIBILITY_" + verdict + ": " + reason);
    return verdict === "UNKNOWN" ? 78 : 1;
  }
  let verifiedAfterSuite;
  try {
    verifiedAfterSuite = buildFingerprint(projectRoot, INFRA_DIR);
  } catch (error) {
    auditEvent(stateDir, "HASH_MISMATCH", fingerprint, { verdict: "UNKNOWN", reason: "Post-suite fingerprint verification failed: " + error.message });
    console.error("COMPATIBILITY_UNKNOWN: post-suite fingerprint verification failed: " + error.message);
    return 78;
  }
  if (verifiedAfterSuite.key !== fingerprint.key) {
    auditEvent(stateDir, "HASH_MISMATCH", fingerprint, { verdict: "UNKNOWN", reason: "CLI, policy, test, or host fingerprint changed during compatibility evaluation" });
    console.error("COMPATIBILITY_UNKNOWN: fingerprint changed while compatibility tests were running");
    return 78;
  }
  let warnings;
  try {
    warnings = extractSoftWarnings(suite);
  } catch (error) {
    auditEvent(stateDir, "CHECK_FAILED", fingerprint, { verdict: "UNKNOWN", reason: error.message });
    console.error("COMPATIBILITY_UNKNOWN: " + error.message);
    return 78;
  }
  for (const warning of warnings) {
    auditEvent(stateDir, "SOFT_WARNING", fingerprint, { verdict: "PASS", reason: warning });
    console.error("COMPATIBILITY_SOFT_WARNING: " + warning);
  }
  const next = cache.entries.filter((item) => item.key !== fingerprint.key);
  next.unshift({
    key: fingerprint.key,
    cli: fingerprint.cli,
    policySha256: fingerprint.policy.sha256,
    host: fingerprint.host,
    warnings,
    verdict: "PASS",
    approvedAt: new Date().toISOString(),
    lastUsedAt: new Date().toISOString()
  });
  writeCacheAtomic(stateDir, { schema: CACHE_SCHEMA, entries: next.slice(0, MAX_CACHE_ENTRIES) });
  auditEvent(stateDir, "CHECK_PASSED", fingerprint, { verdict: "PASS", reason: warnings.length ? warnings.length + " soft warning(s)" : null });
  console.error("COMPATIBILITY_CHECK_PASS " + fingerprint.key);
  console.log(fingerprint.cli.realpath);
  return 0;
}

function runWithLock(action, projectRoot) {
  const stateDir = ensureStateDirectory(getStateDirectory());
  const lockFile = path.join(stateDir, "compatibility.lock");
  const flock = (() => { try { return resolveExecutable("flock").realpath; } catch { return null; } })();
  if (flock) {
    const fd = fs.openSync(lockFile, fs.constants.O_CREAT | fs.constants.O_RDWR | (fs.constants.O_NOFOLLOW || 0), 0o600);
    fs.closeSync(fd);
    validateStateFile(lockFile);
    const result = spawnSync(flock, ["-x", "-w", "10", lockFile, process.execPath, SCRIPT_PATH, "--locked", action, projectRoot], {
      encoding: "utf8",
      timeout: 17 * 60 * 1000 + 15000,
      maxBuffer: 8 * 1024 * 1024,
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, SAFE_AGY_INFRA_DIR: INFRA_DIR, CI: "true" }
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) return result.error.code === "ETIMEDOUT" ? 78 : 3;
    return result.status ?? 3;
  }
  const lockDir = path.join(stateDir, "compatibility.lock.d");
  const deadline = Date.now() + 10000;
  const waitCell = new Int32Array(new SharedArrayBuffer(4));
  for (;;) {
    try {
      fs.mkdirSync(lockDir, { mode: 0o700 });
      break;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      if (Date.now() >= deadline) fail("Compatibility lock is held or stale; inspect " + lockDir, 78);
      Atomics.wait(waitCell, 0, 0, 100);
    }
  }
  const owner = path.join(lockDir, "owner.json");
  const token = crypto.randomBytes(16).toString("hex");
  try {
    fs.writeFileSync(owner, JSON.stringify({ pid: process.pid, token, at: new Date().toISOString() }) + "\n", { flag: "wx", mode: 0o600 });
  } catch (error) {
    try { fs.rmdirSync(lockDir); } catch { /* leave a visible stale lock if cleanup is unsafe */ }
    throw error;
  }
  const cleanup = () => {
    try {
      const record = JSON.parse(fs.readFileSync(owner, "utf8"));
      if (record.pid === process.pid && record.token === token) {
        validateStateFile(owner);
        fs.unlinkSync(owner);
        fs.rmdirSync(lockDir);
      }
    } catch { /* best-effort cleanup; stale locks fail closed */ }
  };
  const onSignal = (signal) => {
    cleanup();
    process.exit(signal === "SIGINT" ? 130 : 143);
  };
  process.once("exit", cleanup);
  process.once("SIGINT", onSignal);
  process.once("SIGTERM", onSignal);
  try { return runLocked(action, projectRoot); }
  finally {
    cleanup();
    process.removeListener("exit", cleanup);
    process.removeListener("SIGINT", onSignal);
    process.removeListener("SIGTERM", onSignal);
  }
}

export function status(projectRoot) {
  const stateDir = getStateDirectory();
  assertNoSymlinkComponents(path.dirname(stateDir));
  const fingerprint = buildFingerprint(projectRoot, INFRA_DIR);
  let cache = { schema: CACHE_SCHEMA, entries: [] };
  if (fs.existsSync(stateDir)) {
    ensureStateDirectory(stateDir);
    cache = readCache(stateDir);
  }
  const entry = findCacheEntry(cache, fingerprint);
  const result = {
    status: entry ? "PASS" : "NOT_APPROVED",
    version: fingerprint.cli.version,
    executable: fingerprint.cli.realpath,
    executableSha256: fingerprint.cli.sha256,
    buildId: fingerprint.cli.elf.buildId,
    policySha256: fingerprint.policy.sha256,
    compatibilityKey: fingerprint.key,
    cacheEntries: cache.entries.length,
    warnings: entry?.warnings || [],
    diffSummary: entry ? "Current fingerprint matches an approved cache entry." : diffSummary(cache, fingerprint),
    stateDirectory: stateDir
  };
  console.log(JSON.stringify(result, null, 2));
  return entry ? 0 : 1;
}

function main(args) {
  const action = args[0] || "--help";
  if (action === "--help" || action === "-h") {
    console.log("Usage: compatibility.mjs --status [project-root] | --check [project-root] | --ensure <project-root> | --capture <project-root> <agy args...> | --exec <project-root> <agy args...>");
    return 0;
  }
  if (action === "--locked") return runLocked(args[1], args[2]);
  const projectRoot = path.resolve(args[1] || process.env.SAFE_AGY_PROJECT_ROOT || INFRA_DIR);
  if (action === "--status") return status(projectRoot);
  if (action === "--check") return runWithLock("check", projectRoot);
  if (action === "--ensure") return runWithLock("ensure", projectRoot);
  if (action === "--capture") return executeCached(projectRoot, args.slice(2), true);
  if (action === "--exec") return executeCached(projectRoot, args.slice(2), false);
  fail("Unknown compatibility action: " + action, 64);
}

if (process.argv[1] && path.resolve(process.argv[1]) === SCRIPT_PATH) {
  try { process.exitCode = main(process.argv.slice(2)); }
  catch (error) {
    console.error("SAFE_AGY_COMPATIBILITY_UNKNOWN: " + error.message);
    process.exitCode = error.exitCode || 78;
  }
}

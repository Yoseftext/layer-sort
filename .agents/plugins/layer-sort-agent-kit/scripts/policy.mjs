import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const ALLOWED_TOOLS = new Set([
  "view_file", "read_file", "list_dir", "find_by_name", "grep_search", "run_command",
  "manage_task", "search_web", "invoke_subagent", "send_message",
  "manage_subagents", "ask_question"
]);

const BLOCKED_WRITE_TOOLS = new Set([
  "write_file", "edit_file", "write_to_file", "replace_file_content",
  "multi_replace_file_content", "apply_patch", "create_file", "delete_file",
  "remove_file", "move_file", "copy_file", "rename_file", "append_file",
  "create_directory", "make_directory", "write_pdf"
]);

// Only these content-writing tools may write, and only into a verified nested Git Worktree.
const WORKTREE_WRITE_PATH_FIELDS = Object.freeze({
  write_file: "Path"
});

const READ_PATH_FIELDS = Object.freeze({
  view_file: "AbsolutePath",
  read_file: "Path",
  list_dir: "DirectoryPath",
  find_by_name: "SearchDirectory",
  grep_search: "SearchPath"
});

const SENSITIVE_PATH =
  /(^|\/)(?:\.env(?:\.[^/]*)?|\.ssh|\.git|secrets?(?:\.[^/]*)?|credentials?(?:\.[^/]*)?|id_rsa(?:\.pub)?|id_ed25519(?:\.pub)?)(?:\/|$)|\.(?:jks|keystore|pem|key)$/i;
const WORKTREE_PROTECTED_PATH = /(^|\/)\.agents(?:\/|$)/i;

const SHELL_META = /[;&|><$(){}\[\]\r\n\\'"!#*?~]/;
const PROJECT_ROOT = "/root/projects/layer-sort";
const WORKTREE_BASE = path.join(PROJECT_ROOT, ".worktrees");

// Maintainer-owned task registry. Keys are exact Worktree directory names.
// "files" contains exact POSIX paths relative to that Worktree; no globs or directories.
// Keep the infrastructure Worktree empty: policy/configuration work is maintainer-only.
const WORKTREE_TASK_WRITE_ALLOWLISTS = Object.freeze({
  "agent-system-access": Object.freeze({
    taskId: "AGENT-SYSTEM-ACCESS",
    files: Object.freeze([])
  })
});

const MAX_COMMAND_LENGTH = 2048;
const MAX_COMMAND_TOKENS = 64;

function allow() {
  return { decision: "allow" };
}

function deny(reason) {
  return { decision: "deny", reason };
}

function canonicalPath(candidate) {
  let current = path.resolve(candidate);
  const suffix = [];
  for (;;) {
    try {
      const real = fs.realpathSync.native(current);
      return path.join(real, ...suffix.reverse());
    } catch {
      const parent = path.dirname(current);
      if (parent === current) return path.resolve(candidate);
      suffix.push(path.basename(current));
      current = parent;
    }
  }
}

function isWithin(candidate, roots) {
  const resolved = canonicalPath(candidate);
  return roots.some((root) => {
    const base = canonicalPath(root);
    return resolved === base || resolved.startsWith(base + path.sep);
  });
}

function basename(value) {
  return path.posix.basename(value.replaceAll("\\", "/")).toLowerCase();
}

function getWorkspaceRoots(payload) {
  if (!Array.isArray(payload?.workspacePaths)) return [];
  const expectedRoot = canonicalPath(PROJECT_ROOT);
  const includesProjectRoot = payload.workspacePaths.some(
    (item) =>
      typeof item === "string" &&
      path.isAbsolute(item) &&
      canonicalPath(item) === expectedRoot
  );
  if (includesProjectRoot) return [PROJECT_ROOT];

  const registeredWorkspaceRoots = new Set();
  for (const item of payload.workspacePaths) {
    if (typeof item !== "string" || !path.isAbsolute(item)) continue;
    const resolved = path.resolve(item);
    const canonical = canonicalPath(resolved);
    if (resolved !== canonical) continue;

    const worktreeRoot = getRegisteredWorktreeRoot(canonical);
    if (worktreeRoot && canonicalPath(worktreeRoot) === canonical) {
      registeredWorkspaceRoots.add(worktreeRoot);
    }
  }

  return registeredWorkspaceRoots.size === 1 ? [...registeredWorkspaceRoots] : [];
}

function isRegisteredGitWorktree(worktreeRoot) {
  try {
    const absoluteRoot = path.resolve(worktreeRoot);
    if (canonicalPath(absoluteRoot) !== absoluteRoot) return false;

    const rootStat = fs.lstatSync(absoluteRoot);
    if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) return false;

    const marker = path.join(absoluteRoot, ".git");
    const markerStat = fs.lstatSync(marker);
    if (!markerStat.isFile() || markerStat.isSymbolicLink()) return false;

    const markerMatch = /^gitdir:\s*(.+)$/i.exec(fs.readFileSync(marker, "utf8").trim());
    if (!markerMatch) return false;

    const adminRoot = canonicalPath(path.join(PROJECT_ROOT, ".git", "worktrees"));
    const adminDir = canonicalPath(path.resolve(absoluteRoot, markerMatch[1]));
    if (path.dirname(adminDir) !== adminRoot) return false;

    const adminStat = fs.lstatSync(adminDir);
    if (!adminStat.isDirectory() || adminStat.isSymbolicLink()) return false;

    const commonDirFile = path.join(adminDir, "commondir");
    const backlinkFile = path.join(adminDir, "gitdir");
    const commonDirStat = fs.lstatSync(commonDirFile);
    const backlinkStat = fs.lstatSync(backlinkFile);
    if (
      !commonDirStat.isFile() ||
      commonDirStat.isSymbolicLink() ||
      !backlinkStat.isFile() ||
      backlinkStat.isSymbolicLink()
    ) {
      return false;
    }

    const commonDirText = fs.readFileSync(commonDirFile, "utf8").trim();
    const backlinkText = fs.readFileSync(backlinkFile, "utf8").trim();
    if (!commonDirText || !backlinkText) return false;

    const expectedCommon = canonicalPath(path.join(PROJECT_ROOT, ".git"));
    const actualCommon = canonicalPath(path.resolve(adminDir, commonDirText));
    if (actualCommon !== expectedCommon) return false;

    const actualBacklink = canonicalPath(path.resolve(adminDir, backlinkText));
    return actualBacklink === canonicalPath(marker);
  } catch {
    return false;
  }
}

function getRegisteredWorktreeRoot(candidate) {
  const expectedBase = path.resolve(WORKTREE_BASE);
  if (!fs.existsSync(expectedBase) || canonicalPath(expectedBase) !== expectedBase) {
    return null;
  }

  const canonicalCandidate = canonicalPath(candidate);
  if (!isWithin(canonicalCandidate, [expectedBase])) return null;

  const relative = path.relative(expectedBase, canonicalCandidate);
  const segments = relative.split(path.sep).filter(Boolean);
  if (segments.length < 1) return null;

  const worktreeRoot = path.join(expectedBase, segments[0]);
  if (!isRegisteredGitWorktree(worktreeRoot)) return null;
  return isWithin(canonicalCandidate, [worktreeRoot]) ? worktreeRoot : null;
}

function getActiveWorktreeRoot(payload) {
  const workspacePaths = payload?.workspacePaths;
  if (!Array.isArray(workspacePaths) || workspacePaths.length !== 1) return null;

  const [workspacePath] = workspacePaths;
  if (typeof workspacePath !== "string" || !path.isAbsolute(workspacePath)) return null;

  const resolvedWorkspace = path.resolve(workspacePath);
  if (workspacePath !== resolvedWorkspace || canonicalPath(resolvedWorkspace) !== resolvedWorkspace) {
    return null;
  }

  const registeredRoot = getRegisteredWorktreeRoot(resolvedWorkspace);
  return registeredRoot === resolvedWorkspace ? registeredRoot : null;
}

function hasControlCharacters(value) {
  for (const character of value) {
    const codePoint = character.charCodeAt(0);
    if (codePoint <= 0x1f || codePoint === 0x7f) return true;
  }
  return false;
}

function isSafeTaskRelativeFile(candidate) {
  if (
    typeof candidate !== "string" ||
    candidate.length === 0 ||
    candidate.startsWith("/") ||
    candidate.endsWith("/") ||
    candidate.includes("\\") ||
    hasControlCharacters(candidate) ||
    ["*", "?", "[", "]", "{", "}"].some((character) => candidate.includes(character)) ||
    path.posix.normalize(candidate) !== candidate
  ) {
    return false;
  }

  const segments = candidate.split("/");
  if (segments.some((segment) => !segment || segment === "." || segment === "..")) {
    return false;
  }
  if (segments.some((segment) => [".git", ".agents"].includes(segment.toLowerCase()))) {
    return false;
  }
  return !SENSITIVE_PATH.test(candidate) && !WORKTREE_PROTECTED_PATH.test(candidate);
}

function getTaskWritePolicy(worktreeRoot, taskWriteAllowlists) {
  if (
    !taskWriteAllowlists ||
    typeof taskWriteAllowlists !== "object" ||
    Array.isArray(taskWriteAllowlists)
  ) {
    return null;
  }

  const worktreeKey = path.relative(WORKTREE_BASE, worktreeRoot).split(path.sep).join("/");
  if (!worktreeKey || worktreeKey.includes("/") || !Object.hasOwn(taskWriteAllowlists, worktreeKey)) {
    return null;
  }

  const taskPolicy = taskWriteAllowlists[worktreeKey];
  if (
    !taskPolicy ||
    typeof taskPolicy.taskId !== "string" ||
    !/^[A-Z0-9][A-Z0-9-]{2,63}$/.test(taskPolicy.taskId) ||
    !Array.isArray(taskPolicy.files) ||
    new Set(taskPolicy.files).size !== taskPolicy.files.length ||
    taskPolicy.files.some((candidate) => !isSafeTaskRelativeFile(candidate))
  ) {
    return null;
  }

  return taskPolicy;
}

function evaluateWorktreeWriteTool(toolName, payload, taskWriteAllowlists) {
  const field = WORKTREE_WRITE_PATH_FIELDS[toolName];
  if (!field) return null;

  const worktreeRoot = getActiveWorktreeRoot(payload);
  if (!worktreeRoot) {
    return deny("Writes require exactly one active workspace that is the registered Git Worktree root.");
  }

  const args = payload?.toolCall?.args ?? {};
  const candidate = args[field];
  if (typeof candidate !== "string" || candidate.length === 0) {
    return deny("Worktree write tools require an absolute Path argument.");
  }

  const normalized = candidate;
  const segments = normalized.split("/");
  if (
    !path.isAbsolute(normalized) ||
    normalized.includes("\\") ||
    hasControlCharacters(normalized) ||
    segments.slice(1).some((segment) => !segment || segment === "." || segment === "..") ||
    SENSITIVE_PATH.test(normalized) ||
    WORKTREE_PROTECTED_PATH.test(normalized)
  ) {
    return deny("Worktree write paths must be absolute, normalized, traversal-free, and non-sensitive.");
  }

  const lexicalCandidate = path.resolve(normalized);
  const canonicalCandidate = canonicalPath(lexicalCandidate);
  if (canonicalCandidate !== lexicalCandidate) {
    return deny("Symlink traversal is not permitted for Worktree writes.");
  }

  const canonicalForPolicy = canonicalCandidate.replaceAll("\\", "/");
  if (
    SENSITIVE_PATH.test(canonicalForPolicy) ||
    WORKTREE_PROTECTED_PATH.test(canonicalForPolicy)
  ) {
    return deny("Writes to Git metadata, agent configuration, secrets, and signing material are blocked.");
  }

  const targetWorktreeRoot = getRegisteredWorktreeRoot(canonicalCandidate);
  if (
    targetWorktreeRoot !== worktreeRoot ||
    !isWithin(canonicalCandidate, [worktreeRoot])
  ) {
    return deny("Write targets must remain inside the exact active registered Git Worktree.");
  }

  const relative = path.relative(worktreeRoot, canonicalCandidate);
  if (!relative || relative === "." || relative.split(path.sep).includes("..")) {
    return deny("A Worktree write must target a file below the Worktree root.");
  }

  const taskPolicy = getTaskWritePolicy(worktreeRoot, taskWriteAllowlists);
  if (!taskPolicy) {
    return deny("No valid maintainer-owned task write allowlist is registered for this Worktree.");
  }
  if (taskPolicy.files.length === 0) {
    return deny("The active task has an empty write allowlist; all file writes are denied.");
  }

  const relativePosix = relative.split(path.sep).join("/");
  if (!taskPolicy.files.includes(relativePosix)) {
    return deny("Write target '" + relativePosix + "' is not explicitly allowlisted for task " + taskPolicy.taskId + ".");
  }

  const parentPath = path.dirname(canonicalCandidate);
  if (canonicalPath(parentPath) !== parentPath) {
    return deny("Symlink traversal in the target parent path is not permitted.");
  }
  try {
    if (!fs.statSync(parentPath).isDirectory()) {
      return deny("The parent path for a Worktree write must be an existing directory.");
    }
  } catch {
    return deny("The parent directory for a Worktree write must already exist.");
  }

  try {
    const targetStat = fs.lstatSync(canonicalCandidate);
    if (!targetStat.isFile() || targetStat.isSymbolicLink() || targetStat.nlink > 1) {
      return deny("Worktree write targets must be regular files without symlink or hard-link aliases.");
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      return deny("The Worktree write target could not be safely inspected.");
    }
  }

  return allow();
}

function validatePath(candidate, cwd, roots) {
  if (typeof candidate !== "string" || candidate.length === 0) {
    return deny("A non-empty path is required.");
  }

  const normalized = candidate.replaceAll("\\", "/");
  if (
    normalized === "-" ||
    normalized.startsWith("-") ||
    normalized.includes("\0") ||
    SENSITIVE_PATH.test(normalized)
  ) {
    return deny("This path is not permitted.");
  }

  const resolved = path.isAbsolute(candidate)
    ? candidate
    : path.resolve(cwd, candidate);

  if (!isWithin(resolved, roots)) {
    return deny("Path arguments must remain inside the active workspace.");
  }

  if (SENSITIVE_PATH.test(canonicalPath(resolved).replaceAll("\\", "/"))) {
    return deny("Access to secret, signing, Git metadata, and environment files is blocked.");
  }

  return null;
}

function validateExistingPath(candidate, cwd, roots, expectedType = "any") {
  const pathDecision = validatePath(candidate, cwd, roots);
  if (pathDecision) return pathDecision;

  const resolved = path.isAbsolute(candidate)
    ? candidate
    : path.resolve(cwd, candidate);

  try {
    const stat = fs.statSync(canonicalPath(resolved));
    if (expectedType === "file" && !stat.isFile()) {
      return deny("This command accepts regular files only.");
    }
    if (expectedType === "directory" && !stat.isDirectory()) {
      return deny("This command requires a directory path.");
    }
  } catch {
    return deny("The requested path must exist inside the active workspace.");
  }

  return null;
}

function validatePathList(paths, cwd, roots, expectedType = "any") {
  if (paths.length === 0) return deny("At least one workspace path is required.");
  for (const candidate of paths) {
    const decision = validateExistingPath(candidate, cwd, roots, expectedType);
    if (decision) return decision;
  }
  return allow();
}

function evaluateReadPathTool(toolName, payload) {
  const field = READ_PATH_FIELDS[toolName];
  if (!field) return null;

  const args = payload?.toolCall?.args ?? {};
  const candidate = args[field];
  const roots = getWorkspaceRoots(payload);

  if (
    typeof candidate !== "string" ||
    !path.isAbsolute(candidate) ||
    roots.length === 0
  ) {
    return deny("File inspection requires an absolute path inside the active workspace.");
  }

  return validatePath(candidate, roots[0], roots);
}

function evaluateSimpleRead(executable, args, cwd, roots) {
  if (executable === "pwd") {
    return args.length === 0 ? allow() : deny("pwd does not accept arguments.");
  }

  const flags = {
    ls: new Set([
      "-l", "-a", "-la", "-al", "-1",
      "--all", "--almost-all", "--directory", "--classify", "--color=never"
    ]),
    stat: new Set(),
    file: new Set(["-b", "--brief", "--mime-type", "--mime-encoding"]),
    sha256sum: new Set(),
    cat: new Set([
      "-n", "--number", "-b", "--number-nonblank",
      "-s", "--squeeze-blank", "-T", "--show-tabs", "-A", "--show-all"
    ]),
    head: new Set(["-q", "--quiet", "-v", "--verbose"]),
    tail: new Set(["-q", "--quiet", "-v", "--verbose"])
  };

  const valueFlags = {
    head: new Set(["-n", "--lines", "-c", "--bytes"]),
    tail: new Set(["-n", "--lines", "-c", "--bytes"])
  };

  const paths = [];
  const allowedFlags = flags[executable];
  const withValue = valueFlags[executable] ?? new Set();
  let index = 0;

  while (index < args.length) {
    const token = args[index];

    if (token === "--") {
      paths.push(...args.slice(index + 1));
      break;
    }

    if (token.startsWith("-")) {
      if (withValue.has(token)) {
        const value = args[index + 1] ?? "";
        if (!/^[1-9][0-9]{0,6}$/.test(value) || Number(value) > 1000000) {
          return deny("Numeric read-command options must be bounded positive integers.");
        }
        index += 2;
        continue;
      }
      if (!allowedFlags.has(token)) {
        return deny("Option '" + token + "' is not allowed for " + executable + ".");
      }
      index += 1;
      continue;
    }

    paths.push(token);
    index += 1;
  }

  if (executable === "ls" && paths.length === 0) return allow();
  return validatePathList(
    paths,
    cwd,
    roots,
    ["cat", "head", "tail", "file", "sha256sum"].includes(executable) ? "file" : "any"
  );
}

function evaluateRg(args, cwd, roots) {
  const flags = new Set([
    "-n", "--line-number", "-i", "--ignore-case", "-F", "--fixed-strings",
    "-S", "--smart-case", "-l", "--files-with-matches", "-c", "--count",
    "--no-heading", "--no-messages", "--color=never", "--files"
  ]);

  let pattern = null;
  let listFiles = false;
  let afterSeparator = false;
  const paths = [];

  for (const token of args) {
    if (!afterSeparator && token === "--") {
      afterSeparator = true;
      continue;
    }
    if (!afterSeparator && token.startsWith("-")) {
      if (!flags.has(token)) return deny("ripgrep option '" + token + "' is not allowlisted.");
      if (token === "--files") {
        if (pattern !== null) return deny("rg --files cannot be combined with a search pattern.");
        listFiles = true;
      }
      continue;
    }
    if (listFiles) paths.push(token);
    else if (pattern === null) pattern = token;
    else paths.push(token);
  }

  if (!listFiles && (pattern === null || pattern.length === 0)) {
    return deny("rg requires a literal search pattern.");
  }
  if (listFiles && pattern !== null) {
    return deny("rg --files cannot be combined with a search pattern.");
  }
  return validatePathList(paths, cwd, roots, listFiles ? "any" : "file");
}

function evaluateGrep(args, cwd, roots) {
  const flags = new Set([
    "-n", "--line-number", "-i", "--ignore-case", "-F", "--fixed-strings",
    "-H", "--with-filename", "-h", "--no-filename",
    "-l", "--files-with-matches", "-c", "--count"
  ]);

  let pattern = null;
  let afterSeparator = false;
  const paths = [];

  for (const token of args) {
    if (!afterSeparator && token === "--") {
      afterSeparator = true;
      continue;
    }
    if (!afterSeparator && token.startsWith("-")) {
      if (!flags.has(token)) return deny("grep option '" + token + "' is not allowlisted.");
      continue;
    }
    if (pattern === null) pattern = token;
    else paths.push(token);
  }

  if (pattern === null || pattern.length === 0) {
    return deny("grep requires a literal search pattern.");
  }
  return validatePathList(paths, cwd, roots, "file");
}

function evaluateSed(args, cwd, roots) {
  let quiet = false;
  let script = null;
  let afterSeparator = false;
  const files = [];

  for (let index = 0; index < args.length; index += 1) {
    const token = args[index];

    if (!afterSeparator && token === "--") {
      afterSeparator = true;
      continue;
    }
    if (!afterSeparator && (token === "-n" || token === "--quiet" || token === "--silent")) {
      quiet = true;
      continue;
    }
    if (!afterSeparator && token === "-e") {
      if (script !== null || index + 1 >= args.length) {
        return deny("sed accepts exactly one inline print-only expression.");
      }
      script = args[index + 1];
      index += 1;
      continue;
    }
    if (!afterSeparator && token.startsWith("-")) {
      return deny("sed option '" + token + "' is not allowed.");
    }
    if (script === null) script = token;
    else files.push(token);
  }

  if (!quiet || script === null || !/^(?:[0-9]+|\$)(?:,(?:[0-9]+|\$))?p$/.test(script)) {
    return deny("sed is limited to -n with a single numeric print-only expression; w/e and in-place commands are blocked.");
  }
  return validatePathList(files, cwd, roots, "file");
}

function evaluateFind(args, cwd, roots) {
  if (args.length === 0 || args[0].startsWith("-")) {
    return deny("find requires an explicit workspace start path.");
  }

  const startDecision = validateExistingPath(args[0], cwd, roots);
  if (startDecision) return startDecision;

  for (let index = 1; index < args.length; index += 1) {
    const token = args[index];

    if (token === "-print" || token === "-print0" || token === "-prune") continue;

    if (token === "-maxdepth" || token === "-mindepth") {
      const value = args[index + 1] ?? "";
      if (!/^(0|[1-9][0-9]?)$/.test(value) || Number(value) > 12) {
        return deny("find depth must be an integer between 0 and 12.");
      }
      index += 1;
      continue;
    }

    if (token === "-type") {
      const value = args[index + 1] ?? "";
      if (!["f", "d", "l"].includes(value)) return deny("find -type is limited to f, d, or l.");
      index += 1;
      continue;
    }

    if (token === "-name" || token === "-iname") {
      const value = args[index + 1] ?? "";
      if (!value || value.startsWith("-") || value.includes("/") || value.includes("\\")) {
        return deny("find name predicates must be simple filename literals.");
      }
      index += 1;
      continue;
    }

    return deny("find expression '" + token + "' is not allowlisted.");
  }

  return allow();
}

function evaluateJq(args, cwd, roots) {
  const flags = new Set([
    "-r", "--raw-output", "-c", "--compact-output",
    "-e", "--exit-status", "-M", "--monochrome-output"
  ]);

  let filter = null;
  let afterSeparator = false;
  const files = [];

  for (const token of args) {
    if (!afterSeparator && token === "--") {
      afterSeparator = true;
      continue;
    }
    if (!afterSeparator && token.startsWith("-")) {
      if (!flags.has(token)) return deny("jq option '" + token + "' is not allowlisted.");
      continue;
    }
    if (filter === null) filter = token;
    else files.push(token);
  }

  if (
    filter === null ||
    !/^(?:\.|[A-Za-z_][A-Za-z0-9_]*|\.[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)$/.test(filter)
  ) {
    return deny("jq is limited to simple property-selection filters.");
  }
  return validatePathList(files, cwd, roots, "file");
}

function isSafeRevision(token) {
  return token === "HEAD" || /^[0-9a-f]{7,40}$/i.test(token);
}

function evaluateGit(args, cwd, roots) {
  const subcommand = args[0] ?? "";
  const rest = args.slice(1);

  if (
    !subcommand ||
    subcommand.startsWith("-") ||
    rest.some((token) =>
      token === "--output" || token.startsWith("--output=") ||
      token === "-o" || token.startsWith("-o=")
    )
  ) {
    return deny("Git global options and output-file redirection are not permitted.");
  }

  const separatorIndex = rest.indexOf("--");
  const beforeSeparator = separatorIndex < 0 ? rest : rest.slice(0, separatorIndex);
  const pathspecs = separatorIndex < 0 ? [] : rest.slice(separatorIndex + 1);
  const validatePathspecs = () =>
    pathspecs.length === 0 ? null : validatePathList(pathspecs, cwd, roots);

  if (subcommand === "status") {
    const allowed = new Set([
      "--short", "--branch", "--porcelain", "--porcelain=v1",
      "--untracked-files=no", "--untracked-files=normal",
      "--untracked-files=all", "--ignored=no"
    ]);
    if (beforeSeparator.some((token) => !allowed.has(token))) {
      return deny("git status accepts only explicitly allowlisted read-only flags.");
    }
    return validatePathspecs() ?? allow();
  }

  if (subcommand === "diff") {
    const allowed = new Set([
      "--check", "--stat", "--name-only", "--name-status",
      "--cached", "--no-ext-diff", "--no-color", "--color=never", "--no-renames"
    ]);
    if (beforeSeparator.some((token) => !allowed.has(token))) {
      return deny("git diff option is not allowlisted; patch output and --output are blocked.");
    }
    if (!beforeSeparator.some((token) =>
      ["--check", "--stat", "--name-only", "--name-status"].includes(token)
    )) {
      return deny("git diff is limited to --check, --stat, and filename-only output.");
    }
    return validatePathspecs() ?? allow();
  }

  if (subcommand === "log" || subcommand === "show") {
    const allowed = new Set([
      "--oneline", "--decorate", "--no-decorate", "--date=short", "--date=iso",
      "--stat", "--name-only", "--name-status", "--no-patch", "--no-color",
      "--format=%h", "--format=%s", "--format=%h-%s", "--pretty=oneline"
    ]);
    for (const token of beforeSeparator) {
      if (allowed.has(token) || /^-[1-9][0-9]?$/.test(token)) continue;
      if (!isSafeRevision(token)) {
        return deny("Git revision arguments must be HEAD or a hexadecimal commit ID.");
      }
    }
    const metadataOnly = beforeSeparator.some((token) =>
      [
        "--oneline", "--stat", "--name-only", "--name-status", "--no-patch",
        "--format=%h", "--format=%s", "--format=%h-%s", "--pretty=oneline"
      ].includes(token)
    );
    if (!metadataOnly) {
      return deny("git " + subcommand + " is limited to commit metadata; file-content output is blocked.");
    }
    return validatePathspecs() ?? allow();
  }

  if (subcommand === "rev-parse") {
    const allowed = new Set([
      "--show-toplevel", "--show-prefix", "--is-inside-work-tree", "--verify"
    ]);
    if (beforeSeparator.some((token) => !allowed.has(token) && !isSafeRevision(token))) {
      return deny("git rev-parse accepts only repository metadata and HEAD/object IDs.");
    }
    return allow();
  }

  if (subcommand === "ls-files") {
    const allowed = new Set([
      "--cached", "--others", "--exclude-standard",
      "--stage", "--full-name", "--error-unmatch"
    ]);
    if (beforeSeparator.some((token) => !allowed.has(token))) {
      return deny("git ls-files option is not allowlisted.");
    }
    return validatePathspecs() ?? allow();
  }

  if (subcommand === "diff-tree") {
    const allowed = new Set([
      "--no-commit-id", "--name-only", "--name-status", "-r", "--root", "--no-renames"
    ]);
    if (beforeSeparator.some((token) => !allowed.has(token) && !isSafeRevision(token))) {
      return deny("git diff-tree accepts only filename metadata and safe commit IDs.");
    }
    if (!beforeSeparator.some((token) => ["--name-only", "--name-status"].includes(token))) {
      return deny("git diff-tree must use filename-only output.");
    }
    return validatePathspecs() ?? allow();
  }

  if (subcommand === "cat-file") {
    if (
      beforeSeparator.length !== 2 ||
      !["-t", "-s"].includes(beforeSeparator[0]) ||
      !isSafeRevision(beforeSeparator[1])
    ) {
      return deny("git cat-file is limited to object type/size metadata; object contents are blocked.");
    }
    return allow();
  }

  if (subcommand === "branch") {
    return rest.length === 1 && ["--show-current", "-vv"].includes(rest[0])
      ? allow()
      : deny("Only git branch --show-current and git branch -vv are permitted.");
  }

  return deny("Git operation '" + subcommand + "' is not on the read-only allowlist.");
}

function evaluateAgy(tokens, cwd, roots) {
  if (tokens.length === 2 && ["--version", "--help"].includes(tokens[1])) return allow();
  if (tokens.length === 2 && ["agents", "models"].includes(tokens[1])) return allow();
  if (tokens.length === 3 && tokens[1] === "plugin" && tokens[2] === "list") return allow();

  if (tokens[1] === "plugin" && tokens[2] === "validate") {
    const paths = [];
    for (const token of tokens.slice(3)) {
      if (token === "--strict") continue;
      if (token.startsWith("-")) return deny("agy plugin validate option is not allowlisted.");
      paths.push(token);
    }
    if (paths.length !== 1) return deny("agy plugin validate requires exactly one plugin path.");
    const decision = validateExistingPath(paths[0], cwd, roots, "directory");
    if (decision) return decision;
    return allow();
  }

  return deny("Agent commands may inspect the CLI but may not alter plugin or agent configuration.");
}

function evaluateGodot(tokens, roots) {
  let headless = false;
  let projectPath = null;
  let script = null;

  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index];

    if (token === "--headless" || token === "--quit") {
      if (token === "--headless") headless = true;
      continue;
    }

    if (token === "--path" || token === "--script") {
      const value = tokens[index + 1] ?? "";
      if (!value || value.startsWith("-")) return deny("Godot option requires a valid value.");
      if (token === "--path") projectPath = value;
      else script = value;
      index += 1;
      continue;
    }

    return deny("Godot option '" + token + "' is not allowlisted.");
  }

  if (!headless || projectPath !== "." || !script || !script.startsWith("res://tests/")) {
    return deny("Godot is limited to existing headless scripts under res://tests/.");
  }

  const scriptPath = path.resolve(roots[0], script.slice("res://".length));
  const testsRoot = path.resolve(roots[0], "tests");
  if (!isWithin(scriptPath, [testsRoot]) || !fs.existsSync(scriptPath)) {
    return deny("Godot test scripts must exist under the workspace tests directory.");
  }

  try {
    if (!fs.statSync(scriptPath).isFile()) return deny("Godot test target must be a regular file.");
  } catch {
    return deny("Godot test target could not be verified.");
  }

  return allow();
}

function isApprovedAgentctlExecutable(token, cwd, workspaceRoot) {
  const expected = path.resolve(workspaceRoot, "tools/device-tests/agentctl");
  const expectedRelative = "tools/device-tests/agentctl";
  if (token !== expectedRelative && token !== expected) return false;

  const actual = path.isAbsolute(token) ? path.resolve(token) : path.resolve(cwd, token);
  if (actual !== expected || canonicalPath(actual) !== expected) return false;

  try {
    const stat = fs.lstatSync(actual);
    return stat.isFile() && !stat.isSymbolicLink() && stat.nlink === 1 && (stat.mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

function evaluateRunCommand(payload) {
  const args = payload?.toolCall?.args ?? {};
  const command = args.CommandLine;

  if (typeof command !== "string" || command.trim().length === 0) {
    return deny("Missing CommandLine; command execution is denied.");
  }
  if (command.length > MAX_COMMAND_LENGTH) return deny("Command exceeds the policy length limit.");
  if (SHELL_META.test(command) || command.includes(String.fromCharCode(96))) {
    return deny("Shell chaining, substitution, globbing, redirection, quoting, and comments are disabled.");
  }

  const roots = getWorkspaceRoots(payload);
  if (roots.length === 0) return deny("Workspace root is missing; command cannot be constrained.");

  const cwd = args.Cwd ?? roots[0];
  if (typeof cwd !== "string" || !path.isAbsolute(cwd) || !isWithin(cwd, roots)) {
    return deny("Command working directory must remain inside the active workspace.");
  }

  const tokens = command.trim().split(/\s+/).filter(Boolean);
  if (tokens.length === 0 || tokens.length > MAX_COMMAND_TOKENS) {
    return deny("Command token count is invalid.");
  }

  const executableToken = tokens[0];
  const executable = basename(executableToken);
  if (executableToken !== executable) {
    if (
      executable !== "agentctl" ||
      !isApprovedAgentctlExecutable(executableToken, cwd, roots[0])
    ) {
      return deny("Path-qualified executables are blocked; only the exact project agentctl wrapper may be invoked by path.");
    }
  } else if (executable === "agentctl") {
    return deny("Invoke device QA only through the exact tools/device-tests/agentctl path.");
  }

  const commandArgs = tokens.slice(1);

  const blockedExecutables = new Set([
    "adb", "appium", "phone-queue", "game-test", "phone-connect",
    "pm", "am", "input", "monkey", "logcat", "settings", "supervisorctl",
    "rish", "shizuku", "curl", "wget", "nc", "ncat", "socat", "ssh", "scp",
    "sftp", "rsync", "sudo", "su", "rm", "rmdir", "unlink", "mv", "cp",
    "chmod", "chown", "kill", "pkill", "killall", "mount", "umount",
    "mkfs", "fdisk", "parted", "dd", "apt", "apt-get", "dpkg", "pip",
    "pip3", "npm", "npx", "node", "python", "python3", "perl", "ruby",
    "php", "lua", "busybox", "env", "eval", "sh", "dash", "zsh", "fish"
  ]);
  if (blockedExecutables.has(executable)) {
    return deny("Direct execution of '" + executable + "' is blocked.");
  }

  if (executable === "bash") {
    const expected = "tools/device-tests/test-wrapper.sh";
    const actual = commandArgs[0] ?? "";
    return commandArgs.length === 1 &&
      actual === expected &&
      isWithin(path.resolve(cwd, actual), roots) &&
      fs.existsSync(path.resolve(cwd, actual))
      ? allow()
      : deny("Only the fixed device-wrapper unit-test script may run through Bash.");
  }

  if (executable === "agentctl") {
    const expected = path.resolve(roots[0], "tools/device-tests/agentctl");
    const actual = path.resolve(cwd, tokens[0]);
    const actions = new Set(["status", "battery", "thermal", "performance-check", "screenshot", "logcat"]);
    return actual === expected && commandArgs.length === 1 && actions.has(commandArgs[0])
      ? allow()
      : deny("Only exact read-only actions through tools/device-tests/agentctl are allowed.");
  }

  if (executable === "device_qa.py") {
    return deny("Call the package-scoped tools/device-tests/agentctl wrapper, not its implementation.");
  }

  if (executable === "godot") return evaluateGodot(tokens, roots);
  if (executable === "git") return evaluateGit(commandArgs, cwd, roots);
  if (executable === "agy") return evaluateAgy(tokens, cwd, roots);
  if (executable === "rg") return evaluateRg(commandArgs, cwd, roots);
  if (executable === "grep") return evaluateGrep(commandArgs, cwd, roots);
  if (executable === "sed") return evaluateSed(commandArgs, cwd, roots);
  if (executable === "find") return evaluateFind(commandArgs, cwd, roots);
  if (executable === "jq") return evaluateJq(commandArgs, cwd, roots);

  if (["pwd", "ls", "stat", "file", "sha256sum", "cat", "head", "tail"].includes(executable)) {
    return evaluateSimpleRead(executable, commandArgs, cwd, roots);
  }

  return deny("Command '" + executable + "' is not on the project command allowlist.");
}

export function evaluate(payload, taskWriteAllowlists = WORKTREE_TASK_WRITE_ALLOWLISTS) {
  const toolName = payload?.toolCall?.name;

  if (typeof toolName !== "string" || toolName.length === 0) {
    return deny("Missing tool name; request denied closed.");
  }

  if (/remote[_\s-]*desktop[_\s-]*commander|desktop[_\s-]*commander/i.test(toolName)) {
    return deny("Agents must not inherit or invoke Remote Desktop Commander.");
  }

  const worktreeWriteDecision = evaluateWorktreeWriteTool(toolName, payload, taskWriteAllowlists);
  if (worktreeWriteDecision) return worktreeWriteDecision;

  if (BLOCKED_WRITE_TOOLS.has(toolName)) {
    return deny("Agent file-write tools are disabled until the infrastructure gates are complete.");
  }

  if (!ALLOWED_TOOLS.has(toolName)) {
    return deny("Tool '" + toolName + "' is not explicitly allowlisted; default-deny policy applies.");
  }

  const readPathDecision = evaluateReadPathTool(toolName, payload);
  if (readPathDecision) return readPathDecision;

  if (toolName !== "run_command") return allow();
  return evaluateRunCommand(payload);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const input = fs.readFileSync(0, "utf8");
    if (input.length > 65536) {
      process.stdout.write(JSON.stringify(deny("Policy input exceeded the size limit.")));
    } else {
      process.stdout.write(JSON.stringify(evaluate(JSON.parse(input))));
    }
  } catch {
    process.stdout.write(JSON.stringify(deny("Policy input was invalid; request denied closed.")));
  }
}

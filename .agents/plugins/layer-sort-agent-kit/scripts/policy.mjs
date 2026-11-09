import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const BLOCKED_EXECUTABLES = new Set([
  "adb", "appium", "phone-queue", "game-test", "phone-connect",
  "pm", "am", "input", "monkey", "logcat", "settings", "supervisorctl",
  "rish", "shizuku", "curl", "wget", "nc", "ncat", "socat", "ssh", "scp",
  "sftp", "rsync", "sudo", "su", "rm", "rmdir", "unlink", "mv", "cp",
  "chmod", "chown", "kill", "pkill", "killall", "mount", "umount",
  "mkfs", "fdisk", "parted", "dd", "apt", "apt-get", "dpkg", "pip",
  "pip3", "npm", "npx", "node", "python", "python3", "perl", "ruby",
  "php", "lua", "busybox", "env", "eval", "sh", "dash", "zsh", "fish"
]);

const BLOCKED_WRITE_TOOLS = new Set([
  "write_file", "edit_file", "write_to_file", "replace_file_content",
  "multi_replace_file_content", "apply_patch", "create_file", "delete_file", "remove_file",
  "move_file", "copy_file", "rename_file", "append_file",
  "create_directory", "make_directory", "write_pdf"
]);

const READ_ONLY_COMMANDS = new Set([
  "pwd", "ls", "stat", "file", "sha256sum", "rg", "grep", "find",
  "sed", "head", "tail", "cat", "jq"
]);

const SHELL_META = /[;&|><$(){}\[\]\r\n\\'"]/;
const SENSITIVE_PATH = /(^|\/)(\.env(?:\.[^/]*)?|\.ssh|secrets?|credentials?)(\/|$)|(?:id_rsa|id_ed25519)|\.(?:jks|keystore|pem|key)$/i;

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

function validateArguments(tokens, cwd, roots) {
  for (const token of tokens) {
    if (SENSITIVE_PATH.test(token)) {
      return deny("Access to secret, signing, or environment files is blocked.");
    }
    if (token === ".." || token.startsWith("../") || token.includes("/../")) {
      return deny("Parent-directory traversal is not allowed.");
    }
    if (token.startsWith("-") || token.startsWith("res://")) continue;
    const candidate = token.startsWith("/") ? token : path.resolve(cwd, token);
    if (!isWithin(candidate, roots)) {
      return deny("Path arguments must remain inside the active workspace.");
    }
    if (SENSITIVE_PATH.test(canonicalPath(candidate))) {
      return deny("Access to secret, signing, and environment files is blocked.");
    }
  }
  return null;
}

function evaluateRunCommand(payload) {
  const args = payload?.toolCall?.args ?? {};
  const command = args.CommandLine;
  if (typeof command !== "string" || command.trim().length === 0) {
    return deny("Missing CommandLine; command execution is denied.");
  }
  if (
    SHELL_META.test(command) ||
    command.includes(String.fromCharCode(96)) ||
    command.includes("~") ||
    /[*?]/.test(command)
  ) {
    return deny("Shell chaining, substitution, globbing, redirection, and quoting are disabled.");
  }

  const roots = Array.isArray(payload.workspacePaths)
    ? payload.workspacePaths.filter((item) => typeof item === "string")
    : [];
  if (roots.length === 0) {
    return deny("Workspace root is missing; command cannot be constrained.");
  }

  const cwd = args.Cwd ?? roots[0];
  if (typeof cwd !== "string" || !isWithin(cwd, roots)) {
    return deny("Command working directory must remain inside the active workspace.");
  }

  const tokens = command.trim().split(/\s+/).filter(Boolean);
  const executable = basename(tokens[0]);
  const argumentDecision = validateArguments(tokens.slice(1), cwd, roots);
  if (argumentDecision) return argumentDecision;

  if (executable === "bash") {
    return tokens.length === 2 && tokens[1] === "tools/device-tests/test-wrapper.sh"
      && isWithin(path.resolve(cwd, tokens[1]), roots)
      ? allow()
      : deny("Only the fixed device-wrapper unit-test script may run through Bash.");
  }

  if (tokens[0].includes("/")) {
    const executablePath = path.isAbsolute(tokens[0])
      ? tokens[0]
      : path.resolve(cwd, tokens[0]);
    if (!isWithin(executablePath, roots)) {
      return deny("Executable path must remain inside the active workspace.");
    }
  }

  if (BLOCKED_EXECUTABLES.has(executable)) {
    return deny("Direct execution of '" + executable + "' is blocked.");
  }

  if (executable === "agentctl") {
    const expected = path.resolve(roots[0], "tools/device-tests/agentctl");
    const actual = path.resolve(cwd, tokens[0]);
    const readOnlyActions = new Set(["status", "battery", "thermal", "screenshot", "logcat"]);
    return actual === expected && tokens.length === 2 && readOnlyActions.has(tokens[1])
      ? allow()
      : deny("Only exact read-only actions through tools/device-tests/agentctl are allowed.");
  }

  if (executable === "device_qa.py") {
    return deny("Call the package-scoped tools/device-tests/agentctl wrapper, not its implementation.");
  }

  if (executable === "godot") {
    const index = tokens.indexOf("--script");
    const script = index >= 0 ? tokens[index + 1] : "";
    const scriptPath = script.startsWith("res://")
      ? path.resolve(roots[0], script.slice("res://".length))
      : "";
    const valid = tokens.includes("--headless")
      && tokens.includes("--path")
      && tokens[tokens.indexOf("--path") + 1] === "."
      && script.startsWith("res://tests/")
      && fs.existsSync(scriptPath)
      && isWithin(scriptPath, roots)
      && !tokens.some((token) => token.startsWith("--export"));
    return valid ? allow() : deny("Godot is limited to existing headless scripts under res://tests/.");
  }

  if (executable === "git") {
    const subcommand = tokens[1] ?? "";
    const safe = new Set([
      "status", "diff", "log", "show", "rev-parse", "ls-files",
      "diff-tree", "cat-file", "branch"
    ]);
    if (subcommand === "branch") {
      return ["--show-current", "-vv"].includes(tokens[2])
        ? allow()
        : deny("Only read-only Git branch inspection is permitted.");
    }
    if (!safe.has(subcommand)) {
      return deny("Git operation '" + subcommand + "' is not permitted.");
    }
    return allow();
  }

  if (executable === "agy") {
    const action = tokens.slice(1, 3).join(" ");
    if (["agents", "models", "plugin list"].includes(action)) return allow();
    if (tokens[1] === "plugin" && tokens[2] === "validate") return allow();
    return deny("Agent commands may inspect the CLI but may not alter plugin or agent configuration.");
  }

  return READ_ONLY_COMMANDS.has(executable)
    ? denyDangerousReadOptions(executable, tokens)
    : deny("Command '" + executable + "' is not on the project command allowlist.");
}

function denyDangerousReadOptions(executable, tokens) {
  if (executable === "sed" && tokens.slice(1).some((token) => token === "-i" || token.startsWith("--in-place"))) {
    return deny("In-place file editing is blocked.");
  }
  if (executable === "find" && tokens.slice(1).some((token) =>
    ["-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls"].includes(token)
  )) {
    return deny("Mutating or command-executing find expressions are blocked.");
  }
  return allow();
}

function evaluateReadPathTool(toolName, payload) {
  const args = payload?.toolCall?.args ?? {};
  const pathField = {
    view_file: "AbsolutePath",
    list_dir: "DirectoryPath",
    find_by_name: "SearchDirectory",
    grep_search: "SearchPath",
  }[toolName];
  if (!pathField) return null;

  const candidate = args[pathField];
  const roots = Array.isArray(payload.workspacePaths)
    ? payload.workspacePaths.filter((item) => typeof item === "string")
    : [];
  if (typeof candidate !== "string" || !path.isAbsolute(candidate) || roots.length === 0) {
    return deny("File inspection requires an absolute path inside the active workspace.");
  }
  if (!isWithin(candidate, roots)) {
    return deny("File inspection outside the active workspace is blocked.");
  }
  if (SENSITIVE_PATH.test(canonicalPath(candidate))) {
    return deny("Access to secret, signing, and environment files is blocked.");
  }
  return allow();
}

export function evaluate(payload) {
  const toolName = payload?.toolCall?.name;
  if (typeof toolName !== "string" || toolName.length === 0) {
    return deny("Missing tool name; request denied closed.");
  }

  if (/remote[_\s-]*desktop[_\s-]*commander|desktop[_\s-]*commander/i.test(toolName)) {
    return deny("Agents must not inherit or invoke Remote Desktop Commander.");
  }

  if (BLOCKED_WRITE_TOOLS.has(toolName)) {
    return deny("Agent file-write tools are disabled until the infrastructure gates are complete.");
  }

  const readPathDecision = evaluateReadPathTool(toolName, payload);
  if (readPathDecision) return readPathDecision;

  if (toolName !== "run_command") return allow();
  return evaluateRunCommand(payload);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const payload = JSON.parse(fs.readFileSync(0, "utf8"));
    process.stdout.write(JSON.stringify(evaluate(payload)));
  } catch {
    process.stdout.write(JSON.stringify(deny("Policy input was invalid; request denied closed.")));
  }
}

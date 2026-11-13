import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const hash = (value) => createHash("sha256").update(value).digest("hex");

export function hashFile(filePath, bufferSize = 64 * 1024) {
  const fd = fs.openSync(filePath, "r");
  try {
    const hasher = createHash("sha256");
    const buffer = Buffer.alloc(bufferSize);
    let bytesRead = 0;
    while ((bytesRead = fs.readSync(fd, buffer, 0, bufferSize, null)) > 0) {
      hasher.update(buffer.subarray(0, bytesRead));
    }
    return hasher.digest("hex");
  } finally {
    fs.closeSync(fd);
  }
}

function git(root, args) {
  return execFileSync("git", ["-C", root, ...args], {
    encoding: "utf8", timeout: 10000, maxBuffer: 16 * 1024 * 1024
  });
}

export function captureState(root) {
  const actualRoot = git(root, ["rev-parse", "--show-toplevel"]).trim();
  if (actualRoot !== path.resolve(root) || fs.realpathSync(root) !== actualRoot) throw new Error("Snapshot requires the exact worktree root");
  const head = git(root, ["rev-parse", "--verify", "HEAD"]).trim();
  const index = hash(git(root, ["ls-files", "--stage", "-z"]));
  const records = git(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"]).split("\0");
  const files = new Map();
  for (let i = 0; i < records.length; i += 1) {
    const record = records[i];
    if (!record) continue;
    const status = record.slice(0, 2);
    const names = [record.slice(3)];
    if (/[RC]/.test(status)) {
      if (!records[i + 1]) throw new Error("Missing rename/copy source");
      names.push(records[++i]);
    }
    for (const name of names) {
      // The launcher's line-based allowlist cannot represent control characters.
      if (/[\x00-\x1f\x7f]/.test(name)) throw new Error("Unsupported control character in Git path");
      const target = path.join(root, name);
      let entry;
      try {
        const stat = fs.lstatSync(target);
        const mode = stat.mode & 0o7777;
        if (stat.isSymbolicLink()) entry = ["link", mode, fs.readlinkSync(target)];
        else if (stat.isFile()) entry = ["file", mode, stat.nlink, hashFile(target)];
        else throw new Error("Unsupported changed entry: " + name);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
        entry = ["missing"];
      }
      files.set(name, [status, ...entry]);
    }
  }
  return { head, index, files: Object.fromEntries([...files].sort(([a], [b]) => a.localeCompare(b))) };
}

export function changedPaths(before, after) {
  if (!before?.head || !after?.head || !before?.index || !after?.index ||
      !before.files || !after.files) throw new Error("Invalid state snapshot");
  const changed = [];
  if (before.head !== after.head) changed.push("HEAD");
  if (before.index !== after.index) changed.push("INDEX");
  for (const name of new Set([...Object.keys(before.files), ...Object.keys(after.files)])) {
    if (JSON.stringify(before.files[name]) !== JSON.stringify(after.files[name])) changed.push(name);
  }
  return changed.sort();
}


if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const [action, first, second] = process.argv.slice(2);
    if (action === "snapshot") process.stdout.write(JSON.stringify(captureState(first)) + "\n");
    else if (action === "compare") process.stdout.write(changedPaths(
      JSON.parse(fs.readFileSync(first, "utf8")), JSON.parse(fs.readFileSync(second, "utf8"))
    ).join("\n"));
    else throw new Error("Unknown guard-state action");
  } catch (error) {
    console.error("GUARD_STATE_FAIL: " + error.message);
    process.exitCode = 3;
  }
}

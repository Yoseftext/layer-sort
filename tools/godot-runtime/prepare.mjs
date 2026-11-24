import fs from "node:fs";
import path from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const hash = bytes => createHash("sha256").update(bytes).digest("hex");
const dir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(dir, "../..");
try {
  if (process.platform !== "linux" || process.arch !== "arm64") throw Error("This preparation is validated for Linux ARM64 only");
  if (process.env.LD_PRELOAD) throw Error("Unexpected existing LD_PRELOAD");
  const candidate = process.env.GODOT_BIN ?? process.env.PATH.split(path.delimiter)
    .map(p => path.join(p, "godot")).find(p => { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch { return false; } });
  if (!candidate) throw Error("Godot executable not found");
  const engine = fs.realpathSync(candidate);
  const engineHash = hash(fs.readFileSync(engine));
  const expected = "3fcb80f4fe794e3859360eb641d8c41d8ffe2c2e54ba1981e55a76851d5ed1f4";
  if (engineHash !== expected) throw Error("Expected verified official Godot 4.7.2 ARM64 binary; hash mismatch");
  const common = fs.realpathSync(path.resolve(root, execFileSync("git", ["-C", root, "rev-parse", "--git-common-dir"], { encoding: "utf8", timeout: 10000 }).trim()));
  const state = path.join(common, "agent-runtime-tools");
  fs.mkdirSync(state, { recursive: true, mode: 0o700 });
  if (fs.realpathSync(state) !== state) throw Error("Private runtime directory must not use symlinks");
  const cache = fs.mkdtempSync(path.join(state, "godot47-"));
  fs.mkdirSync(path.join(cache, "bin"), { mode: 0o700 });
  const sourceHashes = {};
  for (const name of ["scandir-guard.c", "runner.c"]) {
    const bytes = fs.readFileSync(path.join(dir, name));
    sourceHashes[name] = hash(bytes);
    fs.writeFileSync(path.join(cache, name), bytes, { flag: "wx", mode: 0o600 });
  }
  const library = path.join(cache, "libgodot-scandir-guard.so");
  const compile = args => execFileSync("cc", args, { stdio: "pipe", timeout: 30000 });
  compile(["-shared", "-fPIC", "-O2", "-Wall", "-Wextra", "-Werror", "-o", library, path.join(cache, "scandir-guard.c"), "-ldl"]);
  const libraryHash = hash(fs.readFileSync(library));
  const executable = path.join(cache, "bin/godot");
  compile(["-O2", "-Wall", "-Wextra", "-Werror", "-DGODOT_BINARY=" + JSON.stringify(engine), "-DGODOT_SHA256=" + JSON.stringify(engineHash), "-DGUARD_LIBRARY=" + JSON.stringify(library), "-DGUARD_SHA256=" + JSON.stringify(libraryHash), "-o", executable, path.join(cache, "runner.c")]);
  const metadata = { engine, engineHash, libraryHash, sourceHashes, runnerHash: hash(fs.readFileSync(executable)), compiler: execFileSync("cc", ["--version"], { encoding: "utf8", timeout: 10000 }).split("\n")[0], createdAt: new Date().toISOString() };
  fs.writeFileSync(path.join(cache, "build.json"), JSON.stringify(metadata, null, 2) + "\n", { flag: "wx", mode: 0o600 });
  const version = execFileSync(executable, ["--version"], { encoding: "utf8", timeout: 20000 }).trim();
  if (version !== "4.7.2.stable.official.ed1daf0bf") throw Error("Unexpected engine version");
  const pointer = path.join(state, "godot-runtime.json"), temporary = pointer + "." + randomUUID();
  fs.writeFileSync(temporary, JSON.stringify({ bin: path.join(cache, "bin"), runnerHash: metadata.runnerHash }) + "\n", { flag: "wx", mode: 0o600 });
  fs.renameSync(temporary, pointer);
  console.log(JSON.stringify({ status: "PASS", version, bin: path.join(cache, "bin"), ...metadata }, null, 2));
} catch (error) { console.error("GODOT_PREPARE_FAIL: " + error.message); process.exitCode = 3; }

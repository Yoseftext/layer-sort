import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
const source = path.dirname(fileURLToPath(import.meta.url));
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "godot-compat-"));
const hash = file => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const run = (command, args, env = {}) => spawnSync(command, args, { encoding: "utf8", timeout: 30000, env: { ...process.env, LD_PRELOAD: "", ...env } });
function compile(args) { const r = run("cc", ["-O2", "-Wall", "-Wextra", "-Werror", ...args]); assert.equal(r.status, 0, r.stderr); }
const guard = path.join(dir, "guard.so"), fake = path.join(dir, "denied.so"), probe = path.join(dir, "probe");
const fakeSource = `#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#define FAKE(name,type) int name(const char *p,struct type ***n,int(*f)(const struct type *),int(*c)(const struct type **,const struct type **)){typedef int(*fn)(const char*,struct type***,int(*)(const struct type*),int(*)(const struct type**,const struct type**)); if(strcmp(p,"/dev")==0){errno=EACCES;return -1;} fn next=(fn)dlsym(RTLD_NEXT,#name);return next(p,n,f,c);}
FAKE(scandir,dirent)
FAKE(scandir64,dirent64)
`;
fs.writeFileSync(path.join(dir, "denied.c"), fakeSource);
const probeSource = `#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
static int reject(const struct dirent *e){(void)e;return 0;}
static int reject64(const struct dirent64 *e){(void)e;return 0;}
int main(int argc,char **argv){if(argc!=3)return 2;
${[["scandir", "dirent", "reject", "alphasort"], ["scandir64", "dirent64", "reject64", "alphasort64"]].map(([scan,type,reject,sort],i)=>`{struct ${type} **list=(void*)1;errno=0;int n=${scan}("/dev",&list,NULL,${sort});if(n!=-1||errno!=EACCES||list!=NULL)return ${i+10};free(list);list=(void*)1;errno=0;n=${scan}(argv[2],&list,NULL,${sort});if(n!=-1||errno!=ENOENT||list!=(void*)1)return ${i+20};n=${scan}(argv[1],&list,${reject},${sort});if(n!=0)return ${i+30};free(list);n=${scan}(argv[1],&list,NULL,${sort});if(n<=0)return ${i+40};for(int j=0;j<n;j++)free(list[j]);free(list);}`).join("\n")}
puts("SCANDIR_CONTRACT_PASS both_ABIs denied_dev unchanged_other_error zero_and_positive_results");return 0;}
`;
fs.writeFileSync(path.join(dir, "probe.c"), probeSource);
compile(["-shared", "-fPIC", "-o", guard, path.join(source, "scandir-guard.c"), "-ldl"]);
compile(["-shared", "-fPIC", "-o", fake, path.join(dir, "denied.c"), "-ldl"]);
compile(["-o", probe, path.join(dir, "probe.c")]);

test("both scandir ABIs retain denial and successful behavior, normalizing only failed /dev output", () => {
  const args = [dir, path.join(dir, "missing")];
  const baseline = run(probe, args, { LD_PRELOAD: fake });
  assert.equal(baseline.status, 10, baseline.stderr);
  const repaired = run(probe, args, { LD_PRELOAD: guard + ":" + fake });
  assert.equal(repaired.status, 0, repaired.stderr);
  assert.match(repaired.stdout, /SCANDIR_CONTRACT_PASS/);
});

const engine = fs.realpathSync("/usr/bin/true"), runner = path.join(dir, "godot");
function buildRunner(file, expectedEngine = hash(engine)) {
  compile(["-DGODOT_BINARY=" + JSON.stringify(engine), "-DGODOT_SHA256=" + JSON.stringify(expectedEngine), "-DGUARD_LIBRARY=" + JSON.stringify(guard), "-DGUARD_SHA256=" + JSON.stringify(hash(guard)), "-o", file, path.join(source, "runner.c")]);
}
buildRunner(runner);

test("runner forwards a verified invocation and rejects conflicting preload or wrong engine", () => {
  assert.equal(run(runner, []).status, 0);
  const conflicting = run(runner, [], { LD_PRELOAD: fake });
  assert.equal(conflicting.status, 3);
  assert.match(conflicting.stderr, /unexpected existing LD_PRELOAD/);
  const wrong = path.join(dir, "wrong-engine");
  buildRunner(wrong, "0".repeat(64));
  assert.equal(run(wrong, []).status, 3);
});

test("runner rejects a changed library before executing the engine", () => {
  fs.appendFileSync(guard, "modified fixture");
  const r = run(runner, []);
  assert.equal(r.status, 3, r.stderr);
  assert.match(r.stderr, /hash mismatch/);
});
console.log("Retained compatibility fixtures: " + dir);

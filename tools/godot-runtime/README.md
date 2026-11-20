# Local Godot 4.7.2 runtime

The official ARM64 binary is unchanged. Its camera discovery frees an uninitialized
list after failed scandir("/dev"). Editor documentation creates CameraTexture,
which starts that discovery even for an empty project. This host denies /dev
listing (EACCES); expanding device permissions is unnecessary.

prepare.mjs verifies the official binary SHA256, freezes reviewed C sources in
private .git/agent-runtime-tools, builds a small compatibility library and runner,
and publishes an operator-owned pointer. safe-agy prepends that private bin;
normal godot commands and existing task permissions remain unchanged.

Run once from a reviewed infrastructure checkout:

~~~sh
node tools/godot-runtime/prepare.mjs
~~~

Use the returned bin/godot for direct local commands. Antigravity safe-agy selects
it automatically. Never grant agents write access to private runtime caches.
The runner checks engine and library hashes before execution and refuses to
compose an existing LD_PRELOAD configuration. That check does not prevent an
already supplied library from loading into the runner. The selected preload is
invocation-local and may be inherited by Godot's external importer children;
no global loader file, device permission or game setting is changed.

The library normalizes only a failed exact /dev scandir/scandir64 output to NULL.
Actual return values and errno are preserved; other paths and successful scans
are unchanged. It is a compatibility workaround for the pinned engine, not a
claim that upstream Godot or the OS has been patched. The source-level correction
is supplied as upstream-camera-free.patch for an eventual reviewed engine build.

Preparation requires Linux ARM64, the installed C compiler and the verified
4.7.2 binary; other engines fail the hash gate. Re-run reviewed preparation after
changing the runner source; do not hand-edit generated binaries. Old private
builds are retained for audit and can be deliberately retired by the operator.
To stop selecting the workaround, move the private godot-runtime.json pointer
aside; preserve it for rollback. Do not do this during a live agent session.

~~~sh
node --test tools/godot-runtime/test-compat.mjs
~~~

Tests force scan denial in a dedicated fixture (no /dev permissions are changed),
check both ABIs and successful scans, preserve other-path failure behavior, and
reject wrong engine/library hashes and conflicting preload configuration.

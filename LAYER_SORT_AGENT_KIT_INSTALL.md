# Layer Sort — Antigravity Agent Kit

This is a **workspace-scoped** Antigravity plugin for `~/projects/layer-sort`.

## Install without overwriting anything

1. Download the ZIP.
2. Set `ZIP_PATH` to the actual downloaded file path, then run:

   ```bash
   python3 - <<'PY'
   from pathlib import Path
   from zipfile import ZipFile

   archive = Path("/path/to/layer-sort-agent-kit.zip")
   root = (Path.home() / "projects/layer-sort").resolve()

   with ZipFile(archive) as zf:
       for name in zf.namelist():
           target = (root / name).resolve()
           if root not in target.parents:
               raise SystemExit(f"Unsafe archive path: {name}")
           if target.exists():
               print("SKIP existing:", target)
               continue
           if name.endswith("/"):
               target.mkdir(parents=True, exist_ok=True)
           else:
               target.parent.mkdir(parents=True, exist_ok=True)
               target.write_bytes(zf.read(name))
               print("CREATED:", target)
   PY
   ```

   Replace `/path/to/layer-sort-agent-kit.zip` with the real path. Existing files are skipped, never overwritten.

3. Validate the plugin. Do not install it globally:

   ```bash
   cd ~/projects/layer-sort
   agy plugin validate --strict .agents/plugins/layer-sort-agent-kit
   ```

4. If validation exits non-zero, stop and inspect the output. Do not bypass validation.

5. Confirm agent discovery:

   ```bash
   agy agents
   ```

6. Confirm the active hook and sandbox before enabling command or write tools:

   ```bash
   agy --sandbox --agent layer-sort-lead
   ```

   Use `/hooks` to confirm the plugin guard is loaded. A successful `unshare -Ur` probe is not sufficient; verify that an agent command cannot read a known path outside the workspace. If the host cannot create the required Linux namespaces, `--sandbox` has no effect.

   **Current host result (2026-11-09):** `/hooks` lists `layer-sort-agent-guard` as enabled, but the sandboxed `run_command` probe failed before execution with `fork/exec /root/.local/bin/agy: operation not permitted`. Keep `commandExecutionPolicy: off` and all agent write tools disabled until this is resolved.

## Important

- Do **not** run `agy plugin install` for this kit. That stages a global plugin and is not the intended project-only setup.
- The plugin includes one plugin-scoped PreToolUse guard; it does not add MCP servers, external packages, or global settings.
- No agent currently has file-write, file-edit, or shell command tools. Re-enable them only after the Remote Desktop Commander boundary, device wrapper, hook activation, `.agents/` commit, terminal sandbox isolation, and dedicated worktree are verified.
- The plugin's PreToolUse guard is policy enforcement, not an OS sandbox. If command tools are ever re-enabled, run them only under a verified terminal sandbox.
- The kit does not edit game files, CI workflows, Android services, or Git branches.
- Keep the existing untracked file named `t --left-right --count \\` untouched. Its content was not verified during the earlier cleanup attempt.
- The project’s current worktree may contain other local changes. Review `git status` before staging anything.

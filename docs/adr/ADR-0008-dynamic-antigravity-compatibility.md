# ADR-0008 — Dynamic Antigravity CLI compatibility gate

Date: 2026-11-14. Owner: Layer Sort repository owner, explicit approval in the 2026-11-14 engineering session. Status: OWNER APPROVED FOR IMPLEMENTATION; no PR merge or production rollout is authorized by this ADR.

## Context

The installed Antigravity CLI is updated independently of this repository. A fixed `1.5.8` version check in `tools/agent-guard/safe-agy.sh` makes every later release fail closed until the wrapper is manually edited. Removing that check without replacing it would trust untested runtime changes and could silently weaken the agent permission boundary.

The current inspected host resolves `agy` to `/root/.local/bin/agy`, a native AArch64 ELF executable, version `1.5.9`, SHA-256 `684136e4246393499343c9ba07ac4a69fa97729178f702d0132b50520d7ed699`, Build ID `8bd94ab72ea8c8f6195a724821ea3b2e`. No adjacent package.json was found. The installed artifact must therefore be fingerprinted according to its actual native ELF layout, not assumed to be a Node package.

## Decision

Replace the single-version pin with a **Compatibility-Gated Launcher**. Antigravity version strings are recorded as metadata, not treated as sufficient proof of compatibility. A new version or changed binary/policy/test fingerprint triggers a bounded compatibility evaluation. A version is not trusted merely because it is newer, signed by a package manager, or has a familiar version string.

The launcher may execute Antigravity only when the current executable identity, compatibility contract, active policy, and required negative probes are verified. Missing evidence, timeout, unsupported host format, malformed metadata, hash mismatch, policy drift, or failed security probes produces `UNKNOWN` or `REJECT` and blocks agent execution.

## Trust and fingerprint model

1. Resolve the configured CLI through an absolute path and canonical `realpath`. Reject PATH ambiguity, unexpected symlinks, non-regular files, unexpected ownership/modes, and path changes.
2. Record the tuple `(absolute realpath, SHA-256, reported version)`. For ELF, also record Build ID, ELF class/machine, interpreter, DT_NEEDED entries, and the canonical path plus SHA-256 of each resolved dynamic dependency and the interpreter. If any dependency cannot be resolved or fingerprinted, compatibility is `UNKNOWN`; do not silently omit it.
3. If a future installation is a script/package runtime, fingerprint the executable and its actual package entry point/manifest plus the resolved runtime package files that affect execution. Do not assume `package.json` exists. Unsupported formats fail closed until a tested adapter exists.
4. Build a separate policy fingerprint from the launcher, compatibility evaluator, Hook dispatcher, policy sources, runtime helpers, schemas, and compatibility/negative-test harness. Include the host/runtime identity and supported tool versions in the composite cache key. A policy or test change invalidates prior approvals even when the Antigravity binary is unchanged.
5. Recompute the executable and dependency identity on **every launch**, including cache hits. Cache hits may skip only the expensive compatibility suite; they never skip current identity verification or the pre-exec identity check.
6. Recompute the complete CLI, dependency, policy, test and host fingerprint after the compatibility suite. If any component changes while tests run, do not create a PASS cache entry.

## Execution identity and TOCTOU

Path/hash/version verification followed by a normal path-based exec is insufficient because the path can be replaced between verification and execution. The implementation must open the canonical executable without following a final symlink, verify the opened file's device/inode/type/owner/mode and SHA-256, and execute the same opened object using a tested descriptor-based execution mechanism (for example `execveat(AT_EMPTY_PATH)` for the current native ELF target). If the host/runtime cannot safely execute the verified descriptor, fail closed rather than falling back silently to path-based exec.

The descriptor approach prevents path replacement between verification and exec. The launcher also rejects inherited `LD_*`, `NODE_OPTIONS`, `NODE_PATH` and `BASH_ENV` overrides that could alter loader or helper startup behavior. It does not create OS isolation and must not be described as preventing a malicious same-UID process from modifying an already-open writable inode. File ownership/mode checks and the existing Hook/Worktree policy remain defense-in-depth, not a sandbox. Any stronger immutable-copy or sealed-memfd strategy requires separate implementation and tests before it is claimed.

## Compatibility evaluation

A cache miss runs a deterministic, bounded harness with `CI=true`, non-interactive environment variables, closed stdin, no inherited interactive terminal, fixed argument vectors, and per-test deadlines. The harness checks the actual CLI contract used by this repository: version reporting, supported invocation arguments, settings/plugin discovery, workspace Hook invocation, agent delegation/partial editing behavior where required, task-grant enforcement, post-run state verification, and reviewer workflow compatibility.

The harness includes **active negative probes** in a disposable temporary test fixture. It must attempt at least one out-of-scope write and one prohibited command/tool request through the real Antigravity permission/Hook path. The test passes only when the unauthorized operation is denied and no forbidden side effect exists. Each probe is delegated separately to an implementer; the harness verifies the exact tool arguments and actual tool result from the subagent's structured transcript, rather than trusting the coordinator's summary. A separate read-only Reviewer must inspect the successful allowlisted file and return an explicit `ACCEPT` verdict. These are application-level policy probes in a disposable directory, not an OS sandbox. A synthetic unit test alone is not a substitute for the real CLI probe.

Classify results as:
- `HARD_FAIL`: security contract drift, bypass, unexpected write, missing/changed Hook, authority override accepted, hash mismatch, or failed negative probe. Block execution.
- `UNKNOWN`: timeout, missing dependency/evidence, unsupported executable format, incomplete probe, or environment failure. Block execution.
- `SOFT_WARNING`: recognized deprecation or non-security warning with a tested compatibility path. Allow only if all hard gates pass; report the warning and record it in the audit log.
- `PASS`: all required positive and negative tests pass with exact evidence.

Antigravity may report prompt-suggestion truncation for its Flutter and Firebase plugin manifests. The active probe accepts the exact message and the approved manifest paths when real subagent delegation has been verified, even if the source line number changes. Other logger names, plugin paths, and messages remain subject to review. The known fallback from the relative `.gemini` path to the default directory, the exact canceled analytics request, and the configuration-service timeout fallback are reported when delegation has succeeded. Unit tests cover both accepted and rejected contexts.

The active compatibility probe also classifies a small set of host-specific warnings, but only with corroborating evidence:
- Startup cache messages and the exact `errorreport.go:307` messages `error getting token source` / `Failed to poll ListExperiments` are accepted only when every such line precedes an explicit `OAuth: authenticated successfully` log entry and the same run records a successful `streamGenerateContent` request. A missing OAuth/model-stream marker, or any auth warning/error after OAuth success, remains `UNKNOWN`. The evidence stores booleans only; it does not store the account email.
- `admin controls not applicable` is accepted only when the same log proves `authMethod=consumer` with no quota project. It is not accepted for enterprise/unknown auth contexts. This condition matters because upstream CLI changelog documents an earlier startup race involving admin-control cache state; the compatibility gate must not blanket-suppress it.
- The missing `/usr/bin/cs` lookup is a soft warning only on Linux when that exact helper path is absent. Its optional helper capability is not claimed as verified.
- The `/proc/<pid>/fd` auto-updater warning is accepted only for the exact read-only PRoot signature. Background auto-update may be skipped in this host; use `agy update` explicitly, then let the compatibility fingerprint gate evaluate the new binary before launch.
- Missing `agy-node` for `science_biomolecular_structure_viewer_mcp` and missing `dart` for `flutter_dart-mcp-server` are soft warnings only when the Layer Sort project declares no MCP servers. These global optional servers are not silently installed or enabled by this gate.
- Exact `.agents/agents/*.md: not a directory` discovery errors are accepted only when the active probe independently proves all four Implementer delegations and the Reviewer delegation. The parser now captures both Go warning and error severity lines; any unknown `W` or `E` line remains `UNKNOWN`.

Every recognized warning is reduced to a non-sensitive summary in the audit/evidence record. Failure evidence stores hashes and a redacted, bounded warning summary; it must not persist the combined raw debug transcript, account email, bearer token, or API key. The structured JSONL subagent stream may be retained separately for tool-result verification only under the private `0700` state directory with file mode `0600`. New warning signatures, unexpected source paths, unknown plugin/server names, unresolved auth, or any mismatch remain `UNKNOWN`. These rules are not a general warning allowlist; they are exact, context-gated compatibility exceptions with negative tests.

## External state, cache, and audit

Store compatibility state outside the repository at `$XDG_STATE_HOME/safe-agy/`, falling back to `$HOME/.local/state/safe-agy/`. The directory must be owned by the current UID, be a real directory (not a symlink), and have mode `0700`; state files use `0600`. Reject unsafe pre-existing paths rather than repairing ownership or permissions silently. The Antigravity agent must not receive write authority to this directory. This is an application-policy boundary; because the agent and launcher currently share a Linux UID, it is not a kernel-enforced user isolation boundary.

Use a composite key covering the CLI/dependency fingerprint, launcher/evaluator/policy/test fingerprint, host identity, and schema version. Keep a bounded LRU of the last five successful fingerprints. Failed/unknown results are not reusable as approvals. Rollback to a previously approved fingerprint may reuse its entry only after current executable and policy fingerprints are revalidated.

Serialize cache/audit operations with `flock`; where unavailable, use an atomic `mkdir` lock with bounded wait and conservative stale-lock handling. Write cache updates to a same-directory temporary file, fsync, and atomically rename; never expose partially written approval records. Every compatibility event is appended as one JSONL record (`CACHE_HIT`, `CHECK_PASSED`, `CHECK_FAILED`, `HASH_MISMATCH`, `SOFT_WARNING`) with timestamp, fingerprint key, CLI version, verdict, and concise reason. Rotate the audit log at 1 MiB. File permissions and append mode reduce accidental changes; the log is not claimed to be tamper-proof against the same UID.

## CLI and host behavior

Provide read-only `--status`, explicit full `--check`, and normal launch behavior. `--status` reports installed identity, cached verdict and current state without changing approval. `--check` performs the full suite and updates state only after all gates pass. Normal launch verifies identity every time and performs a full check on cache miss.

Preflight required host tools before running tests. Prefer `sha256sum`, fall back to `shasum -a 256`; require `realpath`, the appropriate executable-format inspection tool, and Node for the current harness. Use `flock` when present and the atomic-directory lock fallback otherwise. The current supported target is the inspected Linux ARM64/glibc PRoot environment. macOS, native Termux/Bionic, other architectures, and other executable formats remain `UNSUPPORTED/UNKNOWN` until their adapters are implemented and tested; do not infer portability from command availability alone.

## Node restriction

Do not remove Node from the persistent Remote Desktop Commander blocklist. The trusted launcher may use Node internally for its fixed, reviewed guard/evaluator code. Tests that require Node must be invoked through a fixed, hash-verified test wrapper/subshell with a scoped test environment and exact test entrypoints. The Antigravity agent must not receive unrestricted Node execution; only explicitly reviewed test commands may be allowed by the project policy. No persistent blocklist change is part of this decision.

## Rollout and acceptance

Implementation occurs on a dedicated Worktree/branch. Required tests include:
- cache key changes when CLI binary, dependency, launcher, policy, tests, host schema, or version changes;
- path replacement, symlink substitution, inode mismatch, hash mismatch, and descriptor-exec behavior;
- concurrent checks, interrupted writes, stale locks, atomic rename and cache rotation;
- timeout, closed stdin, and non-interactive behavior;
- hard-fail versus soft-warning classification;
- real CLI positive and active negative probes;
- `--status`, `--check`, cache hit, cache miss, and rollback to a previously approved fingerprint;
- Node remains blocked in persistent RDC configuration before and after test execution, including failure/interrupt paths.

An independent Reviewer must inspect the exact patch and evidence. A successful local unit suite alone does not establish runtime compatibility. No automatic policy edits, package upgrades, global settings changes, Git commits, pushes, PR merges, phone installation, or OS-level isolation are authorized by this ADR.

## Explicit limitations

This design is a compatibility and policy gate, not an OS sandbox. Worktrees and Hooks cannot prevent all same-user filesystem or process tampering. The audit log is not immutable. A cache approval is bound to measured executable/dependency/policy/test/host fingerprints, not a general trust statement about every future runtime behavior. Any material security-contract change requires review and a new policy fingerprint.

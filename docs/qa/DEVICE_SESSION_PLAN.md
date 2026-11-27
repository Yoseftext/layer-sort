# Device session plan — review foundation

A session plan is a proposal for a specific build, installed APK, device and
ordered test actions. The owner previously authorized tests of a specific run;
that historical approval does not automatically authorize a later reinstall or
a new session. Recheck current state and record applicable authorization.

`tools/device-tests/session_plan.py` validates a small plan offline and prints
a deterministic SHA-256 for review. It does not issue a grant, verify the owner,
run an agent, execute ADB, check live device state, or provide replay protection.
A plan file or a self-supplied hash must never be treated as proof of consent.

The present slice supports launch, screenshot and bounded taps on the tested
720x1600 display. It deliberately does not implement installation or changing
device state. A separately reviewed step must define how a trusted operator
records the owner's exact authorization and binds it to the private task
snapshot and a single session. The execution path must independently recheck
build provenance, installed package/hash, device identity, foreground and
display dimensions, hold the existing phone lock, and handle expiry, revocation,
replay and interruption without guessing the result. The agent must not be able
to create, alter or approve its own grant.

A SHA-256 identifies the canonical JSON plan; it is not a signature or an
authorization. The operator should compare the complete plan and its hash
before recording a grant. Include no credentials or personal data. Reassess the
display constraint for other devices before extending the schema.

Example review only:
`python3 tools/device-tests/session_plan.py .runtime/session-plans/review.json`

Required later evidence: successful/negative offline tests, real Antigravity
policy and session permission tests, explicit reviewed task scope, actual phone
result and capture, timeout/rollback review, and a report distinguishing CLI,
agent and physical-device evidence.

## Offline sequence prototype

`session_sequence.py` is an offline SQLite-backed progress prototype. It
claims one reviewed step before execution, rejects out-of-order or duplicate
claims, and leaves interrupted or failed steps blocked. Its tests include two
simultaneous claims. It does not issue owner authorization, collect evidence,
call ADB, protect its database from a same-user process, or connect to the Hook.
Do not use it as an active security or execution boundary until a trusted
operator-controlled integration and real end-to-end review exist.

## Offline broker prototype

`session_broker.py` joins the existing plan and sequence prototypes through
injected observation and dispatch callbacks. It checks preconditions before and
after claiming a step, advances only for a matching PASS result, and blocks on
unknown results or exceptions. The six added tests use fake callbacks only.

This is **not** a live device broker or an authorization mechanism: callbacks
must come from a trusted runtime, and the module is not connected to agentctl,
Antigravity permissions, a phone lock, or independent build/device evidence.
Same-user database modifications remain possible. The checks alone do not make
observation and dispatch atomic. A PASS for synthetic input does not prove a
game interaction succeeded. Live integration needs all of those issues resolved
and tested before allowing an agent to act.

## Read-only observation helper

`session_observe.py` connects the plan precondition check to the existing
verified cached build, installed APK inspection, device identity and display
size. The phone lock is held throughout device observation. Its unit tests mock
the external services and phone; they do not establish a live-device PASS.

This is only a snapshot, not an authorization or a dispatch-time guarantee.
Any live executor must hold the same lock over fresh preconditions and the
actual operation, provide independently controlled results, and check foreground,
expiry and session authority. The helper is not wired to agentctl or the hook.

## Locked orchestration prototype

`session_locked.py` holds a verified cached build and the existing phone lock
while the broker checks device evidence and calls a supplied dispatcher. Four
unit tests exercise lock lifetime, expiry, device loss and timeout with mocked
callbacks; the combined 26 session tests passed. The extracted
`session_observe.observe_locked` requires its caller to hold that lock and
verify the build first; its name is not runtime proof of either condition.

This internal Python prototype has no CLI or real dispatcher and is not wired
to agentctl or Antigravity. The callback and state are not a same-user security
boundary. It does not independently establish owner authorization, session
binding, revocation, foreground at input dispatch, or actual gameplay. Integrate
and review those requirements before exposing actions to agents. Holding a
cooperative lock does not stop non-cooperating programs or Android itself.

## Internal device dispatcher

`session_dispatch.py` adapts a validated launch, screenshot or tap to the
existing `device_qa` implementation while its caller holds the phone lock.
The latter now has a private locked function, and its ordinary CLI still
acquires the lock and checks its previous approval flags. The dispatcher does
not establish owner authorization, acquire the lock, bind an Antigravity
session or expose a CLI. Its audit label is not proof of consent.

Unit tests simulate device responses, including foreground changes and invalid
coordinates; no actual device action is claimed. ADB input success means only
that input was dispatched, not that gameplay responded. Before agent access,
an operator-controlled session grant, integrity/revocation model and trusted
integration need review and testing, including lock ownership, recovery and real
phone execution. Do not expose the private function to agents directly.

## Scoped capture and return

The owner may authorize one `capture-restore` action for a specific verified
run, commit, and installed APK. The operator prepares this capability using
`prepare-task.mjs WORKTREE TASK-ID --capture-restore RUN COMMIT APK_SHA256`.
The Hook and launcher expose only that fixed `agentctl capture-restore`
operation to that task. The executor revalidates the active grant and cached
build, locks the phone, matches the installed APK, consumes a one-use marker
before launch, captures the game and attempts to restore the previously
focused Android activity. It does not clear data, install, or tap.

A confirmed return means that the same activity is focused, not that its
internal page, keyboard, scroll position or contents are identical. A process
kill, Android behavior, or an unexported activity can prevent restoration; the
result is UNKNOWN and must not be retried automatically. This is a cooperative
policy, not same-user OS isolation. Test results and any real-device outcome
must be reported separately.

## Interactive gameplay session

A separately prepared `--play-session RUN COMMIT APK_SHA256` grants the
Lead four fixed operations: game-open, game-capture, game-tap X Y and
game-finish. It verifies the build and installed APK before opening; the agent
reads actual screenshots and chooses coordinates. Each input is recorded
before dispatch, timeouts block further input, and a session is capped at 60
taps. A tap PASS means Android accepted synthetic input, not that game state
changed or physical touch accuracy was measured. Screenshots and game outcomes
must substantiate gameplay.

On finish, or normal launcher cleanup, the prior Android activity is restored
best-effort if Layer Sort is still foreground. If the user switched elsewhere,
the cleanup does not take over that screen. Foreground activity identity is not
proof of identical internal screen contents. Process kills, lost connectivity or
Android restrictions can prevent cleanup. This is a cooperative guard, not
same-user OS isolation. Unit tests use mocked device calls; real-device results
must be recorded independently. The earlier 27 November capture contained the
Godot startup splash, not a playable game screen.

## Paired move

`game-move X1 Y1 X2 Y2` sends a source/destination pair in one device session and lock, reducing per-command overhead. The pair is journaled before input. A partial or uncertain result blocks further input; the agent must not retry automatically. A successful dispatch does not prove a valid pour: capture and inspect the next board. No physical-device speedup is claimed until measured.

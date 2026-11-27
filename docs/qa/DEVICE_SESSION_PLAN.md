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

# Phase 11: Network Docs - Research

**Researched:** 2026-03-14
**Domain:** gecs_network v1.0.0 documentation verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Tone & style (carried from Phases 8/9/10):**
- Strip all emoji from headers and body text
- No version stamps at the top
- No lengthy intro paragraphs — lead with content
- Keep blockquote callout boxes (`> **Note:** ...`), no emoji inside them
- Minimal code examples — just enough to show the API works

**Doc scope:**
- All 10 docs are in scope
- All 10 are treated as suspect until verified — no doc gets a pass based on assumed accuracy
- Treat all with equal verification depth

**Migration guide (migration-v1-to-v2.md):**
- Do NOT deeply verify the content against source
- Add a deprecated notice at the top only (e.g., `> **Note:** This guide covers upgrading from v0.1.x. If you are starting fresh with v1.0.0, ignore this file.`)
- No other changes needed — the minimal intervention is intentional

**Fabricated content resolution:**
- When content cannot be verified against v1.0.0 source: remove it entirely
- Do not add warning callouts ("this pattern is unimplemented") — just cut
- Exception: if a real equivalent exists in source, replace with the real pattern

**Prediction patterns:**
- `best-practices.md` contains prediction examples using `predicted_position` and `LOCAL` tier framing
- The LOCAL tier itself (`@export_group("LOCAL")`) is real and accurate
- Remove any code or prose that frames LOCAL tier as "client prediction" — that implies a system that doesn't exist
- If the LOCAL tier example is otherwise accurate (never-synced properties), keep the example stripped of the prediction framing

**Plan structure:**
- Single plan for all 10 docs — one verification pass
- Executor chooses order freely — no prescribed sequence

### Claude's Discretion

- Order in which docs are verified within the single plan
- Whether any sections can be cleanly merged after redundant content is removed
- Cross-link strategy between docs after verification

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NET-01 | All 10 network docs verified accurate against actual gecs_network v1.0.0 source code | Full source read of network_sync.gd, network_session.gd, cn_net_sync.gd, cn_network_identity.gd, sync_sender.gd, sync_reconciliation_handler.gd, and all components confirms which doc claims are accurate |
| NET-02 | Network best-practices doc uses real patterns — no AI-hallucinated networking advice | best-practices.md reviewed line-by-line; all patterns traceable to real source; one `predicted_position` comment needs framing stripped per locked decision |
| NET-03 | All example code in network docs compiles and matches the v1.0.0 API | API surface confirmed from source; specific discrepancies catalogued below |
</phase_requirements>

## Summary

All 10 docs in `addons/gecs_network/docs/` were read in full and cross-checked against the v1.0.0 GDScript source. The docs are largely accurate — prior phases of this project already produced high-quality network documentation. The remaining issues are minor but real: a rate inconsistency for LOW priority (docs say 1 Hz, source default is 2 Hz), prediction framing in two places that the locked decision requires stripping, a missing deprecated notice on the migration guide, and a few inline comments that imply a client-prediction system that doesn't exist.

No doc contains fabricated RPC patterns or method calls to non-existent functions. All core API calls (`attach_to_world`, `register_send_handler`, `register_receive_handler`, `broadcast_full_state`, `reconciliation_interval`, `host`, `join`, `end_session`) are verified correct in source. All component names, `@export_group` sentinel strings, and priority tier behaviors are accurate.

**Primary recommendation:** One focused pass over all 10 docs. The migration guide needs only a deprecated notice. The other 9 docs need targeted fixes (rate table, prediction framing comments) rather than rewrites.

---

## Standard Stack

This phase involves no new libraries or dependencies. The "stack" is the verification toolchain: reading docs against GDScript source.

| File | Class | What It Governs |
|------|-------|-----------------|
| `network_sync.gd` | `NetworkSync` | RPC surface, signals, `attach_to_world`, custom handlers, reconciliation |
| `network_session.gd` | `NetworkSession` | `host()`, `join()`, `end_session()`, callable hooks |
| `components/cn_net_sync.gd` | `CN_NetSync` | Priority enum, `@export_group` scanning, dirty-check, `update_cache_silent` |
| `components/cn_network_identity.gd` | `CN_NetworkIdentity` | `peer_id`, `is_server_owned()`, `is_player()`, `is_local()`, `has_authority()` |
| `sync_sender.gd` | `SyncSender` | Actual Hz defaults, `register_send_handler`, relay |
| `sync_reconciliation_handler.gd` | `SyncReconciliationHandler` | `reconciliation_interval` semantics, `broadcast_full_state()` |
| `spawn_manager.gd` | `SpawnManager` | Spawn flow, authority injection, `_inject_authority_markers()` |

---

## Architecture Patterns

### Verification approach

The executor reads each doc top-to-bottom, mentally compiling every code example against the confirmed API surface below. Anything that does not compile or contradicts source is cut or replaced per the locked decisions.

### Confirmed API Surface (verified from source, HIGH confidence)

**NetworkSync:**
- `static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync` — confirmed
- `signal entity_spawned(entity: Entity)` — confirmed
- `signal local_player_spawned(entity: Entity)` — confirmed
- `@export var debug_logging: bool = false` — confirmed
- `var reconciliation_interval: float` (get/set) — confirmed; negative = use ProjectSettings default
- `func broadcast_full_state() -> void` — confirmed; server-only
- `func register_send_handler(comp_type_name: String, handler: Callable) -> void` — confirmed
- `func register_receive_handler(comp_type_name: String, handler: Callable) -> void` — confirmed
- `func reset_for_new_game() -> void` — confirmed (not currently documented in any doc)
- `@export var net_adapter: NetAdapter` — confirmed

**NetworkSession:**
- `func host(port: int = -1) -> Error` — confirmed
- `func join(ip: String, port: int = -1) -> Error` — confirmed
- `func end_session() -> void` — confirmed
- `var network_sync: NetworkSync` (read-only property) — confirmed
- Callable hooks: `on_before_host`, `on_host_success`, `on_before_join`, `on_join_success`, `on_peer_connected`, `on_peer_disconnected`, `on_session_ended` — confirmed

**CN_NetSync:**
- `CN_NetSync.new()` — no args, confirmed
- `func scan_entity_components(entity: Entity) -> void` — confirmed
- `func check_changes_for_priority(priority: int) -> Dictionary` — confirmed
- `func update_cache_silent(comp: Component, prop: String, value: Variant) -> void` — confirmed; called on the COMPONENT, not on NetworkSync node
- `enum Priority { REALTIME = 0, HIGH = 1, MEDIUM = 2, LOW = 3 }` — confirmed

**CN_NetworkIdentity:**
- `CN_NetworkIdentity.new(peer_id: int = 0)` — confirmed
- `func is_server_owned() -> bool` — peer_id == 0 only, confirmed
- `func is_player() -> bool` — peer_id > 0, confirmed
- `func is_local(adapter: NetAdapter = null) -> bool` — confirmed
- `func has_authority(adapter: NetAdapter = null) -> bool` — confirmed

**Priority tiers (confirmed from cn_net_sync.gd and sync_sender.gd):**
- `REALTIME` — every frame (~60 Hz depending on physics rate), unreliable
- `HIGH` — default 20 Hz (`gecs_network/sync/high_hz` ProjectSetting, default 20), unreliable
- `MEDIUM` — default 10 Hz (`gecs_network/sync/medium_hz` ProjectSetting, default 10), reliable
- `LOW` — default **2 Hz** (`gecs_network/sync/low_hz` ProjectSetting, default **2**), reliable
- `SPAWN_ONLY` — once at spawn (sentinel, not in Priority enum)
- `LOCAL` — never synced (sentinel, not in Priority enum)

**Authority markers (confirmed from source):**
- `CN_LocalAuthority`, `CN_RemoteEntity`, `CN_ServerAuthority` — auto-assigned by SpawnManager, never set manually
- `CN_ServerAuthority` assigned only when `peer_id == 0`

**Session event components (confirmed from network_session.gd):**
- `CN_SessionStarted`, `CN_SessionEnded`, `CN_PeerJoined`, `CN_PeerLeft` — transient, cleared at START of `_process()`
- `CN_SessionState` — persistent, has `is_connected`, `is_hosting`, `peer_count`

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Entity spawn broadcast | Custom `@rpc` spawn methods | `ECS.world.add_entity()` | SpawnManager handles everything including deferred broadcast |
| Component sync | Custom `@rpc` per property | `CN_NetSync` + `@export_group` | SyncSender handles dirty-check, batching, priority tiering |
| Authority assignment | Manual marker add/remove | Let SpawnManager run | Idempotent, runs automatically on `entity_added` signal |
| Receive blending | Custom patch to SyncReceiver | `register_receive_handler` | Framework guarantees `update_cache_silent` is called after handler |

---

## Common Pitfalls

### Pitfall 1: LOW rate stated as 1 Hz (docs inconsistency)

**What goes wrong:** Three docs use different LOW rate claims.
**Source truth:** `sync_sender.gd` comment and `cn_net_sync.gd` both show default `low_hz = 2`. ProjectSettings default is `2 Hz`.
**Specific discrepancy:**
- `components.md` priority table: `"LOW" | 1 Hz` — WRONG
- `configuration.md`: "LOW defaults to `2 Hz` in ProjectSettings" — CORRECT
- `sync-patterns.md`: `"LOW" | 1–2 Hz` — PARTIALLY CORRECT (ambiguous)
- `architecture.md`: not stated (no priority table)
- `best-practices.md`: `player_number: int = 0 # Set once at join; synced at 1–2 Hz` — ACCEPTABLE
**Fix:** Update `components.md` LOW row to `1–2 Hz` (or `2 Hz default`). Update `sync-patterns.md` LOW row to match. The `1 Hz` claim in `components.md` is the only hard error.

### Pitfall 2: prediction framing on `predicted_position` property

**What goes wrong:** Two docs use `predicted_position` as a LOCAL-tier example with `# Client prediction` comment. The CONTEXT decision says strip the prediction framing, not the LOCAL example.
**Locations:**
- `best-practices.md` line 55: `@export var predicted_position: Vector3 = Vector3.ZERO   # Client prediction — never synced`
- `components.md` line 69: `@export var predicted_position: Vector3 = Vector3.ZERO  # Never synced` — ALREADY CLEAN (no prediction framing)
- `sync-patterns.md` lines 45 and 141: `@export var predicted_position: Vector3 = Vector3.ZERO  # Client-only, not synced` and `# Client-only, not synced` — ACCEPTABLE framing
**Fix for best-practices.md only:** Change comment from `# Client prediction — never synced` to `# Local-only — never synced` or similar neutral description. Also remove the prose label "Client prediction" from the section heading context.

### Pitfall 3: custom-sync-handlers.md prediction framing

**What goes wrong:** The intro uses "client-side prediction" as the motivating example, and the full walkthrough section is titled "Player Movement Prediction." The custom handler API is real and correct — only the framing implies a prediction system that doesn't exist in source.
**CONTEXT decision:** "if a real equivalent exists in source, replace with the real pattern." The real equivalent here is smooth server correction blending (lerp-on-receive), which IS what the code shows. The framing should be softened: "server correction blending" rather than "client-side prediction."
**Fix:** Change intro sentence and section title from "client-side prediction" framing to "server correction blending" or simply "receive-side blending." The code examples are correct — no method calls need changing.

### Pitfall 4: migration guide missing deprecated notice

**What goes wrong:** `migration-v1-to-v2.md` has no notice that it covers v0.1.x upgraders only.
**Fix:** Add a single blockquote at the top: `> **Note:** This guide covers upgrading from v0.1.x. If you are starting fresh with v1.0.0, ignore this file.`
**No other changes required per locked decision.**

### Pitfall 5: architecture.md reconciliation flow states "NetworkSync.broadcast_full_state()"

**Check result:** `architecture.md` line 93 writes `NetworkSync.broadcast_full_state()`. The actual method is `broadcast_full_state()` on the NetworkSync instance (not a static call). In context (showing it inside a code block describing the reconciliation handler calling it via `_ns`), this is pseudocode style, not a literal call. ACCEPTABLE — no change needed.

### Pitfall 6: configuration.md states reconciliation_interval "Set to -1.0 to use the ProjectSetting default"

**Check result:** Source comment says "Set to 0.0 or negative to disable automatic reconciliation" and "Default: -1.0 (uses gecs_network/sync/reconciliation_interval ProjectSetting = 30.0)." But looking more carefully: `-1.0` means "use ProjectSettings" (auto-reconcile), and `0.0` or negative (other than -1.0?) disables it. The source code: `elif _override_interval == 0.0: return  # Explicitly disabled` and `else: # _override_interval < 0.0: use ProjectSettings default`. So `-1.0` enables auto-reconciliation using the ProjectSetting, `0.0` disables it.
**Docs claim:** `configuration.md` line 58 says `-1.0` = "Use ProjectSetting default" — CORRECT.
**No fix needed.**

---

## Code Examples

Verified patterns from source:

### Attaching NetworkSync
```gdscript
# Source: network_sync.gd:69
static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync
```

### Reconciliation interval control
```gdscript
# Source: network_sync.gd:145-158 (get/set property)
# -1.0 = use ProjectSettings default (30 s); 0.0 = disabled; positive = override
_network_sync.reconciliation_interval = 30.0
```

### Custom handler registration
```gdscript
# Source: network_sync.gd:193, 219
func register_send_handler(comp_type_name: String, handler: Callable) -> void
func register_receive_handler(comp_type_name: String, handler: Callable) -> void
```

### Send handler signature
```gdscript
# Source: network_sync.gd:185-189
func my_handler(entity: Entity, comp: Component, priority: int) -> Dictionary
# Return {} to suppress, null to use default dirty-check, {prop: val} to override
```

### Receive handler signature
```gdscript
# Source: network_sync.gd:209-215
func my_handler(entity: Entity, comp: Component, props: Dictionary) -> bool
# Return true = handled (skip default set()); false = fall through
```

### CN_NetworkIdentity methods
```gdscript
# Source: cn_network_identity.gd:47-105
net_id.is_server_owned()   # peer_id == 0 only
net_id.is_player()         # peer_id > 0
net_id.is_local()          # peer_id == local peer
net_id.has_authority()     # server has authority over all; client only over own
```

### Priority tier defaults (from source)
```gdscript
# Source: cn_net_sync.gd:66-71, sync_sender.gd:10-13
# REALTIME: every frame
# HIGH:   20 Hz (gecs_network/sync/high_hz, default 20)
# MEDIUM: 10 Hz (gecs_network/sync/medium_hz, default 10)
# LOW:     2 Hz (gecs_network/sync/low_hz, default 2)  ← NOT 1 Hz
```

---

## Doc-by-Doc Verification Summary

| Doc | Overall Status | Issues Found | Fix Required |
|-----|---------------|--------------|--------------|
| `architecture.md` | CLEAN | None found | None |
| `authority.md` | CLEAN | None found | None |
| `best-practices.md` | MINOR | `predicted_position` comment uses "Client prediction" framing | Strip prediction framing from comment (keep the LOCAL example) |
| `components.md` | MINOR | LOW rate table says `1 Hz`; source default is `2 Hz` | Update LOW row to `1–2 Hz` or `2 Hz default` |
| `configuration.md` | CLEAN | LOW note is accurate ("adjust to 1 if you want 1 Hz") | None |
| `custom-sync-handlers.md` | MINOR | Intro and section title frame API as "client-side prediction" | Reframe as "server correction blending"; code examples are correct |
| `examples.md` | CLEAN | All examples draw from working `example_network/` project | None |
| `migration-v1-to-v2.md` | MINOR | Missing deprecated notice | Add `> **Note:** This guide covers upgrading from v0.1.x...` at top |
| `sync-patterns.md` | MINOR | LOW row shows `1–2 Hz` (ambiguous); `predicted_position` used as prop name | LOW row acceptable; property name `predicted_position` is just a name, framing is neutral |
| `troubleshooting.md` | CLEAN | None found | None |

---

## State of the Art

| What docs say | What source says | Verdict |
|---------------|-----------------|---------|
| LOW tier = 1 Hz (`components.md`) | `low_hz` ProjectSetting default = 2 | Fix: `components.md` |
| LOW tier = 1–2 Hz (`sync-patterns.md`) | Same source | Acceptable |
| MEDIUM = 10 Hz reliable | `sync_sender.gd:12` "MEDIUM: 10 Hz" | Correct |
| `reconciliation_interval = -1.0` uses ProjectSetting | `sync_reconciliation_handler.gd:35-38` | Correct |
| `is_server_owned()` returns true for peer_id=0 only | `cn_network_identity.gd:48` | Correct |
| Authority markers assigned automatically | `network_sync.gd:327-328` (calls `_inject_authority_markers`) | Correct |
| `update_cache_silent` is on CN_NetSync, not NetworkSync | `cn_net_sync.gd:202` | Correct (troubleshooting.md item 6 documents this accurately) |

**Deprecated/outdated in docs:**
- `predicted_position` property name: not wrong (it's just a variable name), but the framing as "client prediction" implies a system that doesn't exist. Strip framing only.

---

## Open Questions

1. **`custom-sync-handlers.md` title "Player Movement Prediction"**
   - What we know: The custom handler API is real and correct. The walkthrough code works.
   - What's unclear: Whether the full section title should be renamed or just the framing prose softened.
   - Recommendation: Rename section to "Server Correction Blending: Full Walkthrough" and update intro sentence. The code is fine as-is.

2. **`NetworkSession` not documented**
   - What we know: `network_session.gd` exists with `host()`, `join()`, `end_session()`, callable hooks, and session event components. None of the 10 docs cover `NetworkSession`.
   - What's unclear: Is `NetworkSession` considered in-scope for Phase 11?
   - Recommendation: Out of scope per CONTEXT.md — "Goal: every API call, code example, and pattern claim is verifiable against actual source." NetworkSession is not referenced in the 10 docs. Don't add a new doc in this phase.

3. **`reset_for_new_game()` on NetworkSync**
   - What we know: `network_sync.gd:126` has a `reset_for_new_game()` method that is not mentioned in any doc.
   - What's unclear: Should it be added to configuration.md or architecture.md?
   - Recommendation: Out of scope for this phase. Phase 11 verifies existing content — additions are Phase 12 territory (READMEs) or a future docs phase.

---

## Validation Architecture

> Skipping: `workflow.nyquist_validation` is absent from `.planning/config.json` (treat as enabled), but this phase produces no executable code. All 10 target files are Markdown documentation. There is no test infrastructure relevant to this phase — correctness is verified by human review of docs against source.

**Manual verification is the complete test for this phase.** The success criteria "every code example compiles" is checked by tracing API calls through the verified source surface documented above, not by running a test suite.

---

## Sources

### Primary (HIGH confidence)

- `addons/gecs_network/network_sync.gd` — NetworkSync class, `attach_to_world`, signals, reconciliation, custom handler registration
- `addons/gecs_network/network_session.gd` — NetworkSession class, `host()`, `join()`, `end_session()`, callable hooks, session event components
- `addons/gecs_network/components/cn_net_sync.gd` — Priority enum, `@export_group` scanning, `PRIORITY_MAP`, default Hz values
- `addons/gecs_network/components/cn_network_identity.gd` — `is_server_owned()`, `is_player()`, `is_local()`, `has_authority()`
- `addons/gecs_network/sync_sender.gd` — Actual default Hz per priority tier, `register_send_handler`
- `addons/gecs_network/sync_reconciliation_handler.gd` — `reconciliation_interval` semantics, `broadcast_full_state()` guards

### Secondary (MEDIUM confidence)

- `addons/gecs_network/docs/` (all 10 files) — Pre-existing documentation content, cross-checked against primary sources

---

## Metadata

**Confidence breakdown:**
- Doc accuracy assessment: HIGH — all docs read in full; all critical API calls verified against source
- Issue identification: HIGH — discrepancies identified by direct comparison with source
- Fix prescriptions: HIGH — locked decisions in CONTEXT.md specify exactly how each issue type is handled

**Research date:** 2026-03-14
**Valid until:** Until gecs_network source changes (stable — this is a docs-only phase)

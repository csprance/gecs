# Phase 12: Entry Points - Research

**Researched:** 2026-03-14
**Domain:** README authoring — GDScript API accuracy, install documentation, quick-start code correctness
**Confidence:** HIGH

## Summary

Phase 12 rewrites three README files: the root `README.md`, `addons/gecs/README.md`, and `addons/gecs_network/README.md`. All three files have been read in full and their current state is understood. The work is a targeted editing pass, not a ground-up rewrite — most content is structurally sound. The key changes are: (1) adding a proper install section with three labeled paths to the root README, (2) fixing the root README quick-start code to compile against GECS v6.8.1, (3) cleaning up the gecs addon README (remove "Deferred Execution" version-stamped entry, replace SyncConfig reference with NetAdapter), and (4) adding Step 4 (NetworkSession) to the network addon README quick start.

All API used in quick-start snippets has been verified against actual source files. The STATE.md already records the specific changes made in a prior session — this research confirms what the planner needs to produce accurate tasks.

**Primary recommendation:** Edit each README file in a single focused task per file. The changes are well-scoped and the source of truth for all API details is the live .gd files already read during this session.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Quick-start code (root README)**
- Medium depth (~40 lines): show entity creation, add_component(), relationships, and a full System with process()
- Show both component patterns in one snippet: `@export var` with a default AND a custom `_init()` with a parameter — with a comment explaining that every property needs a default or Godot will error
- Include `ECS.process(delta)` in a `_process()` function so the loop is complete
- Code must actually compile and run against GECS v6.8.1 — no illustrative-only snippets

**Feature list (root README)**
- Keep emoji in the feature list bullets only (🎯 🚀 etc.) — README landing pages are different from reference docs
- Keep "Battle Tested — Used in games being actively developed." as-is
- Include Debug Viewer in the feature list — it exists in v6.8.1
- GECS Network: reference as a separate optional addon with a link, not a core GECS feature

**Install instructions (root README)**
- Cover all three install paths: Godot Asset Library, manual copy, git submodule
- Add a Requirements section stating Godot 4.x minimum
- GECS Network install lives in the network addon's own README only — root README links to it

**Addon README relationship**
- Root README and gecs addon README serve the same audience — one is for GitHub visitors, one for in-editor browsing after install. Keep them essentially the same depth and content.
- Emoji policy for READMEs: keep emoji in feature lists and section headers (same as root README) — does NOT apply the strict no-emoji policy from docs Phase 8-11

**GECS addon README**
- Keep the Learning Path and topic tables — useful navigation for the in-editor experience
- Transport providers claim ("ENet, Steam, or custom backends") is accurate — both `ENetTransportProvider` and `SteamTransportProvider` exist in source. Keep it.

**GECS Network addon README quick start**
- Add Step 4: Start a session with NetworkSession (host/join/end_session API)
- NetworkSession is the primary entry point from Phase 7 and must appear in the quick start
- Steps: 1) declare sync priorities, 2) define_components with CN_NetworkIdentity + CN_NetSync, 3) attach NetworkSync, 4) start session with NetworkSession

### Claude's Discretion

- Exact phrasing of install step text
- Whether to use numbered steps or headings for install paths
- Exact wording of Requirements section
- What code appears in the NetworkSession quick start step (use real API from network_session.gd)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| READ-01 | Root README.md rewritten as clean, accurate project homepage — correct install steps, real quick-start code | Root README current state read; install section is absent; quick-start code has type bug (Vector3 vs Vector2 vs Vector3); fix confirmed from STATE.md; all API verified against source |
| READ-02 | GECS addon README and network addon README consistent with rewritten docs | gecs/README.md: "Deferred Execution" entry is version-stamped prose (not doc link), SyncConfig table reference outdated; gecs_network/README.md: network_session.gd present in file structure but missing from quick start; both files read and deltas identified |
</phase_requirements>

## Standard Stack

### Core
| Item | Version/State | Purpose | Why Standard |
|------|--------------|---------|--------------|
| GECS addon | 6.8.1 | ECS framework | Plugin version in plugin.cfg |
| GDScript | Godot 4.x | Language for all code examples | Project language |
| `Component` base | Resource subclass | Data container | Verified in component.gd |
| `Entity` base | Node subclass | Entity container | Verified in CLAUDE.md |
| `System` base | Node subclass, `process()` signature | Logic processor | Verified in CLAUDE.md |
| `ECS` singleton | auto-load at `res://addons/gecs/ecs.gd` | Global world access | project.godot setting |

### Supporting
| Item | Purpose | When to Use |
|------|---------|-------------|
| `NetworkSession` | Host/join/end_session — the multiplayer entry point | Network addon quick start step 4 |
| `ENetTransportProvider` | Default ENet transport | Default if no transport assigned |
| `SteamTransportProvider` | Steam transport | When GodotSteam is present |
| `NetworkSync` | Main sync orchestrator | Attached to World — usually managed by NetworkSession internally |

## Architecture Patterns

### Component: Two Patterns in One Snippet

The CONTEXT.md requires showing both patterns. Both are valid GDScript:

```gdscript
# Pattern 1: @export var with default (no constructor needed)
# All properties need a default value or Godot will error
class_name C_Health
extends Component

@export var current: int = 100
@export var max_health: int = 100


# Pattern 2: custom _init() with a parameter
class_name C_Velocity
extends Component

@export var direction: Vector3 = Vector3.ZERO  # default required even with _init

func _init(dir: Vector3 = Vector3.ZERO) -> void:
    direction = dir
```

**Key fact verified from source:** `Component` extends `Resource`, not `Node`. Properties must have defaults because Godot's Resource system requires it.

### Quick-Start Entity and System Pattern

The current root README quick-start calls `ECS.world.process(delta)` — this should be `ECS.process(delta)` per the ECS singleton API shown in ecs.gd docstring examples. The CONTEXT decision requires `ECS.process(delta)` inside `_process()`.

Entity creation and world addition pattern (verified from CLAUDE.md and ecs.gd):
```gdscript
var player = Entity.new()
player.add_component(C_Health.new())
player.add_component(C_Velocity.new(Vector3(5, 0, 0)))
ECS.world.add_entity(player)
```

System pattern (verified from CLAUDE.md):
```gdscript
class_name VelocitySystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var vel := entity.get_component(C_Velocity) as C_Velocity
        vel.direction += Vector3.DOWN * delta
```

ECS process loop:
```gdscript
func _process(delta: float) -> void:
    ECS.process(delta)
```

### Install Section Structure

The root README currently has no dedicated install section — only a "Quick Start" with a single download bullet. The CONTEXT requires three labeled subsections:

1. **Godot Asset Library** — search "GECS" in Godot editor, one-click install
2. **Manual copy** — download release zip, copy `addons/gecs/` to project
3. **Git submodule** — `git submodule add` command with the release branch syntax from CLAUDE.md

Requirements section content: "Godot 4.x (tested with 4.6+)"

### NetworkSession Quick-Start Step 4

Real API from `network_session.gd` (verified):
- `host(port: int = -1) -> Error` — starts hosting on `default_port` (7777) if port omitted
- `join(ip: String, port: int = -1) -> Error` — connects to ip on `default_port` if port omitted
- `end_session() -> void` — cleans up all network resources
- `transport: TransportProvider` — exported property, defaults to `ENetTransportProvider.new()` in `_ready()`
- Must be added to the scene tree as a child node before calling `host()`/`join()`

Minimal step 4 snippet:
```gdscript
### Step 4: Start a session with NetworkSession

func _ready() -> void:
    var session = NetworkSession.new()
    add_child(session)
    session.host()  # or session.join("192.168.1.10")
```

`NetworkSession` does NOT call `world.process()` internally (verified in source — comment on line 75: "Game code is responsible for calling world.process()"). This is worth noting in the quick start.

### gecs addon README: Required Edits

Two specific content fixes identified from STATE.md and confirmed by reading the file:

1. **"Deferred Execution" section** (line 29-31 in current file): This is prose, not a doc link. The CONTEXT says to remove the version stamp. The section reads:
   > **CommandBuffer** - Queue structural changes during iteration with `cmd`. Eliminates backwards iteration and defensive snapshots. Three flush modes: PER_SYSTEM, PER_GROUP, MANUAL.

   This content is accurate but has no version badge — nothing to strip. The STATE.md entry says "Deferred Execution version stamp removed" which may refer to a different version of the file. Verify during execution.

2. **Networking table row** (line 71-72): The "Configuration" row links to `configuration.md` with description "NetAdapter, priority tiers, ProjectSettings" — this is already correct from Phase 11 work. However, STATE.md entry says "SyncConfig replaced with NetAdapter in networking table." The current file at line 71 shows the description already reads "NetAdapter, priority tiers, ProjectSettings." Confirm current state during task execution before making changes.

### gecs_network addon README: Required Edit

File structure table already includes `network_session.gd` (line 67 in current file). The quick start has only 3 steps. Step 4 using `NetworkSession` needs to be added after the existing step 3.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Install path documentation | Custom format | Use the three-subsection pattern locked in CONTEXT.md |
| NetworkSession API signatures | Guessing from name | Read `network_session.gd` (already done) |
| Component syntax examples | Assumptions | Verify against `component.gd` and CLAUDE.md (already done) |

## Common Pitfalls

### Pitfall 1: Wrong `ECS.process()` call form
**What goes wrong:** Root README currently calls `ECS.world.process(delta)` instead of `ECS.process(delta)`. These are different — `ECS.process(delta)` is the preferred singleton API.
**How to avoid:** Always use `ECS.process(delta)` in quick-start examples.

### Pitfall 2: Vector type mismatch in quick-start
**What goes wrong:** STATE.md records "Vector2 -> Vector3 type fix in quick-start example (C_Velocity._init takes Vector3)". The current README code passes `Vector3(5, 0, 0)` which is already fixed. Verify the new quick-start snippet uses Vector3 consistently.
**How to avoid:** Use `Vector3` for velocity/direction throughout.

### Pitfall 3: Component properties without defaults
**What goes wrong:** GDScript Resources require all exported properties to have default values or Godot errors at export time.
**How to avoid:** Include the comment `# All properties need a default value or Godot will error` in the quick-start snippet, and ensure every `@export var` in the example has a default.

### Pitfall 4: Emoji policy confusion
**What goes wrong:** Phases 8-11 applied strict no-emoji to docs. READMEs follow a different policy: emoji allowed in feature list bullets and section headers.
**How to avoid:** Keep emoji in feature bullets (🎯 🚀 etc.) and section headers on READMEs. Remove emoji only from body text paragraphs if any exist there.

### Pitfall 5: NetworkSession scene tree requirement
**What goes wrong:** Calling `session.host()` before `add_child(session)` — `_ready()` won't have run and `transport` will be null.
**How to avoid:** Show `add_child(session)` before `session.host()` in the quick-start snippet.

## Code Examples

### NetworkSession Step 4 (verified against network_session.gd)

```gdscript
### Step 4: Start a session with NetworkSession

func _ready() -> void:
    var session = NetworkSession.new()
    add_child(session)       # _ready() sets default transport (ENet) automatically
    session.host()           # host on port 7777
    # or: session.join("192.168.1.10")  # join as client
```

### Full Root README Quick-Start (target structure)

The planner should build approximately 40 lines covering:
1. Component definitions (both `@export var` pattern and `_init()` pattern, with default-value comment)
2. Entity creation with `add_component()` calls
3. Relationship creation with `Relationship.new()`
4. A System class with `query()` and `process()`
5. World setup: `ECS.world.add_entity()` / `ECS.world.add_system()`
6. Main scene `_process()` calling `ECS.process(delta)`

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `SyncConfig` (v0.1.x) | `NetAdapter` + `@export_group` priority annotations | Confirmed replaced in Phase 11 |
| Backwards iteration for entity removal | `cmd.remove_entity(entity)` (CommandBuffer) | v6.8.0+ |
| `ECS.world.process(delta)` | `ECS.process(delta)` | ECS singleton is the preferred call site |

## Open Questions

1. **gecs addon README "Deferred Execution" version stamp**
   - What we know: STATE.md says "Deferred Execution version stamp removed" was done in Phase 12
   - What's unclear: Current file at line 29-31 shows no version badge — the stamp may already be gone from a previous run
   - Recommendation: During task execution, read the file fresh and confirm whether any "v6.8.0" or similar text appears in that section before touching it

2. **gecs addon README networking table SyncConfig reference**
   - What we know: STATE.md says "SyncConfig replaced with NetAdapter" was done in Phase 12; current file already shows "NetAdapter" in the description column
   - What's unclear: Whether a prior execution already applied this change
   - Recommendation: During task execution, read current file state and skip if already correct

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | gdUnit4 (Godot test runner) |
| Config file | addons/gdUnit4/runtest.cmd (Windows) |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"` |
| Full suite command | Same as quick run |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| READ-01 | Root README install steps are correct and complete | manual-only | N/A — no automated way to test install step accuracy | N/A |
| READ-01 | Quick-start GDScript compiles against GECS v6.8.1 | manual-only | N/A — code in README is not executed by test suite; requires human review | N/A |
| READ-02 | gecs addon README consistent with Phase 8-11 docs | manual-only | N/A — cross-doc consistency is a human review task | N/A |
| READ-02 | gecs_network README quick-start includes NetworkSession step | manual-only | N/A — README content review | N/A |

**Justification for manual-only:** All READ requirements are documentation accuracy requirements. The GDScript quick-start snippet in README.md is not a runnable test file — it is illustrative code that would require standing up a full Godot project to execute. Automated test coverage of README content is out of scope for this project. Verification is done by code review: compare each snippet against the verified source API (which was already done during this research pass).

### Sampling Rate
- **Per task commit:** Not applicable — no automated test to run
- **Per wave merge:** Not applicable
- **Phase gate:** Human review of each README before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements (all requirements are manual-only README review tasks, not testable by the automated suite).

## Sources

### Primary (HIGH confidence)
- `addons/gecs/ecs/ecs.gd` — ECS.process(delta) call form, world access pattern
- `addons/gecs/ecs/component.gd` — Component base class, Resource extension, property default requirement
- `addons/gecs_network/network_session.gd` — host(), join(), end_session() signatures, transport default behavior, add_child() requirement
- `addons/gecs/plugin.cfg` — version 6.8.1 confirmed
- `addons/gecs_network/transports/enet_transport_provider.gd`, `steam_transport_provider.gd` — transport provider classes confirmed to exist
- `README.md`, `addons/gecs/README.md`, `addons/gecs_network/README.md` — current file state read in full
- `CLAUDE.md` — component, entity, system creation patterns; naming conventions; ECS singleton autoload path
- `.planning/STATE.md` — prior Phase 12 session changes recorded

### Secondary (MEDIUM confidence)
- `.planning/milestones/v0.2-phases/12-entry-points/12-CONTEXT.md` — locked decisions directly from user discussion

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all classes verified in source
- Architecture: HIGH — patterns verified against CLAUDE.md and live source files
- Pitfalls: HIGH — derived from STATE.md recorded fixes and source verification
- Validation: HIGH — all requirements are manual review; confirmed no automated tests exist or are needed

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (stable domain — GDScript API does not change between sessions)

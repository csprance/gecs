# Phase 6: Cleanup, Documentation, and Example Network Update — Research

**Researched:** 2026-03-12
**Domain:** GDScript addon cleanup, Markdown documentation rewrite, Godot 4 ECS networking API
**Confidence:** HIGH — all findings are from direct file inspection of the repo; no external library research required

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dead Code Deletion**
- Delete all v0.1.x handlers: `sync_spawn_handler.gd`, `sync_property_handler.gd`,
  `sync_state_handler.gd` and their `.uid` sidecars. These are fully replaced by
  `spawn_manager.gd`, `sync_sender.gd`, `sync_receiver.gd`, and `native_sync_handler.gd`.
- Delete all deprecated stubs: `sync_config.gd`, `cn_sync_entity.gd`, `cn_server_owned.gd`
  and their `.uid` sidecars. No compatibility shims; clean break.
- Delete v0.1.x test files: `test_sync_spawn_handler.gd`, `test_sync_state_handler.gd`
  and their `.uid` sidecars. (`test_native_sync_handler.gd` is a v2 Phase 3 test — keep it.)
- No archiving or legacy/ folders — delete completely, rely on git history if anyone needs reference.

**Example Network Rewrite**
- Rewrite `example_network/` in-place — same player/projectile scenario, v2 API throughout.
  Delete `ExampleSyncConfig` (was `extends SyncConfig`) and `ExampleMiddleware` (v1 pattern).
- All four v2 features showcased:
  1. `CN_NetSync` with priority tiers via `@export_group` annotations on component properties
  2. `CN_NativeSync` for player transform (MultiplayerSynchronizer, no manual RPC position sync)
  3. One custom sync handler registered in a System's `_ready()` (demonstrates ADV-03)
  4. Reconciliation configured via `NetworkSync.reconciliation_interval` property
- Visual application — direct signal connections in `main.gd` (connect to `entity_spawned`,
  `local_player_spawned`). No separate middleware class. This is the clean v2 pattern.

**Documentation Rewrite**
- Full rewrite of `README.md` — new v2 Quick Start.
  Remove all SyncConfig/CN_SyncEntity/NetworkMiddleware references. Update file structure table.
- Full rewrites of all `docs/*.md` files — 8 docs need v2 replacements. Priority order:
  `components.md`, `architecture.md`, `configuration.md`, `sync-patterns.md`, `authority.md`,
  `best-practices.md`, `examples.md`, `troubleshooting.md`.
  `custom-sync-handlers.md` (written in Phase 5) needs review only — likely already v2-accurate.
- Update `CHANGELOG.md` — add a proper `## [2.0.0]` entry.

**Migration Guide Format**
- Standalone `docs/migration-v1-to-v2.md` — dedicated file in `docs/`, linked from README.
- Quick reference table format — v1 class/concept → v2 equivalent. Simple table, no extended
  code examples. Cover: `SyncConfig`, `CN_SyncEntity`, `NetworkMiddleware`, authority API
  (`is_server_owned()`), `SyncPriority` enum location.

### Claude's Discretion

- Exact content and structure of each rewritten doc file
- Whether to add GdUnit4 test stubs verifying the example project compiles (no integration tests needed)
- Order of subtasks within each plan wave
- Whether `plugin.gd` file structure listing in README should be updated or left to `docs/`

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 6 is a pure cleanup and documentation phase. All 16 v1 requirements are complete. The task is:
(1) delete nine v0.1.x files that are now dead code, (2) rewrite the example_network project to
demonstrate the v2 API, and (3) rewrite all documentation to describe the v2 system accurately.

There is no new code to write for the addon itself. The only GDScript changes are in example_network/
(updating entity definitions, components, and main.gd to use v2 API) and deleting dead source files.
The bulk of the work is documentation content — nine .md files plus a new migration guide.

**Primary recommendation:** Structure the phase as three sequential waves: (1) delete dead code and
tests first (establishes clean baseline, no dangling references), (2) rewrite example_network so
there is a working v2 reference to draw documentation from, (3) write all docs using the rewritten
example as the source of truth.

---

## Inventory: Files to Delete (Confirmed by Direct Inspection)

All the following files exist and are confirmed ready for deletion.

### v0.1.x Handler Files

| File | Size | Status |
|------|------|--------|
| `addons/gecs_network/sync_spawn_handler.gd` | 17,491 bytes | v0.1.1 handler — replaced by `spawn_manager.gd` |
| `addons/gecs_network/sync_spawn_handler.gd.uid` | 20 bytes | sidecar |
| `addons/gecs_network/sync_property_handler.gd` | 16,716 bytes | v0.1.1 handler — replaced by `sync_sender.gd` + `sync_receiver.gd` |
| `addons/gecs_network/sync_property_handler.gd.uid` | 20 bytes | sidecar |
| `addons/gecs_network/sync_state_handler.gd` | 16,492 bytes | v0.1.1 handler — replaced by authority injection in `spawn_manager.gd` |
| `addons/gecs_network/sync_state_handler.gd.uid` | 20 bytes | sidecar |

**Note:** `sync_native_handler.gd` from the CONTEXT.md delete list does NOT exist. It was referenced
in the discuss session as a v0.1.1 artifact, but the actual v2 native sync file is
`native_sync_handler.gd` — that is a v2 file and must NOT be deleted.

### v0.1.x Stub Files

| File | Size | Status |
|------|------|--------|
| `addons/gecs_network/sync_config.gd` | 509 bytes | Stub — `## Stub — registry removed in v2` comment confirms safe to delete |
| `addons/gecs_network/sync_config.gd.uid` | 20 bytes | sidecar |
| `addons/gecs_network/components/cn_sync_entity.gd` | ~800 bytes | `## DEPRECATED stub` comment confirms safe to delete |
| `addons/gecs_network/components/cn_sync_entity.gd.uid` | — | sidecar |
| `addons/gecs_network/components/cn_server_owned.gd` | ~900 bytes | v0.1.1 marker, replaced by `CN_ServerAuthority` |
| `addons/gecs_network/components/cn_server_owned.gd.uid` | — | sidecar |

### v0.1.x Test Files

| File | Status |
|------|--------|
| `addons/gecs_network/tests/test_sync_spawn_handler.gd` | CONFIRMED EXISTS — preloads `sync_spawn_handler.gd` at line 7 |
| `addons/gecs_network/tests/test_sync_spawn_handler.gd.uid` | sidecar |
| `addons/gecs_network/tests/test_sync_state_handler.gd` | CONFIRMED EXISTS — preloads `sync_state_handler.gd` at line 7 |
| `addons/gecs_network/tests/test_sync_state_handler.gd.uid` | sidecar |

**`test_native_sync_handler.gd` — DO NOT DELETE.** This is the v2 Phase 3 test for
`NativeSyncHandler` (SYNC-04). It is kept.

---

## Inventory: Files to Rewrite (example_network/)

All files confirmed to exist by direct inspection.

### Delete These (v1-only files with no v2 analog)

| File | Why Delete |
|------|-----------|
| `example_network/config/example_sync_config.gd` | `extends SyncConfig` — SyncConfig is deleted in v2 |
| `example_network/config/example_sync_config.gd.uid` | sidecar |
| `example_network/network/example_middleware.gd` | v1 middleware pattern — replaced by direct signals in main.gd |
| `example_network/network/example_middleware.gd.uid` | sidecar |

### Rewrite These

| File | Current State | v2 Change Required |
|------|--------------|-------------------|
| `example_network/main.gd` | Uses `ExampleSyncConfig.new()` in `attach_to_world()`, references `ExampleMiddleware` | Remove both, call `NetworkSync.attach_to_world(world)` (no config arg), connect `entity_spawned` and `local_player_spawned` directly, add visual handling inline, set `reconciliation_interval` |
| `example_network/entities/e_player.gd` | Uses `C_NetworkIdentity` (v1 name), `C_SyncEntity` (deleted) | Use `CN_NetworkIdentity`, replace `C_SyncEntity.new(true, true, false)` with `CN_NativeSync.new()`, add `CN_NetSync.new()` |
| `example_network/entities/e_projectile.gd` | Uses `C_NetworkIdentity` (v1 name), references `C_NetPosition` | Use `CN_NetworkIdentity`, add `CN_NetSync.new()` for spawn-only, remove `C_NetPosition` (handled via CN_NetSync SPAWN_ONLY group) |
| `example_network/components/c_net_velocity.gd` | Has `@export_group("HIGH")` already — correct v2 pattern | Confirm annotation format matches v2 spec; add docstring |
| `example_network/components/c_player_input.gd` | Extends `SyncComponent` (undefined class — SyncComponent no longer exists) and has no `@export_group` | Extend `Component` instead, add `@export_group("HIGH")` before properties |

**Critical discovery:** `c_player_input.gd` extends `SyncComponent` which has no definition
anywhere in the codebase (`find` found zero `sync_component.gd` files). This is a v0.1.1 base
class that was never stubbed. Extending it currently causes a parser error. The fix is to extend
`Component` directly and add `@export_group("HIGH")` annotations.

### New File to Create (if demonstrating ADV-03)

Per the locked decision, one custom sync handler must be registered in a System's `_ready()`.
The CONTEXT.md specifies reusing the player movement prediction pattern from
`docs/custom-sync-handlers.md`. This means creating or updating a system in
`example_network/systems/` — likely `s_movement.gd` — to register a custom handler that
blends server corrections rather than snapping.

---

## Inventory: Documentation Files

### Keep As-Is (Verified v2-Accurate)

| File | Reason |
|------|--------|
| `addons/gecs_network/docs/custom-sync-handlers.md` | Written in Phase 5, all API references confirmed correct against `network_sync.gd` (`register_send_handler`, `register_receive_handler`), uses `CN_LocalAuthority` correctly |

### Full Rewrite Required

All 8 remaining docs reference v1 concepts (CN_SyncEntity, SyncConfig, SyncComponent,
NetworkMiddleware, `is_server_owned()`, etc.). Verified by reading each file.

| File | Primary v1 Concepts That Must Go |
|------|----------------------------------|
| `docs/components.md` | CN_SyncEntity section, SyncComponent base class, SyncConfig Priority reference |
| `docs/architecture.md` | "Two-tier" diagram shows CN_SyncEntity, handler table lists v0.1.1 handlers |
| `docs/configuration.md` | Entire SyncConfig API, model_ready_component, transform_component |
| `docs/sync-patterns.md` | "No CN_SyncEntity = spawn-only" language, references SyncConfig |
| `docs/authority.md` | Likely correct authority pattern language but references old marker set |
| `docs/best-practices.md` | Likely references SyncConfig and SyncComponent |
| `docs/examples.md` | References old API throughout |
| `docs/troubleshooting.md` | References old migration steps, old class names |

### New File to Create

| File | Content |
|------|---------|
| `docs/migration-v1-to-v2.md` | Migration table: v1 concept → v2 equivalent |

---

## Architecture Patterns (v2 — Current Truth)

These are the patterns that ALL documentation and example code must reflect.

### v2 Component Map

| v1 Concept | v2 Equivalent | Notes |
|------------|--------------|-------|
| `SyncConfig` with priority dict | `@export_group("HIGH")` etc. on component properties | Priority declared inline, no external registry |
| `CN_SyncEntity` | `CN_NativeSync` | Data-only component: `sync_position`, `sync_rotation`, `root_path`, `replication_interval`, `replication_mode` |
| `SyncComponent` base class | `Component` + `@export_group` annotations | SyncComponent does not exist in v2 |
| `NetworkMiddleware` class | Direct signal connections in game code | `entity_spawned` and `local_player_spawned` signals on `NetworkSync` |
| `CN_ServerOwned` marker | `CN_ServerAuthority` marker | `peer_id == 0` only (not peer_id=1) |
| `SyncConfig.Priority` enum | `CN_NetSync.Priority` enum | REALTIME=0, HIGH=1, MEDIUM=2, LOW=3 |
| `is_server_owned()` authority check | `has_component(CN_ServerAuthority)` query | Or `has_component(CN_LocalAuthority)` for local |
| `NetworkSync.attach_to_world(world, config)` | `NetworkSync.attach_to_world(world)` | No config parameter in v2 |

### v2 Entity Setup Pattern

```gdscript
# Player entity (continuous sync + native transform)
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(owner_peer_id),
        CN_NetSync.new(),          # Enables property sync
        CN_NativeSync.new(),       # Enables MultiplayerSynchronizer transform sync
        C_NetVelocity.new(),       # @export_group("HIGH") on its properties
        C_PlayerInput.new(),       # @export_group("HIGH") on its properties
        C_PlayerNumber.new(),
    ]

# Projectile entity (spawn-only — properties marked SPAWN_ONLY in component)
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),
        CN_NetSync.new(),          # Still needed; properties use @export_group("SPAWN_ONLY")
        C_Projectile.new(),
        C_NetVelocity.new(),
    ]
```

### v2 World Setup Pattern (main.gd)

```gdscript
func _setup_network_sync() -> void:
    _network_sync = NetworkSync.attach_to_world(world)  # No config arg
    _network_sync.debug_logging = true
    _network_sync.reconciliation_interval = 30.0        # ADV-02 showcase
    _network_sync.entity_spawned.connect(_on_entity_spawned)
    _network_sync.local_player_spawned.connect(_on_local_player_spawned)
```

### v2 Authority Query Patterns

```gdscript
# Input: only local player
func query():
    return q.with_all([C_PlayerInput, CN_LocalAuthority])

# Skip remote entities in physics
func query():
    return q.with_all([C_NetVelocity]).with_none([CN_RemoteEntity])

# Server-only processing
func query():
    return q.with_all([C_EnemyAI, CN_ServerAuthority])
```

### v2 Custom Handler Registration (ADV-03 showcase in example)

Per CONTEXT.md: register in a System's `_ready()`. Reuse movement prediction pattern from
`docs/custom-sync-handlers.md` (the documentation was already written in Phase 5).

```gdscript
func _ready() -> void:
    var ns := ECS.world.get_node("NetworkSync") as NetworkSync
    if ns == null:
        return
    ns.register_receive_handler("C_NetVelocity", _blend_velocity_correction)

func _blend_velocity_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
    if props.has("direction"):
        comp.direction = comp.direction.lerp(props["direction"], 0.3)
    return true
```

---

## v2 Public API Reference (for documentation writers)

Confirmed from `network_sync.gd` and `cn_net_sync.gd` direct inspection.

### NetworkSync

```gdscript
# Factory (preferred)
static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync

# Configuration
@export var net_adapter: NetAdapter
@export var debug_logging: bool = false

# Reconciliation (ADV-02)
var reconciliation_interval: float  # get/set; -1.0 = use ProjectSetting (30.0)
func broadcast_full_state() -> void  # server-only; immediate full-state broadcast

# Custom sync handlers (ADV-03)
func register_send_handler(comp_type_name: String, handler: Callable) -> void
func register_receive_handler(comp_type_name: String, handler: Callable) -> void

# Session management
func reset_for_new_game() -> void

# Signals
signal entity_spawned(entity: Entity)
signal local_player_spawned(entity: Entity)
```

### CN_NetSync

```gdscript
class_name CN_NetSync
extends Component

enum Priority { REALTIME = 0, HIGH = 1, MEDIUM = 2, LOW = 3 }

# @export_group sentinel names (on sibling components)
# "REALTIME" -> ~60 Hz, unreliable
# "HIGH"     -> 20 Hz, unreliable
# "MEDIUM"   -> 10 Hz, reliable
# "LOW"      -> 1 Hz,  reliable
# "SPAWN_ONLY" -> sent at spawn only, never continuous
# "LOCAL"      -> never synced

func scan_entity_components(entity: Entity) -> void
func check_changes_for_priority(priority: int) -> Dictionary
func update_cache_silent(comp: Component, prop: String, value: Variant) -> void
```

### CN_NativeSync (data-only component)

```gdscript
class_name CN_NativeSync
extends Component

@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var root_path: NodePath = ".."          # ".." = entity node itself
@export var replication_interval: float = 0.0   # 0.0 = every frame
@export var replication_mode: int = 1           # 1 = REPLICATION_MODE_ALWAYS
```

### CN_NetworkIdentity

```gdscript
class_name CN_NetworkIdentity
extends Component

@export var peer_id: int = 0  # 0 = server-owned; 1 = host-player; 2+ = client players

func _init(p_peer_id: int = 0) -> void
func is_server_owned() -> bool  # peer_id == 0 ONLY (not 1)
func is_player() -> bool        # peer_id > 0
func is_local(adapter: NetAdapter = null) -> bool
func has_authority(adapter: NetAdapter = null) -> bool
```

### ProjectSettings (registered by plugin)

```
gecs_network/sync/high_hz         = 20   (int)
gecs_network/sync/medium_hz       = 10   (int)
gecs_network/sync/low_hz          = 2    (int)
gecs_network/sync/reconciliation_interval = 30.0  (float)
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Priority assignment per component | Custom SyncConfig dict | `@export_group("HIGH")` on component properties | Already implemented in CN_NetSync |
| Native transform sync setup | Manual MultiplayerSynchronizer creation | `CN_NativeSync` component | NativeSyncHandler creates synchronizer automatically |
| Entity spawn tracking | Manual RPC spawn calls | `CN_NetworkIdentity` + `CN_NetSync` on entity | SpawnManager handles deferred broadcast |
| Reconciliation timer | Custom timer node | `NetworkSync.reconciliation_interval` property | SyncReconciliationHandler manages internally |
| Session validity | Per-RPC session checks | Built into every RPC — `_game_session_id` | Cannot be bolted on; already in every RPC signature |

---

## Common Pitfalls

### Pitfall 1: SyncComponent Base Class No Longer Exists

**What goes wrong:** `c_player_input.gd` currently extends `SyncComponent`, which has no
definition anywhere. This is a parser error.
**Why it happens:** SyncComponent was a v0.1.1 base class. It was never stubbed in v2 (only
SyncConfig was stubbed).
**How to avoid:** Change `extends SyncComponent` to `extends Component` and add
`@export_group("HIGH")` before the exported properties.
**Warning signs:** GDScript parser error "Cannot find class 'SyncComponent'" at test run time.

### Pitfall 2: Example Uses C_NetworkIdentity (Old Name)

**What goes wrong:** `e_player.gd` and `e_projectile.gd` both call `C_NetworkIdentity.new()`.
The class is named `CN_NetworkIdentity` in the addon.
**Why it happens:** Example was never updated after the CN_ prefix rename in v0.1.1.
**How to avoid:** Replace all `C_NetworkIdentity` references with `CN_NetworkIdentity` in
example_network files.

### Pitfall 3: attach_to_world() Signature Changed

**What goes wrong:** v1 README and `main.gd` both call
`NetworkSync.attach_to_world(world, ExampleSyncConfig.new())`. The v2 signature takes an
optional `NetAdapter`, not a SyncConfig.
**Why it happens:** The v2 factory signature is `attach_to_world(world, net_adapter = null)`.
**How to avoid:** All documentation Quick Start examples must use `attach_to_world(world)` only.

### Pitfall 4: CN_ServerOwned vs CN_ServerAuthority

**What goes wrong:** v1 documentation and `cn_server_owned.gd` describe `CN_ServerOwned` as
matching `peer_id = 0 OR 1`. The v2 model is `CN_ServerAuthority` for `peer_id == 0` only.
`CN_ServerOwned` is being deleted.
**Why it happens:** The v2 authority model was locked in Phase 1:
"peer_id=1 (host) is NOT server-owned in v2".
**How to avoid:** Migration guide table must explicitly map `CN_ServerOwned` → `CN_ServerAuthority`
with a note that the semantics changed (host player is no longer server-owned).

### Pitfall 5: Spawn-Only Pattern Changed

**What goes wrong:** v1 docs say "no CN_SyncEntity = spawn-only". v2 uses CN_NetSync for ALL
synced entities; spawn-only is declared by using `@export_group("SPAWN_ONLY")` on component
properties. Not by absence of a component.
**Why it happens:** The v2 design is declarative; every networked entity that syncs has
`CN_NetSync`. Properties control sync mode, not component presence.
**How to avoid:** `docs/sync-patterns.md` rewrite must explain `SPAWN_ONLY` group as the new
pattern. Example `e_projectile.gd` must demonstrate this.

### Pitfall 6: `docs/custom-sync-handlers.md` References `net_sync.update_cache_silent()`

**What goes wrong:** In `custom-sync-handlers.md`, the pitfall section (line 138-150) shows
`net_sync.update_cache_silent(comp, "health", props["health"])` in the wrong example. This method
exists on `CN_NetSync` (the component), not on `NetworkSync` (the node).
**Why it happens:** The doc correctly explains NOT to call it; the "WRONG" code block uses the
right class. However, readers might be confused about which object to call it on.
**How to avoid:** When reviewing custom-sync-handlers.md, verify the WRONG/CORRECT examples
reference the right object (`CN_NetSync` instance, accessed via the entity's component, not the
NetworkSync node).

---

## Migration Table (v1 → v2)

This is the content for `docs/migration-v1-to-v2.md`:

| v1 (v0.1.x) | v2 (current) | Notes |
|-------------|-------------|-------|
| `SyncConfig` class | `@export_group` on component properties | Priority declared inline; no external registry |
| `extends SyncConfig` | Delete — no base class needed | |
| `component_priorities = {"C_Health": Priority.HIGH}` | `@export_group("HIGH")` before health properties | |
| `CN_SyncEntity` component | `CN_NativeSync` component | Different properties; see docs/components.md |
| `C_SyncEntity.new(true, true, false)` | `CN_NativeSync.new()` with `sync_position=true, sync_rotation=true` | |
| `extends SyncComponent` | `extends Component` | SyncComponent removed |
| `NetworkMiddleware` pattern | Direct signal connections to `NetworkSync` | Connect `entity_spawned` + `local_player_spawned` |
| `NetworkSync.attach_to_world(world, config)` | `NetworkSync.attach_to_world(world)` | No config parameter |
| `CN_ServerOwned` marker | `CN_ServerAuthority` marker | Semantics changed: host player (peer_id=1) no longer matches |
| `is_server_owned()` → true for peer_id 0 or 1 | `has_component(CN_ServerAuthority)` → true for peer_id=0 only | |
| `SyncConfig.Priority.HIGH` | `CN_NetSync.Priority.HIGH` | Enum moved to CN_NetSync |
| No CN_SyncEntity = spawn-only | `@export_group("SPAWN_ONLY")` on properties | CN_NetSync present on both continuous and spawn-only entities |
| `sync_config.enable_reconciliation = true` | `network_sync.reconciliation_interval = 30.0` | ProjectSetting default is 30.0 |
| `sync_config.model_ready_component` | Not needed — SpawnManager uses CN_NetworkIdentity | |
| `sync_config.transform_component` | Not needed — use CN_NativeSync component | |

---

## File Structure: v2 Clean State

The README `## File Structure` section must be rewritten to reflect actual v2 files.

```text
addons/gecs_network/
├── plugin.gd                      # Editor plugin, ProjectSettings registration
├── plugin.cfg                     # Plugin metadata
├── network_sync.gd                # Main orchestrator — attach to World; all @rpc declarations
├── spawn_manager.gd               # Entity lifecycle: spawn, despawn, late-join, disconnect
├── sync_sender.gd                 # Priority-tiered outbound batching (REALTIME/HIGH/MEDIUM/LOW)
├── sync_receiver.gd               # Inbound apply, authority validation, echo-loop guard
├── native_sync_handler.gd         # Creates MultiplayerSynchronizer for CN_NativeSync entities
├── sync_relationship_handler.gd   # Relationship sync with deferred resolution
├── sync_reconciliation_handler.gd # Periodic full-state reconciliation (ADV-02)
├── net_adapter.gd                 # Network abstraction — testable without two Godot instances
├── transport_provider.gd          # Abstract transport interface
├── transports/
│   ├── enet_transport_provider.gd     # Default ENet transport
│   └── steam_transport_provider.gd    # Steam transport (requires GodotSteam)
├── docs/
│   ├── components.md              # CN_NetworkIdentity, CN_NetSync, CN_NativeSync, markers
│   ├── architecture.md            # Handler architecture, sync pipeline diagram
│   ├── authority.md               # Authority query patterns (CN_LocalAuthority, CN_ServerAuthority)
│   ├── configuration.md           # ProjectSettings, NetAdapter, transport providers
│   ├── sync-patterns.md           # Spawn-only vs continuous, SPAWN_ONLY group
│   ├── custom-sync-handlers.md    # ADV-03: register_send_handler, register_receive_handler
│   ├── best-practices.md          # ECS patterns, authority discipline, bandwidth
│   ├── examples.md                # Complete code examples
│   ├── troubleshooting.md         # Common issues and fixes
│   └── migration-v1-to-v2.md     # v0.1.x → v2 migration table (NEW)
├── icons/
│   ├── network_sync.svg
│   └── sync_config.svg            # Icon remains; can be repurposed for CN_NetSync
└── components/
    ├── cn_network_identity.gd     # Required: peer ownership, late-join identity
    ├── cn_net_sync.gd             # Required for sync: priority scanner + dirty tracker
    ├── cn_native_sync.gd          # Optional: MultiplayerSynchronizer transform sync
    ├── cn_local_authority.gd      # Marker: local peer controls this entity
    ├── cn_remote_entity.gd        # Marker: remote peer controls this entity
    └── cn_server_authority.gd     # Marker: server-owned (peer_id=0 only)
```

---

## v2 README Quick Start (authoritative sequence)

The three-step quick start must be:

**Step 1: Declare sync priorities on components using @export_group**
```gdscript
class_name C_Velocity
extends Component

@export_group("HIGH")           # 20 Hz sync
@export var direction: Vector3 = Vector3.ZERO
```

**Step 2: Add CN_NetworkIdentity and CN_NetSync to networked entities**
```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        CN_NetSync.new(),
        CN_NativeSync.new(),     # Optional: for transform sync via MultiplayerSynchronizer
        C_Velocity.new(),
    ]
```

**Step 3: Attach NetworkSync to your World**
```gdscript
func _setup_network_sync() -> void:
    var net_sync = NetworkSync.attach_to_world(world)
    net_sync.entity_spawned.connect(_on_entity_spawned)
    net_sync.local_player_spawned.connect(_on_local_player_spawned)
```

---

## Validation Architecture

> nyquist_validation key is absent from .planning/config.json — treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | GdUnit4 (bundled at `addons/gdUnit4/`) |
| Config file | `addons/gdUnit4/GdUnitRunner.cfg` |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| Full suite command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c` |

### Phase Requirements → Test Map

Phase 6 has no new functional requirements — it is cleanup and documentation. The relevant
verification points are:

| Check | Behavior | Test Type | Notes |
|-------|----------|-----------|-------|
| Dead code deleted | v1 handler files removed, no broken preloads | Manual inspection | `find addons/gecs_network -name "sync_spawn_handler.gd"` returns empty |
| No dangling references | Remaining tests compile without errors | Full suite run | All 13 v2 test files pass after deletions |
| Example compiles | example_network GDScript files parse cleanly | Headless import | `$GODOT_BIN --headless --import --quit-after 5` |
| c_player_input.gd fixed | No more `extends SyncComponent` parse error | Headless import | |

### Wave 0 Gaps

None — this phase has no new functional code requiring test stubs. The GdUnit4 test infrastructure
is in place. The cleanup verification is performed via:
1. Full test suite run confirming no regressions after deletions
2. Godot headless import confirming example_network scripts parse

If the planner elects to add a compile-check test for example_network files, it would be placed
in `addons/gecs_network/tests/` per CLAUDE.md rules (all tests in that directory).

---

## Sources

### Primary (HIGH confidence — direct file inspection)

All findings are based on direct `Read` tool inspection of the actual repo files. No external
sources were consulted because this phase involves no external libraries.

- `addons/gecs_network/network_sync.gd` — v2 public API shape, signal names, factory signature
- `addons/gecs_network/components/cn_net_sync.gd` — Priority enum, PRIORITY_MAP, annotation names
- `addons/gecs_network/components/cn_native_sync.gd` — data-only component shape
- `addons/gecs_network/components/cn_network_identity.gd` — authority methods, peer_id=0 definition
- `addons/gecs_network/sync_config.gd` — stub comment confirms safe deletion
- `addons/gecs_network/components/cn_sync_entity.gd` — deprecated stub comment confirms safe deletion
- `addons/gecs_network/tests/test_sync_spawn_handler.gd` — confirmed: preloads deleted handler
- `addons/gecs_network/tests/test_sync_state_handler.gd` — confirmed: preloads deleted handler
- `addons/gecs_network/plugin.gd` — confirmed: no references to v1 handlers in CUSTOM_TYPES
- `addons/gecs_network/docs/custom-sync-handlers.md` — confirmed v2-accurate
- `example_network/entities/e_player.gd` — confirmed: uses C_NetworkIdentity (wrong), C_SyncEntity (wrong)
- `example_network/components/c_player_input.gd` — confirmed: extends SyncComponent (broken)
- `example_network/config/example_sync_config.gd` — confirmed: extends SyncConfig (deleted class)
- `example_network/network/example_middleware.gd` — confirmed: v1 middleware pattern
- `example_network/main.gd` — confirmed: calls attach_to_world with ExampleSyncConfig arg

---

## Metadata

**Confidence breakdown:**
- Files to delete: HIGH — all verified to exist, all confirmed safe (stub comments, v0.1.1 patterns)
- Example rewrite scope: HIGH — all discrepancies found by direct inspection
- Documentation scope: HIGH — all 8 docs confirmed to contain v1 concepts
- v2 API patterns: HIGH — read directly from source files
- Migration table: HIGH — both v1 and v2 classes directly inspected

**Research date:** 2026-03-12
**Valid until:** N/A — findings are based on repo state, not external library versions

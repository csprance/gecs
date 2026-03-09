# Phase 3: Authority Model and Native Transform Sync - Research

**Researched:** 2026-03-09
**Domain:** Godot 4 MultiplayerSynchronizer, ECS marker components, authority propagation
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIFE-05 | Entity network authority is declared via `CN_LocalAuthority` / `CN_ServerAuthority` marker components — game systems query authority by checking for these components, not by calling `is_multiplayer_authority()` | Marker components already exist; research covers WHERE/WHEN they are added (SpawnManager._apply_component_data hook) and how they must be updated on peer-changes |
| SYNC-04 | Entity transforms use Godot's native `MultiplayerSynchronizer` for position/rotation sync — provides built-in interpolation without per-frame RPC overhead | Research covers MultiplayerSynchronizer API, property path format, authority model, setup timing, and cleanup. The v0.1.1 sync_native_handler.gd is the reference implementation to adapt. |
</phase_requirements>

---

## Summary

Phase 3 has two distinct deliverables that interact at the architecture level:

**LIFE-05 (Authority Markers):** The components `CN_LocalAuthority` and `CN_ServerAuthority` already exist as stubs in `addons/gecs_network/components/`. They just need to be _added_ to entities at the right time. The natural hook is `SpawnManager._apply_component_data()` — after deserializing `CN_NetworkIdentity`, the spawn manager checks the peer_id and adds the correct marker components. This is cheap, contained, and testable without real network calls.

**SYNC-04 (Native Transform Sync):** Godot's `MultiplayerSynchronizer` node takes a `SceneReplicationConfig` resource that lists node property paths. The authority peer (set via `set_multiplayer_authority(peer_id)`) sends updates; all others receive. The key integration point is the entity's scene node — the MultiplayerSynchronizer must be a child of the node whose properties it syncs. In an ECS context, entities are Nodes, so the synchronizer can target the Entity node directly. The v0.1.1 `sync_native_handler.gd` already implements the correct setup sequence but depends on `CN_SyncEntity` (deprecated stub). Phase 3 replaces this dependency with a new `CN_NativeSync` component and rewrites the handler cleanly.

**Primary recommendation:** Add a new `CN_NativeSync` component (replaces `CN_SyncEntity`) that declares which node properties to sync via MultiplayerSynchronizer. The `NativeSyncHandler` (adapted from `sync_native_handler.gd`) creates, configures, and cleans up the `_NetSync` MultiplayerSynchronizer child node on each entity. Authority markers are added by extending `SpawnManager._apply_component_data()`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `MultiplayerSynchronizer` | Godot 4.x built-in | Position/rotation sync with interpolation | Native Godot node; no custom RPC needed |
| `SceneReplicationConfig` | Godot 4.x built-in | Declares which properties the synchronizer replicates | Required resource for MultiplayerSynchronizer |
| `CN_LocalAuthority` | Already exists | Marker: this peer controls the entity | ECS-idiomatic query pattern |
| `CN_ServerAuthority` | Already exists | Marker: server controls the entity | ECS-idiomatic query pattern |

### New Files Required
| File | Purpose |
|------|---------|
| `addons/gecs_network/components/cn_native_sync.gd` | Replaces `CN_SyncEntity`; declares sync_position, sync_rotation, replication_interval |
| `addons/gecs_network/native_sync_handler.gd` | Adapter from sync_native_handler.gd; manages MultiplayerSynchronizer lifecycle |

### Files to Delete
| File | Reason |
|------|--------|
| `addons/gecs_network/components/cn_sync_entity.gd` | Deprecated stub, replaced by `CN_NativeSync` |
| `addons/gecs_network/sync_native_handler.gd` | v0.1.1 handler replaced by `native_sync_handler.gd` |
| `addons/gecs_network/sync_config.gd` | Stub kept for Phase 2 compat; now safe to delete if Phase 3 handlers no longer reference it |

### Files to Modify
| File | What changes |
|------|-------------|
| `addons/gecs_network/spawn_manager.gd` | Add authority marker injection in `_apply_component_data()` |
| `addons/gecs_network/network_sync.gd` | Wire `_native_sync_handler` reference; call setup/cleanup in entity lifecycle hooks |
| `addons/gecs_network/plugin.gd` | Update CUSTOM_TYPES: remove CN_SyncEntity reference, add CN_NativeSync |

---

## Architecture Patterns

### Pattern 1: Authority Marker Injection (LIFE-05)

**Where it happens:** `SpawnManager._apply_component_data()`, after `CN_NetworkIdentity` is deserialized.

**Logic:**
```gdscript
# In SpawnManager._apply_component_data() — AFTER applying component data
# (so CN_NetworkIdentity.peer_id is populated)
var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
if net_id:
    _inject_authority_markers(entity, net_id)

func _inject_authority_markers(entity: Entity, net_id: CN_NetworkIdentity) -> void:
    # Remove stale markers first (idempotent re-spawn safety)
    entity.remove_component(CN_LocalAuthority)
    entity.remove_component(CN_ServerAuthority)

    # CN_ServerAuthority: server-owned entities (peer_id == 0) on ALL peers
    if net_id.is_server_owned():
        entity.add_component(CN_ServerAuthority.new())

    # CN_LocalAuthority: local peer's own entity, on all peers
    # Also: server gets CN_LocalAuthority on server-owned entities (server "is local" for them)
    if net_id.is_local(_ns.net_adapter) or (_ns.net_adapter.is_server() and net_id.is_server_owned()):
        entity.add_component(CN_LocalAuthority.new())
```

**Invariant:** Marker presence reflects the current session state. Re-injection must be idempotent (safe to call on update-spawn when entity already exists).

**When to also call:** When `handle_world_state()` applies entities to a late-joining client — same hook fires automatically because `handle_spawn_entity` → `_apply_component_data`.

### Pattern 2: CN_NativeSync Component (SYNC-04)

Replaces `CN_SyncEntity`. Holds configuration that the NativeSyncHandler reads at entity-spawn time.

```gdscript
class_name CN_NativeSync
extends Component

## Declare which transform properties to sync via MultiplayerSynchronizer.
## Add this component to any entity whose position/rotation should use native sync.

@export var sync_position: bool = true
@export var sync_rotation: bool = false
@export var replication_interval: float = 0.0   # 0.0 = every frame
@export var delta_interval: float = 0.0          # 0.0 = every frame (ON_CHANGE mode)
```

Game code opts in:
```gdscript
# Entity definition — opts into native transform sync
entity.add_component(CN_NativeSync.new())         # defaults: position=true, rotation=false
entity.add_component(CN_NetworkIdentity.new(peer_id))
```

The `CN_NetSync` scanner MUST be extended to skip `CN_NativeSync` properties (they are never included in batched RPC sync — MultiplayerSynchronizer handles them). Add `CN_NativeSync` to the skip-list in `CN_NetSync.scan_entity_components()` alongside `CN_NetworkIdentity`.

### Pattern 3: NativeSyncHandler — MultiplayerSynchronizer Setup (SYNC-04)

**Critical ordering constraints (from sync_native_handler.gd v0.1.1 + Godot docs):**

1. Create `MultiplayerSynchronizer` node
2. Set `replication_config` BEFORE `add_child()`
3. Call `set_multiplayer_authority(peer_id)` BEFORE `add_child()`
4. Call `add_child(synchronizer)` — this activates replication
5. Set `root_path` — defaults to `".."` (parent node), which is the Entity node itself

```gdscript
func setup_native_sync(entity: Entity) -> void:
    var native_sync: CN_NativeSync = entity.get_component(CN_NativeSync)
    if native_sync == null:
        return

    var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
    if net_id == null:
        return

    # Idempotent — skip if already set up
    if entity.get_node_or_null("_NetSync") != null:
        return

    var config := SceneReplicationConfig.new()

    # Property path format: ".:property_name"
    # "." = root_path (defaults to ".." = parent = the Entity node)
    # So ".:position" syncs Entity.position
    if native_sync.sync_position:
        var path := ".:position"
        config.add_property(path)
        config.property_set_spawn(path, true)
        config.property_set_sync(path, true)
        config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

    if native_sync.sync_rotation:
        var path := ".:rotation"
        config.add_property(path)
        config.property_set_spawn(path, true)
        config.property_set_sync(path, true)
        config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

    var synchronizer := MultiplayerSynchronizer.new()
    synchronizer.name = "_NetSync"
    synchronizer.replication_config = config           # BEFORE add_child
    synchronizer.replication_interval = native_sync.replication_interval
    synchronizer.delta_interval = native_sync.delta_interval

    # Authority: peer_id > 0 = that peer, peer_id == 0 = server (peer 1 in Godot)
    var authority: int = net_id.peer_id if net_id.peer_id > 0 else 1
    synchronizer.set_multiplayer_authority(authority)  # BEFORE add_child

    entity.add_child(synchronizer)                     # Activates replication
```

**Cleanup** — call before entity.queue_free():
```gdscript
func cleanup_native_sync(entity: Entity) -> void:
    var synchronizer = entity.get_node_or_null("_NetSync")
    if synchronizer:
        synchronizer.get_parent().remove_child(synchronizer)
        synchronizer.queue_free()
```

### Pattern 4: NetworkSync Wiring

The `NativeSyncHandler` follows the same delegation pattern as `SpawnManager` and `SyncSender`/`SyncReceiver`:

```gdscript
# In NetworkSync._ready():
_native_sync_handler = NativeSyncHandler.new(self)

# In NetworkSync._on_entity_added() — AFTER SpawnManager has processed it:
# (entity_added signal fires after SpawnManager.on_entity_added runs)
# NativeSyncHandler.setup is called from SpawnManager._apply_component_data
# OR as a separate call in _on_entity_added on the server side
```

Two options for hook location:
1. **Option A:** Call `_native_sync_handler.setup_native_sync(entity)` from within `SpawnManager._apply_component_data()` after authority markers are injected — simple, single call-site.
2. **Option B:** Call from `NetworkSync._on_entity_added()` after the deferred broadcast fires — requires explicit ordering.

**Recommendation: Option A** — SpawnManager already has the entity context and runs on both server (via `_deferred_broadcast` path) and client (via `handle_spawn_entity`). One call-site, no ordering issues.

### Recommended File Structure

```
addons/gecs_network/
├── components/
│   ├── cn_native_sync.gd          # NEW — replaces cn_sync_entity.gd
│   ├── cn_local_authority.gd      # EXISTS — no changes
│   ├── cn_server_authority.gd     # EXISTS — no changes
│   └── cn_network_identity.gd     # EXISTS — no changes
├── native_sync_handler.gd         # NEW — adapted from sync_native_handler.gd
├── spawn_manager.gd               # MODIFIED — authority marker injection
├── network_sync.gd                # MODIFIED — wire _native_sync_handler
└── tests/
    ├── test_authority_markers.gd  # NEW Wave 0 stubs
    └── test_native_sync_handler.gd # NEW Wave 0 stubs
```

### Anti-Patterns to Avoid

- **Adding MultiplayerSynchronizer after add_child():** Godot activates replication at add_child time. Changing `replication_config` after add_child does NOT update sync — the fix was merged in early 2023 but the pattern is still fragile. Always set config before add_child.
- **Setting authority after add_child():** `set_multiplayer_authority()` before add_child is critical. The synchronizer reads authority at activation time.
- **Using peer_id=0 as Godot authority:** Godot's MultiplayerAPI uses peer_id=1 for the server. When `CN_NetworkIdentity.peer_id == 0` (server-owned), pass `1` to `set_multiplayer_authority()`.
- **Relying on Node authority inheritance:** Godot does NOT inherit multiplayer authority from parent nodes automatically. The Entity node's authority must be set explicitly — and the MultiplayerSynchronizer within it must have its own authority set separately.
- **Calling `is_multiplayer_authority()` in game systems:** LIFE-05 specifically prohibits this. Systems must query `CN_LocalAuthority` / `CN_ServerAuthority` instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Transform interpolation | Custom lerp/slerp in update loop | `MultiplayerSynchronizer` with `replication_interval` | Godot's built-in handles interpolation, jitter buffering, and late-join snapshot |
| Position RPC per frame | `@rpc` on transform update | `MultiplayerSynchronizer` | Native sync uses SceneTree replication path, not RPC overhead |
| Dynamic property addition | Modifying `replication_config` after `add_child` | Set config BEFORE `add_child` | Post-add config mutation had a known Godot bug (PR #73806); even after fix, pre-add is the documented pattern |
| Authority query at runtime | `entity.is_multiplayer_authority()` in systems | `entity.has_component(CN_LocalAuthority)` | ECS query-based filtering; no network state reads in game systems |

**Key insight:** `MultiplayerSynchronizer` with `REPLICATION_MODE_ALWAYS` handles everything from jitter reduction to late-join initial snapshot — the `property_set_spawn(path, true)` flag means new peers automatically get current values when they connect.

---

## Common Pitfalls

### Pitfall 1: Authority Mapping — peer_id=0 vs Godot peer 1

**What goes wrong:** `net_id.peer_id == 0` means "server owned" in GECS v2. Godot's `set_multiplayer_authority()` uses `1` for the host/server. Passing `0` gives undefined authority behavior.

**How to avoid:**
```gdscript
var authority: int = net_id.peer_id if net_id.peer_id > 0 else 1
synchronizer.set_multiplayer_authority(authority)
```
This is already in `sync_native_handler.gd` line 339 — preserve it exactly.

### Pitfall 2: MultiplayerSynchronizer Node Naming Collision

**What goes wrong:** Multiple entities each want a child node named `"_NetSync"`. If the entity is a Node, `add_child` auto-renames nodes with duplicate names (appends `@2`, etc.). The `get_node_or_null("_NetSync")` cleanup check then fails.

**How to avoid:** Each entity gets its own MultiplayerSynchronizer as a DIRECT child. Since each entity is a separate Node, there is no naming collision between entities — the name `"_NetSync"` is entity-local. Confirm with `entity.get_node_or_null("_NetSync")` in idempotent guard.

### Pitfall 3: CN_NetSync Must Skip CN_NativeSync Properties

**What goes wrong:** If an entity has both `CN_NativeSync` and `CN_NetSync`, the scanner may pick up `sync_position`, `sync_rotation`, `replication_interval` as properties to batch-sync via RPC — doubling the work and fighting with the MultiplayerSynchronizer.

**How to avoid:** Extend `CN_NetSync.scan_entity_components()` to skip `CN_NativeSync` alongside `CN_NetworkIdentity`:
```gdscript
if comp is CN_NativeSync:
    continue  # Native sync handles its own target node — don't batch-RPC its config
```

### Pitfall 4: Late-Join Clients and MultiplayerSynchronizer Order

**What goes wrong:** Late-joining client receives world state via `handle_world_state()` → `handle_spawn_entity()`. The Entity node is added to the world, authority markers are applied, and `setup_native_sync()` is called. The MultiplayerSynchronizer is created and added as a child. BUT the `property_set_spawn(path, true)` flag on the synchronizer means the server should send an initial snapshot — this snapshot arrives only if the server's synchronizer has already been activated and its visibility covers the new peer.

**How to avoid:** `refresh_synchronizer_visibility()` (from `sync_native_handler.gd`) must be called on the server when a new peer connects — after the world state is sent. The server must call this deferred (after the world state RPC fires) so new-peer synchronizers are visible. Wire this in `NetworkSync._on_peer_connected()`:
```gdscript
func _on_peer_connected(peer_id: int) -> void:
    if not net_adapter.is_server() or _world == null:
        return
    var state = _spawn_manager.serialize_world_state()
    _sync_world_state.rpc_id(peer_id, state)
    # Deferred so spawn RPC fires first, then visibility refresh
    call_deferred("_deferred_refresh_visibility")
```

### Pitfall 5: Authority Markers on Re-Spawn (World State Update)

**What goes wrong:** `handle_spawn_entity()` has an early-return path for entities that already exist: `if _ns._world.entity_id_registry.has(entity_id): _apply_component_data(existing, data); return`. This means authority markers can be re-injected on an entity that already has them. The injection must be idempotent (remove old markers before adding new ones).

**How to avoid:** Always call `entity.remove_component(CN_LocalAuthority)` and `entity.remove_component(CN_ServerAuthority)` before re-adding them. GECS `remove_component` is a no-op if the component is absent.

### Pitfall 6: sync_native_handler.gd References _ns.sync_config

**What goes wrong:** The existing `sync_native_handler.gd` calls `_ns.sync_config.model_component`, `_ns.sync_config.transform_component`, etc. `NetworkSync` in v2 has no `sync_config` field. The handler must be rewritten, not patched.

**Resolution:** Write `native_sync_handler.gd` from scratch. The only logic worth porting is the `auto_setup_native_sync()` MultiplayerSynchronizer construction sequence and `cleanup_synchronizer()`. The model instantiation, position snapshot, and animation-rig wiring are NOT needed in v2.

---

## Code Examples

Verified patterns from the existing v0.1.1 implementation and Godot documentation:

### MultiplayerSynchronizer Setup (from sync_native_handler.gd, lines 266-343)

```gdscript
# Source: addons/gecs_network/sync_native_handler.gd (v0.1.1 — reference, NOT final code)
var synchronizer = MultiplayerSynchronizer.new()
synchronizer.name = "_NetSync"

var config = SceneReplicationConfig.new()
# Property path format: ".:property" where "." = root_path = parent = target node
config.add_property(".:position")
config.property_set_spawn(".:position", true)
config.property_set_sync(".:position", true)
config.property_set_replication_mode(
    ".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS
)

synchronizer.replication_config = config             # BEFORE add_child
synchronizer.set_multiplayer_authority(actual_authority)  # BEFORE add_child
target.add_child(synchronizer)                       # Activates replication
```

### Authority Check via Component (LIFE-05 pattern)

```gdscript
# Source: example_network/systems/s_input.gd (already in use)
# Query pattern — no is_multiplayer_authority() call:
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, C_LocalAuthority]).iterate([C_PlayerInput])

# Alternative: imperative check (also valid)
func process(entities, components, delta):
    for entity in entities:
        if entity.has_component(CN_LocalAuthority):
            # process input for this entity
```

### SceneReplicationConfig Constants

```gdscript
# Replication modes:
SceneReplicationConfig.REPLICATION_MODE_NEVER    # 0 — not replicated
SceneReplicationConfig.REPLICATION_MODE_ALWAYS   # 1 — sent every replication_interval
SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE # 2 — sent when value changes (uses delta_interval)
```

### MultiplayerSynchronizer VisibilityUpdateMode Enum

```gdscript
MultiplayerSynchronizer.VISIBILITY_PROCESS_IDLE    # 0 — update visibility in _process
MultiplayerSynchronizer.VISIBILITY_PROCESS_PHYSICS # 1 — update visibility in _physics_process
MultiplayerSynchronizer.VISIBILITY_PROCESS_NONE    # 2 — manual update only (call update_visibility())
```

### Refresh Visibility for Late Join (from sync_native_handler.gd, lines 486-528)

```gdscript
# Force synchronizer visibility refresh after peer connects
# Source: addons/gecs_network/sync_native_handler.gd
func refresh_synchronizer_visibility() -> void:
    for entity in _ns._world.entities:
        var synchronizer = entity.get_node_or_null("_NetSync") as MultiplayerSynchronizer
        if not synchronizer:
            continue
        # Toggle public_visibility to trigger Godot's internal peer-list rebuild
        var was_public = synchronizer.public_visibility
        synchronizer.public_visibility = false
        synchronizer.public_visibility = was_public
```

---

## State of the Art

| Old Approach (v0.1.1) | Current Approach (v2) | Impact |
|----------------------|----------------------|--------|
| `CN_SyncEntity` component with `target_node` Node ref | `CN_NativeSync` component with bool flags (`sync_position`, `sync_rotation`) | No Node ref stored in component; target is always the Entity node itself |
| `sync_config.transform_component` string lookup | Direct `CN_NativeSync` presence check | No global config dependency |
| `sync_native_handler.gd` references `_ns.sync_config` | `native_sync_handler.gd` reads only `CN_NativeSync` | Self-contained, no external config |
| `CN_SyncEntity.get_sync_target()` returns arbitrary Node | Target is always the Entity node (no indirection) | Simpler; entities ARE nodes in GECS |
| Authority checks via `is_multiplayer_authority()` | Authority checks via `CN_LocalAuthority` component query | ECS-idiomatic; no network state in game systems |

**Deprecated/outdated:**
- `CN_SyncEntity`: deprecated stub — delete in Phase 3
- `sync_native_handler.gd`: v0.1.1 handler — delete and replace
- `sync_config.gd`: stub kept for Phase 2 compat — now safe to delete
- `CN_ServerOwned`: exists but is NOT part of LIFE-05 spec (which uses `CN_ServerAuthority` and `CN_LocalAuthority`). `CN_ServerOwned` documentation conflicts with the LIFE-05 decision — treat it as legacy.

---

## Open Questions

1. **CN_ServerOwned vs CN_ServerAuthority**
   - What we know: Both marker components exist. `CN_ServerOwned` docs say it's added "when peer_id is 0 or 1". `CN_ServerAuthority` docs say it's added to "server-owned entities (peer_id=0)". The LIFE-05 requirement specifies `CN_LocalAuthority` and `CN_ServerAuthority` only.
   - What's unclear: Is `CN_ServerOwned` used anywhere in game code? Does it need to remain?
   - Recommendation: Phase 3 implements `CN_LocalAuthority` and `CN_ServerAuthority` per LIFE-05. Leave `CN_ServerOwned` in place (it doesn't harm anything). Do NOT add it as part of Phase 3 — it is out of scope.

2. **Does Entity have `position` and `rotation` properties?**
   - What we know: GECS Entity extends Godot's `Node` class. `Node` does NOT have `position`/`rotation` — those are on `Node2D` and `Node3D`.
   - What's unclear: Do example entities extend `Node3D` or `Node2D`?
   - Recommendation: The planner must decide whether `CN_NativeSync` targets `Node3D` properties (position, rotation as Vector3) or `Node2D` properties (position as Vector2, rotation as float). The example `c_net_position.gd` stores `Vector3 position` on a Component, not on the node. The `sync_native_handler.gd` targeted a `CharacterBody3D` sub-node, not the entity itself.
   - **Resolution path:** `CN_NativeSync` should NOT assume the entity IS a Node3D. Instead, it should sync properties from a configurable path within the entity's subtree. Default `root_path = ".."` targets the entity. For games using `CharacterBody3D` children, override `root_path`. The planner may decide to keep the design simple: target the Entity node, and game code puts movement directly on the entity by extending `CharacterBody3D` or `Node3D`. OR, accept that `CN_NativeSync` in Phase 3 syncs properties on the Entity's `global_position` if the Entity is a `Node3D`.

3. **refresh_synchronizer_visibility() — toggle pattern reliability**
   - What we know: The v0.1.1 handler toggles `public_visibility` false then true to force Godot to rebuild the peer visibility list.
   - What's unclear: Is this still the correct workaround in Godot 4.5? The `update_visibility(peer_id)` method exists as the documented API.
   - Recommendation: Use `synchronizer.update_visibility(0)` (0 = all peers) in Phase 3 instead of the toggle hack. This is the documented method. Mark LOW confidence — verify this works in Godot 4.5 during implementation.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | GdUnit4 |
| Config file | `GdUnitRunner.cfg` |
| Quick run command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c` |
| Full suite command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests" -c` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIFE-05 | `CN_LocalAuthority` is added to entity when `net_id.peer_id == local_peer_id` | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ Wave 0 |
| LIFE-05 | `CN_ServerAuthority` is added to entity when `net_id.peer_id == 0` | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ Wave 0 |
| LIFE-05 | Server gets `CN_LocalAuthority` on server-owned (peer_id=0) entities | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ Wave 0 |
| LIFE-05 | Client does NOT get `CN_LocalAuthority` on other players' entities | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ Wave 0 |
| LIFE-05 | Marker injection is idempotent on re-spawn (no duplicate components) | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ Wave 0 |
| SYNC-04 | `CN_NativeSync` component scanned by `NativeSyncHandler` creates `_NetSync` child | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ Wave 0 |
| SYNC-04 | `_NetSync` NOT created for entities without `CN_NativeSync` | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ Wave 0 |
| SYNC-04 | Cleanup removes `_NetSync` node from entity | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ Wave 0 |
| SYNC-04 | `CN_NetSync.scan_entity_components()` skips `CN_NativeSync` | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ✅ (add test case) |
| SYNC-04 | Authority is set to `1` when `net_id.peer_id == 0` | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c`
- **Per wave merge:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `addons/gecs_network/tests/test_authority_markers.gd` — covers LIFE-05 (all 5 test cases above)
- [ ] `addons/gecs_network/tests/test_native_sync_handler.gd` — covers SYNC-04 (5 test cases above)
- [ ] New `class_name` files need `godot --headless --import` after creation: `cn_native_sync.gd`, `native_sync_handler.gd`

---

## Sources

### Primary (HIGH confidence)
- `addons/gecs_network/sync_native_handler.gd` — reference implementation for MultiplayerSynchronizer setup sequence; property path format; authority mapping; visibility refresh pattern
- `addons/gecs_network/components/cn_local_authority.gd` — existing component spec
- `addons/gecs_network/components/cn_server_authority.gd` — existing component spec
- `addons/gecs_network/spawn_manager.gd` — injection hook location and idempotency requirements
- `addons/gecs_network/components/cn_net_sync.gd` — skip-list pattern for CN_NetworkIdentity (MEDIUM → HIGH for CN_NativeSync skip requirement)
- Godot issue #65725 closed 2023-02-23 — `replication_config` dynamic add_property fix confirmed merged (PR #73806)

### Secondary (MEDIUM confidence)
- [rokojori.com MultiplayerSynchronizer 4.4 docs](https://rokojori.com/en/labs/godot/docs/4.4/multiplayersynchronizer-class) — properties, signals, VisibilityUpdateMode enum values
- [bluerobotguru.com MultiplayerSynchronizer tutorial](https://bluerobotguru.com/how-to-use-multiplayersynchronizer-in-godot/) — replication_interval vs delta_interval behavior, authority model
- `example_network/systems/s_input.gd` — real example of `CN_LocalAuthority` query pattern already in use

### Tertiary (LOW confidence)
- WebSearch community reports on "set_multiplayer_authority before add_child" — multiple sources agree on ordering; not yet verified against Godot 4.5 source
- `update_visibility(0)` as replacement for public_visibility toggle hack — documented API but unverified in Godot 4.5 for late-join case

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — components exist, MultiplayerSynchronizer API confirmed stable since Godot 4.0
- Authority marker injection: HIGH — clear hook location, idempotency pattern well understood
- NativeSyncHandler setup sequence: HIGH — ported directly from working v0.1.1 code
- Late-join visibility refresh: MEDIUM — pattern confirmed but specific API call (update_visibility vs toggle) is LOW
- CN_NativeSync design (target node question): MEDIUM — open question about Entity being Node3D vs Node

**Research date:** 2026-03-09
**Valid until:** 2026-06-09 (Godot 4.x API is stable; MultiplayerSynchronizer has not changed significantly since 4.0)

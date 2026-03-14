# Phase 1: Foundation and Entity Lifecycle - Research

**Researched:** 2026-03-07
**Domain:** Godot 4.x multiplayer — entity lifecycle sync, session management, NetAdapter abstraction
**Confidence:** HIGH — all findings drawn from direct analysis of the working v0.1.1 codebase in `addons/gecs_network/`

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- `is_server_owned()` returns `peer_id == 0` only — peer_id=0 means server-owned NPC/world entity
- peer_id=1 (host) is NOT treated as server-owned — framework makes no assumption about the host
- Framework provides no built-in `is_host()` convention — game decides how to treat peer_id=1
- Authority validation is done server-side using the actual RPC sender's peer_id (unforgeable from transport), not component fields
- Keep `NetworkSync.attach_to_world(world, net_adapter: NetAdapter = null)` factory method
- null net_adapter uses default Godot multiplayer — no boilerplate for simple games
- NetworkSync auto-discovers its parent World by walking the scene tree — no explicit world reference needed after attach
- Node name "NetworkSync" is set explicitly in factory and guarded in `_ready()` (critical for RPC routing)
- Use sequential spawn counter — server increments a session-scoped integer per spawn
- Network ID stored in `CN_NetworkIdentity` as `spawn_index` (existing field, keep it)
- `CN_NetworkIdentity` holds both `peer_id` and `spawn_index` — together they uniquely identify an entity
- No composite IDs or client-side ID generation — v2 is server-authoritative spawning only
- Payload includes: scene path (auto-detected from `entity.scene_file_path`) + serialized component data
- Scene path auto-detection from `scene_file_path` — no manual registration required
- Developers set component values on the entity BEFORE the network spawn happens — deferred broadcast captures correct values
- Broadcast is deferred via `call_deferred` with `_broadcast_pending` guard to prevent double-broadcast

### Claude's Discretion

- Internal implementation of `_broadcast_pending` cancellation logic
- Exact session ID increment strategy (random vs monotonic)
- Error handling for missing scene paths (entity created at runtime without a scene)
- How disconnect cleanup handles in-flight RPCs

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | Developer can declare a component's sync priority using `@export_group` annotations (REALTIME/HIGH/MEDIUM/LOW) — no external SyncConfig registry required | This is a Phase 2 concern (CN_NetSync); Phase 1 only needs CN_NetworkIdentity to carry the network identity, not sync priority. However, the @export_group detection pattern from SyncComponent is documented here for awareness. |
| FOUND-02 | Every network RPC includes a monotonic session ID — receivers reject RPCs from previous game sessions | Fully documented: `_game_session_id` field, `reset_for_new_game()` increment, session validation in all spawn/despawn handlers. Patterns confirmed in v0.1.1 `network_sync.gd` lines 75-77, `sync_spawn_handler.gd` lines 130-138. |
| FOUND-03 | All sync work is gated on session state — zero networking overhead when running as single-player or offline | `net_adapter.is_in_game()` check. `_process()` returns immediately when false. NetAdapter returns `false` when no MultiplayerPeer connected. Pattern confirmed in `network_sync.gd` line 288. |
| FOUND-04 | NetAdapter abstraction wraps MultiplayerAPI — networking logic is testable without running two Godot instances | `NetAdapter` class is fully implemented, verbatim reusable. MockNetAdapter pattern exists in tests. Confirmed in `net_adapter.gd` and test files. |
| LIFE-01 | When the server spawns a networked entity, it is automatically replicated to all connected clients — no manual spawn RPC required | Deferred broadcast pattern via `call_deferred("_deferred_broadcast_entity_spawn", ...)` + `_broadcast_pending` guard. Confirmed in `network_sync.gd` lines 533-540. |
| LIFE-02 | When the server despawns a networked entity, it is automatically removed on all connected clients — no manual despawn RPC required | `_on_entity_removed` → `_despawn_entity.rpc(entity.id, _game_session_id)`. `_broadcast_pending` cancellation handles sub-frame removal. Confirmed in `network_sync.gd` lines 562-586. |
| LIFE-03 | A client connecting after a game session has started receives a full world state snapshot — all existing networked entities appear on the client | `_on_peer_connected` → `serialize_world_state()` → `_sync_world_state.rpc_id(peer_id, state)`. Three-phase late-join sequence (world state, native sync refresh, position snapshot). Confirmed in `network_sync.gd` lines 381-408. |
| LIFE-04 | When a peer disconnects, all entities owned by that peer are automatically removed from the world on all remaining peers | `_on_peer_disconnected` scans `_world.entities` for `net_id.peer_id == peer_id`, calls `_world.remove_entity()` then `entity.queue_free()`. Confirmed in `network_sync.gd` lines 411-431. |
</phase_requirements>

---

## Summary

Phase 1 is a focused rewrite of the v0.1.1 networking foundation with one critical semantic change: `is_server_owned()` now returns `peer_id == 0` only (previously `peer_id == 0 or peer_id == 1`). Everything else in this phase is a direct port of proven, working v0.1.1 patterns — the code exists, it works, and the only risk is omitting a critical guard clause during the rewrite.

The v0.1.1 codebase contains all four patterns that are "non-retrofittable" — meaning that if they are missing, every subsequent phase's code must be revisited to add them: (1) the `_applying_network_data` sync-loop guard, (2) the `_broadcast_pending` deferred-spawn guard, (3) the `session_id` in every RPC, and (4) the `"NetworkSync"` node name. These are not implementation choices — they are correctness invariants that the entire system depends on.

The phase scope is: `CN_NetworkIdentity` (with updated `is_server_owned()`), `NetAdapter` (verbatim), `TransportProvider` (verbatim), the `NetworkSync` skeleton with lifecycle RPCs and `SpawnManager` logic, and session/disconnect management. Component property sync (SyncSender, SyncReceiver, CN_NetSync) is Phase 2.

**Primary recommendation:** Port the v0.1.1 lifecycle patterns directly. The working code is the specification. The only design work is the `is_server_owned()` semantic change and removing SyncConfig dependency from Phase 1 components.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot 4.x MultiplayerAPI | Built-in | RPC transport, peer management | Only networking API available in GDScript; already validated by v0.1.1 |
| ENetMultiplayerPeer | Built-in | UDP transport peer | Default Godot transport; reliable+unreliable channels built-in; already used by v0.1.1 |
| OfflineMultiplayerPeer | Built-in | Single-player passthrough | `is_in_game()` returns false → zero overhead; standard pattern in v0.1.1 |
| GdUnit4 | addons/gdUnit4 | Test framework | Project standard; existing network tests use it |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Component.serialize()` | GECS core | Spawn payload serialization | Serializes all `@export` properties to Dictionary; used for every spawn broadcast |
| `World.entity_id_registry` | GECS core | Entity lookup by network ID | O(1) lookup for despawn and component application on clients |
| `World.add_entity()` / `World.remove_entity()` | GECS core | Entity lifecycle management | NetworkSync hooks via signals — it does NOT call these directly except in spawn RPC handler |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ENetMultiplayerPeer` | `WebRTCMultiplayerPeer` | WebRTC supports browser clients but is P2P topology — incompatible with server-authoritative model |
| `Component.serialize()` | Custom binary format | Binary is faster but GDScript has no custom binary serialization; Dictionary is sufficient at Phase 1 scale |
| Sequential `spawn_index` counter | UUID | UUID avoids counter reset bugs but is overkill — counter is reset by `reset_for_new_game()` which already handles session boundaries |

**Installation:** No packages to install. All dependencies are Godot 4.x built-ins or the existing GECS addon.

---

## Architecture Patterns

### Recommended File Structure (Phase 1 output)

```
addons/gecs_network/
  network_sync.gd              REFACTOR: Remove SyncConfig dep; slim to lifecycle + RPC surface
  net_adapter.gd               KEEP VERBATIM: Clean abstraction, works correctly
  transport_provider.gd        KEEP VERBATIM: Clean abstraction
  transports/
    enet_transport_provider.gd KEEP VERBATIM
    steam_transport_provider.gd KEEP VERBATIM
  spawn_manager.gd             NEW: Extract from sync_spawn_handler.gd; owns lifecycle logic
  components/
    cn_network_identity.gd     MODIFY: is_server_owned() → peer_id == 0 only; remove is_host()
    cn_local_authority.gd      KEEP VERBATIM: Marker component, no changes
    cn_server_authority.gd     KEEP VERBATIM: Marker component, no changes
    cn_server_owned.gd         KEEP VERBATIM: Marker component, no changes
    cn_remote_entity.gd        KEEP VERBATIM: Marker component, no changes
  tests/
    test_cn_network_identity.gd  UPDATE: Add tests for new is_server_owned() semantics
    test_net_adapter.gd          KEEP: Existing tests still valid
    test_spawn_manager.gd        NEW: Port from test_sync_spawn_handler.gd
```

### Pattern 1: Factory Method with Hardcoded Node Name

**What:** Static factory sets `node.name = "NetworkSync"` before `add_child()`; `_ready()` guards against auto-generated names.

**When to use:** Always — this is mandatory for Godot RPC routing.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 124-139
static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync:
    var net_sync = NetworkSync.new()
    net_sync.name = "NetworkSync"  # CRITICAL: must match across all peers
    if net_adapter != null:
        net_sync.net_adapter = net_adapter
    world.add_child(net_sync)
    return net_sync

func _ready() -> void:
    if name.begins_with("@"):
        name = "NetworkSync"  # Fallback guard
```

### Pattern 2: Deferred Spawn with _broadcast_pending Guard

**What:** `entity_added` signal queues a deferred call, guarded by a dictionary of pending entity IDs. The deferred call serializes and broadcasts. If the entity is removed before the deferred call fires, the entry is erased and no broadcast happens.

**When to use:** Every server-side spawn broadcast — no exceptions.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 533-540, 562-576
# Source: addons/gecs_network/sync_spawn_handler.gd lines 64-73

# On entity_added (signal handler):
func _on_entity_added(entity: Entity) -> void:
    if not net_adapter.is_server():
        return
    if not entity.has_component(CN_NetworkIdentity):
        return
    if not _broadcast_pending.has(entity.id):
        _broadcast_pending[entity.id] = true
        call_deferred("_deferred_broadcast_entity_spawn", entity, entity.id)

# On entity_removed (cancellation):
func _on_entity_removed(entity: Entity) -> void:
    if _broadcast_pending.has(entity.id):
        _broadcast_pending.erase(entity.id)
        return  # Entity never existed on clients — skip despawn RPC

# Deferred callback:
func _deferred_broadcast_entity_spawn(entity: Entity, entity_id: String) -> void:
    if not is_instance_valid(entity):  # Freed before deferred call fired
        _broadcast_pending.erase(entity_id)
        return
    if not _broadcast_pending.has(entity_id):
        return  # Cancelled by entity_removed
    _broadcast_pending.erase(entity_id)
    var spawn_data = _spawn_manager.serialize_entity(entity)
    _spawn_entity.rpc(spawn_data)
```

### Pattern 3: Session ID in Every Lifecycle RPC

**What:** `_game_session_id` (monotonically incrementing integer) is included in every spawn, despawn, add_component, remove_component RPC. Receivers reject RPCs where `session_id != _game_session_id`. `reset_for_new_game()` increments the counter and broadcasts session ID to clients via world state snapshot.

**When to use:** Every lifecycle RPC — spawn, despawn, component add/remove.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 232-273
# Source: addons/gecs_network/sync_spawn_handler.gd lines 128-138

var _game_session_id: int = 0

func reset_for_new_game() -> void:
    _game_session_id += 1
    _broadcast_pending.clear()
    _spawn_counter = 0

# Receiver side (in SpawnManager.handle_spawn):
func handle_spawn_entity(data: Dictionary) -> void:
    var session_id = data.get("session_id", 0)
    if session_id != _ns._game_session_id:
        return  # Stale RPC — reject
```

### Pattern 4: RPC Authority Modes (Security Contract)

**What:** Different RPCs use different authority modes based on who is allowed to send them.

**When to use:** Set correctly at declaration — cannot be changed without breaking network routing.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 785-796

@rpc("authority", "reliable")          # Server-only sender (spawn, despawn, world state)
func _spawn_entity(data: Dictionary) -> void: pass

@rpc("authority", "reliable")
func _despawn_entity(entity_id: String, session_id: int) -> void: pass

@rpc("authority", "reliable")
func _sync_world_state(state: Dictionary) -> void: pass

@rpc("any_peer", "reliable")           # Any peer sender (component add/remove, with validation)
func _add_component(entity_id, comp_type, script_path, comp_data, session_id) -> void: pass
```

### Pattern 5: is_in_game() Guard for Zero Single-Player Overhead

**What:** `_process()` and all signal handlers check `net_adapter.is_in_game()` before doing any work.

**When to use:** Top of every method that would otherwise do networking work.

```gdscript
# Source: addons/gecs_network/network_sync.gd line 288
func _process(delta: float) -> void:
    if _world == null or not net_adapter.is_in_game():
        return
```

### Pattern 6: Late-Join Three-Phase World State

**What:** When a peer connects, the server sends (1) the full world state with all entities and session ID, (2) immediately triggers native sync refresh for transform entities, (3) deferred position snapshot for fast-moving entities.

**When to use:** `_on_peer_connected` on server.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 381-408
func _on_peer_connected(peer_id: int) -> void:
    if not net_adapter.is_server() or _world == null:
        return
    var state = _spawn_manager.serialize_world_state()
    _sync_world_state.rpc_id(peer_id, state)  # Phase 1 of 3: entity spawns
    # Phase 2 and 3 (native sync refresh, position snapshot) are Phase 3 concerns
```

### Pattern 7: Disconnect Cleanup (Peer-Owned Entity Removal)

**What:** On `peer_disconnected`, server scans all entities, finds those with `CN_NetworkIdentity.peer_id == disconnected_peer_id`, removes them from world, frees from scene tree.

**When to use:** `_on_peer_disconnected` on server.

```gdscript
# Source: addons/gecs_network/network_sync.gd lines 411-431
func _on_peer_disconnected(peer_id: int) -> void:
    if not net_adapter.is_server() or _world == null:
        return
    var to_remove: Array[Entity] = []
    for entity in _world.entities:
        var net_id = entity.get_component(CN_NetworkIdentity)
        if net_id and net_id.peer_id == peer_id:
            to_remove.append(entity)
    for entity in to_remove:
        _world.remove_entity(entity)  # Triggers despawn RPC to remaining clients
        if is_instance_valid(entity):
            entity.queue_free()
```

### Anti-Patterns to Avoid

- **Calling queue_free() before remove_entity():** The despawn RPC fires from `entity_removed` signal. If the entity is freed first, the signal never fires and clients are never notified. Always `remove_entity()` first.
- **Skipping `is_instance_valid()` in deferred callbacks:** `call_deferred` captures the entity reference. The entity may be freed before the callback fires. Always guard.
- **Using `entity.id` after `queue_free()`:** Pass entity ID as a separate String parameter to deferred callbacks so the ID is available even if the entity is freed.
- **Checking `peer_id == 0 or peer_id == 1` for server ownership:** The locked decision is `peer_id == 0` only. peer_id=1 is the host-as-player, not a server-owned entity.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MultiplayerAPI stale reference on scene change | Custom reference tracking | `NetAdapter.get_multiplayer()` | Already detects SceneTree MultiplayerAPI replacement by comparing identity, not validity |
| Component serialization | Custom serializer | `Component.serialize()` (GECS) | Serializes all `@export` properties; handles nested Resources; proven reliable |
| Entity lookup by network ID | Custom registry | `World.entity_id_registry` | Already maintained by World; O(1) lookup; kept consistent by `add_entity`/`remove_entity` |
| Transport abstraction | Custom peer factory | `TransportProvider` + `ENetTransportProvider` | Already implemented; preserves path to Steam/WebRTC transports |

**Key insight:** This phase is largely a port, not a build. The v0.1.1 codebase is the implementation blueprint.

---

## Common Pitfalls

### Pitfall 1: Spawn Broadcast Racing Component Setup (CRITICAL — Phase 1)

**What goes wrong:** Server calls `World.add_entity(entity)` which immediately fires `entity_added`, triggering the spawn RPC before any component values are set in the next line.

**Why it happens:** `World.add_entity` → signal → RPC is synchronous. Component values are set after `add_entity()`.

**How to avoid:** Always defer the spawn broadcast with `call_deferred`. Always gate with `_broadcast_pending`. Never serialize component data at signal time — serialize at deferred-call time.

**Warning signs:** Clients see entities spawn at Vector3.ZERO then snap to position. `@export` properties with non-default initial values appear with defaults on clients.

### Pitfall 2: Stale RPC Delivery After Game Reset (CRITICAL — Phase 1)

**What goes wrong:** In-flight RPCs from a previous game session arrive after `reset_for_new_game()`, targeting entities in the new session by coincidentally matching ID.

**How to avoid:** Include `session_id: int` in EVERY lifecycle RPC signature from the start. Receivers reject where `session_id != _game_session_id`. World state snapshot payload includes session ID so late-joining clients sync their counter.

**Warning signs:** Entities vanish immediately after spawning in new sessions. Entity counts diverge after lobby → game transitions.

### Pitfall 3: Node Name Inconsistency Breaking All RPCs (CRITICAL — Phase 1)

**What goes wrong:** Godot routes `@rpc` calls by full node path string. Auto-generated names (`"@Node@15"`) differ between peers, causing silent RPC failure.

**How to avoid:** `net_sync.name = "NetworkSync"` in factory method before `add_child()`. Guard in `_ready()`: `if name.begins_with("@"): name = "NetworkSync"`.

**Warning signs:** All networking is silent. No errors thrown. Enabling `debug_print_multiplayer_warnings` shows "Node not found" for every RPC.

### Pitfall 4: Sub-Frame Entity Removal Sending Ghost Despawn (CRITICAL — Phase 1)

**What goes wrong:** Entity is added (deferred spawn queued), then removed in the same frame. Despawn RPC fires. Later, deferred spawn fires. Clients receive spawn for an entity the server destroyed. Ghost persists permanently.

**How to avoid:** `_broadcast_pending` cancellation — `_on_entity_removed` checks if entity is in `_broadcast_pending`, erases it, returns without sending despawn.

**Warning signs:** Clients have entities the server does not. Reconciliation (Phase 5) will clean these up but they persist.

### Pitfall 5: is_server_owned() Semantic Mismatch (CRITICAL — Phase 1)

**What goes wrong:** v0.1.1 `is_server_owned()` returns `peer_id == 0 or peer_id == 1`. The locked decision changes this to `peer_id == 0` only. If old code is ported without this change, host-player entities (peer_id=1) are incorrectly treated as server-owned, breaking their authority model.

**How to avoid:** In `cn_network_identity.gd`, update `is_server_owned()` to `return peer_id == 0`. Remove or rename `is_host()` to avoid confusion. Update tests.

**Warning signs:** Host player (peer_id=1) entities do not receive `CN_LocalAuthority` or are given `CN_ServerOwned`. Host player cannot process input locally.

### Pitfall 6: _apply_component_data Before define_components (MODERATE — Phase 1)

**What goes wrong:** Applying component data before `World.add_entity()` is called means `_initialize()` hasn't run yet, so `define_components()` hasn't populated the entity's components. Values are discarded.

**How to avoid:** Call `World.add_entity(entity)` first, then `_apply_component_data(entity, data)`. The `_initialize()` call happens inside `add_entity` before the function returns.

**Warning signs:** Server-set initial component values never appear on clients even after spawn.

### Pitfall 7: Despawn/Remove-Entity Double-Free (MODERATE — Phase 1)

**What goes wrong:** Both `World.remove_entity()` and `entity.queue_free()` must be called. `remove_entity()` triggers the despawn RPC; `queue_free()` removes the node from the scene tree. Calling only `queue_free()` means clients are never notified. Calling `queue_free()` before `remove_entity()` may invalidate the entity before the signal fires.

**How to avoid:** Always: `_world.remove_entity(entity)` then `entity.queue_free()`. Never reverse this order.

---

## Code Examples

Verified patterns from v0.1.1 source (direct port, not theoretical):

### CN_NetworkIdentity — Updated is_server_owned()

```gdscript
# Modified from: addons/gecs_network/components/cn_network_identity.gd
# Change: is_server_owned() now returns peer_id == 0 ONLY

func is_server_owned() -> bool:
    return peer_id == 0  # peer_id=1 (host) is NOT server-owned in v2

# Remove is_host() entirely — game code decides how to treat peer_id=1
# Keep is_player(), is_local(), has_authority() verbatim
```

### Spawn Payload Serialization

```gdscript
# Source: addons/gecs_network/sync_spawn_handler.gd lines 528-574
# The model_ready_component exclusion belongs in Phase 2+ (no SyncConfig in Phase 1)

func serialize_entity(entity: Entity) -> Dictionary:
    var components_data := {}
    var script_paths := {}
    for comp_path in entity.components.keys():
        var comp = entity.components[comp_path]
        var script = comp.get_script()
        var comp_type: String
        if script == null:
            comp_type = comp.get_class()
        else:
            comp_type = script.get_global_name()
            if comp_type == "":
                comp_type = script.resource_path.get_file().get_basename()
                push_warning("Component without class_name: %s" % script.resource_path)
        components_data[comp_type] = comp.serialize()
        if script != null and script.resource_path != "":
            script_paths[comp_type] = script.resource_path
    return {
        "id": entity.id,
        "name": entity.name,
        "scene_path": entity.scene_file_path,
        "components": components_data,
        "script_paths": script_paths,
        "session_id": _session_id
    }
```

### World State for Late Join

```gdscript
# Source: addons/gecs_network/sync_spawn_handler.gd lines 18-29
func serialize_world_state() -> Dictionary:
    var entities_data: Array[Dictionary] = []
    for entity in _world.entities:
        if not entity.has_component(CN_NetworkIdentity):
            continue
        entities_data.append(serialize_entity(entity))
    return {"entities": entities_data, "session_id": _session_id}

# Receiver: MUST sync session_id FIRST before processing entities
func handle_world_state(state: Dictionary) -> void:
    var server_session_id = state.get("session_id", 0)
    if server_session_id != _session_id:
        _session_id = server_session_id  # Adopt server's session counter
    for entity_data in state.get("entities", []):
        handle_spawn_entity(entity_data)
```

### NetAdapter (verbatim, no changes)

```gdscript
# Source: addons/gecs_network/net_adapter.gd — keep completely verbatim
# Key behaviors:
# - is_in_game(): returns false when no MultiplayerPeer connected (single-player = false)
# - is_server(): returns true in single-player (no peer = "server")
# - get_multiplayer(): uses identity comparison to detect stale MultiplayerAPI refs
```

---

## State of the Art

| Old Approach (v0.1.1) | v2 Approach | Change Required | Impact on Phase 1 |
|----------------------|-------------|-----------------|-------------------|
| `is_server_owned()` → `peer_id == 0 or peer_id == 1` | `peer_id == 0` only | Modify `cn_network_identity.gd` | Every authority check downstream; must be in Phase 1 |
| `NetworkSync` with embedded `SyncConfig` dependency | `NetworkSync` with no `SyncConfig`; sync priorities live in `CN_NetSync` (Phase 2) | Remove `sync_config` field from `NetworkSync`; remove `_create_default_config()` | Phase 1 NetworkSync skeleton must not depend on SyncConfig |
| `SyncSpawnHandler` (no class_name, preloaded as const) | `SpawnManager` (class_name, proper encapsulation) | Rename/refactor; extract from NetworkSync coupling | Cleaner dependency graph; tests can import by class_name |
| `entity.id` as String UUID for network identity | `entity.id` as String; `CN_NetworkIdentity.spawn_index` as sequential int for ordering | Keep both; `spawn_index` is from spawn counter | No change to wire format; spawn_index is already in CN_NetworkIdentity |
| `transform_component` in SyncConfig used in spawn serialization | No transform_component concept in Phase 1 | Remove transform_component references from spawn serializer | Spawn payload sends all components; transform handling is Phase 2/3 |

**Deprecated/outdated (remove from Phase 1):**

- `SyncConfig` reference in `NetworkSync._init_sync_config()` — Phase 1 must not depend on SyncConfig
- `_native_handler` reference in `_on_peer_connected` — native sync is Phase 3
- `_relationship_handler` reference in `_on_entity_added` — relationship sync is Phase 4
- `_property_handler` in `_process()` — property sync is Phase 2
- `_state_handler.sync_server_time()` — time sync is Phase 5
- `_state_handler.process_reconciliation()` — reconciliation is Phase 5

---

## Open Questions

1. **Entity ID format for v2**
   - What we know: v0.1.1 uses `GECSIO.uuid()` (from the GECS IO module) to generate string UUIDs for `entity.id`
   - What's unclear: v2 uses `spawn_index` as the primary network identifier. Does `entity.id` stay as UUID (for scene tree node identity) while `spawn_index` is the network key, or does `entity.id` become the stringified spawn_index?
   - Recommendation: Keep `entity.id` as UUID for scene tree uniqueness; use `spawn_index` as the network ID key in all RPCs. The `World.entity_id_registry` is already keyed by `entity.id` — ensure SpawnManager consistently uses the same key across server and client.

2. **SpawnManager owns session_id or NetworkSync owns it**
   - What we know: In v0.1.1, `_game_session_id` lives on `NetworkSync` and is accessed by all handlers via `_ns._game_session_id`
   - What's unclear: Should `SpawnManager` own session tracking or remain a consumer from `NetworkSync`?
   - Recommendation: Keep `_game_session_id` on `NetworkSync` (single source of truth); `SpawnManager` reads it via constructor reference. `reset_for_new_game()` stays on `NetworkSync`.

3. **Error handling for runtime-created entities without scene paths**
   - What we know: `entity.scene_file_path` is empty for entities created via `Entity.new()`. The v0.1.1 serializer sends `"scene_path": ""` and the receiver calls `Entity.new()` on the client.
   - What's unclear: How should the framework warn about missing component definitions when the entity is reconstructed via `Entity.new()` + component data? The component data in the spawn payload handles this but depends on `script_paths` dict.
   - Recommendation: Use the existing `script_paths` dict approach from v0.1.1 — include script paths for all components so clients can instantiate them. Emit `push_warning` if a component type in the payload has no script_path. Claude's discretion area.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | GdUnit4 (addons/gdUnit4) |
| Config file | addons/gdUnit4/GdUnitRunner.cfg |
| Quick run command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| Full suite command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-02 | session_id rejection of stale spawns | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_rejects_stale_session_id"` | ❌ Wave 0 (port from test_sync_spawn_handler.gd) |
| FOUND-03 | is_in_game() returns false in single-player | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_net_adapter.gd"` | ✅ existing |
| FOUND-04 | NetAdapter wraps MultiplayerAPI; MockNetAdapter enables unit testing | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_net_adapter.gd"` | ✅ existing |
| FOUND-01 | CN_NetworkIdentity is_server_owned() returns peer_id==0 only | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_cn_network_identity.gd"` | ✅ existing (update test) |
| LIFE-01 | Server spawn triggers deferred RPC to clients | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_deferred_broadcast_on_entity_added"` | ❌ Wave 0 |
| LIFE-02 | Server despawn triggers RPC; sub-frame removal cancels spawn | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_broadcast_pending_cancellation"` | ❌ Wave 0 |
| LIFE-03 | Late-join: world state snapshot includes all networked entities + session_id | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_serialize_world_state"` | ❌ Wave 0 (port from test_sync_spawn_handler.gd) |
| LIFE-04 | Peer disconnect removes all peer-owned entities from world | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_peer_disconnect_cleanup"` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"`
- **Per wave merge:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — covers LIFE-01, LIFE-02, LIFE-03, LIFE-04, FOUND-02 (port from `test_sync_spawn_handler.gd`, update MockNetworkSync to remove SyncConfig dependency)
- [ ] Update `addons/gecs_network/tests/test_cn_network_identity.gd` — add test for `is_server_owned()` returning false for peer_id=1

---

## Sources

### Primary (HIGH confidence)

- `addons/gecs_network/network_sync.gd` (v0.1.1) — spawn/despawn patterns, session ID, deferred broadcast, multiplayer signal handlers
- `addons/gecs_network/sync_spawn_handler.gd` (v0.1.1) — serialization, spawn/despawn RPC handling, world state, component add/remove
- `addons/gecs_network/net_adapter.gd` (v0.1.1) — MultiplayerAPI abstraction, stale reference detection, is_in_game()
- `addons/gecs_network/components/cn_network_identity.gd` (v0.1.1) — current is_server_owned() implementation (being changed)
- `addons/gecs_network/transport_provider.gd` (v0.1.1) — transport abstraction (keep verbatim)
- `.planning/research/PITFALLS.md` — pitfall analysis drawn from v0.1.1 code with line numbers
- `.planning/research/ARCHITECTURE.md` — v2 target architecture with component boundaries
- `.planning/phases/01-foundation-and-entity-lifecycle/01-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)

- Godot 4.x MultiplayerAPI docs — RPC modes ("authority" vs "any_peer"), node path routing requirement, `get_remote_sender_id()` for sender validation

### Tertiary (LOW confidence)

- None — all findings are backed by direct codebase analysis

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — entire stack is Godot 4.x built-ins already validated by v0.1.1
- Architecture: HIGH — drawn from direct analysis of working v0.1.1 code; patterns are confirmed working
- Pitfalls: HIGH — every pitfall is documented with line numbers from working mitigation code in v0.1.1

**Research date:** 2026-03-07
**Valid until:** 2026-04-07 (stable domain — Godot 4.x API; no external dependencies that change rapidly)

**Key difference from previous research phase:** The prior SUMMARY.md, ARCHITECTURE.md, and PITFALLS.md documents cover all 5 phases broadly. This document narrows scope to Phase 1 specifically: what files to port, what to change, what to remove, and exactly which guard clauses must be present in the Phase 1 skeleton. The planner should treat this as the authoritative source for Phase 1, and the prior research documents as background context.

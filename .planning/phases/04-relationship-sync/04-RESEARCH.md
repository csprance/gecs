# Phase 4: Relationship Sync - Research

**Researched:** 2026-03-10
**Domain:** GDScript networking — ECS relationship synchronization, signal wiring, SyncConfig cleanup
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Relationship Opt-In Model**
- Always-on for all networked entities — if an entity has `CN_NetworkIdentity`, all its relationships are synced. Zero configuration required.
- No `sync_config.sync_relationships` gate — that field is deleted with SyncConfig
- Handler authority check becomes: "does this entity have CN_NetworkIdentity?" (already in handler)
- Signal hookup: per-entity on spawn — `NetworkSync._on_entity_added` connects to `entity.relationship_added` and `entity.relationship_removed` signals when an entity is added to the world (same lifecycle as native sync setup in Phase 3)
- Clients can broadcast for owned entities — client sends add/remove for entities it owns (`net_id.peer_id == my_peer_id`), server validates authority and relays to all clients

**World State Inclusion (Late-Join)**
- Bundled in spawn payload — `serialize_entity()` always includes a `"relationships"` key containing an array of relationship recipes (even if empty)
- `apply_entity_relationships()` is called in `handle_spawn_entity` / `handle_world_state` after component data is applied — same RPC, same timing
- `try_resolve_pending()` is called from `NetworkSync._on_entity_added` (not SpawnManager) — fires whenever ANY entity joins the world, catching both initial and late-join scenarios

**Deferred Pending Cleanup**
- Session reset only — pending relationships accumulate until `reset_for_new_game()` clears them. Relationships are rare events; memory cost is negligible.
- No per-entity cleanup on despawn, no bounded queue — keep it simple for Phase 4
- Unbounded pending queue — no warnings or drops for Phase 4

**SyncConfig Gate Removal**
- Full cleanup — remove all `sync_config.*` references from `sync_relationship_handler.gd` (the `_ns.sync_config` checks in `serialize_relationship()`, `serialize_entity_relationships()`, and `_broadcast_relationship_change()`)
- Tests updated: `MockNetworkSync` in `test_sync_relationship_handler.gd` loses its `sync_config` field entirely; no SyncConfig import or instantiation
- Opportunistic scope: also remove SyncConfig references from `sync_state_handler.gd` and `sync_spawn_handler.gd` (and their tests) since we're touching the codebase anyway

**NetworkSync RPC Additions**
- Two new RPCs on `NetworkSync`:
  ```gdscript
  @rpc("any_peer", "reliable")
  func _sync_relationship_add(payload: Dictionary) -> void: ...

  @rpc("any_peer", "reliable")
  func _sync_relationship_remove(payload: Dictionary) -> void: ...
  ```
- Both delegate to `_relationship_handler.handle_relationship_add(payload)` / `handle_relationship_remove(payload)` — follows SpawnManager/SyncSender/SyncReceiver delegation pattern
- `NetworkSync._ready()` instantiates: `_relationship_handler = SyncRelationshipHandler.new(self)`

### Claude's Discretion

- Exact signal connect/disconnect lifecycle for per-entity relationship signals (whether to disconnect on entity removal or rely on GC)
- Whether `_on_entity_added` on clients also triggers `try_resolve_pending` (it should — clients need deferred resolution too)
- Error handling when `relationship_added` fires on a non-networked entity (no CN_NetworkIdentity)
- Whether `reset_for_new_game()` extension calls `_relationship_handler.reset()`

### Deferred Ideas (OUT OF SCOPE)

- Source entity despawn cleanup for pending relationships — Phase 5 or future insertion phase
- Bounded pending queue with warnings — Phase 5+
- Mid-game relationship transfer across authorities — future phase
- REPLICATION_MODE_ON_CHANGE equivalent for relationships — future
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ADV-01 | Entity-to-entity relationships are synchronized across peers — a deferred resolution queue handles cases where the target entity has not yet spawned on the client | `sync_relationship_handler.gd` already contains the full deferred resolution logic (`_pending_relationships` dict + `try_resolve_pending()`). Phase 4 wires it into `NetworkSync` and removes the SyncConfig gate that was preventing it from activating. |
</phase_requirements>

---

## Summary

Phase 4 is a wiring-and-cleanup task, not a greenfield implementation. `sync_relationship_handler.gd` already contains the complete serialize/deserialize/deferred-resolution/authority/RPC logic — it was written as part of earlier development but never connected to the v2 `NetworkSync` node.

The two-part work is: (1) wire the handler into `NetworkSync` the same way `_spawn_manager`, `_sender`, `_receiver`, and `_native_sync_handler` were wired in prior phases; and (2) remove all `sync_config.sync_relationships` gates that currently block the handler from emitting anything, along with opportunistic cleanup of `sync_config` references in the two v0.1.1 handlers (`sync_state_handler.gd`, `sync_spawn_handler.gd`) and their tests.

The handler's deferred pending queue (`_pending_relationships`) is keyed on source entity ID and stores raw recipe dictionaries. `try_resolve_pending(entity)` iterates all pending recipes checking if the newly-arrived entity is the awaited target — this must be called from `NetworkSync._on_entity_added` for every entity arrival on every peer (both server and client).

**Primary recommendation:** Follow the exact file list in CONTEXT.md. Every change is a targeted edit: a few line removals in the handler, a few line additions in `network_sync.gd` and `spawn_manager.gd`, and MockNetworkSync field deletions in three test files.

---

## Standard Stack

### Core (Already Present — No New Dependencies)

| Component | File | Purpose | Status |
|-----------|------|---------|--------|
| SyncRelationshipHandler | `addons/gecs_network/sync_relationship_handler.gd` | Full relationship serialize/deserialize/pending/authority logic | EXISTS — needs SyncConfig gate removal only |
| NetworkSync | `addons/gecs_network/network_sync.gd` | RPC surface, handler instantiation, signal wiring | EXISTS — needs 2 RPC methods + `_relationship_handler` field |
| SpawnManager | `addons/gecs_network/spawn_manager.gd` | Serialize entity for spawn, apply on receive | EXISTS — needs `"relationships"` key in `serialize_entity()` + `apply_entity_relationships()` calls |
| Entity signals | `addons/gecs/ecs/entity.gd` line 40, 42 | `relationship_added(entity, relationship)` / `relationship_removed(entity, relationship)` | EXISTS — ready to connect |

### No New Installations Required

All dependencies exist in the project. Phase 4 adds zero new files and zero new imports.

---

## Architecture Patterns

### Established Delegation Pattern (from Phases 1–3)

Every handler is a `RefCounted` with `_ns` reference, instantiated in `NetworkSync._ready()`:

```gdscript
# NetworkSync._ready() pattern — add _relationship_handler to this list:
_spawn_manager = SpawnManager.new(self)
_sender = SyncSender.new(self)
_receiver = SyncReceiver.new(self)
_native_sync_handler = NativeSyncHandler.new(self)
_relationship_handler = SyncRelationshipHandler.new(self)  # ADD
```

### Signal Hookup Pattern (from Phase 3 NativeSyncHandler)

`_on_entity_added` connects per-entity signals. Phase 3 added native sync setup; Phase 4 adds relationship signal connection in the same function:

```gdscript
func _on_entity_added(entity: Entity) -> void:
    # EXISTING Phase 1 guard:
    if not net_adapter.is_in_game() or not net_adapter.is_server():
        return
    _spawn_manager.on_entity_added(entity)
    # ADD for Phase 4 — both server AND client need this:
    # (remove the is_server guard before these two lines)
```

**Critical discretion point:** The CONTEXT.md states `try_resolve_pending()` fires "whenever ANY entity joins the world" including on clients. This means the `_on_entity_added` handler must NOT gate the relationship wiring behind `is_server()`. The existing handler gates spawning logic behind `is_server()` — relationship wiring needs a separate unconditional block.

Pattern for the updated `_on_entity_added`:

```gdscript
func _on_entity_added(entity: Entity) -> void:
    if not net_adapter.is_in_game():
        return
    # Server-only: spawn broadcast
    if net_adapter.is_server():
        _spawn_manager.on_entity_added(entity)
    # All peers: relationship signal hookup + pending resolution
    if _relationship_handler != null:
        entity.relationship_added.connect(
            func(e, r): _relationship_handler.on_relationship_added(e, r)
        )
        entity.relationship_removed.connect(
            func(e, r): _relationship_handler.on_relationship_removed(e, r)
        )
        _relationship_handler.try_resolve_pending(entity)
```

### RPC Declaration Pattern (NetworkSync is the only @rpc node)

```gdscript
# Source: network_sync.gd existing RPC pattern — same shape as _sync_components_reliable
@rpc("any_peer", "reliable")
func _sync_relationship_add(payload: Dictionary) -> void:
    if _relationship_handler == null:
        return
    _relationship_handler.handle_relationship_add(payload)

@rpc("any_peer", "reliable")
func _sync_relationship_remove(payload: Dictionary) -> void:
    if _relationship_handler == null:
        return
    _relationship_handler.handle_relationship_remove(payload)
```

Note: `"any_peer"` mode with server-side authority validation (inside the handler) is the correct pattern — mirrors `_sync_components_reliable`. The handler already validates sender authority via `get_remote_sender_id()`.

### SyncConfig Gate Removal Pattern

Three guard clauses in `sync_relationship_handler.gd` must be deleted:

```gdscript
# REMOVE FROM serialize_relationship() (line 45-46):
if not _ns.sync_config or not _ns.sync_config.sync_relationships:
    return {}

# REMOVE FROM serialize_entity_relationships() (line 139-140):
if not _ns.sync_config or not _ns.sync_config.sync_relationships:
    return []

# REMOVE FROM _broadcast_relationship_change() (line 244-245):
if not _ns.sync_config or not _ns.sync_config.sync_relationships:
    return
```

After removal: serialization always proceeds for entities with `CN_NetworkIdentity`. The authority check (`net_id = entity.get_component(CN_NetworkIdentity)`) already handles the "is this networked?" question.

### Late-Join Inclusion in spawn_manager.gd

`serialize_entity()` in `spawn_manager.gd` currently returns a dict with no `"relationships"` key. Add:

```gdscript
# At end of serialize_entity(), before the return statement:
var relationships: Array[Dictionary] = []
if _ns.get("_relationship_handler") != null:
    relationships = _ns._relationship_handler.serialize_entity_relationships(entity)

return {
    "id": entity.id,
    "name": entity.name,
    "scene_path": entity.scene_file_path,
    "components": components_data,
    "script_paths": script_paths,
    "relationships": relationships,   # ADD
    "session_id": _ns._game_session_id
}
```

And in `handle_spawn_entity()`, after `_apply_component_data()`:

```gdscript
# After _inject_authority_markers and native sync setup:
if _ns.get("_relationship_handler") != null:
    var rel_data = data.get("relationships", [])
    _ns._relationship_handler.apply_entity_relationships(entity, rel_data)
```

Use `_ns.get("_relationship_handler")` null-safety guard (same pattern as `_ns.get("_native_sync_handler")` used in current `spawn_manager.gd` line 203).

### Anti-Patterns to Avoid

- **Connecting signals without Callable capture:** GDScript `entity.relationship_added.connect(_relationship_handler.on_relationship_added)` would pass the entity as the first arg since the signal emits `(entity, relationship)`. The handler's `on_relationship_added(entity, relationship)` signature matches the signal exactly, so direct method binding works: `entity.relationship_added.connect(_relationship_handler.on_relationship_added)`.

- **Disconnecting on entity removal (discretion area):** The CONTEXT.md leaves signal disconnect/GC to Claude's discretion. The safe choice: do NOT disconnect explicitly in `_on_entity_removed`. Entities are `queue_free()`'d; GDScript signals are automatically disconnected when the signal emitter (the entity) is freed. Explicitly tracking and disconnecting would add complexity for no benefit.

- **Calling `try_resolve_pending` only on clients:** Both server and client may receive entities out-of-order in world state snapshots. Call `try_resolve_pending` unconditionally (guarded only by `is_in_game()`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deferred relationship resolution | Custom queue per entity | Existing `_pending_relationships` dict in handler | Already correct — keyed on source entity ID, entries are raw recipes, `try_resolve_pending` iterates efficiently |
| Recipe serialization | Custom binary format | Existing `{"r": path, "tt": type, "t": ref}` format | Handles all 4 target types (Entity/Component/Script/Null), validated by `_load_script_instance` |
| Sync loop prevention | Manual flags | Existing `_applying_relationship_data` + `_ns._applying_network_data` dual check | Both flags must be checked; handler already does this |
| Authority validation | Custom per-RPC logic | Existing `handle_relationship_add/remove` authority pattern | Mirrors `handle_add_component` — server accepts from owner, client accepts from server only |

---

## Common Pitfalls

### Pitfall 1: Forgetting the `is_in_game()` Guard on `_on_entity_added`

**What goes wrong:** `_on_entity_added` is called even in single-player or editor mode (any time entities are added to the world). Connecting relationship signals unconditionally adds unnecessary per-entity overhead and `try_resolve_pending` accesses `_ns._world.entity_id_registry` which may be null.

**How to avoid:** Gate all Phase 4 additions in `_on_entity_added` behind `if not net_adapter.is_in_game(): return` — same guard that already exists for the spawn path.

**Warning sign:** `null` errors in `try_resolve_pending` when testing in single-player.

### Pitfall 2: `_on_entity_added` is Gated `is_server()` — Breaks Client-Side Deferred Resolution

**What goes wrong:** The current `_on_entity_added` returns early if `not net_adapter.is_server()`. If relationship signal hookup and `try_resolve_pending` are added inside that block, clients will never resolve pending relationships when target entities arrive.

**How to avoid:** Restructure `_on_entity_added` so spawn logic stays server-only, but relationship wiring is unconditional (after the `is_in_game()` check). See the pattern in Architecture Patterns above.

**Warning sign:** Deferred resolution test passes on server, fails on client side.

### Pitfall 3: SyncConfig Still Referenced in MockNetworkSync After Cleanup

**What goes wrong:** `test_sync_relationship_handler.gd` `MockNetworkSync` still has `var sync_config: SyncConfig` and `sync_config = SyncConfig.new()`. After removing the gate clauses from the handler, the handler no longer accesses `_ns.sync_config` — but the test `test_serialize_returns_empty_when_disabled()` specifically sets `mock_ns.sync_config.sync_relationships = false` to test that behavior. This test must be deleted (the gate no longer exists).

**How to avoid:** Delete `test_serialize_returns_empty_when_disabled()` and the `sync_config` field from `MockNetworkSync` in `test_sync_relationship_handler.gd` at the same time the gate is removed. The serialization-always-on behavior can be validated by the existing positive tests.

**Warning sign:** Test references `mock_ns.sync_config` after the field was removed — parse error at test load time.

### Pitfall 4: `serialize_entity_relationships()` Called Before `_relationship_handler` Exists

**What goes wrong:** `SpawnManager.serialize_entity()` is called from `_deferred_broadcast` which fires shortly after `_ready()`. If `_relationship_handler` is instantiated after `_spawn_manager` but a race condition occurs, `serialize_entity()` could call `_ns._relationship_handler` when it's null.

**How to avoid:** Use `_ns.get("_relationship_handler")` (the null-safe property getter) when calling from SpawnManager, same pattern as `_ns.get("_native_sync_handler")` at line 203 of current `spawn_manager.gd`. The handler is set unconditionally in `_ready()` before any world signals fire, so this is defensive coding only.

### Pitfall 5: `handle_world_state` Skips Relationships

**What goes wrong:** `SpawnManager.handle_world_state()` calls `handle_spawn_entity(entity_data)` for each entity. If `handle_spawn_entity()` calls `apply_entity_relationships()` correctly, late-join relationships work automatically. If the call is placed in `handle_world_state()` separately, double-apply is possible.

**How to avoid:** Place `apply_entity_relationships()` inside `handle_spawn_entity()` only — not in `handle_world_state()`. Since `handle_world_state` delegates entirely to `handle_spawn_entity`, this single placement covers both initial spawn and late-join.

### Pitfall 6: v0.1.1 SyncConfig Cleanup — `sync_spawn_handler.gd` Has `_ns.sync_config` in Debug Paths

**What goes wrong:** `sync_spawn_handler.gd` accesses `_ns.sync_config.transform_component` in two debug logging branches (lines 87–88 and 253–260, 272). These are v0.1.1 code paths that should be removed along with the SyncConfig gate references. If only the obvious gate checks are removed but debug paths remain, tests may fail if `sync_config` is removed from MockNetworkSync.

**How to avoid:** When doing opportunistic SyncConfig cleanup in `sync_spawn_handler.gd`, search for ALL occurrences of `_ns.sync_config` (there are 4+ in that file) and either delete the debug block or replace `_ns.sync_config.transform_component` with a comment stub. The v0.1.1 handlers are being cleaned up, not rewritten — the safest path is to delete the affected diagnostic blocks entirely.

---

## Code Examples

### Pattern: _on_entity_added Restructure

```gdscript
# Source: analysis of network_sync.gd current implementation + CONTEXT.md decisions
func _on_entity_added(entity: Entity) -> void:
    if not net_adapter.is_in_game():
        return
    # Server-only: queue deferred spawn broadcast
    if net_adapter.is_server():
        _spawn_manager.on_entity_added(entity)
    # All peers: wire relationship signals + attempt deferred resolution
    if _relationship_handler != null:
        entity.relationship_added.connect(_relationship_handler.on_relationship_added)
        entity.relationship_removed.connect(_relationship_handler.on_relationship_removed)
        _relationship_handler.try_resolve_pending(entity)
```

### Pattern: reset_for_new_game Extension

```gdscript
# Source: CONTEXT.md Claude's Discretion — recommend yes
func reset_for_new_game() -> void:
    _game_session_id += 1
    _broadcast_pending.clear()
    _spawn_counter = 0
    if _relationship_handler != null:
        _relationship_handler.reset()  # Clears _pending_relationships
```

### Pattern: MockNetworkSync for test_sync_relationship_handler.gd After Cleanup

```gdscript
# After SyncConfig removal — MockNetworkSync has NO sync_config field
class MockNetworkSync:
    extends RefCounted
    var _world: World
    var _applying_network_data: bool = false
    var _game_session_id: int = 0
    var net_adapter: NetAdapter
    var debug_logging: bool = false

    var last_rpc_method: String = ""
    var last_rpc_payload: Dictionary = {}

    func _init(w: World) -> void:
        _world = w
        net_adapter = NetAdapter.new()

    func _sync_relationship_add(_payload: Dictionary) -> void:
        last_rpc_method = "_sync_relationship_add"
        last_rpc_payload = _payload
```

### Pattern: New Integration Tests for NetworkSync Wiring

New tests in `test_spawn_manager.gd` or a new `test_network_sync_relationships.gd` should verify the wiring end-to-end:

```gdscript
# Test: serialize_entity includes relationships key
func test_serialize_entity_includes_relationships_key():
    var entity = Entity.new()
    entity.id = "e1"
    entity.add_component(CN_NetworkIdentity.new(0))
    world.add_entity(entity)
    mock_ns._relationship_handler = SyncRelationshipHandler.new(mock_ns)

    var data = spawn_manager.serialize_entity(entity)
    assert_bool(data.has("relationships")).is_true()
    assert_array(data["relationships"]).is_empty()  # No relationships yet

# Test: try_resolve_pending fires when entity added
func test_entity_added_triggers_try_resolve_pending():
    # ... setup pending recipe, add entity, verify resolution
```

---

## SyncConfig Cleanup Scope

This is the full scope of `sync_config` references to remove across the opportunistic files:

### sync_relationship_handler.gd (3 removal points)
1. `serialize_relationship()` lines 45–46: delete the `if not _ns.sync_config...` guard
2. `serialize_entity_relationships()` lines 139–140: delete the `if not _ns.sync_config...` guard
3. `_broadcast_relationship_change()` lines 244–245: delete the `if not _ns.sync_config...` guard

### test_sync_relationship_handler.gd (MockNetworkSync cleanup)
1. Delete `var sync_config: SyncConfig` field from MockNetworkSync
2. Delete `sync_config = SyncConfig.new()` and `sync_config.sync_relationships = true` from `_init`
3. Delete entire `test_serialize_returns_empty_when_disabled()` test (the feature it tested no longer exists)

### sync_state_handler.gd (opportunistic — 3 occurrences)
1. `process_reconciliation()` line 172: `if not _ns.sync_config or not _ns.sync_config.enable_reconciliation:` — this whole method can be left as-is since reconciliation is Phase 5, or the guard can be changed to a `return` stub
2. `serialize_entity_full()` line 220: `if _ns.sync_config and _ns.sync_config.should_skip(comp_type):` — remove guard (or simplify to never skip)
3. `process_entity_count_diagnostics()` lines 435–438: `if _ns.sync_config:` branch for `get_entity_category` — simplify to always use peer_id heuristic fallback

### sync_spawn_handler.gd (opportunistic — 4+ occurrences)
1. `broadcast_entity_spawn()` lines 87–88: `_ns.sync_config.transform_component` in debug block — delete or comment out the transform diagnostic block
2. `handle_spawn_entity()` lines 253–278: Multiple `_ns.sync_config.transform_component` references in debug + sync blocks — these are v0.1.1-only logic; delete the affected blocks
3. `serialize_entity_spawn()` line 533: `if comp_type == _ns.sync_config.model_ready_component:` — remove this skip (v2 handles model_ready via CN_NativeSync, not SyncConfig)

### test_sync_state_handler.gd (check only — MockNetworkSync has sync_config)
Current `MockNetworkSync` has `var sync_config: SyncConfig` at line 47 and `sync_config = SyncConfig.new()` in `_init`. After `sync_state_handler.gd` no longer accesses `_ns.sync_config`, this field can be removed. Verify no test assertions rely on it.

### test_sync_spawn_handler.gd (check only — MockNetworkSync has sync_config)
Current `MockNetworkSync` has `sync_config = SyncConfig.new()` with `sync_relationships = true`. After `sync_spawn_handler.gd` no longer uses `_ns.sync_config`, remove the field and any test that asserts sync_config behavior.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | GdUnit4 (project default) |
| Config file | `GdUnitRunner.cfg` |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` |
| Full suite command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADV-01 | Relationship add/remove serialization and RPC broadcast | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` | Yes |
| ADV-01 | Deferred resolution: pending recipe applied when target entity arrives | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd::test_deferred_resolution_entity_target"` | Yes |
| ADV-01 | serialize_entity() includes "relationships" key | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd"` | Yes (needs new test) |
| ADV-01 | _on_entity_added triggers try_resolve_pending | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd"` | Yes (needs new test) |
| ADV-01 | reset_for_new_game clears pending relationships | unit | in test_sync_relationship_handler.gd::test_reset_clears_pending | Yes |

### Sampling Rate
- **Per task commit:** `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"`
- **Per wave merge:** `runtest.cmd -a "res://addons/gecs_network/tests" -c`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — needs new test for `serialize_entity()` relationships key inclusion (ADV-01 late-join coverage)
- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — needs new test for `handle_spawn_entity()` calling `apply_entity_relationships()` (ADV-01 receive-side)

*(All other existing tests in `test_sync_relationship_handler.gd` already cover ADV-01 core behaviors. No new test files needed.)*

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sync_config.sync_relationships = true` gate | Always-on for CN_NetworkIdentity entities | Phase 4 | Removes opt-in ceremony; relationships sync by default |
| SyncConfig as central configuration registry | Per-component `@export_group` on CN_NetSync | Phase 2 | SyncConfig is now a stub; Phase 4 finishes removing its last few gate references |
| `sync_spawn_handler.gd` / `sync_state_handler.gd` as v0.1.1 handlers | Clean v2 handlers (`spawn_manager.gd`, `sync_sender.gd`, `sync_receiver.gd`, `native_sync_handler.gd`) | Phases 1–3 | v0.1.1 handlers remain as dead code until Phase 4 opportunistic cleanup |

**Deprecated/outdated:**
- `SyncConfig.sync_relationships`: deleted in Phase 4 (gate removal makes it meaningless)
- `SyncConfig.model_ready_component`: used in `sync_spawn_handler.gd` serialize — remove with Phase 4 cleanup; v2 uses CN_NativeSync
- `SyncConfig.transform_component`: used in `sync_spawn_handler.gd` debug blocks — remove with cleanup

---

## Open Questions

1. **Signal connect method binding vs. lambda**
   - What we know: `entity.relationship_added` signal signature is `(entity: Entity, relationship: Relationship)` — matches `on_relationship_added(entity, relationship)` exactly
   - What's unclear: Whether `entity.relationship_added.connect(_relationship_handler.on_relationship_added)` works for a RefCounted method reference in GDScript, or whether a lambda is needed
   - Recommendation: Use direct method reference `entity.relationship_added.connect(_relationship_handler.on_relationship_added)`. This is valid GDScript; RefCounted methods are callable. If test runner shows signal-not-connected errors, switch to lambda form.

2. **`sync_state_handler.gd` process_reconciliation() cleanup scope**
   - What we know: `process_reconciliation()` checks `_ns.sync_config.enable_reconciliation` — this is Phase 5 (ADV-02) functionality
   - What's unclear: Whether to stub the method (return early) or remove the sync_config check and leave it accessible via a future `enable_reconciliation` flag on NetworkSync itself
   - Recommendation: Replace the `sync_config` guard with a simple `return` (since reconciliation isn't implemented in Phase 4) and leave a `# TODO Phase 5 (ADV-02)` comment. This is the minimal change.

3. **`test_spawn_manager.gd` existing structure**
   - What we know: The file exists and has tests for `serialize_entity()` and `handle_spawn_entity()`
   - What's unclear: Whether existing tests already create a `_relationship_handler` on their MockNetworkSync, or whether adding the `"relationships"` key to `serialize_entity()` will break existing assertions
   - Recommendation: Check `test_spawn_manager.gd` at plan time. If existing tests assert exact dict structure of `serialize_entity()` output, they'll need updating to accept (or ignore) the new `"relationships"` key.

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `addons/gecs_network/sync_relationship_handler.gd` — full handler logic, all 3 SyncConfig gate locations identified by line number
- Direct code inspection: `addons/gecs_network/network_sync.gd` — current RPC pattern, `_on_entity_added` structure, `reset_for_new_game` body
- Direct code inspection: `addons/gecs_network/spawn_manager.gd` — `serialize_entity()` return dict structure, `handle_spawn_entity()` post-component-apply sequence
- Direct code inspection: `addons/gecs/ecs/entity.gd` — `relationship_added` and `relationship_removed` signal declarations at lines 40 and 42
- `04-CONTEXT.md` — all locked decisions, file list, integration points
- `REQUIREMENTS.md` — ADV-01 requirement text

### Secondary (MEDIUM confidence)
- Pattern inference: `_ns.get("_native_sync_handler")` null-safety pattern in `spawn_manager.gd` line 203 — same pattern should be used for `_relationship_handler` calls from SpawnManager
- Signal lifecycle: GDScript documentation convention that signals are auto-disconnected when emitter is freed — verified by project pattern (no explicit disconnects for per-entity signals in Phase 3)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files inspected directly; no new libraries
- Architecture: HIGH — wiring pattern is verbatim from established Phase 1–3 patterns; exact line references provided
- Pitfalls: HIGH — identified from direct code inspection of guard clause locations and `_on_entity_added` structure
- SyncConfig cleanup scope: HIGH — all occurrences found via grep-style review of each file

**Research date:** 2026-03-10
**Valid until:** Stable — no external library dependencies; all findings are from codebase inspection

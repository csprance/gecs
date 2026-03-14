# Phase 4: Relationship Sync - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire `SyncRelationshipHandler` (which already exists with comprehensive logic) into the v2
`NetworkSync` node: add relationship RPCs, connect per-entity signals, include relationships in
world state snapshots (late-join), call `try_resolve_pending()` on entity arrival, and remove all
`SyncConfig` references from the handler and its tests. Phase 4 also opportunistically removes
`SyncConfig` references from all remaining v0.1.1 handlers. Property sync (Phase 2) and native
transform sync (Phase 3) are not touched.

</domain>

<decisions>
## Implementation Decisions

### Relationship Opt-In Model

- **Always-on for all networked entities** — if an entity has `CN_NetworkIdentity`, all its
  relationships are synced. Zero configuration required.
- No `sync_config.sync_relationships` gate — that field is deleted with SyncConfig
- Handler authority check becomes: "does this entity have CN_NetworkIdentity?" (already in handler)
- **Signal hookup: per-entity on spawn** — `NetworkSync._on_entity_added` connects to
  `entity.relationship_added` and `entity.relationship_removed` signals when an entity is added to
  the world (same lifecycle as native sync setup in Phase 3)
- **Clients can broadcast for owned entities** — client sends add/remove for entities it owns
  (`net_id.peer_id == my_peer_id`), server validates authority and relays to all clients

### World State Inclusion (Late-Join)

- **Bundled in spawn payload** — `serialize_entity()` always includes a `"relationships"` key
  containing an array of relationship recipes (even if empty)
- `apply_entity_relationships()` is called in `handle_spawn_entity` / `handle_world_state` after
  component data is applied — same RPC, same timing
- `try_resolve_pending()` is called from **`NetworkSync._on_entity_added`** (not SpawnManager)
  — fires whenever ANY entity joins the world, catching both initial and late-join scenarios

### Deferred Pending Cleanup

- **Session reset only** — pending relationships accumulate until `reset_for_new_game()` clears
  them. Relationships are rare events; memory cost is negligible.
- No per-entity cleanup on despawn, no bounded queue — keep it simple for Phase 4
- Unbounded pending queue — no warnings or drops for Phase 4

### SyncConfig Gate Removal

- **Full cleanup** — remove all `sync_config.*` references from `sync_relationship_handler.gd`
  (the `_ns.sync_config` checks in `serialize_relationship()`, `serialize_entity_relationships()`,
  and `_broadcast_relationship_change()`)
- Tests updated: `MockNetworkSync` in `test_sync_relationship_handler.gd` loses its `sync_config`
  field entirely; no SyncConfig import or instantiation
- **Opportunistic scope**: also remove SyncConfig references from `sync_state_handler.gd` and
  `sync_spawn_handler.gd` (and their tests) since we're touching the codebase anyway

### NetworkSync RPC Additions

- Two new RPCs on `NetworkSync`:
  ```gdscript
  @rpc("any_peer", "reliable")
  func _sync_relationship_add(payload: Dictionary) -> void: ...

  @rpc("any_peer", "reliable")
  func _sync_relationship_remove(payload: Dictionary) -> void: ...
  ```
- Both delegate to `_relationship_handler.handle_relationship_add(payload)` /
  `handle_relationship_remove(payload)` — follows SpawnManager/SyncSender/SyncReceiver delegation
  pattern
- `NetworkSync._ready()` instantiates: `_relationship_handler = SyncRelationshipHandler.new(self)`

### Claude's Discretion

- Exact signal connect/disconnect lifecycle for per-entity relationship signals (whether to
  disconnect on entity removal or rely on GC)
- Whether `_on_entity_added` on clients also triggers `try_resolve_pending` (it should — clients
  need deferred resolution too)
- Error handling when `relationship_added` fires on a non-networked entity (no CN_NetworkIdentity)
- Whether `reset_for_new_game()` extension calls `_relationship_handler.reset()`

</decisions>

<specifics>
## Specific Ideas

- `sync_relationship_handler.gd` already has the full implementation — Phase 4 is primarily a
  wiring and cleanup task, not a greenfield implementation
- The handler's existing `_pending_relationships` dict and `try_resolve_pending()` are correct
  as-is; no rework needed
- The authority check in `handle_relationship_add` / `handle_relationship_remove` already handles
  server relay to all clients — correct model

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `sync_relationship_handler.gd` — full serialize/deserialize/deferred-resolution/authority/RPC
  handler already written. Only needs: SyncConfig gate removal and wiring into NetworkSync.
- `entity.relationship_added` / `entity.relationship_removed` signals (entity.gd lines 40, 42) —
  ready to connect per-entity in `_on_entity_added`
- `spawn_manager.serialize_entity()` — extend to add `"relationships"` key using
  `_relationship_handler.serialize_entity_relationships(entity)`
- `spawn_manager.handle_spawn_entity()` / `handle_world_state()` — extend to call
  `apply_entity_relationships()` after component data is applied

### Established Patterns

- RefCounted delegation: `_relationship_handler = SyncRelationshipHandler.new(self)` in
  `NetworkSync._ready()` — same pattern as `_spawn_manager`, `_sender`, `_receiver`,
  `_native_sync_handler`
- `_ns._sync_relationship_add` / `_ns._sync_relationship_remove` — handler already references
  these on `_ns`; NetworkSync just needs to declare them as `@rpc` methods
- Session ID in payload: handler already includes `session_id` in RPC payloads — correct

### Integration Points

- `network_sync.gd._on_entity_added()` — add: connect entity signals + call
  `try_resolve_pending(entity)` (for clients resolving deferred pending)
- `network_sync.gd._ready()` — add: `_relationship_handler = SyncRelationshipHandler.new(self)`
- `network_sync.gd.reset_for_new_game()` — add: `_relationship_handler.reset()`
- `spawn_manager.gd.serialize_entity()` — add `"relationships"` key
- `spawn_manager.gd.handle_spawn_entity()` + `handle_world_state()` — call
  `apply_entity_relationships()`

### Files to Modify

- `addons/gecs_network/network_sync.gd` — wire handler, add 2 RPCs, extend `_on_entity_added`,
  extend `reset_for_new_game`
- `addons/gecs_network/spawn_manager.gd` — include relationships in serialize/apply
- `addons/gecs_network/sync_relationship_handler.gd` — remove SyncConfig gate checks
- `addons/gecs_network/tests/test_sync_relationship_handler.gd` — update MockNetworkSync
- `addons/gecs_network/sync_state_handler.gd` — remove SyncConfig references (opportunistic)
- `addons/gecs_network/sync_spawn_handler.gd` — remove SyncConfig references (opportunistic)
- `addons/gecs_network/tests/test_sync_state_handler.gd` — update if SyncConfig used in mocks
- `addons/gecs_network/tests/test_sync_spawn_handler.gd` — update if SyncConfig used in mocks

</code_context>

<deferred>
## Deferred Ideas

- Source entity despawn cleanup for pending relationships — Phase 5 or future insertion phase
- Bounded pending queue with warnings — Phase 5+
- Mid-game relationship transfer across authorities — future phase
- REPLICATION_MODE_ON_CHANGE equivalent for relationships — future

</deferred>

---

*Phase: 04-relationship-sync*
*Context gathered: 2026-03-10*

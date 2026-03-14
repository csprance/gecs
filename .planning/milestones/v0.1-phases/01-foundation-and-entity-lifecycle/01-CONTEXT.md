# Phase 1: Foundation and Entity Lifecycle - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the networking foundation: NetAdapter, session ID anti-ghost, entity spawn/despawn broadcast, late-join world state snapshot, disconnect cleanup, and zero single-player overhead. This phase makes entities exist consistently across all peers. Component property sync is Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Peer ID Semantics
- `is_server_owned()` returns `peer_id == 0` only — peer_id=0 means server-owned NPC/world entity
- peer_id=1 (host) is NOT treated as server-owned — framework makes no assumption about the host
- Framework provides no built-in `is_host()` convention — game decides how to treat peer_id=1
- Authority validation is done server-side using the actual RPC sender's peer_id (unforgeable from transport), not component fields

### World Integration Model
- Keep `NetworkSync.attach_to_world(world, net_adapter: NetAdapter = null)` factory method
- null net_adapter uses default Godot multiplayer — no boilerplate for simple games
- NetworkSync auto-discovers its parent World by walking the scene tree — no explicit world reference needed after attach
- Node name "NetworkSync" is set explicitly in factory and guarded in `_ready()` (critical for RPC routing)

### Entity Identity
- Use sequential spawn counter — server increments a session-scoped integer per spawn
- Network ID stored in `CN_NetworkIdentity` as `spawn_index` (existing field, keep it)
- `CN_NetworkIdentity` holds both `peer_id` and `spawn_index` — together they uniquely identify an entity
- No composite IDs or client-side ID generation — v2 is server-authoritative spawning only

### Spawn Payload
- Payload includes: scene path (auto-detected from `entity.scene_file_path`) + serialized component data
- Scene path auto-detection from `scene_file_path` — no manual registration required
- Developers set component values on the entity BEFORE the network spawn happens — deferred broadcast captures correct values
- Broadcast is deferred via `call_deferred` with `_broadcast_pending` guard to prevent double-broadcast

### Claude's Discretion
- Internal implementation of `_broadcast_pending` cancellation logic
- Exact session ID increment strategy (random vs monotonic)
- Error handling for missing scene paths (entity created at runtime without a scene)
- How disconnect cleanup handles in-flight RPCs

</decisions>

<specifics>
## Specific Ideas

- Framework should "get out of the way" of host/server topology decisions — no assumptions about whether peer_id=1 is a player or a server
- The v0.1.1 `_applying_network_data` flag pattern is correct and must be carried forward
- The `_broadcast_pending` guard from v0.1.1 is correct — keep it

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetAdapter` (net_adapter.gd): Fully reusable — wraps MultiplayerAPI with cache invalidation, is_in_game(), get_connected_peers(). Keep verbatim.
- `CN_NetworkIdentity` (components/cn_network_identity.gd): Keep peer_id, spawn_index fields. Update is_server_owned() to return peer_id == 0 only.
- `TransportProvider` / `ENetTransportProvider` (transports/): Keep verbatim — pluggable transport layer is architecturally correct.
- `NetworkSync._applying_network_data` flag: Keep — prevents sync loops (critical, non-retrofittable).
- `NetworkSync._broadcast_pending` dict: Keep — prevents double-broadcast on deferred spawn (critical).
- `NetworkSync._game_session_id` + session ID in RPC signatures: Keep — prevents stale RPC delivery (critical, non-retrofittable).

### Established Patterns
- Factory method `attach_to_world()`: v0.1.1 pattern is correct — preserve it.
- Deferred spawn broadcast: `entity_added` signal fires → store in `_broadcast_pending` → `call_deferred` executes broadcast → serialize component data at broadcast time (not at signal time).
- `Component.serialize()`: Existing GECS method serializes all @export properties — use for spawn payload.

### Integration Points
- `World.entity_added` / `World.entity_removed` signals: NetworkSync connects to these for spawn/despawn triggers.
- `World.add_entity()` / `World.remove_entity()`: Standard path for entity lifecycle — NetworkSync hooks via signals, not by overriding these methods.
- `multiplayer.peer_connected` / `multiplayer.peer_disconnected` signals on MultiplayerAPI: For late-join and disconnect cleanup.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation-and-entity-lifecycle*
*Context gathered: 2026-03-07*

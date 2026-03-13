# GECS Networking v2

## What This Is

A complete overhaul of GECS networking that replaces the old `NetworkMiddleware` system with a declarative, component-driven networking layer. Developers mark components as networked with `CN_NetSync` + `@export_group` annotations, call `session.host()` or `session.join()`, and the framework handles all RPC dispatch, spawn/despawn replication, authority management, and reconciliation automatically.

## Core Value

Developers can add multiplayer to their ECS game by marking components as networked — no manual RPC calls, serialization code, or complex networking logic required.

## Requirements

### Validated

- ✓ Component-level network configuration via `CN_NetSync` + `@export_group` (REALTIME/HIGH/MEDIUM/LOW) — v0.1
- ✓ Automatic entity lifecycle sync (spawn/despawn without manual RPCs) — v0.1
- ✓ Late-join full world state snapshot — v0.1
- ✓ Peer disconnect cleanup (all owned entities removed on all peers) — v0.1
- ✓ Authority model via `CN_LocalAuthority` / `CN_ServerAuthority` marker components — v0.1
- ✓ Native transform sync via `MultiplayerSynchronizer` (built-in interpolation) — v0.1
- ✓ Entity relationship sync with deferred resolution — v0.1
- ✓ Periodic full-state reconciliation broadcast (default 30s, configurable) — v0.1
- ✓ Custom sync handler override API (`register_send/receive_handler`) — v0.1
- ✓ `NetworkSession` node with `host()` / `join()` / `end_session()` API — v0.1
- ✓ ECS-friendly session lifecycle events as transient components — v0.1
- ✓ Zero networking overhead in single-player — v0.1
- ✓ Full v2 documentation suite + v1→v2 migration guide — v0.1

### Active

- [ ] Server time sync (TIME-01, TIME-02) — client can query server clock offset for authoritative cooldowns
- [ ] Client-side prediction helpers (PRED-01, PRED-02, PRED-03) — rollback buffer, predicted components, smoothed corrections
- [ ] Interest management (INT-01, INT-02) — visibility zones, custom relevancy filters

### Out of Scope

| Feature | Reason |
|---------|--------|
| Client-side prediction implementation | Override hooks provided in ADV-03 (v0.1); full implementation deferred to v3 |
| Server time synchronization | Useful but not blocking core sync — deferred to next milestone |
| P2P / WebRTC networking | Different topology, fundamentally changes architecture — server-client only |
| Lobby / matchmaking | GECS Networking is a state sync layer, not session management |
| Interest management / spatial culling | Hooks exposed (ADV-03), full policy deferred |
| Backwards compatibility with v0.1.x | Clean break — v1→v2 migration guide provided |
| Deterministic physics / lockstep | Different architecture; incompatible with async sync model |

## Context

**Shipped v0.1** with 6,168 lines of GDScript across `addons/gecs_network/`.

**Tech stack:** GDScript, Godot 4.x MultiplayerAPI, ENet, `MultiplayerSynchronizer`, gdUnit4.

**Architecture:** `NetworkSync` node as single RPC surface, delegating to `SpawnManager`, `SyncSender`, `SyncReceiver`, `NativeSyncHandler`, `SyncRelationshipHandler`, `SyncReconciliationHandler`. `NetworkSession` wraps connection boilerplate. Session events surface as ECS components (`CN_PeerJoined`, `CN_PeerLeft`, etc.) on a persistent session entity.

**Example project:** `example_network/` demonstrates all v2 features — entity lifecycle, property sync, authority, projectile spawning, and `NetworkSession` wiring.

**Known issues / tech debt:**
- `sync_state_handler.gd`, `sync_property_handler.gd`, `sync_spawn_handler.gd` are v0.1.1-era stubs that still reference the deleted `CN_SyncEntity` — they are dead code left as historical stubs, should be fully deleted in a cleanup pass
- `MultiplayerSynchronizer` `refresh_synchronizer_visibility()` availability not verified against all Godot 4.x minor versions
- Performance under high entity count (>500 networked entities) not benchmarked

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace `NetworkMiddleware` with declarative `CN_NetSync` | ECS components are natural sync units; middleware required too much boilerplate | ✓ Good — core v2 design |
| New branch, clean break from v0.1.x | Allows complete redesign without breaking existing users | ✓ Good — migration guide handles upgrades |
| `peer_id=0` = server-owned only (not `peer_id=1`) | Eliminates ambiguity; `peer_id=1` is the host client in ENet | ✓ Good — locked in Phase 1 |
| `NetworkSync` as single RPC surface | Testable; all `@rpc` methods in one Node | ✓ Good — SyncSender/Receiver stay as RefCounted |
| `CN_NetSync` scan via `scan_entity_components()` | Lazy, called on first sync tick — avoids _ready() ordering issues | ✓ Good |
| `call_deferred('_deferred_broadcast')` for spawn batching | Handles add-then-remove-same-frame race | ✓ Good |
| `_applying_network_data` guard in SpawnManager | Prevents echo broadcast of received data (sync loop prevention) | ✓ Good |
| `on_peer_disconnected` removes entity before `queue_free()` | Despawn RPC fires to remaining peers before node is freed | ✓ Good |
| `CN_LocalAuthority` / `CN_ServerAuthority` markers (not `is_multiplayer_authority()`) | Game systems stay decoupled from Godot's multiplayer internals | ✓ Good |
| `NativeSyncHandler` wraps `MultiplayerSynchronizer` | Built-in interpolation; no per-frame RPC overhead for transforms | ✓ Good |
| Relationship deferred resolution queue | Non-deterministic spawn ordering on clients — deferred apply once target arrives | ✓ Good |
| Reconciliation via full-state broadcast (not delta) | Simpler, correctness over efficiency; 30s interval keeps bandwidth acceptable | ✓ Good |
| `register_send/receive_handler` API on `NetworkSync` | Sufficient override surface for prediction patterns without framework complexity | ✓ Good |
| `NetworkSession` with `end_session()` (not `disconnect()`) | `Node.disconnect()` is a built-in signal method — shadowing causes parser warnings | ✓ Good |
| Transient event components cleared at START of `_process()` | Game systems see events for a full frame before clearing | ✓ Good |
| `session.network_sync == null` as connection guard | Single source of truth; avoids `_is_connected` bool drift | ✓ Good |
| `TransportProvider extends Resource` (not `RefCounted`) | `@export` compatibility with Godot inspector | ✓ Good |

## Constraints

- **Tech stack**: GDScript only — maintain GECS's simplicity
- **Godot version**: Must work with Godot 4.x multiplayer APIs
- **Performance**: Zero networking overhead for single-player games
- **Migration**: New branch, v1→v2 migration guide provided
- **Architecture**: Build on existing GECS core, replace only networking layer

---
*Last updated: 2026-03-13 after v0.1 milestone*

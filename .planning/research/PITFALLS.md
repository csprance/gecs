# Domain Pitfalls: GECS Networking v2

**Domain:** Declarative ECS networking for Godot 4.x
**Researched:** 2026-03-07
**Source basis:** Direct analysis of existing GECS networking v1 codebase (`addons/gecs_network/`) — all pitfalls below are drawn from real guard clauses, deferred-call workarounds, comments, and session-tracking mechanisms discovered in the live code. Confidence is HIGH for all critical and moderate pitfalls because the mitigations are already implemented as working code.

---

## Critical Pitfalls

Mistakes that cause rewrites or persistent, hard-to-debug desyncs.

---

### Pitfall 1: Spawn Broadcast Racing Component Setup

**What goes wrong:** The server adds an entity to the world, then sets component values in the next line. `entity_added` fires immediately and triggers the spawn RPC. The RPC reaches clients before component values are set, so clients spawn the entity with all-default values (position 0,0,0; health 100 when it should be 30, etc.).

**Why it happens:** `World.add_entity` → signal → RPC is synchronous. Component property assignment happens on the line after `add_entity()`. The network packet is already sent.

**Consequences:** Clients see entities flash to origin, then jump to correct position one frame later. Initial state (spawn-time health, inventory, team) is always wrong.

**Prevention:** Defer the spawn broadcast to end-of-frame using `call_deferred`. Gate all component-value syncing through a `_broadcast_pending` dictionary keyed on entity ID. Only serialize and broadcast once the deferred call fires — by then all `add_component()` calls for that frame have completed.

**Detection:** Entities on clients always spawn at Vector3.ZERO then snap to the correct position. Any `@export` property that is set immediately after `add_entity()` appears with its default value on clients.

**Phase:** Must be addressed in Phase 1 (entity spawn/despawn foundation). This is the first bug you will hit.

**Evidence in v1 code:** `network_sync.gd` lines 534–540 — the `_broadcast_pending` dictionary and `call_deferred("_deferred_broadcast_entity_spawn", ...)` pattern. The comment reads: "IMPORTANT: Defer spawn broadcast to end of frame. This allows component values to be set AFTER add_entity() is called."

---

### Pitfall 2: Stale RPC Delivery After Game Reset

**What goes wrong:** The server broadcasts a despawn for entity X at end of game. Client calls `reset_for_new_game()` and starts a new session. The in-flight despawn RPC arrives and despawns a newly spawned entity in the new session that happens to have the same ID.

**Why it happens:** UDP/reliable-ordered RPCs can be in-flight for 100-500ms. Game sessions can reset faster than that (lobby → game transitions). Entity IDs re-used across sessions collide with stale packets.

**Consequences:** Entities vanish immediately after spawning in new game sessions. Ghosts persist from previous sessions. Desyncs accumulate without any visible error.

**Prevention:** Include a monotonically incrementing `session_id` in every spawn, despawn, component-add, and component-remove RPC. On the receiver side, reject any RPC where `session_id != local_game_session_id`. The server sets the canonical session ID; clients sync it when they receive the world state snapshot.

**Detection:** Entities appearing then immediately vanishing on clients but not on the server. Entity counts diverge between server and clients after returning to lobby.

**Phase:** Must be addressed in Phase 1. Needs to be baked into the initial RPC design — retrofitting session IDs later requires touching every RPC signature.

**Evidence in v1 code:** `network_sync.gd` `_game_session_id` field plus session validation in `handle_spawn_entity`, `handle_despawn_entity`, `handle_add_component` throughout `sync_spawn_handler.gd`. `reset_for_new_game()` increments `_game_session_id` and logs the transition.

---

### Pitfall 3: Node Name Inconsistency Breaks All RPCs

**What goes wrong:** Godot routes `@rpc` calls by node path. If the NetworkSync node is named differently on server vs. client (e.g., server creates `NetworkSync.new()` manually and gets `"@Node@15"`, client's scene has `"NetworkSync"`), every single RPC silently fails with "node not found."

**Why it happens:** Godot auto-names nodes with internal identifiers when they are instantiated programmatically without setting `.name`. RPC routing uses the full node path as a string, so paths must match byte-for-byte across all peers.

**Consequences:** Complete networking silence. No errors unless `debug_print_multiplayer_warnings` is enabled. Extremely difficult to diagnose because no exception is thrown — the RPC just does nothing.

**Prevention:** Always assign a hardcoded, consistent name before adding a node to the scene tree: `node.name = "NetworkSync"`. Provide a static factory method that sets this automatically. Add a `_ready()` guard that detects auto-generated names (they start with `"@"`) and renames to the canonical value.

**Detection:** RPCs complete on local machine but peers receive nothing. Enabling `debug_print_multiplayer_warnings = true` in Project Settings shows "Node not found" for every RPC attempt.

**Phase:** Phase 1. The factory method or scene setup must enforce consistent naming before any other work begins.

**Evidence in v1 code:** `network_sync.gd` lines 128–132 (factory method sets `net_sync.name = "NetworkSync"`) and `_ready()` lines 148–150 (guard: `if name.begins_with("@"): name = "NetworkSync"`).

---

### Pitfall 4: Sync Loop — Applied Network Data Re-Triggers Sync

**What goes wrong:** The property setter on a component emits `property_changed` when any property is set. The networking layer listens to `component_property_changed` to detect dirty data and queue sync. When the networking layer applies received data by calling `component.set(prop, value)`, it triggers `property_changed`, which queues the same data for re-broadcast. The server sends data to client A; client A rebroadcasts it back to the server, which rebroadcasts to all clients, creating an infinite loop.

**Why it happens:** ECS components use a reactive change-detection pattern (signals on property set). The same signal hooks both local-to-network flow and network-to-local flow without guarding against the reverse direction.

**Consequences:** Bandwidth explosion. All peers converge to thrashing the same property value. CPU spikes from unbounded RPC queuing. Eventually Godot's packet buffer fills and connections are dropped.

**Prevention:** Use a boolean guard flag (`_applying_network_data`). Set it to `true` before calling `component.set()` from network code, reset to `false` after. In the property change listener, return early if the flag is set. For `SyncComponent`-based polling, call `update_cache_silent(prop, value)` instead of setting the property directly — this updates the dirty-detection baseline without emitting a signal.

**Detection:** Bandwidth meters show exponentially growing traffic after the first sync. Debug logs show each property change triggering another change on the same entity in the same frame. Server and clients fight each other for the same property value (oscillation).

**Phase:** Phase 1. The `_applying_network_data` flag must be the very first thing implemented in the change-detection pathway, before any property sync is wired up.

**Evidence in v1 code:** `network_sync.gd` `_applying_network_data` field; `_apply_component_data()` lines 726–755 that set and clear the flag around every `component.set()` call; `sync_property_handler.gd` early return at lines 127–129.

---

### Pitfall 5: MultiplayerSynchronizer Node Path Race (Native Sync)

**What goes wrong:** Godot's `MultiplayerSynchronizer` must be created *after* its target node is in the scene tree, but *before* the first sync packet arrives from the authority peer. If the entity model/body node is created asynchronously (e.g., via a deferred call or a separate instantiation system), there is a window where sync data arrives and `MultiplayerSynchronizer` cannot find its `root_path` target. Godot logs "Node not found in replication config" and silently drops the sync.

**Why it happens:** ECS model-instantiation systems often run as a separate `System` (e.g., `S_ModelInstantiation`), which runs later in the same frame or in the next frame. If the `MultiplayerSynchronizer` is created at the same time as the entity (during spawn RPC handling), the model node it should synchronize does not yet exist.

**Consequences:** Entities exist on clients but never have their physics body positions updated. Characters stand still at spawn position. No error — the synchronizer just finds nothing to sync and emits no signals.

**Prevention:** Trigger `MultiplayerSynchronizer` creation *reactively* when the model node becomes available, not at entity spawn time. Use a marker component (e.g., `CN_ModelReady`) that is added once the body/model is in the scene tree. Connect the `component_added` signal to detect this marker and then create the synchronizer. For client-side spawns received via RPC, synchronously instantiate the model during `handle_spawn_entity` before calling `auto_setup_native_sync`, ensuring no async gap.

**Detection:** `MultiplayerSynchronizer` exists (verifiable via `entity.get_node_or_null("_NetSync")` not null) but `synchronized` signal is never emitted. Characters are stuck at spawn position but exist in the ECS world.

**Phase:** Phase 2 or Phase 3 (native sync integration). Also affects the client spawn sequence in Phase 1 — clients must synchronously instantiate models during spawn handling.

**Evidence in v1 code:** `sync_native_handler.gd` entire `sync_instantiate_model()` method; `sync_property_handler.gd` `on_component_added()` checking `model_ready_component` name at lines 20–27; `sync_spawn_handler.gd` lines 285–298 (`CN_SyncEntity` detection causing synchronous model instantiation during client spawn).

---

### Pitfall 6: Authority Not Inherited by Child Nodes

**What goes wrong:** Godot's `set_multiplayer_authority(peer_id)` does NOT propagate to children. If you set authority on an `Entity` node (the ECS container), the child `CharacterBody3D` model node has authority = 1 (server) regardless. A `MultiplayerSynchronizer` on the `CharacterBody3D` whose authority should be the owning client will incorrectly run in server mode, causing the server to broadcast the body's position instead of accepting the client's position.

**Why it happens:** Godot's multiplayer authority is per-node, not inherited through the tree. The ECS architecture places game logic (Entity) and physics (CharacterBody3D) on different nodes in the tree. Setting authority at the Entity level silently leaves child nodes unaffected.

**Consequences:** All player positions are controlled by the server. Client input causes local movement but the server immediately overwrites it with its authoritative position (which doesn't have client input). Players appear to freeze or rubber-band constantly.

**Prevention:** After setting authority on the `Entity` node, explicitly call `set_multiplayer_authority(peer_id)` on every child node that will be the target of a `MultiplayerSynchronizer`. The physics body specifically must always have its authority set explicitly.

**Detection:** Server-side log shows it is broadcasting `global_position` for all entities including client-owned ones. Client log shows position being overwritten every frame by incoming sync data despite the client moving locally.

**Phase:** Phase 2 (authority model). Must be documented as a requirement, not discovered during testing.

**Evidence in v1 code:** `sync_native_handler.gd` `populate_model_references()` lines 122–123: `var entity_authority = entity.get_multiplayer_authority(); body.set_multiplayer_authority(entity_authority)` — the explicit comment "Propagate multiplayer authority from Entity to CharacterBody3D — Godot does NOT inherit authority from parent nodes automatically."

---

## Moderate Pitfalls

---

### Pitfall 7: Despawn/Remove-Entity Double-Free and Orphan Nodes

**What goes wrong:** `World.remove_entity(entity)` removes the entity from the ECS world index but does NOT call `entity.queue_free()` — the node remains in the scene tree as an orphan. Separately, if `entity.queue_free()` is called by game logic before the networking layer can send the despawn RPC, the entity ID is no longer in the registry when the RPC fires and clients never receive the despawn.

**Why it happens:** ECS "remove from world" and "free from scene tree" are two separate operations. The networking layer listens to `entity_removed` signal to broadcast despawns, but if the caller also calls `queue_free()` in the same frame, the despawn RPC may be sent for a freed node, or the node may be freed before the deferred broadcast fires.

**Consequences:** Clients accumulate ghost entities that never despawn. Server leaks memory from orphaned nodes. Errors in networking logs about invalid entity references.

**Prevention:** Establish a canonical despawn pattern: always call `World.remove_entity(entity)` first (triggers the despawn RPC signal), then call `entity.queue_free()`. Never call `queue_free()` alone for networked entities. Add an `is_instance_valid(entity)` guard in the deferred broadcast before reading entity data.

**Detection:** Entity count on clients grows unboundedly over time while server count stays correct. `Orphaned nodes` warning in Godot output log.

**Phase:** Phase 1 (entity lifecycle). Establish the canonical remove pattern in documentation before implementation.

**Evidence in v1 code:** `network_sync.gd` `_on_peer_disconnected()` lines 421–431 — always calls `_world.remove_entity()` first, then `entity.queue_free()` separately. `sync_spawn_handler.gd` `broadcast_entity_spawn()` line 67 — `if not is_instance_valid(entity): return` guard.

---

### Pitfall 8: Late-Join Client Spawns Entities with Stale Positions

**What goes wrong:** When a client connects late, the server sends a world-state snapshot with all current entities. The snapshot captures component values at the moment `serialize_world_state()` is called. However, fast-moving entities (projectiles, characters) will have moved significantly by the time the snapshot data is deserialized and applied on the client. Additionally, the snapshot misses in-flight unreliable component updates that were already sent before the client connected.

**Why it happens:** There is an inherent time gap between snapshot serialization and snapshot application. Unreliable packets are fire-and-forget; they are not buffered for late-joining clients.

**Consequences:** Late-joining clients see all entities at positions from 200-500ms in the past. Fast entities teleport to correct position once the continuous sync catches up.

**Prevention:** Send the world-state snapshot first, then immediately send a separate position-snapshot RPC with the most current positions of all transform-carrying entities. For entities using native `MultiplayerSynchronizer`, call `refresh_synchronizer_visibility()` to force Godot to resync all property values to the new peer.

**Detection:** Late-joining clients see entities in slightly wrong positions for the first second. The effect is worst for fast entities (projectiles).

**Phase:** Phase 1 (entity spawn/despawn). The late-join case must be explicitly designed, not discovered during player testing.

**Evidence in v1 code:** `network_sync.gd` `_on_peer_connected()` — the three-phase approach: `_sync_world_state.rpc_id()`, then `_native_handler.refresh_synchronizer_visibility()`, then `call_deferred("_deferred_send_position_snapshot", peer_id)`.

---

### Pitfall 9: Spawn-Before-Broadcast Entity Removed Sending Ghost Despawn

**What goes wrong:** Entity is added to the world (queuing a deferred spawn broadcast). Before the deferred call fires, the entity is removed from the world (e.g., instantly destroyed by collision). A despawn RPC is sent. Then the deferred spawn fires and sends a spawn RPC. Clients receive: `despawn X` then `spawn X`. The despawn is ignored because X doesn't exist yet; the spawn creates X. Entity is now permanently live on clients even though the server destroyed it.

**Why it happens:** The ordering of deferred calls and signal-driven despawn broadcasts interacts in non-obvious ways when an entity's lifetime is shorter than one frame.

**Consequences:** Ghost entities on clients that the server has already destroyed. These entities may interact with other clients (blocking pathways, dealing damage, etc.).

**Prevention:** Maintain a `_broadcast_pending` set of entity IDs. When `entity_removed` fires and the entity ID is still in `_broadcast_pending`, cancel the pending spawn and do NOT send the despawn RPC — the entity never existed on clients. Clear the pending entry on both the deferred spawn callback and on early removal.

**Detection:** Clients have entities that the server does not. Reconciliation (periodic full-state sync) will eventually clean these up but they will persist between reconciliation intervals.

**Phase:** Phase 1. The `_broadcast_pending` cancellation pattern must be part of the initial spawn architecture.

**Evidence in v1 code:** `network_sync.gd` `_on_entity_removed()` lines 563–576 — checks `_broadcast_pending.has(entity.id)`, erases it, returns without sending despawn RPC, logs "SPAWN CANCELLED (removed before broadcast)."

---

### Pitfall 10: Bandwidth Explosion from Naively Syncing All Component Properties

**What goes wrong:** Component-level sync that fires on every `property_changed` signal at 60 FPS sends one RPC per property change per entity per frame. With 50 entities each having position + rotation + velocity (6 floats), that is 50 × 3 × 60 = 9,000 RPCs per second from the server alone.

**Why it happens:** ECS components emit `property_changed` granularly (once per property). Without batching, each signal becomes an RPC immediately.

**Consequences:** Network saturation within seconds. Packet loss triggers retransmission for "reliable" RPCs, compounding the problem. Godot's UDP buffer fills and peers disconnect.

**Prevention:** Batch all pending property changes into a single dictionary keyed by entity_id → component_type → property. Send the batch on a timer per priority tier: REALTIME (every frame, unreliable), HIGH (20 FPS, unreliable), MEDIUM (10 FPS, reliable), LOW (1 FPS, reliable). Use different `@rpc` modes for different priority tiers.

**Detection:** NetworkMonitor in Godot editor shows incoming/outgoing packets growing proportionally to entity count. Single-entity games work fine; 20+ entity games saturate bandwidth immediately.

**Phase:** Phase 2 (component sync). The batching design must be established before any property sync is implemented — adding batching after the fact is a near-rewrite.

**Evidence in v1 code:** `sync_config.gd` `Priority` enum with `INTERVALS` constants; `sync_property_handler.gd` `update_sync_timers()` and `send_pending_updates_batched()` pattern; separate `_sync_components_unreliable` and `_sync_components_reliable` RPC methods.

---

### Pitfall 11: Component Class Name Resolution Fragility

**What goes wrong:** The network layer identifies components by their GDScript class name (returned by `script.get_global_name()`). If a component's `class_name` declaration is missing or the script has no `class_name`, `get_global_name()` returns `""`. The fallback to `resource_path.get_file().get_basename()` produces inconsistent results if files are renamed or located in different directories on different installations.

**Why it happens:** GDScript's `class_name` declaration is optional. Developers forget to add it, especially for simple marker components. Resource paths include full project directory structure which can differ between development and export builds.

**Consequences:** Components are serialized as `""` (empty key) in network dictionaries. On receive, no component matches the empty key. Properties silently fail to sync. Harder to debug because it appears as a "no update received" bug rather than a serialization error.

**Prevention:** Require all networked components to have `class_name` declarations. Add an assertion or editor warning in the framework when a component without `class_name` is added to a networked entity. Use both `get_global_name()` and the filename fallback but emit a push_warning when falling back so developers are immediately notified.

**Detection:** Specific component types never sync while others do. Component data in serialized dictionaries shows empty string keys.

**Phase:** Phase 1 (component serialization foundation). The serialization approach determines the fallback behavior.

**Evidence in v1 code:** Pattern appears in at least 8 locations across all handler files: `var comp_type = script.get_global_name(); if comp_type == "": comp_type = script.resource_path.get_file().get_basename()`.

---

### Pitfall 12: Marker Components Triggering Sync Loops on Authority Assignment

**What goes wrong:** When the networking layer assigns authority marker components (`CN_LocalAuthority`, `CN_RemoteEntity`, `CN_ServerOwned`, `CN_ServerAuthority`), the `component_added` signal fires. If the sync layer does not explicitly skip these marker types, it attempts to broadcast them to other peers — causing remote peers to add them too, which triggers their own `component_added`, and so on.

**Why it happens:** Marker components are added locally by the networking layer itself, but the `component_added` signal handler does not distinguish between game-created components (should sync) and framework-created markers (should not sync).

**Consequences:** Marker components incorrectly appear on remote entities. An entity that is `CN_RemoteEntity` on one peer becomes `CN_LocalAuthority` on the same entity on another peer, breaking all authority-based queries.

**Prevention:** Maintain a hardcoded list of framework-internal marker component types that are explicitly excluded from sync broadcast. Check `component is CN_LocalAuthority or component is CN_RemoteEntity` etc. before any sync logic runs in `on_component_added`.

**Detection:** System queries using `with_all([CN_LocalAuthority])` return entities on peers where they should not have authority. Entities process input on both server and client simultaneously.

**Phase:** Phase 1 or Phase 2. Must be part of the authority marker design — decide which components are "local only" and enforce that at the sync layer boundary.

**Evidence in v1 code:** `sync_property_handler.gd` `on_component_added()` lines 30–37 — explicit type checks for all four marker types before any sync logic.

---

### Pitfall 13: Relationship Target Resolution Ordering

**What goes wrong:** When the server broadcasts a relationship `entity_A → ChildOf → entity_B` and entity B has not yet been spawned on the client (because the spawn packets arrive in non-deterministic order), deserializing the relationship produces null because `entity_id_registry.get(entity_B.id)` returns null.

**Why it happens:** ECS relationships reference other entities by object reference. Network serialization converts this to entity IDs. If entity B's spawn packet arrives after the relationship packet (possible with non-FIFO packet ordering, or because entity B was added to the world state snapshot after entity A), the relationship cannot be resolved at deserialization time.

**Consequences:** Relationships are silently dropped. Systems that query by relationship (e.g., `with_relationship([ChildOf, parent])`) miss entities. Parent-child hierarchies are inconsistent across peers.

**Prevention:** Maintain a `_pending_relationships` buffer per source entity. When a relationship cannot be resolved (entity target not yet in registry), store the raw recipe. When any new entity is added to the world (`entity_added` signal), attempt to resolve all pending relationships that reference the new entity as a target.

**Detection:** Relationship-based queries return different result sets on server vs. client. Hierarchical systems (damage propagation, team membership) behave differently per peer.

**Phase:** Phase 3 (relationships sync). The deferred resolution queue must be designed upfront, not added after the first bug report.

**Evidence in v1 code:** `sync_relationship_handler.gd` `_pending_relationships` dictionary and `try_resolve_pending()` method called from `NetworkSync._on_entity_added()`.

---

### Pitfall 14: Ghost Entity Accumulation Without Periodic Reconciliation

**What goes wrong:** Reliable RPCs guarantee delivery but not against all failure modes (server crash mid-send, rapid game state changes, packet loss on unreliable RPCs). Over time, clients accumulate entities that no longer exist on the server ("ghosts") or miss entities that should exist. Without periodic reconciliation, these desyncs are permanent.

**Why it happens:** Networking is inherently unreliable at the session level even when individual packets are guaranteed. Session transitions, reconnects, and edge cases in deferred call ordering can all cause the client to miss a despawn or spawn.

**Consequences:** Entity count diverges between server and clients. Ghosts consume CPU for ECS processing and may cause incorrect game behavior (e.g., an enemy that no longer exists on the server is still dealing damage on the client).

**Prevention:** Implement periodic full-state reconciliation: server broadcasts the complete entity set with all component values every N seconds (N = 30 is a reasonable default). Clients apply the update and also remove any local entities not present in the server's state ("ghost cleanup"). Per-reconciliation, skip locally-owned entities to avoid overwriting player input.

**Detection:** Entity counts diverge between `debug_print` on server vs. client over long play sessions. Orphaned entities performing actions that should have stopped.

**Phase:** Phase 4 (error handling/reconciliation). Can be deferred but must exist before production.

**Evidence in v1 code:** `sync_state_handler.gd` `process_reconciliation()` and `handle_sync_full_state()` including the ghost-cleanup loop at lines 311–337.

---

## Minor Pitfalls

---

### Pitfall 15: Single-Player Zero Overhead — But Only If Checked Correctly

**What goes wrong:** The networking system connects to world signals and processes in `_process()` unconditionally. In single-player, this wastes CPU on signal connection setup, per-frame timer updates, and per-entity sync index maintenance even though nothing is sent.

**Prevention:** Gate all sync-related work behind `net_adapter.is_in_game()`. In single-player, `is_in_game()` returns `false` (no multiplayer peer connected), so `_process()` returns immediately. Signal connections are still live but their handlers also check `is_in_game()` before doing work.

**Phase:** Phase 1 design decision. Document the contract: `is_in_game() == false` means zero networking cost.

**Evidence in v1 code:** `network_sync.gd` `_process()` line 288: `if _world == null or not net_adapter.is_in_game(): return`.

---

### Pitfall 16: `model_ready_component` Must Be Excluded from Spawn Serialization

**What goes wrong:** The server adds a `C_Instantiated` (or similar) marker component once the entity's model is set up. If this component is included in the spawn packet, clients receive it and skip their own model instantiation system (because the component signals "already done"). The model never gets created on the client side.

**Prevention:** Maintain a configurable `model_ready_component` name in `SyncConfig`. Exclude this component from spawn serialization. Clients must run their own model instantiation logic (or have the networking layer do it synchronously) — they must not inherit the server's "model is ready" marker.

**Phase:** Phase 2 or Phase 3. Discovered when model-dependent systems break on clients.

**Evidence in v1 code:** `sync_spawn_handler.gd` `serialize_entity_spawn()` lines 548–550: `if comp_type == _ns.sync_config.model_ready_component: continue`.

---

### Pitfall 17: RPC Authority Mode Must Match Topology

**What goes wrong:** Using `"any_peer"` RPC mode for spawns allows any client to spawn entities on the server and all other clients. This is a security and correctness hole: a malicious or buggy client can spawn unlimited entities.

**Prevention:** Spawn RPCs must be `"authority"` (server-only sender). Component-value update RPCs can be `"any_peer"` but must validate at the receiver that the sender owns the entity (`net_id.peer_id == sender_id`). Document clearly: clients send input/state to server, server sends world state to clients.

**Phase:** Phase 1. The `@rpc` mode on each function is its security contract — get it right the first time.

**Evidence in v1 code:** `network_sync.gd` lines 785–796: `_sync_world_state`, `_spawn_entity`, `_despawn_entity` are all `"authority"` mode; `_sync_components_unreliable`, `_add_component` etc. are `"any_peer"` with explicit sender validation in their handlers.

---

### Pitfall 18: `call_deferred` on Freed Entities

**What goes wrong:** `call_deferred` schedules a call for end of frame. If the entity is freed (via `queue_free()`) before the deferred call fires, the call executes on a freed object, causing `Invalid get index 'id' on base 'null instance'` errors.

**Prevention:** In every deferred callback, check `is_instance_valid(entity)` as the first line. Also pass entity ID as a separate string parameter so the entity ID can be used for registry cleanup even if the entity itself is freed.

**Phase:** Phase 1. A universal pattern that must be established early.

**Evidence in v1 code:** `sync_spawn_handler.gd` `broadcast_entity_spawn()` lines 64–68: `if not is_instance_valid(entity): _ns._broadcast_pending.erase(entity_id); return`.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Entity spawn/despawn foundation | Spawn racing component setup (Pitfall 1) | Use deferred broadcast with `_broadcast_pending` guard |
| Entity spawn/despawn foundation | Stale RPCs after game reset (Pitfall 2) | Session ID in every RPC from day one |
| Entity spawn/despawn foundation | Node name inconsistency (Pitfall 3) | Hardcode node name in factory method; guard in `_ready` |
| Component sync signal wiring | Sync loop from applied network data (Pitfall 4) | `_applying_network_data` flag before any `component.set()` |
| Component sync signal wiring | Bandwidth explosion (Pitfall 10) | Priority-tiered batching design before first property sync |
| Component sync signal wiring | Marker components triggering sync (Pitfall 12) | Explicit type exclusion list in `on_component_added` |
| Authority model | Authority not inherited by children (Pitfall 6) | Explicit `set_multiplayer_authority()` on every child node |
| Native sync (MultiplayerSynchronizer) | Node path race condition (Pitfall 5) | Reactive setup via marker component; synchronous on client spawn |
| Relationships sync | Target entity not yet spawned (Pitfall 13) | `_pending_relationships` deferred resolution queue |
| Error handling / reconciliation | Ghost entity accumulation (Pitfall 14) | Periodic full-state broadcast with ghost cleanup |
| Late-join support | Stale positions in world snapshot (Pitfall 8) | Position snapshot RPC sent deferred after world state |
| Lifetime edge cases | Sub-frame entity removal causes phantom despawn (Pitfall 9) | `_broadcast_pending` cancellation pattern |
| Class naming | Empty component names (Pitfall 11) | Always require `class_name` on networked components |
| Single-player | Unnecessary sync overhead (Pitfall 15) | Gate all work on `is_in_game()` |

---

## Sources

All findings are drawn from direct code analysis of the GECS networking v1 implementation at:

- `D:/code/gecs/addons/gecs_network/network_sync.gd` — Main orchestrator, session ID, deferred spawn, sync loops
- `D:/code/gecs/addons/gecs_network/sync_spawn_handler.gd` — Spawn/despawn serialization, ghost prevention, client spawn sequence
- `D:/code/gecs/addons/gecs_network/sync_property_handler.gd` — Batching, priority tiers, sync loop prevention, marker exclusion
- `D:/code/gecs/addons/gecs_network/sync_state_handler.gd` — Authority markers, reconciliation, ghost cleanup
- `D:/code/gecs/addons/gecs_network/sync_native_handler.gd` — MultiplayerSynchronizer timing, authority propagation
- `D:/code/gecs/addons/gecs_network/sync_relationship_handler.gd` — Relationship target ordering, pending resolution
- `D:/code/gecs/addons/gecs_network/sync_config.gd` — Priority configuration, skip lists, model_ready_component
- `D:/code/gecs/addons/gecs_network/net_adapter.gd` — MultiplayerAPI stale reference detection
- `D:/code/gecs/addons/gecs_network/components/cn_network_identity.gd` — Authority model, peer_id semantics

Confidence: HIGH for all critical and moderate pitfalls — each is backed by implemented mitigation code in the v1 codebase with explanatory comments.

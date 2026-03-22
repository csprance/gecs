# Architecture

## Handler Pipeline

GECS Network is organized as a single `NetworkSync` node (the RPC surface) that delegates to
focused handler objects. All `@rpc` declarations live on `NetworkSync`; handlers never call
`.rpc()` directly.

```text
+------------------------------------------------------------------+
|                        NetworkSync                                |
|  (single RPC surface — all @rpc methods live here)               |
+----------+----------+----------+----------+----------+-----------+
           |          |          |          |          |
    SpawnManager  SyncSender  SyncReceiver  NativeSyncHandler
           |                               SyncRelationshipHandler
           |                               SyncReconciliationHandler
```

| Handler                     | File                             | Responsibility                                                                                         |
| --------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `SpawnManager`              | `spawn_manager.gd`               | Entity lifecycle: spawn broadcast, despawn, late-join sync, peer disconnect cleanup                    |
| `SyncSender`                | `sync_sender.gd`                 | Priority-tiered outbound batching: polls `CN_NetSync.check_changes_for_priority()` per tier per tick   |
| `SyncReceiver`              | `sync_receiver.gd`               | Inbound apply: authority validation, `_applying_network_data` echo-loop guard, custom receive handlers |
| `NativeSyncHandler`         | `native_sync_handler.gd`         | Creates `MultiplayerSynchronizer` for entities with `CN_NativeSync`; configures position/rotation sync |
| `SyncRelationshipHandler`   | `sync_relationship_handler.gd`   | Serializes ECS relationships via creation recipes; deferred entity resolution for late-join            |
| `SyncReconciliationHandler` | `sync_reconciliation_handler.gd` | Periodic full-state reconciliation (ADV-02): broadcasts authoritative state at configured interval     |

## Spawn Flow

```text
1. Server: ECS.world.add_entity(entity)
2. SpawnManager detects CN_NetworkIdentity → schedules call_deferred("_deferred_broadcast")
3. Server sets component values (runs this frame after add_entity)
4. End of frame: _deferred_broadcast runs → serializes @export properties on all CN_NetSync components
5. SpawnManager.rpc_broadcast_spawn() → sends serialized payload to all clients
6. Each client: SpawnManager.handle_spawn_entity() → instantiates entity from scene, applies component data
7. SpawnManager._inject_authority_markers() → assigns CN_LocalAuthority / CN_RemoteEntity / CN_ServerAuthority
```

**Why deferred?** The `_deferred_broadcast` pattern allows the caller to set component values
(velocity, position, damage) after `add_entity()` in the same frame. The broadcast captures
the final values at end of frame, not the defaults from `define_components()`.

## Property Sync Flow

```text
SyncSender._process(delta):
  For each priority tier (REALTIME/HIGH/MEDIUM/LOW):
    If tick interval elapsed:
      For each entity with CN_NetSync:
        dirty = CN_NetSync.check_changes_for_priority(priority)
        If dirty not empty:
          Batch into outbound payload

SyncSender → NetworkSync.rpc_sync_components_unreliable/reliable → all clients

SyncReceiver.handle_sync_components(payload, sender_peer_id):
  Validate sender has authority (get_remote_sender_id() check)
  For each component update:
    _applying_network_data = true    ← guard: prevents re-broadcast of received data
    Apply props via comp.set() (or custom receive handler)
    CN_NetSync.update_cache_silent() ← update cache without marking dirty
    _applying_network_data = false
```

**Echo-loop prevention:** `_applying_network_data` is a flag on `CN_NetSync`. When `true`,
`SyncSender` skips dirty-checking for that component — so received values are never
re-broadcast back to the sender.

## Relationship Sync

`SyncRelationshipHandler` serializes ECS relationships across peers using **creation recipes** —
lightweight dictionaries that encode a relationship's component (class + exported properties)
and target (Entity, Component, or Script reference) so any peer can reconstruct it.

Key behaviors:

- **Deferred entity resolution**: If the target entity has not yet spawned on the receiving peer,
  the handler queues a pending resolution and retries once that entity appears.
- **Spawn payload bundling**: During late-join world-state sync, relationships are bundled into
  the spawn payload so new clients reconstruct the full relationship graph in one pass.
- **Path validation**: All incoming script paths are validated (`res://` prefix +
  `ResourceLoader.exists`) before instantiation.

## Reconciliation Flow (ADV-02)

```text
SyncReconciliationHandler._process(delta):
  _elapsed += delta
  If _elapsed >= reconciliation_interval:
    _elapsed = 0.0
    NetworkSync.broadcast_full_state()  ← server-only; sends full entity state to all clients

broadcast_full_state():
  Serialize all live entities (same format as spawn payloads)
  rpc_sync_full_state(payload) → all clients apply authoritatively
```

Reconciliation corrects drift accumulated from packet loss, priority downsampling, or missed
updates. The interval is configured via `NetworkSync.reconciliation_interval` (default: 30 s,
set via ProjectSettings).

## Signals

```gdscript
# Emitted on clients when any entity spawns via network (after component data applied)
_network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity) -> void:
    # Apply visual properties, spawn effects, etc.
    pass

# Emitted on clients when the local player's entity spawns
_network_sync.local_player_spawned.connect(_on_local_player_spawned)

func _on_local_player_spawned(entity: Entity) -> void:
    # Set up camera, HUD, etc.
    pass
```

Connect these signals directly in your main scene or game manager — no middleware class is
needed. See `docs/configuration.md` for the complete setup pattern.

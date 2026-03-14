# Architecture Patterns

**Domain:** Declarative ECS networking for Godot 4.x (GECS Networking v2)
**Researched:** 2026-03-07
**Confidence:** HIGH — drawn entirely from direct codebase analysis of both GECS core and the existing gecs_network addon

---

## Recommended Architecture

The v2 system must do what the v1 system does, but arrive there through component declaration rather than imperative configuration. The shape of the solution is already visible in the current addon — the pieces exist, but authority information and sync rules live in the wrong places (a global SyncConfig resource instead of on the components themselves). The primary architectural shift is: move sync metadata from external configuration onto the components that need syncing.

### High-Level Structure

```
addons/
  gecs/               (unchanged — GECS core)
    ecs/
      entity.gd
      component.gd
      system.gd
      world.gd
      observer.gd
      command_buffer.gd
      query_builder.gd

  gecs_network/       (v2 — replaces current addon)
    network_sync.gd           NEW: World child node, single RPC surface
    net_adapter.gd            KEEP: Unchanged — clean abstraction already
    transport_provider.gd     KEEP: Unchanged — correct abstraction
    transports/               KEEP: ENet + Steam providers unchanged
    components/
      cn_network_identity.gd  KEEP: Minimal changes — authority model is sound
      cn_net_sync.gd          NEW: Replaces SyncComponent + SyncConfig priorities
      cn_local_authority.gd   KEEP: Marker component — already correct
      cn_server_authority.gd  KEEP: Marker component — already correct
    systems/
      s_network_send.gd       NEW: Reads cn_net_sync components, sends deltas
      s_network_receive.gd    NEW: Applies incoming data to entities
    serializer.gd             NEW: Extracted serialization, no cross-dependencies
    spawn_manager.gd          NEW: Entity lifecycle sync, replaces SyncSpawnHandler
```

---

## Component Boundaries

### Unchanged GECS Core

| Component | File | Role | Change |
|-----------|------|------|--------|
| Entity | `ecs/entity.gd` | Container Node, emits component_added/removed/property_changed | None |
| Component | `ecs/component.gd` | Data Resource, emits property_changed | None |
| World | `ecs/world.gd` | Manages entities/systems, emits entity_added/removed, component_added/removed | None |
| CommandBuffer | `ecs/command_buffer.gd` | Deferred structural changes | None |
| Observer | `ecs/observer.gd` | Reactive system on component events | None |
| QueryBuilder | `ecs/query_builder.gd` | Archetype query engine | None |

The core is not touched. All networking is additive — a separate addon that listens to World signals.

### New/Modified Network Components

#### `cn_network_identity.gd` — KEEP with minor additions

The existing design is correct. `peer_id` maps to multiplayer authority. The `has_authority()` and `is_local()` methods already do the right thing.

Minor addition: add `network_id: String` here (replacing `Entity.id` for network purposes), so entity identity is fully encapsulated in this component.

```gdscript
class_name CN_NetworkIdentity
extends Component

@export var peer_id: int = 0          # 0 = server-owned, 1 = host, >1 = client
@export var network_id: String = ""   # Stable ID across peers (previously Entity.id)
@export var spawn_index: int = 0      # Deterministic ordering aid
```

#### `cn_net_sync.gd` — NEW (replaces SyncComponent + SyncConfig)

This is the central architectural change. Instead of a global SyncConfig mapping class names to priorities, each component that needs syncing extends `cn_net_sync` (or carries inline annotations). However, GDScript inheritance means components cannot extend both Component and cn_net_sync.

**Recommended approach:** `cn_net_sync` IS a Component — it carries the sync declaration for one or more sibling components. This is the tag-component pattern already used in GECS.

```gdscript
class_name CN_NetSync
extends Component

enum Priority { REALTIME, HIGH, MEDIUM, LOW, LOCAL }
enum Reliability { UNRELIABLE, UNRELIABLE_ORDERED, RELIABLE }

# Which component types to sync on this entity
# Key: GDScript resource_path, Value: SyncRule
@export var sync_rules: Dictionary = {}
# Fallback: if empty, sync all components except LOCAL-tagged ones
@export var sync_all_by_default: bool = false
@export var default_priority: Priority = Priority.HIGH
@export var default_reliability: Reliability = Reliability.UNRELIABLE_ORDERED
```

A `SyncRule` resource (sub-resource):

```gdscript
class_name SyncRule
extends Resource

@export var priority: CN_NetSync.Priority = CN_NetSync.Priority.HIGH
@export var reliability: CN_NetSync.Reliability = CN_NetSync.Reliability.UNRELIABLE_ORDERED
@export var properties: Array[String] = []   # empty = all @export properties
@export var exclude_properties: Array[String] = []
```

**Why this shape:** It keeps sync configuration attached to the entity (where it belongs in ECS), not in a global resource. Different entity archetypes naturally carry different `CN_NetSync` instances. It removes the string-keyed class name lookups from the hot sync path. The current SyncComponent's `@export_group` approach (detecting PROPERTY_USAGE_GROUP) is clever but invisible — the new approach is explicit and inspectable.

#### `cn_local_authority.gd` — KEEP

Marker component. Present on entities the local peer controls. Added by the network layer after spawn. Already correct — no changes needed.

#### `cn_server_authority.gd` — KEEP

Marker component. Already correct.

---

## New System Classes

### `NetworkSync` (Node — child of World)

The single RPC surface. All `@rpc` methods must live here (Godot constraint). In v1 this node was already the hub but delegated to handler RefCounteds. Keep that delegation pattern — it makes the class tractable.

**Responsibilities:**
- Connect to World signals: `entity_added`, `entity_removed`, `component_added`, `component_removed`, `component_property_changed` (via entity signal relay)
- Connect to `MultiplayerAPI` signals: `peer_connected`, `peer_disconnected`, `connected_to_server`, `server_disconnected`
- Host all `@rpc` method stubs, delegate to sub-objects
- Expose public API: `transfer_authority`, `reset_for_new_game`
- Zero overhead when `net_adapter.is_in_game()` is false (single-player check stays)

**Communicates With:**
- `SpawnManager` — entity lifecycle events
- `SyncSender` — outbound property deltas
- `SyncReceiver` — inbound RPC application

### `SpawnManager` (RefCounted — owned by NetworkSync)

Replaces `SyncSpawnHandler`. Responsible for entity lifecycle across peers.

**Responsibilities:**
- Serialize entity state for spawn broadcast (components + relationships)
- Instantiate entities from spawn data on clients (scene load or `Entity.new()`)
- Apply initial component data after instantiation
- Handle despawn (remove from world + queue_free)
- World state snapshot for late-join (`_sync_world_state` RPC)
- Session ID validation to reject stale spawn/despawn RPCs
- Deferred spawn broadcast (call_deferred to allow component value setup)

**Key data:** session tracking (`_game_session_id`), pending broadcast deduplication (`_broadcast_pending`), entity ID registry lookup (from `World.entity_id_registry`)

### `SyncSender` (RefCounted — owned by NetworkSync)

Replaces `SyncPropertyHandler`. Responsible for outbound property change batching.

**Responsibilities:**
- Maintain per-priority timers and accumulate changed properties
- On `component_property_changed` signal: check if entity has `CN_NetSync`, check if property is in sync rules, check authority, enqueue to priority batch
- Flush each priority bucket when its interval elapses
- Select reliable vs unreliable RPC based on priority
- Skip when `_applying_network_data` flag is true (prevents sync loops)

**Hot path optimization (from v1 analysis):** The `_sync_entity_index` (entity instance_id -> {entity, sync_comps}) approach from v1 is correct — rebuild this index on `component_added`/`removed` for entities with `CN_NetworkIdentity`. The per-frame scan replaces polling all entities.

### `SyncReceiver` (RefCounted — owned by NetworkSync)

Replaces `SyncPropertyHandler.handle_apply_sync_data`. Responsible for applying inbound RPC data.

**Responsibilities:**
- Validate sender authority (server accepts from entity owner, client accepts from server only)
- Look up entity by network_id in `World.entity_id_registry`
- Apply property values with `_applying_network_data = true` guard
- Update sync cache silently to prevent re-queuing the received values

### `Serializer` (RefCounted — static-style utility)

Extracted from `SyncSpawnHandler.serialize_entity_spawn`. No state.

**Responsibilities:**
- Serialize entity components to Dictionary (respecting sync rules)
- Deserialize component data back to properties
- Type-safe deep copy for sync cache values
- Approximate equality comparison for float/vector types (from SyncComponent._has_changed)

---

## Integration Points With Existing GECS

### World Signals (the primary hook)

NetworkSync connects to these signals — no modifications to World required:

| Signal | Handler | Purpose |
|--------|---------|---------|
| `entity_added(entity)` | `SpawnManager` | Broadcast spawn to clients (server only) |
| `entity_removed(entity)` | `SpawnManager` | Broadcast despawn, cleanup synchronizers |
| `component_added(entity, comp)` | `SyncSender` | Rebuild sync index, queue sync of new comp data |
| `component_removed(entity, comp)` | `SyncSender` | Rebuild sync index, broadcast removal |
| `component_property_changed(entity, comp, prop, old, new)` | `SyncSender` | Enqueue property change |
| `relationship_added(entity, rel)` | `RelationshipSync` | Broadcast relationship |
| `relationship_removed(entity, rel)` | `RelationshipSync` | Broadcast removal |

The `component_property_changed` signal is relayed from Entity via World. Entity connects to each component's `property_changed` signal and re-emits it as `component_property_changed`. This relay is already implemented in v1.

### Entity Signals

NetworkSync also subscribes to each entity's `component_property_changed` directly (per-entity subscription, cleaned up on entity removal). This gives finer-grained control than World-level subscription and avoids routing all property changes through World for non-networked entities.

### CommandBuffer Integration

The v2 networking layer spawning entities on clients must go through the same World API as local code. There is no need to bypass CommandBuffer — the spawn happens via `World.add_entity(entity)` synchronously (not via cmd buffer), which is the same as v1. The network layer is not a System, so it does not have a `cmd` reference, and it should not acquire one. Direct `World.add_entity` / `World.remove_entity` calls are correct here.

### Observer Integration

The existing `Observer` class (reactive on component add/remove/change) can be used by game code to react to networked changes. No modification needed. When the SyncReceiver applies an incoming component change, it triggers the same `component_property_changed` signal chain, which Observers already watch. Game developers can write Observers that react to network-applied state changes without knowing the changes came from the network.

---

## Data Flow: State Propagation Server to Clients

### Continuous Property Sync

```
[Server Frame]
  Entity.some_component.position = new_value
    -> Component.property_changed.emit(comp, "position", old, new)
    -> Entity._on_component_property_changed()
    -> Entity.component_property_changed.emit(entity, comp, "position", old, new)
    -> NetworkSync._on_component_property_changed()  (per-entity subscription)
       -> SyncSender.on_property_changed(entity, comp, "position", old, new)
          -> Check: _applying_network_data? -> skip if true
          -> Check: entity has CN_NetworkIdentity? -> skip if not
          -> Check: local peer has authority? -> skip if not
          -> Check: CN_NetSync rules for this component? -> get priority
          -> Enqueue to _pending_updates[priority][entity_id][comp_type][prop] = new

[Server per-priority tick]
  SyncSender.update_timers(delta)
    -> For each priority whose timer elapsed:
       -> _pending_updates[priority] -> batch Dictionary
       -> if reliability == UNRELIABLE_ORDERED:
            NetworkSync._sync_components_unreliable.rpc(batch)
          else:
            NetworkSync._sync_components_reliable.rpc(batch)
       -> clear batch for this priority

[Client receives RPC]
  NetworkSync._sync_components_unreliable(data)
    -> SyncReceiver.apply(data)
       -> For each entity_id in data:
          -> entity = World.entity_id_registry[entity_id]
          -> Validate sender == server (peer_id 1)
          -> _applying_network_data = true
          -> For each comp_type / prop / value:
             -> comp = entity.get_component(comp_type_script)
             -> comp.set(prop_name, value)
          -> _applying_network_data = false
```

### Entity Lifecycle (Spawn)

```
[Server]
  World.add_entity(player_entity)
    -> World.entity_added.emit(player_entity)
    -> NetworkSync._on_entity_added(player_entity)
       -> entity has CN_NetworkIdentity? -> yes
       -> call_deferred("_broadcast_spawn", entity, entity.id)
         (deferred so game code can set component values after add_entity)

[Server, next frame]
  NetworkSync._broadcast_spawn(entity, entity_id)
    -> SpawnManager.broadcast(entity, entity_id)
       -> Serializer.serialize_entity(entity) -> spawn_data Dict
       -> NetworkSync._spawn_entity.rpc(spawn_data)

[Client receives _spawn_entity RPC]
  NetworkSync._spawn_entity(data)
    -> SpawnManager.handle_spawn(data)
       -> session_id check
       -> scene_path present? -> load and instantiate scene
       -> no scene_path? -> Entity.new()
       -> entity.id = data.network_id
       -> entity.set_multiplayer_authority(peer_id)
       -> World.add_entity(entity)          <- same call as server
       -> Serializer.apply_component_data(entity, data.components)
       -> emit entity_spawned signal
       -> net_id.is_local()? -> emit local_player_spawned
```

### Entity Lifecycle (Despawn)

```
[Server]
  World.remove_entity(entity)
    -> World.entity_removed.emit(entity)
    -> NetworkSync._on_entity_removed(entity)
       -> entity has CN_NetworkIdentity?
       -> pending spawn not yet broadcast? -> cancel spawn, skip despawn RPC
       -> NetworkSync._despawn_entity.rpc(entity.network_id, session_id)

[Client receives _despawn_entity RPC]
  NetworkSync._despawn_entity(network_id, session_id)
    -> SpawnManager.handle_despawn(network_id, session_id)
       -> session_id check
       -> entity = World.entity_id_registry[network_id]
       -> World.remove_entity(entity)
       -> entity.queue_free()
```

---

## Patterns to Follow

### Pattern 1: Tag Component Authority Filtering

Systems that should only run for entities the local peer controls use the marker component in their query rather than checking `CN_NetworkIdentity.is_local()` inside the loop.

```gdscript
class_name InputSystem
extends System

func query():
    return q.with_all([C_Velocity, CN_LocalAuthority])  # Only local-authority entities

func process(entities, components, delta):
    for entity in entities:
        var vel = entity.get_component(C_Velocity)
        vel.direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

`CN_LocalAuthority` is added by NetworkSync after spawn when `net_id.is_local()` is true. This keeps authority checks out of system logic entirely — the query does the filtering.

### Pattern 2: CN_NetSync as Entity Configuration

Rather than a global SyncConfig keyed by class name strings, each entity type carries its own `CN_NetSync` instance:

```gdscript
class_name PlayerEntity
extends Entity

func define_components() -> Array:
    var sync = CN_NetSync.new()
    sync.sync_rules = {
        C_Position: SyncRule.new(CN_NetSync.Priority.REALTIME, CN_NetSync.Reliability.UNRELIABLE_ORDERED, ["position", "rotation"]),
        C_Health: SyncRule.new(CN_NetSync.Priority.MEDIUM, CN_NetSync.Reliability.RELIABLE, []),
        C_PlayerStats: SyncRule.new(CN_NetSync.Priority.LOW, CN_NetSync.Reliability.RELIABLE, []),
    }
    return [CN_NetworkIdentity.new(), sync, C_Position.new(), C_Health.new(), C_PlayerStats.new()]
```

This eliminates string-keyed component lookups. The network layer looks up rules from `entity.get_component(CN_NetSync)` and accesses `sync.sync_rules` with the component's script as key.

### Pattern 3: Single RPC Surface on NetworkSync Node

All `@rpc` annotated methods must be on a Node with a consistent path across peers. The existing design is correct: one NetworkSync node named `"NetworkSync"` as a child of World. The v2 design preserves this — all RPC stubs remain on NetworkSync, delegating to handler objects.

```gdscript
# All on NetworkSync node - Godot requires @rpc on the node that calls/receives
@rpc("authority", "reliable")
func _spawn_entity(data: Dictionary) -> void:
    _spawn_manager.handle_spawn(data)

@rpc("any_peer", "unreliable_ordered")
func _sync_unreliable(data: Dictionary) -> void:
    _sync_receiver.apply(data)
```

### Pattern 4: _applying_network_data Guard

When applying received data to components, set a flag that prevents the property change observer from re-queueing the change for transmission. This is a solved pattern in v1 — preserve it exactly.

```gdscript
# In SyncReceiver.apply():
_network_sync._applying_network_data = true
component.set(property_name, value)
_network_sync._applying_network_data = false
```

The `SyncSender.on_property_changed` checks this flag before enqueueing.

### Pattern 5: Deferred Spawn Broadcast

The server must defer the spawn RPC by one frame after `World.add_entity` to allow game code to set component values before the snapshot is taken:

```gdscript
func _on_entity_added(entity: Entity) -> void:
    if not net_adapter.is_server():
        return
    if not entity.has_component(CN_NetworkIdentity):
        return
    _broadcast_pending[entity.network_id] = true
    call_deferred("_deferred_broadcast_spawn", entity, entity.network_id)
```

This is one of the most important correctness patterns from v1 — without it, clients receive spawn data with default component values, not the values set after `add_entity()`.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Global SyncConfig with String-Keyed Class Names

**What:** A global Resource mapping `"C_Velocity"` -> Priority.HIGH.
**Why bad:** Requires string matching on the hot path (every property change), forces developers to update a separate file when adding components, breaks if class names change, invisible (not co-located with component definition).
**Instead:** Use `CN_NetSync` on the entity with `sync_rules` keyed by Script reference.

### Anti-Pattern 2: Monolithic NetworkSync with Embedded Logic

**What:** All spawn, property sync, relationship sync, and time sync logic in one 900-line file.
**Why bad:** Unnavigable, hard to test, all concerns coupled.
**Instead:** NetworkSync is a thin coordinator + RPC surface. Delegate to: SpawnManager, SyncSender, SyncReceiver, RelationshipSync, TimeSyncManager.

### Anti-Pattern 3: Subscribing to All Entity property_changed Signals Globally

**What:** Connect `component_property_changed` on every entity regardless of whether it has `CN_NetworkIdentity`.
**Why bad:** In a 1000-entity world, 990 non-networked entities generate signal overhead for every property change.
**Instead:** Only connect to entities that have `CN_NetworkIdentity` when they are added to the world. Maintain a sync entity index. This is what v1 does — preserve it.

### Anti-Pattern 4: Scene Path as Required Spawn Data

**What:** Requiring entities to have a `scene_file_path` to be spawnable.
**Why bad:** Entities created programmatically (`Entity.new()`) with no scene don't have `scene_file_path`, yet they're common (projectiles, pickups).
**Instead:** Accept empty `scene_path` → spawn as `Entity.new()`. Use `script_paths` dict in spawn data to re-add components that were added dynamically after `define_components()` ran.

### Anti-Pattern 5: Applying Network Data Before define_components Runs

**What:** Calling `_apply_component_data` before `World.add_entity` (before `_initialize()` runs).
**Why bad:** Components don't exist yet on the entity. The values get discarded.
**Instead:** Call `World.add_entity(entity)` first, then `Serializer.apply_component_data(entity, data)`. `_initialize()` is called inside `add_entity`, so components exist by the time apply runs.

---

## Build Order (Dependency Graph)

Each item must exist before the items below that reference it:

```
Phase 1 — Foundation (no networking yet)
  CN_NetworkIdentity         (pure data component, no deps)
  CN_LocalAuthority          (marker, no deps)
  CN_ServerAuthority         (marker, no deps)
  NetAdapter                 (Resource, no deps)
  TransportProvider          (RefCounted, no deps)
  Serializer                 (RefCounted, needs Component.serialize())

Phase 2 — Lifecycle Sync
  SpawnManager               (needs: Serializer, World, CN_NetworkIdentity)
  NetworkSync (skeleton)     (needs: World signals, SpawnManager)
  RPC stubs: _spawn_entity, _despawn_entity, _sync_world_state

Phase 3 — Property Sync
  CN_NetSync + SyncRule      (data component, needs: Component base)
  SyncSender                 (needs: CN_NetSync, CN_NetworkIdentity, World signals)
  SyncReceiver               (needs: Serializer, World.entity_id_registry)
  RPC stubs: _sync_unreliable, _sync_reliable

Phase 4 — Relationship Sync
  RelationshipSync           (needs: SpawnManager serialization format, Relationship)
  RPC stubs: _sync_relationship_add, _sync_relationship_remove

Phase 5 — Connection Management
  Peer connect/disconnect handlers in NetworkSync
  Authority transfer
  Late-join world state
  Session ID tracking (stale RPC rejection)

Phase 6 — Time Sync (optional, defer to later)
  TimeSyncManager            (ping/pong server time offset)
  RPC stubs: _request_server_time, _respond_server_time
```

### Why This Order

1. **Foundation first** — The data components and adapters have no dependencies. They define the vocabulary the rest of the system speaks.
2. **Lifecycle before properties** — You cannot sync property changes for entities that don't exist on clients. Spawn must work before property sync is meaningful.
3. **Properties before relationships** — Relationships reference entities by ID. Those entities must be spawnable first.
4. **Connection management late** — The core happy path (all peers connect simultaneously) can be tested without late-join. Late-join adds complexity that is easier to validate once the happy path is solid.
5. **Time sync last** — Server time offset affects ordering of events but is not required for functional correctness. It can be deferred entirely to v3 alongside client prediction.

---

## Scalability Considerations

| Concern | At 4 players | At 16 players | At 64+ players |
|---------|-------------|---------------|----------------|
| Spawn broadcast | Reliable RPC to all — fine | Fine | Consider chunked world state |
| Property batching | Per-priority buckets sufficient | Per-priority buckets sufficient | Add per-peer interest management |
| Entity count in sync index | Trivial | Trivial | Sync index approach scales linearly |
| RPC bandwidth | Priority intervals sufficient | May need adaptive intervals | Need interest management (out of v2 scope) |
| Session ID | Int counter sufficient | Int counter sufficient | Int counter sufficient |

Interest management (spatial visibility filters on MultiplayerSynchronizer) is the correct answer at scale, but it is out of scope for v2. The `CN_SyncEntity.public_visibility` flag and `VisibilityMode` enum in v1 already expose the hooks — preserve them.

---

## What Changes vs. What Stays

| Class | Status | Reason |
|-------|--------|--------|
| `CN_NetworkIdentity` | Keep, minor addition | Authority model is correct |
| `CN_LocalAuthority` | Keep | Marker pattern is correct |
| `CN_ServerAuthority` | Keep | Marker pattern is correct |
| `CN_ServerOwned` | Keep | Marker pattern is correct |
| `CN_RemoteEntity` | Keep | Marker pattern is correct |
| `CN_SyncEntity` | Keep | Native MultiplayerSynchronizer config is correct |
| `NetAdapter` | Keep | Clean abstraction, works well |
| `TransportProvider` | Keep | Clean abstraction, works well |
| `SyncConfig` | Replace | Becomes `CN_NetSync` on entities |
| `SyncComponent` | Replace | Logic absorbed into `SyncSender` + `CN_NetSync` |
| `NetworkSync` | Refactor | Keep as RPC surface, slim down logic |
| `SyncSpawnHandler` | Rename/refactor | Becomes `SpawnManager` |
| `SyncPropertyHandler` | Split | Becomes `SyncSender` + `SyncReceiver` |
| `SyncStateHandler` | Absorb | Authority transfer + time sync into NetworkSync |
| `SyncNativeHandler` | Keep | MultiplayerSynchronizer management is complex, keep isolated |
| `SyncRelationshipHandler` | Keep | Rename to `RelationshipSync` |

---

## Sources

- Direct analysis of `addons/gecs/ecs/` (entity.gd, component.gd, system.gd, world.gd, command_buffer.gd, observer.gd) — HIGH confidence
- Direct analysis of `addons/gecs_network/` (network_sync.gd, sync_component.gd, sync_config.gd, sync_spawn_handler.gd, cn_network_identity.gd, cn_sync_entity.gd, net_adapter.gd, transport_provider.gd) — HIGH confidence
- `.planning/PROJECT.md` requirements — HIGH confidence
- Godot 4.x MultiplayerAPI constraints (RPC method location, set_multiplayer_authority, MultiplayerSynchronizer) — HIGH confidence (from v1 implementation evidence)

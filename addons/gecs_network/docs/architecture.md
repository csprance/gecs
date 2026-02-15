# Architecture

## Two-Tier Synchronization

This addon uses a **two-tier synchronization approach** that leverages Godot's native APIs where they shine:

### High-Level API: Native Transform Sync
For position, rotation, and velocity, use `CN_SyncEntity` which auto-configures Godot's `MultiplayerSynchronizer`:
- Automatic interpolation (handled by Godot)
- Efficient delta compression
- No RPC overhead for transform updates

### Low-Level API: Component RPC Sync
For ECS component data (health, state, inventory), use priority-based RPC batching:
- Property-change detection via GECS signals
- Configurable sync rates per component type
- Reliable/unreliable transport based on priority

```text
+-------------------------------------------------------------+
|                     NetworkSync                               |
+-----------------------------+-------------------------------+
|  Native Transform Sync      |  Component RPC Sync            |
|  (CN_SyncEntity)            |  (SyncComponent)               |
|  ---------------------------+-------------------------------  |
|  - global_position          |  - C_Health (MEDIUM, 10Hz)     |
|  - global_rotation          |  - C_Velocity (HIGH, 20Hz)     |
|  - velocity                 |  - C_FiringInput (HIGH, 20Hz)  |
|  - custom_properties        |  - Any @export property        |
|                             |                                |
|  Godot handles              |  Addon handles                 |
|  interpolation              |  priority batching             |
+-----------------------------+-------------------------------+
```

## Handler Architecture

The addon is split into focused handlers for maintainability:

| Handler | Responsibility |
|---|---|
| `network_sync.gd` | Orchestrator — RPC stubs, signals, public API |
| `sync_spawn_handler.gd` | Entity lifecycle — spawn/despawn broadcasts, world state serialization |
| `sync_native_handler.gd` | Native sync — MultiplayerSynchronizer setup, model instantiation |
| `sync_property_handler.gd` | Property sync — change detection, priority batching, polling |
| `sync_relationship_handler.gd` | Relationship sync — ECS relationship serialization/deserialization across peers (Entity/Component/Script targets) with deferred resolution |
| `sync_state_handler.gd` | State — authority markers, time sync, reconciliation |

All RPC methods remain on `NetworkSync` (Godot requirement) and delegate to handlers internally.

## Relationship Sync

`sync_relationship_handler.gd` serializes ECS relationships across peers using **creation recipes** — lightweight descriptors that can reconstruct a relationship's component and target on any peer.

Key concepts:

- **Creation recipes**: Encode a relationship's component (class + exported properties) and target (Entity, Component, or Script reference) into a dictionary that any peer can deserialize.
- **Deferred entity resolution**: When a target entity hasn't spawned on the receiving peer yet, the handler queues a pending resolution and retries once the entity appears.
- **Spawn payloads**: During world-state sync (late-join), relationships are bundled into the entity spawn payload so new clients reconstruct the full relationship graph in one pass.

The handler validates all incoming script paths (`res://` prefix + `ResourceLoader.exists`) before instantiation and guards against stale entity references.

## Middleware Pattern

The recommended approach is a **thin middleware layer** between the generic addon and your project:

```text
addons/gecs_network/     <-- Generic, reusable addon
game/network/            <-- Project-specific middleware
game/                    <-- Your game code
```

### Example Middleware

Create `game/network/network_middleware.gd`:

```gdscript
class_name NetworkMiddleware
extends Node

var network_sync: NetworkSync

func _init(p_network_sync: NetworkSync) -> void:
    network_sync = p_network_sync
    # Connect to addon signals
    network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity) -> void:
    # Apply project-specific visual properties
    var projectile = entity.get_component(C_Projectile)
    if projectile:
        var visual = entity.get_node_or_null("Visual") as MeshInstance3D
        if visual:
            var material = StandardMaterial3D.new()
            material.albedo_color = projectile.projectile_color
            material.emission_enabled = true
            material.emission = projectile.projectile_color
            material.emission_energy_multiplier = 0.3
            visual.material_override = material
```

Then in your main scene:

```gdscript
func _ready():
    # Create addon (generic)
    var network_sync = NetworkSync.attach_to_world(world, ProjectSyncConfig.new())

    # Create middleware (project-specific)
    var middleware = NetworkMiddleware.new(network_sync)
```

This keeps project-specific logic out of both the addon and your main game code.

## Signals

```gdscript
# Emitted when local player entity spawns (clients only)
network_sync.local_player_spawned.connect(_on_local_player_spawned)

func _on_local_player_spawned(entity: Entity):
    # Set up player camera, UI, etc.
    pass

# Emitted when ANY entity spawns (clients only, after component data applied)
# Connect to this in your middleware for post-spawn setup
network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity):
    # Apply visual properties, play spawn effects, etc.
    pass
```

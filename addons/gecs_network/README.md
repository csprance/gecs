# GECS Network Addon

Multiplayer synchronization addon for the GECS (Godot Entity Component System) framework.

## Requirements

- **Godot 4.x** (tested with 4.5+)
- **GECS Addon** - This addon depends on the GECS framework:
  - `Component` base class with `serialize()` method
  - `Entity` class with `component_property_changed` signal
  - `World` class with `entity_id_registry` and entity lifecycle signals
  - `GECSIO.uuid()` for entity ID generation

## Features

- **Two Sync Patterns**: Spawn-only sync (fire-and-forget) and continuous sync (real-time updates)
- **Automatic Marker Assignment**: Authority markers (`CN_LocalAuthority`, `CN_RemoteEntity`, etc.) assigned based on ownership
- **Native Sync Support**: Auto-configures Godot's `MultiplayerSynchronizer` via `CN_SyncEntity`
- **Priority-Based Batching**: Can reduce bandwidth significantly (HIGH=20Hz, MEDIUM=10Hz, LOW=1Hz), depending on workload
- **Late Join Support**: New players receive full world state on connection
- **Authority Transfer**: Transfer entity ownership between peers at runtime
- **Reconciliation**: Periodic full-state sync to correct drift
- **Session Validation**: Session IDs prevent ghost entities from previous game sessions
- **Transport Providers**: Swap ENet/Steam/custom transports without changing game code

## Installation

1. Ensure the GECS addon is installed in `addons/gecs/`
2. Copy the `addons/gecs_network/` folder to your project's `addons/` directory
3. Enable the plugin in Project Settings > Plugins > GECSNetwork

## Quick Start

### 1. Create Project-Specific SyncConfig

Create `game/config/project_sync_config.gd`:

```gdscript
class_name ProjectSyncConfig
extends SyncConfig

func _init() -> void:
    component_priorities = {
        "C_Velocity": Priority.HIGH,        # 20 Hz
        "C_Health": Priority.MEDIUM,        # 10 Hz
        "C_PlayerXP": Priority.LOW,         # 1 Hz
    }

    skip_component_types = ["C_Transform"]
    model_ready_component = "C_Instantiated"
    transform_component = "C_Transform"
    enable_reconciliation = true
    reconciliation_interval = 10.0
```

### 2. Attach NetworkSync to Your World

```gdscript
func _ready():
    var net_sync = NetworkSync.attach_to_world(world, ProjectSyncConfig.new())

    # Optional: project-specific middleware
    # NetworkMiddleware is a user-defined class (see docs/architecture.md)
    # that connects to network_sync signals in its _init, e.g.:
    #
    # class_name MyMiddleware extends Node
    #     func _init(net_sync: NetworkSync):
    #         net_sync.entity_spawned.connect(_on_entity_spawned)
    #     func _on_entity_spawned(entity: Entity):
    #         pass  # Handle spawned entities
    #
    # var middleware = MyMiddleware.new(net_sync)
    var middleware = NetworkMiddleware.new(net_sync)
```

> **Transport selection** happens at the connection layer, not here.
> See [Transport Providers](docs/configuration.md#transport-providers) for ENet/Steam switching.

### 3. Add Network Identity to Entities

Every networked entity needs `CN_NetworkIdentity` in its `define_components()`:

```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),  # 0=server-owned (sentinel), 1=host peer, 2+=client peers
        C_Transform.new(),
        # ... other components
    ]
```

### 4. Choose Your Sync Pattern

**Spawn-only** (projectiles, effects) — no `CN_SyncEntity`:
```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),
        C_Velocity.new(),
        C_Transform.new(),
        # NO CN_SyncEntity = spawn-only
    ]
```

**Continuous** (players, enemies) — add `CN_SyncEntity`:
```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        C_Transform.new(),
        CN_SyncEntity.new(true, false, false),  # position sync
    ]
```

See [Sync Patterns](docs/sync-patterns.md) for detailed guidance.

## Documentation

| Document | Description |
|----------|-------------|
| [Sync Patterns](docs/sync-patterns.md) | Spawn-only vs continuous sync, choosing between them, detailed spawn-only guide |
| [Components](docs/components.md) | CN_NetworkIdentity, CN_SyncEntity, markers, SyncComponent, priority levels |
| [Authority](docs/authority.md) | Query-based authority patterns A-E, system group gating, authority transfer |
| [Configuration](docs/configuration.md) | SyncConfig, priorities, NetAdapter, transport providers (ENet/Steam) |
| [Architecture](docs/architecture.md) | Two-tier design, handler architecture, middleware pattern, signals |
| [Architecture — Relationships](docs/architecture.md#relationship-sync) | Relationship sync via creation recipes, deferred entity resolution, spawn payloads |
| [Best Practices](docs/best-practices.md) | Avoid RPCs, serialization, state ownership, animation sync |
| [Troubleshooting](docs/troubleshooting.md) | Common issues, solutions, migration guide |
| [Examples](docs/examples.md) | Complete code examples for players, enemies, projectiles, abilities |

## File Structure

```text
addons/gecs_network/
├── plugin.gd                  # Editor plugin registration
├── plugin.cfg                 # Plugin metadata
├── network_sync.gd            # Main sync orchestrator
├── sync_spawn_handler.gd      # Entity spawn/despawn
├── sync_native_handler.gd     # MultiplayerSynchronizer setup
├── sync_property_handler.gd   # Component property sync
├── sync_state_handler.gd      # Authority markers, reconciliation
├── net_adapter.gd             # Network abstraction layer
├── sync_config.gd             # Priority and filtering config
├── sync_component.gd          # Base class for priority-synced components
├── transport_provider.gd      # Abstract transport interface
├── transports/
│   ├── enet_transport_provider.gd   # Default ENet/Offline provider
│   └── steam_transport_provider.gd  # Steam provider (optional GodotSteam)
├── docs/                      # Documentation
│   ├── sync-patterns.md
│   ├── components.md
│   ├── authority.md
│   ├── configuration.md
│   ├── architecture.md
│   ├── best-practices.md
│   ├── troubleshooting.md
│   └── examples.md
├── icons/
│   ├── network_sync.svg
│   └── sync_config.svg
└── components/
    ├── cn_network_identity.gd # Required for all networked entities
    ├── cn_sync_entity.gd      # Opt-in native transform sync
    ├── cn_local_authority.gd   # Marker: local peer controls this
    ├── cn_remote_entity.gd     # Marker: remote peer controls this
    ├── cn_server_authority.gd  # Marker: server has authority over this
    └── cn_server_owned.gd      # Marker: server owns this entity
```

# GECS Network Addon

Declarative multiplayer networking for GECS — mark components as networked, let the framework handle the rest.

## Quick Start

### Step 1: Declare sync priorities on component properties

```gdscript
class_name C_Velocity
extends Component

@export_group("HIGH")           # 20 Hz sync
@export var direction: Vector3 = Vector3.ZERO
```

### Step 2: Add CN_NetworkIdentity and CN_NetSync to networked entities

```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        CN_NetSync.new(),
        CN_NativeSync.new(),     # Optional: transform sync via MultiplayerSynchronizer
        C_Velocity.new(),
    ]
```

### Step 3: Attach NetworkSync to your World

```gdscript
func _setup_network_sync() -> void:
    var net_sync = NetworkSync.attach_to_world(world)
    net_sync.entity_spawned.connect(_on_entity_spawned)
    net_sync.local_player_spawned.connect(_on_local_player_spawned)
```

## Features

- **Declarative sync priorities** — annotate component properties with `@export_group("HIGH")`, `"MEDIUM"`, `"LOW"`, `"SPAWN_ONLY"`, or `"LOCAL"`; no external config class needed
- **Native transform sync** — add `CN_NativeSync` to an entity and `NativeSyncHandler` creates and manages a `MultiplayerSynchronizer` automatically with interpolation support
- **Authority markers** — `CN_LocalAuthority`, `CN_RemoteEntity`, and `CN_ServerAuthority` are injected automatically at spawn; use them in ECS queries to gate systems by ownership
- **Relationship sync** — entity relationships sync across peers with deferred resolution for non-deterministic spawn ordering
- **Periodic reconciliation** — configurable full-state broadcast corrects drift without manual intervention
- **Custom sync handler overrides** — register per-component-type send/receive handlers at the system level for prediction blending or custom serialization
- **Zero overhead in single-player** — `NetworkSync` detects offline mode and skips all RPC and sync work

## Requirements

- **Godot 4.x** (tested with 4.6+)
- **GECS Addon** installed in `addons/gecs/`

## Installation

1. Ensure the GECS addon is installed in `addons/gecs/`
2. Copy the `addons/gecs_network/` folder to your project's `addons/` directory
3. Enable the plugin in **Project Settings > Plugins > GECSNetwork**

## File Structure

```text
addons/gecs_network/
├── plugin.gd                      # Editor plugin, ProjectSettings registration
├── plugin.cfg                     # Plugin metadata
├── network_sync.gd                # Main orchestrator — attach to World; all @rpc declarations
├── spawn_manager.gd               # Entity lifecycle: spawn, despawn, late-join, disconnect
├── sync_sender.gd                 # Priority-tiered outbound batching (REALTIME/HIGH/MEDIUM/LOW)
├── sync_receiver.gd               # Inbound apply, authority validation, echo-loop guard
├── native_sync_handler.gd         # Creates MultiplayerSynchronizer for CN_NativeSync entities
├── sync_relationship_handler.gd   # Relationship sync with deferred resolution
├── sync_reconciliation_handler.gd # Periodic full-state reconciliation (ADV-02)
├── net_adapter.gd                 # Network abstraction — testable without two Godot instances
├── transport_provider.gd          # Abstract transport interface
├── transports/
│   ├── enet_transport_provider.gd     # Default ENet transport
│   └── steam_transport_provider.gd    # Steam transport (requires GodotSteam)
├── docs/
│   ├── components.md              # CN_NetworkIdentity, CN_NetSync, CN_NativeSync, markers
│   ├── architecture.md            # Handler architecture, sync pipeline diagram
│   ├── authority.md               # Authority query patterns (CN_LocalAuthority, CN_ServerAuthority)
│   ├── configuration.md           # ProjectSettings, NetAdapter, transport providers
│   ├── sync-patterns.md           # Spawn-only vs continuous, SPAWN_ONLY group
│   ├── custom-sync-handlers.md    # ADV-03: register_send_handler, register_receive_handler
│   ├── best-practices.md          # ECS patterns, authority discipline, bandwidth
│   ├── examples.md                # Complete code examples
│   ├── troubleshooting.md         # Common issues and fixes
│   └── migration-v1-to-v2.md     # v0.1.x → v2 migration table
├── icons/
│   ├── network_sync.svg
│   └── sync_config.svg
└── components/
    ├── cn_network_identity.gd     # Required: peer ownership, late-join identity
    ├── cn_net_sync.gd             # Required for sync: priority scanner + dirty tracker
    ├── cn_native_sync.gd          # Optional: MultiplayerSynchronizer transform sync
    ├── cn_local_authority.gd      # Marker: local peer controls this entity
    ├── cn_remote_entity.gd        # Marker: remote peer controls this entity
    └── cn_server_authority.gd     # Marker: server-owned (peer_id=0 only)
```

## Documentation

- [Components](docs/components.md)
- [Architecture](docs/architecture.md)
- [Authority](docs/authority.md)
- [Configuration](docs/configuration.md)
- [Sync Patterns](docs/sync-patterns.md)
- [Custom Sync Handlers](docs/custom-sync-handlers.md)
- [Best Practices](docs/best-practices.md)
- [Examples](docs/examples.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Migration Guide](docs/migration-v1-to-v2.md)

## License

MIT License — see `LICENSE` file for details.

## Credits

Originally developed by **Code Fixxers** team during the Arena Survivors MVP project. Then modified by Quantum Tangent Games

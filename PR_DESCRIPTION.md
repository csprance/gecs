# Add GECS Network - Multiplayer Synchronization Addon

## Summary

This PR adds **GECS Network**, a new addon that provides multiplayer entity synchronization for GECS-based games. It enables networked gameplay by automatically synchronizing entities, components, and their properties across clients using Godot's built-in multiplayer system.

## Key Features

### 🎮 Two Sync Patterns

1. **Spawn-Only Sync** - For deterministic entities (projectiles, effects)
   - Sync once at spawn, clients simulate locally
   - Minimal bandwidth usage
   - Perfect for predictable behavior

2. **Continuous Sync** - For dynamic entities (players, enemies)
   - Real-time position/state updates via MultiplayerSynchronizer
   - Native Godot networking integration
   - Configurable update rates and interpolation

### 🔧 Project-Agnostic Design

- **No hardcoded components** - Fully configurable via `SyncConfig`
- **Generic implementation** - Works with any GECS project
- **Middleware pattern** - Clean separation between generic addon and project-specific logic
- **Signal-based reactive architecture** - Optimal for async networking

### 📦 Component-Based Configuration

```gdscript
class_name ProjectSyncConfig
extends SyncConfig

func _init() -> void:
    component_priorities = {
        "C_Velocity": Priority.HIGH,
        "C_Health": Priority.MEDIUM,
        "C_NetworkIdentity": Priority.LOW,
    }
    transform_component = "C_Transform"
    model_ready_component = "C_Instantiated"
```

### 🏗️ Three-Layer Architecture

```
┌─────────────────────────────────────┐
│  addons/gecs_network/               │ ← Generic, reusable addon
│  - NetworkSync (signals, RPCs)      │
│  - SyncConfig (configuration)       │
│  - Network components                │
└─────────────────────────────────────┘
              ↓ signals
┌─────────────────────────────────────┐
│  game/network/NetworkMiddleware     │ ← Optional project layer
│  - Project-specific networking      │
│  - Visual property handling          │
└─────────────────────────────────────┘
              ↑ uses
┌─────────────────────────────────────┐
│  game/                              │ ← Game code
│  - ProjectSyncConfig                │
│  - Components & Systems              │
└─────────────────────────────────────┘
```

## What's Included

### Core Files
- `network_sync.gd` - Main synchronization orchestrator (signal-based)
- `sync_config.gd` - Configuration resource for component priorities and filtering
- `net_adapter.gd` - Multiplayer API abstraction layer
- `sync_component.gd` - Base class for components with network sync
- `plugin.gd` / `plugin.cfg` - Godot plugin integration

### Components
- `C_NetworkIdentity` - Authority and ownership tracking
- `C_SyncEntity` - Enables continuous synchronization
- `C_LocalAuthority` - Marker for locally controlled entities
- `C_RemoteEntity` - Marker for remotely controlled entities
- `C_ServerOwned` - Marker for server-owned entities

### Documentation
- `README.md` - Complete usage guide with examples
  - Quick start (5 steps)
  - Sync pattern explanations
  - Component serialization guide
  - Troubleshooting section
  - Best practices

## Technical Highlights

### Signal-Based Reactive Architecture
Unlike traditional ECS systems that process sequentially, networking is inherently async/parallel. This addon uses Godot signals for immediate reactive responses to component changes, making it ideal for networked games.

### Component Serialization
Components automatically sync `@export` properties at spawn:
```gdscript
class_name C_Projectile
extends Component

@export var damage: int = 0        # Synced at spawn
@export var speed: float = 10.0    # Synced at spawn
@export var color: Color = Color.WHITE  # Synced at spawn
```

### Authority Model
```gdscript
C_NetworkIdentity.new(0)   # Server-owned (enemies, projectiles)
C_NetworkIdentity.new(1)   # Host player
C_NetworkIdentity.new(N)   # Client player (peer_id > 1)
```

### Bandwidth Optimization
- Priority-based update queuing (HIGH/MEDIUM/LOW)
- Configurable component filtering
- Transform batching (position + rotation)
- Spawn-only sync for deterministic entities

## Use Cases

This addon has been battle-tested in a multiplayer wave survival ARPG with:
- ✅ Client-server architecture
- ✅ Player input synchronization
- ✅ Enemy spawning and AI sync
- ✅ Projectile networking (spawn-only sync)
- ✅ Health/XP state synchronization
- ✅ Real-time player movement

## Integration Example

```gdscript
# In your main scene:
func _setup_network_sync() -> void:
    var network_sync = NetworkSync.attach_to_world(world, ProjectSyncConfig.new())
    network_sync.debug_logging = true
```

That's it! The addon handles all entity and component synchronization automatically.

## Why Add This to GECS?

1. **Completes the ECS Framework** - GECS provides local game logic; gecs_network adds multiplayer
2. **Zero-Configuration Networking** - Projects just attach NetworkSync and define their SyncConfig
3. **Godot-Native** - Uses built-in MultiplayerAPI, no external dependencies
4. **Production Ready** - Clean, documented, tested in real games
5. **Community Value** - Multiplayer is a common need for GECS users

## License

This addon is contributed under the same CC0-1.0 license as GECS (public domain).

## Credits

Developed by **Code Fixxers** team during the Arena Survivors MVP project.
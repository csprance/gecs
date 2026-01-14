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

- **ECS-First Architecture**: Designed specifically for GECS entities and components
- **Automatic Marker Assignment**: Entities automatically get `C_LocalAuthority`, `C_RemoteEntity`, or `C_ServerOwned` markers
- **Native Sync Support**: Auto-configures Godot's `MultiplayerSynchronizer` via `C_SyncEntity` component (high-level API for transform sync)
- **Component RPC Sync**: Property-level synchronization for ECS components (low-level API for game state)
- **Priority-Based Batching**: Reduces bandwidth 50-90% by syncing at different rates
- **Late Join Support**: New players receive full world state on connection
- **Authority Transfer**: Transfer entity ownership between peers at runtime
- **Reconciliation**: Periodic full-state sync to correct drift
- **Component Removal Sync**: Components removed on authority are removed on all peers

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
    # Define your component sync priorities
    component_priorities = {
        "C_Velocity": Priority.HIGH,        # 20 Hz
        "C_Health": Priority.MEDIUM,        # 10 Hz
        "C_PlayerXP": Priority.LOW,         # 1 Hz
    }

    # Components to skip (handled by native sync)
    skip_component_types = ["C_Transform"]

    # Component that signals model is ready
    model_ready_component = "C_Instantiated"

    # Transform component name
    transform_component = "C_Transform"
```

### 2. Create Middleware Layer (Optional but Recommended)

Create `game/network/network_middleware.gd` for project-specific networking:

```gdscript
class_name NetworkMiddleware
extends Node

var network_sync: NetworkSync

func _init(p_network_sync: NetworkSync) -> void:
    network_sync = p_network_sync
    network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity) -> void:
    # Apply project-specific visual properties
    # (See "Architecture: Middleware Pattern" section below)
```

### 3. Attach NetworkSync to Your World

```gdscript
func _ready():
    # Create addon with project config
    var net_sync = NetworkSync.attach_to_world(world, ProjectSyncConfig.new())

    # Create middleware (optional)
    var middleware = NetworkMiddleware.new(net_sync)
```

### 4. Add Network Identity to Entities

Every networked entity needs `C_NetworkIdentity`:

```gdscript
# In your entity's define_components():
func define_components() -> Array[Component]:
    return [
        C_NetworkIdentity.new(peer_id),  # peer_id of owner
        C_Transform.new(),
        # ... other components
    ]
```

### 5. Choose Your Sync Pattern

#### Option A: Spawn-Only Sync (Deterministic Simulation)

For entities with predictable behavior (projectiles, effects), only sync the spawn:

```gdscript
func define_components() -> Array[Component]:
    return [
        C_NetworkIdentity.new(0),  # 0 = server-owned
        C_Velocity.new(),          # Synced at spawn time
        C_Transform.new(),         # Synced at spawn time
        C_DeathTimer.new(3.0),
    ]
    # NO C_SyncEntity - clients simulate locally after spawn
```

**How it works:**
1. Server adds entity → addon detects `C_NetworkIdentity`
2. Addon serializes all `@export` properties
3. Addon broadcasts `_spawn_entity.rpc()` to clients
4. Clients reconstruct identical entity
5. Local simulation handles movement (no position updates)

**Best for:** Projectiles, particle effects, short-lived entities with constant velocity

#### Option B: Continuous Transform Sync

For entities needing real-time position updates (players, enemies):

```gdscript
func define_components() -> Array[Component]:
    return [
        C_NetworkIdentity.new(peer_id),
        C_SyncEntity.new(),  # Enables MultiplayerSynchronizer
        C_Transform.new(),
    ]
```

**Best for:** Players, enemies, vehicles, unpredictable movement

## Components

### C_NetworkIdentity

Required for all networked entities. Stores ownership information.

```gdscript
@export var peer_id: int = 0      # 0 = server, 1+ = player peers
@export var spawn_index: int = 0  # For deterministic ordering

# Pure logic methods (no external dependencies)
is_server_owned() -> bool  # True if peer_id is 0 or 1
is_player() -> bool        # True if peer_id > 0

# Network state methods (adapter is optional, uses Godot multiplayer by default)
is_local() -> bool         # True if peer_id matches local peer
has_authority() -> bool    # True if server, or local peer owns entity
```

### C_SyncEntity

Configures automatic `MultiplayerSynchronizer` creation.

```gdscript
@export var target_node: Node = null     # Sync target (defaults to entity)
@export var sync_position: bool = true   # Sync global_position
@export var sync_rotation: bool = true   # Sync global_rotation
@export var sync_velocity: bool = false  # Sync velocity (CharacterBody3D)
@export var custom_properties: Array[String] = []  # Additional properties

# Advanced options
@export var visibility_mode: int = 0
@export var delta_interval: float = 0.0
@export var replication_interval: float = 0.0
@export var public_visibility: bool = true
```

### Marker Components

Automatically assigned by NetworkSync based on ownership:

- **C_LocalAuthority**: Entity is controlled by local peer
- **C_RemoteEntity**: Entity is controlled by remote peer/server
- **C_ServerOwned**: Entity is owned by server (peer_id 0 or 1)

Query pattern example:
```gdscript
func query() -> QueryBuilder:
    # Only process locally controlled entities
    return q.with_all([C_Velocity, C_LocalAuthority])
```

## Configuration

### SyncConfig

Configure sync priorities and filtering:

```gdscript
var config = SyncConfig.new()

# Set component priorities
config.component_priorities = {
    "C_Velocity": SyncConfig.Priority.HIGH,      # 20 Hz
    "C_Health": SyncConfig.Priority.MEDIUM,      # 10 Hz
    "C_PlayerXP": SyncConfig.Priority.LOW,       # 1 Hz
}

# Skip components (blacklist mode)
config.skip_component_types = ["C_Transform"]  # Native sync handles it

# Or whitelist mode
config.sync_only_components = ["C_Health", "C_Velocity"]

# Reconciliation settings
config.enable_reconciliation = true
config.reconciliation_interval = 30.0  # seconds

# Apply config
var net_sync = NetworkSync.attach_to_world(world, config)
```

### Priority Levels

| Priority | Sync Rate | Use For |
|----------|-----------|---------|
| REALTIME | 60 Hz | Critical real-time data |
| HIGH | 20 Hz | Position, velocity, animations |
| MEDIUM | 10 Hz | Health, AI state |
| LOW | 1 Hz | XP, inventory, stats |

### Reliability

- **REALTIME/HIGH**: Unreliable (fast, may drop packets)
- **MEDIUM/LOW**: Reliable (guaranteed delivery)

## NetAdapter

Abstract interface for network operations. Override for custom networking:

```gdscript
class TaloNetAdapter extends NetAdapter:
    func is_server() -> bool:
        return TaloMultiplayer.is_host()

    func get_my_peer_id() -> int:
        return TaloMultiplayer.get_peer_id()

    func is_in_game() -> bool:
        return TaloMultiplayer.is_connected()

# Use custom adapter
var adapter = TaloNetAdapter.new()
var net_sync = NetworkSync.attach_to_world(world, null, adapter)
```

## Authority Transfer

Transfer entity ownership at runtime:

```gdscript
# Server only
network_sync.transfer_authority(entity, new_peer_id)
```

Use cases:
- Player picks up item (transfer to player)
- Player drops item (transfer to server)
- Vehicle exit (transfer back to server)

## Architecture: Middleware Pattern

The recommended approach is a **thin middleware layer** between the generic addon and your project:

```text
addons/gecs_network/     ← Generic, reusable addon
game/network/            ← Project-specific middleware
game/                    ← Your game code
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

## Best Practices

### Avoid Custom RPCs

**Never write custom RPC code for entity spawning.** The addon handles all spawn synchronization automatically:

```gdscript
# BAD - Custom RPC in game code
@rpc("authority", "call_remote", "reliable")
func _spawn_projectile_rpc(pos, dir, speed):
    _spawn_local(pos, dir, speed)

func fire():
    _spawn_local(pos, dir, speed)
    _spawn_projectile_rpc.rpc(pos, dir, speed)  # Don't do this!

# GOOD - Just add entity with C_NetworkIdentity
func fire():
    var projectile = projectile_scene.instantiate()
    # Set component values...
    ECS.world.add_entity(projectile)  # Addon auto-broadcasts to clients
```

### Component Serialization

For spawn sync to work, properties must be `@export`:

```gdscript
class_name C_Projectile
extends Component

@export var damage: int = 0        # Synced at spawn
@export var speed: float = 10.0    # Synced at spawn
var owner_entity: Entity = null    # NOT synced (Entity refs don't serialize)
```

### Choosing Spawn-Only vs Continuous Sync

| Entity Type | Sync Pattern | Components |
|-------------|--------------|------------|
| Projectiles | Spawn-only | `C_NetworkIdentity` only |
| Effects/VFX | Spawn-only | `C_NetworkIdentity` only |
| Players | Continuous | `C_NetworkIdentity` + `C_SyncEntity` |
| Enemies | Continuous | `C_NetworkIdentity` + `C_SyncEntity` |
| Vehicles | Continuous | `C_NetworkIdentity` + `C_SyncEntity` |

## Implementing Spawn-Only Sync (Projectiles)

Spawn-only sync requires careful implementation. Follow these rules:

### Rule 1: Only Server Spawns

**Never spawn locally on clients.** The server spawns, broadcasts, and all clients (including the firing player) receive via RPC.

```gdscript
# In your weapon/spawning system:
func process(...):
    if Net.is_in_game:
        if Net.is_server():
            # Server spawns - addon broadcasts to ALL clients
            _spawn_projectile(position, direction, ...)
        # CLIENT: Do NOT spawn prediction - wait for server broadcast
    else:
        # Single player: spawn locally
        _spawn_projectile(position, direction, ...)
```

**Why no client prediction?** With spawn-only sync, there's no way to reconcile a client prediction with the server-spawned version. You'd get duplicate projectiles.

### Rule 2: Input Must Sync to Server

For the server to spawn on behalf of clients, it needs their input. Use `SyncComponent`:

```gdscript
class_name C_FiringInput
extends SyncComponent  # NOT Component!

@export var is_firing: bool = false      # @export required for sync
@export var aim_direction: Vector3 = Vector3.FORWARD

# Add to SyncConfig priorities:
# "C_FiringInput": SyncConfig.Priority.HIGH  # 20 Hz
```

### Rule 3: All Synced Data Must Be @export

Everything that differs between spawns must be serialized:

```gdscript
class_name C_Projectile
extends Component

@export var damage: int = 0              # Synced
@export var projectile_color: Color = Color.WHITE  # Synced (for visuals)
var owner_entity: Entity = null          # NOT synced (Entity refs don't serialize)
```

### Rule 4: Set Component Values AFTER add_entity()

The addon uses `call_deferred` to serialize components at end of frame. Set values after `add_entity()`:

```gdscript
func _spawn_projectile(position, direction, speed, damage, color):
    var projectile = projectile_scene.instantiate()

    # Add to scene tree first
    entities_node.add_child(projectile)
    projectile.global_position = position

    # Add to ECS world - triggers define_components()
    ECS.world.add_entity(projectile)

    # Set component values AFTER add_entity (addon captures these via deferred call)
    var velocity_comp = projectile.get_component(C_Velocity)
    velocity_comp.direction = direction * speed

    var transform_comp = projectile.get_component(C_Transform)
    transform_comp.position = position

    var proj_comp = projectile.get_component(C_Projectile)
    proj_comp.damage = damage
    proj_comp.projectile_color = color
```

### Rule 5: Entity Definition (No C_SyncEntity)

```gdscript
# e_projectile.gd
func define_components() -> Array[Component]:
    return [
        C_NetworkIdentity.new(0),  # 0 = server-owned
        C_Projectile.new(),
        C_Velocity.new(),
        C_Transform.new(),
        C_DeathTimer.new(3.0),
    ]
    # NO C_SyncEntity - this is what makes it spawn-only!
```

### How It Works Internally

1. Server calls `ECS.world.add_entity(projectile)`
2. `_on_entity_added` detects `C_NetworkIdentity`, schedules `call_deferred("_broadcast_entity_spawn")`
3. Your code sets component values (velocity, position, damage, color)
4. At end of frame, `_broadcast_entity_spawn` serializes all `@export` properties
5. RPC broadcasts spawn data to all clients
6. Clients instantiate entity, apply component data, sync Node3D position from C_Transform
7. All clients simulate locally - **no further sync updates**

### Complete Flow Example

```text
CLIENT A (firing):
1. Holds fire button → S_Input sets C_FiringInput.is_firing = true
2. C_FiringInput syncs to server (20 Hz, HIGH priority)

SERVER:
3. S_WeaponFiring sees is_firing=true for Client A's player
4. Server spawns projectile with C_NetworkIdentity.new(0)
5. Sets velocity, position, damage, color on components
6. End of frame: addon broadcasts spawn RPC to ALL clients

ALL CLIENTS (including A):
7. Receive spawn RPC with full component data
8. Instantiate projectile, apply data, position Node3D
9. Local S_ProjectileMovement simulates flight
10. C_DeathTimer expires → entity removed (also synced)
```

## Troubleshooting

### Entity not syncing

1. Ensure entity has `C_NetworkIdentity`
2. Check peer_id is set correctly
3. Verify NetworkSync is child of World

### Transform not syncing

1. Add `C_SyncEntity` to entity
2. Or use component-based sync (C_Transform changes trigger RPC)
3. Check `sync_config.skip_component_types` doesn't include your component

### Late joiner missing entities

1. Ensure server has entities before client connects
2. Check `_on_peer_connected` is being called
3. Verify world state serialization works

### Performance issues

1. Use priority batching (default config)
2. Increase sync intervals for non-critical data
3. Enable component filtering to skip unnecessary syncs
4. Use native sync (C_SyncEntity) for transform data

### Spawn-only entity appears at origin (0,0,0)

1. Ensure you set `C_Transform.position` AFTER `add_entity()`, not before
2. Check the property has `@export` so it serializes
3. The addon syncs Node3D position from C_Transform after spawn

### Spawn-only entity has wrong values (default instead of set values)

1. Set component values AFTER `add_entity()`, not before
2. The addon uses `call_deferred` to capture values at end of frame
3. If you set values before `add_entity()`, `define_components()` overwrites them

### Duplicate projectiles (prediction + server spawn)

1. **Don't spawn locally on client** - only server should spawn
2. Remove client-side prediction for spawn-only entities
3. Client waits for server's spawn broadcast

### Projectile spawns but doesn't move / has wrong velocity

1. Check `C_Velocity.direction` is set AFTER `add_entity()`
2. Ensure velocity property is `@export`
3. For spawn-only, continuous sync is disabled - values must be correct at spawn

### Input not reaching server (remote player actions not happening)

1. Ensure input component extends `SyncComponent`, not `Component`
2. Add `@export` to input properties
3. Add component to `SyncConfig.component_priorities` with HIGH priority
4. Verify client has `C_LocalAuthority` on the player entity

### Spawn-only entity receiving continuous updates (breaking local simulation)

1. **Remove `C_SyncEntity`** from the entity - its presence enables continuous sync
2. Entities without `C_SyncEntity` only sync at spawn time
3. Check no other code is manually syncing the entity

## Animation Synchronization

### Why Not Native Sync for Animations?

A common question: "Why not sync animations via MultiplayerSynchronizer like transforms?"

**Answer:** Godot's `AnimationPlayer.current_animation` is **read-only**. Even writable properties like `assigned_animation` cause timing drift between clients.

| Approach | Problem |
|----------|---------|
| Sync `current_animation` | Read-only, cannot be set |
| Sync `assigned_animation` | Doesn't auto-play; clients start at different times |
| Sync `current_animation_position` | Read-only; would cause jitter anyway |

**Additional issues with property-based animation sync:**
- Death animations revert to idle after completion
- Missed transition frames and particle effects
- Animation is procedural (`play()` method calls), not just property data

### Recommended Pattern

**Movement animations (Idle/Run/Sprint):** Derive from synced velocity. Each client independently selects the animation based on `C_Velocity` - no animation name sync needed.

**One-shot animations (Attack/Hurt):** Use a `SyncComponent` to sync the animation name:

```gdscript
class_name C_AnimationState
extends SyncComponent

@export var current_animation: String = ""  # HIGH priority (20 Hz)
```

Then in your animation system:
```gdscript
# For remote players, check the synced animation state
if is_remote and anim_state.current_animation != "":
    if anim_player.current_animation != anim_state.current_animation:
        anim_player.play(anim_state.current_animation)
```

Each client plays the animation locally from frame 0 - no timing drift.

This pattern is used in production Godot multiplayer games and avoids the pitfalls of native animation sync.

## Migration from Game-Specific Code

1. Remove `Net` singleton references - use `net_adapter` methods
2. Remove manual marker assignment - NetworkSync handles it
3. Remove manual `MultiplayerSynchronizer` setup - use `C_SyncEntity`
4. Update component imports to addon paths

Before:
```gdscript
if Net.is_server():
    entity.add_component(C_ServerOwned.new())
```

After:
```gdscript
# Automatic! Just add C_NetworkIdentity with correct peer_id
entity.add_component(C_NetworkIdentity.new(0))  # Server-owned
```

## Architecture

This addon uses a **two-tier synchronization approach** that leverages Godot's native APIs where they shine:

### High-Level API: Native Transform Sync
For position, rotation, and velocity, use `C_SyncEntity` which auto-configures Godot's `MultiplayerSynchronizer`:
- Automatic interpolation (handled by Godot)
- Efficient delta compression
- No RPC overhead for transform updates

### Low-Level API: Component RPC Sync
For ECS component data (health, state, inventory), use priority-based RPC batching:
- Property-change detection via GECS signals
- Configurable sync rates per component type
- Reliable/unreliable transport based on priority

```text
┌─────────────────────────────────────────────────────────────┐
│                     NetworkSync                              │
├─────────────────────────────────────────────────────────────┤
│  C_SyncEntity                    │  Component RPC Sync       │
│  (MultiplayerSynchronizer)       │  (Priority Batching)      │
│  ────────────────────────────    │  ─────────────────────    │
│  • global_position               │  • C_Health               │
│  • global_rotation               │  • C_Velocity             │
│  • velocity                      │  • C_AIState              │
│  • custom_properties             │  • Any @export property   │
│                                  │                           │
│  Godot handles interpolation     │  You control sync rate    │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```text
addons/gecs_network/
├── plugin.gd                 # Editor plugin registration
├── plugin.cfg               # Plugin metadata
├── network_sync.gd          # Main sync node (attach to World)
├── net_adapter.gd           # Network abstraction layer
├── simple_logger.gd         # Logging (uses cLogger if available)
├── sync_config.gd           # Priority and filtering config
├── icons/                   # Editor icons
│   ├── network_sync.svg
│   └── sync_config.svg
└── components/
    ├── c_network_identity.gd # Required for all networked entities
    ├── c_sync_entity.gd      # Opt-in native transform sync
    ├── c_local_authority.gd  # Marker: local peer controls this
    ├── c_remote_entity.gd    # Marker: remote peer controls this
    └── c_server_owned.gd     # Marker: server owns this entity
```

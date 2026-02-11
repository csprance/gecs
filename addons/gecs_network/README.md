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
- **Automatic Marker Assignment**: Entities automatically get `CN_LocalAuthority`, `CN_RemoteEntity`, `CN_ServerAuthority`, or `CN_ServerOwned` markers based on ownership
- **Two Sync Patterns**: Spawn-only sync (fire-and-forget) and continuous sync (real-time updates)
- **Native Sync Support**: Auto-configures Godot's `MultiplayerSynchronizer` via `CN_SyncEntity` component
- **Component RPC Sync**: Priority-based property synchronization for ECS components
- **Priority-Based Batching**: Reduces bandwidth 50-90% by syncing at different rates (HIGH=20Hz, MEDIUM=10Hz, LOW=1Hz)
- **Late Join Support**: New players receive full world state on connection
- **Authority Transfer**: Transfer entity ownership between peers at runtime
- **Reconciliation**: Periodic full-state sync to correct drift
- **Component Removal Sync**: Components removed on authority are removed on all peers
- **Session Validation**: Session IDs prevent ghost entities from previous game sessions

## Installation

1. Ensure the GECS addon is installed in `addons/gecs/`
2. Copy the `addons/gecs_network/` folder to your project's `addons/` directory
3. Enable the plugin in Project Settings > Plugins > GECSNetwork

## Quick Start

### 1. Create a SyncConfig

Create a project-specific configuration that tells the addon which components to sync and at what rate:

```gdscript
class_name ProjectSyncConfig
extends SyncConfig

func _init() -> void:
    # Component sync priorities (class name -> Priority)
    component_priorities = {
        # HIGH (20 Hz, unreliable) - Fast-changing data
        "C_Velocity": Priority.HIGH,
        "C_FiringInput": Priority.HIGH,
        "C_AnimationState": Priority.HIGH,

        # MEDIUM (10 Hz, reliable) - Important but less frequent
        "C_Health": Priority.MEDIUM,
        "C_EnemyAI": Priority.MEDIUM,

        # LOW (1 Hz, reliable) - Rarely changing
        "C_PlayerXP": Priority.LOW,
        "C_Upgrades": Priority.LOW,
    }

    # Components handled by native MultiplayerSynchronizer (skip RPC sync)
    skip_component_types = ["C_Transform"]

    # Component that signals model/scene is fully ready
    model_ready_component = "C_Instantiated"

    # Transform component name (for position sync after spawn)
    transform_component = "C_Transform"

    # Reconciliation (server sends full state periodically)
    enable_reconciliation = true
    reconciliation_interval = 10.0
```

### 2. Attach NetworkSync to Your World

```gdscript
func _ready():
    var config = ProjectSyncConfig.new()
    var network_sync = NetworkSync.attach_to_world(world, config)

    # Connect signals for post-spawn setup
    network_sync.entity_spawned.connect(_on_entity_spawned)
    network_sync.local_player_spawned.connect(_on_local_player_spawned)
```

### 3. Add CN_NetworkIdentity to Entities

Every networked entity needs `CN_NetworkIdentity` in its `define_components()`:

```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),  # peer_id of the owning player (0 = server)
        C_Transform.new(),
        # ... other components
    ]
```

The addon automatically detects `CN_NetworkIdentity` when the entity is added to the world, assigns authority markers, and handles spawn synchronization.

## Two Sync Patterns

The addon supports two fundamentally different sync patterns. Choosing the right one is the most important architectural decision for each entity type.

### Spawn-Only Sync

For entities with deterministic behavior after spawning (projectiles, effects, AoE zones). The server broadcasts spawn data once; clients reconstruct and simulate locally with **no further updates**.

**How to use:** Include `CN_NetworkIdentity` but **do NOT include** `CN_SyncEntity`.

```gdscript
# e_projectile.gd
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),   # Server-owned
        C_Projectile.new(),
        C_Velocity.new(),
        C_Transform.new(),
        C_DeathTimer.new(3.0),
        # NO CN_SyncEntity = spawn-only sync
    ]
```

**How it works internally:**
1. Server calls `ECS.world.add_entity(projectile)`
2. Addon detects `CN_NetworkIdentity` and schedules `call_deferred("_broadcast_entity_spawn")`
3. Your code sets component values (velocity, position, damage)
4. At end of frame, addon serializes all `@export` properties and broadcasts via RPC
5. Clients instantiate the entity, apply component data, and simulate locally
6. No further sync updates are sent

**Critical rule — set values AFTER `add_entity()`:**

```gdscript
func _spawn_projectile(position: Vector3, direction: Vector3, speed: float):
    var proj = projectile_scene.instantiate()
    entities_node.add_child(proj)

    # Add to ECS world first (triggers define_components)
    ECS.world.add_entity(proj)

    # THEN set values (addon captures these via deferred call at end of frame)
    proj.get_component(C_Velocity).direction = direction * speed
    proj.get_component(C_Transform).position = position
    proj.get_component(C_Projectile).damage = 25
```

If you set values *before* `add_entity()`, `define_components()` overwrites them with defaults. The deferred broadcast captures whatever values exist at end of frame.

**Best for:** Projectiles, particle effects, AoE damage zones, short-lived entities with predictable movement.

### Continuous Sync

For entities with unpredictable movement that need real-time position/rotation updates. The addon auto-configures a Godot `MultiplayerSynchronizer` for native interpolation.

**How to use:** Include both `CN_NetworkIdentity` AND `CN_SyncEntity`.

```gdscript
# e_player.gd
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        _create_sync_entity(),
        C_Transform.new(),
        C_Velocity.new(),
        C_Health.new(),
    ]

static func _create_sync_entity() -> CN_SyncEntity:
    var sync = CN_SyncEntity.new(true, false, false)  # sync_position=true
    sync.custom_properties.append("Rig:rotation")     # Also sync child node rotation
    return sync
```

**CN_SyncEntity options:**

```gdscript
CN_SyncEntity.new(
    sync_position,   # bool: sync global_position
    sync_rotation,   # bool: sync global_rotation
    sync_velocity,   # bool: sync velocity (CharacterBody3D)
)
# Plus custom_properties for arbitrary node properties:
sync.custom_properties.append("Rig:rotation")       # Child node property
sync.custom_properties.append("Sprite:modulate")     # Any node:property pair
```

**Best for:** Players, enemies, NPCs, vehicles — anything with unpredictable movement.

### Choosing Between Patterns

| Entity Type | Pattern | Components | Why |
|---|---|---|---|
| Projectiles | Spawn-only | `CN_NetworkIdentity` only | Deterministic flight path, short-lived |
| AoE effects | Spawn-only | `CN_NetworkIdentity` only | Static position, timed lifetime |
| Players | Continuous | `+ CN_SyncEntity` | Unpredictable movement, long-lived |
| Enemies | Continuous | `+ CN_SyncEntity` | Server-controlled AI, position matters |
| Vehicles | Continuous | `+ CN_SyncEntity` | Physics-driven, unpredictable |
| Pickups | Spawn-only | `CN_NetworkIdentity` only | Static position, collected once |

## Components

### CN_NetworkIdentity

Required for all networked entities. Stores ownership information.

```gdscript
CN_NetworkIdentity.new(peer_id)

# peer_id values:
# 0   = server-owned (enemies, projectiles, pickups)
# 1   = host player (server is also a player)
# 2+  = client players

# Methods:
net_id.is_server_owned()  # True if peer_id is 0 or 1
net_id.is_player()        # True if peer_id > 0
net_id.is_local()         # True if peer_id matches local peer
net_id.has_authority()     # True if local peer has authority
```

### CN_SyncEntity

Opt-in native transform sync via Godot's `MultiplayerSynchronizer`.

```gdscript
var sync = CN_SyncEntity.new(
    true,    # sync_position: global_position
    false,   # sync_rotation: global_rotation
    false,   # sync_velocity: CharacterBody3D.velocity
)

# Sync additional properties on child nodes
sync.custom_properties = ["Rig:rotation", "Sprite:visible"]

# Advanced configuration
sync.replication_interval = 0.0   # 0 = every physics frame
sync.delta_interval = 0.0
sync.public_visibility = true
```

### Marker Components (Auto-Assigned)

NetworkSync automatically assigns these markers when an entity with `CN_NetworkIdentity` is added to the world. **Never assign these manually.**

| Marker | Assigned When | Use In Queries |
|---|---|---|
| `CN_LocalAuthority` | Entity is owned by the local peer | Input systems, camera, local physics |
| `CN_RemoteEntity` | Entity is owned by a remote peer | Skip in physics, apply interpolation |
| `CN_ServerOwned` | Entity has peer_id 0 or 1 | Identify server-managed entities |
| `CN_ServerAuthority` | Entity is server-owned (peer_id 0) | Server-only processing (see below) |

**How markers are assigned per peer:**

| Entity Owner | On Server | On Client |
|---|---|---|
| Server (peer_id=0) | `CN_LocalAuthority` + `CN_ServerAuthority` + `CN_ServerOwned` | `CN_RemoteEntity` + `CN_ServerAuthority` + `CN_ServerOwned` |
| Host player (peer_id=1) | `CN_LocalAuthority` + `CN_ServerOwned` | `CN_RemoteEntity` + `CN_ServerOwned` |
| Client (peer_id=2+) | `CN_RemoteEntity` | `CN_LocalAuthority` (on that client) |

## Authority Patterns

Authority markers replace runtime `is_server()` checks with declarative query filtering. This keeps network logic out of your game systems.

### Pattern A: Local Player Only

For input handling, camera control, and local feedback:

```gdscript
# Only runs for the entity owned by the local peer
func query():
    return q.with_all([C_Velocity, C_Movement, CN_LocalAuthority])
```

### Pattern B: Skip Remote Entities

For physics systems where remote entities are positioned by native sync:

```gdscript
func query():
    return q.with_all([C_CharacterBody3D, C_Velocity])
        .with_none([CN_RemoteEntity, C_Dying, C_Dead])
```

### Pattern C: Server-Owned Entity Filtering

For systems that should only process server-owned entities (enemies, pickups) and only on the server:

```gdscript
func query():
    return q.with_all([C_EnemyAI, CN_ServerAuthority, CN_LocalAuthority])
```

**How this works:**
- **On server:** Server-owned entities have both `CN_ServerAuthority` AND `CN_LocalAuthority` → query matches → system processes
- **On client:** Server-owned entities have `CN_ServerAuthority` but NOT `CN_LocalAuthority` (they have `CN_RemoteEntity`) → query fails → skipped

This is more granular than system group gating — it filters at the entity level within a system that processes multiple entity types.

### Pattern D: Local vs Remote Subsystems

For systems that need different logic per authority:

```gdscript
func sub_systems() -> Array[Array]:
    return [
        # Local entities: full physics simulation
        [
            q.with_all([C_CharacterBody3D, C_Velocity, CN_LocalAuthority])
                .with_none([C_Dying, C_Dead]),
            _process_local
        ],
        # Remote entities: derive velocity for animation, skip physics
        [
            q.with_all([C_CharacterBody3D, C_Velocity, CN_RemoteEntity])
                .with_none([C_Dying, C_Dead]),
            _process_remote
        ]
    ]

func _process_local(entities, components, delta):
    # Full physics: move_and_slide()
    body.velocity = velocity.direction * movement.speed
    body.move_and_slide()

func _process_remote(entities, components, delta):
    # No physics - MultiplayerSynchronizer handles position
    body.velocity = velocity.direction  # Just for animation blending
```

### Pattern E: System Group Gating

For entire systems that should only run on the server (enemy spawning, AI, loot drops):

```gdscript
# In your main scene _process():
func _process(delta):
    world.process(delta, "initialization")

    if Net.is_server():
        world.process(delta, "server-authoritative")  # Only runs on server

    world.process(delta, "input")
    world.process(delta, "movement")
    world.process(delta, "combat")
```

Systems in the `"server-authoritative"` group need **no** `is_server()` checks in their `process()` method — the group gating handles it.

**Important exception:** System group gating only affects the ECS `process()` method. Godot Node callbacks (`_ready()`, signal handlers, Timer callbacks) run on ALL peers. If a server-authoritative system uses these callbacks to spawn entities or mutate state, those callbacks must be guarded:

```gdscript
# System in "server-authoritative" group
func _ready():
    GameState.state_changed.connect(_on_state_changed)  # Fires on ALL peers

func _on_state_changed(_old, new_state):
    if new_state == GameState.State.PLAYING:
        _start_spawning()

func _start_spawning():
    # REQUIRED: Guard signal handler - system group gating doesn't apply here
    if not Net.is_server():
        return
    _spawn_timer = Timer.new()
    _spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    add_child(_spawn_timer)
    _spawn_timer.start()

func _on_spawn_timer_timeout():
    # Timer only exists on server (guarded above) - no check needed
    _spawn_enemy()
```

## SyncComponent (Priority-Based Property Sync)

For component properties that need ongoing synchronization (not just at spawn time), extend `SyncComponent` instead of `Component`.

### Basic SyncComponent

```gdscript
class_name C_Velocity
extends SyncComponent

@export var direction: Vector3 = Vector3.ZERO

func _init(initial: Vector3 = Vector3.ZERO):
    direction = initial
```

The addon polls `@export` properties at the rate defined in your SyncConfig. Properties must be `@export` for sync to work.

### SyncComponent with Observer Support

If you need GECS Observers to react to property changes, add a setter that emits `property_changed`:

```gdscript
class_name C_Health
extends SyncComponent

@export var current_health: int = 100:
    set(value):
        var old_value = current_health
        current_health = value
        if old_value != value:
            property_changed.emit(self, "current_health", old_value, value)

@export var max_health: int = 100

func _init(cur: int = 100, mx: int = 100):
    current_health = cur
    max_health = mx
```

### Input Sync Pattern (Continuous Flags)

For player abilities that need server-authoritative spawning, use a continuous input flag synced via SyncComponent:

```gdscript
# Component: continuous input flag
class_name C_FiringInput
extends SyncComponent

@export var is_firing: bool = false           # Client sets, server reads
@export var aim_direction: Vector3 = Vector3.FORWARD
```

```gdscript
# Input system (runs on local player only)
func query():
    return q.with_all([C_FiringInput, CN_LocalAuthority])

func process(entities, components, delta):
    for i in entities.size():
        var input = components[0][i] as C_FiringInput
        input.is_firing = Input.is_action_pressed("fire")
        input.aim_direction = _get_aim_direction()
```

```gdscript
# Spawning system (server-authoritative group, processes ALL players)
func query():
    return q.with_all([C_Weapon, C_FiringInput, C_Transform])

func process(entities, components, delta):
    for i in entities.size():
        var weapon = components[0][i] as C_Weapon
        var input = components[1][i] as C_FiringInput

        weapon.time_since_shot += delta  # Server exclusively owns cooldown

        if input.is_firing and weapon.time_since_shot >= weapon.cooldown:
            _spawn_projectile(...)
            weapon.time_since_shot = 0.0
```

**Why continuous flags instead of edge detection:**
- `is_action_just_pressed()` fires for one frame — easy to miss over network
- `is_action_pressed()` is a continuous state that syncs reliably at 20Hz
- Server can read the flag at any time, no missed frames
- Cooldown on the server prevents spam even if client holds the button
- Same pattern works for all abilities (fire, dash, shield, nova blast)

### Priority Levels

| Priority | Sync Rate | Transport | Use For |
|---|---|---|---|
| REALTIME | 60 Hz | Unreliable | Critical real-time data |
| HIGH | 20 Hz | Unreliable | Velocity, input flags, animation state |
| MEDIUM | 10 Hz | Reliable | Health, AI state, XP |
| LOW | 1 Hz | Reliable | Inventory, stats, upgrades |

Components not listed in your SyncConfig default to MEDIUM.

## Configuration

### SyncConfig Reference

```gdscript
var config = SyncConfig.new()

# --- Priority mapping ---
config.component_priorities = {
    "C_Velocity": SyncConfig.Priority.HIGH,
    "C_Health": SyncConfig.Priority.MEDIUM,
}

# --- Filtering ---
# Blacklist mode (default): skip these components from RPC sync
config.skip_component_types = ["C_Transform"]

# OR whitelist mode: only sync these components
config.sync_only_components = ["C_Health", "C_Velocity"]

# --- Model instantiation (optional) ---
config.model_ready_component = "C_Instantiated"  # Triggers native sync setup
config.transform_component = "C_Transform"        # For position sync after spawn
config.character_body_component = "C_CharacterBody3D"
config.animation_rig_component = "C_AnimationRig"

# --- Reconciliation ---
config.enable_reconciliation = true
config.reconciliation_interval = 30.0  # seconds
```

### NetAdapter (Custom Networking)

Override `NetAdapter` to use a custom networking backend instead of Godot's built-in multiplayer:

```gdscript
class SteamNetAdapter extends NetAdapter:
    func is_server() -> bool:
        return SteamLobby.is_host()

    func get_my_peer_id() -> int:
        return SteamLobby.get_peer_id()

    func is_in_game() -> bool:
        return SteamLobby.is_connected()

# Attach with custom adapter
var adapter = SteamNetAdapter.new()
var net_sync = NetworkSync.attach_to_world(world, config, adapter)
```

## Signals

```gdscript
# Emitted when ANY entity is spawned on a client (after component data applied)
network_sync.entity_spawned.connect(func(entity: Entity):
    # Apply visual properties, play spawn effects
    pass
)

# Emitted when the local player entity spawns (clients only)
network_sync.local_player_spawned.connect(func(entity: Entity):
    # Set up camera, HUD bindings, input
    pass
)
```

## Public API

```gdscript
# Attach to a GECS world (static factory)
var net_sync = NetworkSync.attach_to_world(world, config, adapter)

# Reset state between game sessions (clears session ID, prevents ghost entities)
net_sync.reset_for_new_game()

# Transfer entity ownership to a different peer (server only)
net_sync.transfer_authority(entity, new_peer_id)

# Generate a deterministic or random network ID
var id = net_sync.generate_network_id(peer_id, use_deterministic)
```

## Middleware Pattern

Keep project-specific logic out of the addon with a thin middleware layer:

```
addons/gecs_network/     <- Generic addon (never modify)
game/network/            <- Project-specific middleware
game/                    <- Your game code
```

### Example: Post-Spawn Visual Setup

```gdscript
class_name NetworkMiddleware
extends Node

var network_sync: NetworkSync

func _init(p_network_sync: NetworkSync) -> void:
    network_sync = p_network_sync
    network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity) -> void:
    # entity_spawned fires AFTER all component data is applied
    var projectile = entity.get_component(C_Projectile)
    if projectile:
        var visual = entity.get_node_or_null("Visual") as MeshInstance3D
        if visual:
            var mat = StandardMaterial3D.new()
            mat.albedo_color = projectile.projectile_color
            mat.emission_enabled = true
            mat.emission = projectile.projectile_color
            visual.material_override = mat
```

## Complete Examples

### Example 1: Player Entity (Continuous Sync)

```gdscript
class_name E_Player
extends Entity

@export var owner_peer_id: int = 1

@export_category("Combat")
@export var health: C_Health = C_Health.new(100, 100)
@export var weapon: C_Weapon = C_Weapon.new()

func define_components() -> Array:
    return [
        health,
        weapon,
        C_Velocity.new(),
        C_Transform.new(),
        C_FiringInput.new(),
        C_AnimationState.new(),
        CN_NetworkIdentity.new(owner_peer_id),
        _create_sync_entity(),
    ]

static func _create_sync_entity() -> CN_SyncEntity:
    var sync = CN_SyncEntity.new(true, false, false)  # Position only
    sync.custom_properties.append("Rig:rotation")     # Sync model rotation
    return sync
```

### Example 2: Server-Owned Enemy (Continuous Sync)

```gdscript
class_name E_Enemy
extends Entity

@export var health: C_Health = C_Health.new(30, 30)

func define_components() -> Array:
    return [
        health,
        C_Velocity.new(),
        C_EnemyAI.new(),
        C_Transform.new(),
        C_AnimationState.new(),
        CN_NetworkIdentity.new(0),    # 0 = server-owned
        _create_sync_entity(),
    ]

static func _create_sync_entity() -> CN_SyncEntity:
    var sync = CN_SyncEntity.new(true, false, false)
    sync.custom_properties.append("Rig:rotation")
    return sync
```

### Example 3: Projectile (Spawn-Only Sync)

```gdscript
class_name E_Projectile
extends Entity

func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),  # Server-owned
        C_Projectile.new(),
        C_Velocity.new(),
        C_Transform.new(),
        C_DeathTimer.new(3.0),
        # NO CN_SyncEntity = spawn-only
    ]
```

### Example 4: Server-Authoritative Weapon Spawning

```gdscript
class_name S_WeaponSpawning
extends System
# Place in "server-authoritative" system group

var _projectile_scene = preload("res://game/entities/e_projectile.tscn")

func query():
    # Process ALL players on server (local host + remote clients)
    return q.with_all([C_Weapon, C_FiringInput, C_Transform])
        .with_none([C_Dying, C_Dead])
        .iterate([C_Weapon, C_FiringInput, C_Transform])

func process(entities: Array[Entity], components: Array, delta: float):
    # No is_server() check needed - system group gating handles it
    var weapons = components[0]
    var inputs = components[1]
    var transforms = components[2]

    for i in entities.size():
        var weapon = weapons[i] as C_Weapon
        var input = inputs[i] as C_FiringInput
        var transform = transforms[i] as C_Transform

        # Server exclusively owns cooldown state
        weapon.time_since_shot += delta

        if input.is_firing and weapon.time_since_shot >= weapon.cooldown:
            var proj = _projectile_scene.instantiate()
            _entities_node.add_child(proj)
            ECS.world.add_entity(proj)

            # Set values AFTER add_entity
            proj.get_component(C_Velocity).direction = input.aim_direction * weapon.speed
            proj.get_component(C_Transform).position = transform.position

            weapon.time_since_shot = 0.0
```

### Example 5: Ability with Continuous Input Flag

```gdscript
# Component
class_name C_NovaBlast
extends SyncComponent

@export var is_activating: bool = false  # Client sets, server reads (HIGH priority)
@export var damage: int = 100
@export var radius: float = 4.0
@export var cooldown_remaining: float = 0.0  # Server-owned state

# Input system (local player only)
class_name S_NovaBlastInput
extends System

func query():
    return q.with_all([C_NovaBlast, CN_LocalAuthority]).iterate([C_NovaBlast])

func process(entities: Array[Entity], components: Array, delta: float):
    for i in entities.size():
        var nova = components[0][i] as C_NovaBlast
        if Input.is_action_pressed("nova_blast") and nova.cooldown_remaining <= 0.0:
            nova.is_activating = true  # Syncs to server at 20Hz

# Spawning system (server-authoritative group)
class_name S_NovaBlastSpawning
extends System

func query():
    return q.with_all([C_NovaBlast, C_Transform]).iterate([C_NovaBlast, C_Transform])

func process(entities: Array[Entity], components: Array, delta: float):
    for i in entities.size():
        var nova = components[0][i] as C_NovaBlast

        # Server exclusively owns cooldown
        if nova.cooldown_remaining > 0.0:
            nova.cooldown_remaining -= delta
            nova.is_activating = false
            continue

        if nova.is_activating:
            var transform = components[1][i] as C_Transform
            _spawn_nova_effect(transform.position, nova.damage, nova.radius)
            nova.cooldown_remaining = 5.0
            nova.is_activating = false
```

### Example 6: Complete Spawn-Only Flow

```
CLIENT A (firing):
  1. Holds fire button
  2. S_Input sets C_FiringInput.is_firing = true (local player, CN_LocalAuthority)
  3. C_FiringInput syncs to server via SyncComponent polling (HIGH, 20Hz)

SERVER:
  4. S_WeaponSpawning reads is_firing=true on Client A's player entity
  5. Cooldown check passes -> spawns projectile with CN_NetworkIdentity.new(0)
  6. Sets velocity, position, damage on components AFTER add_entity()
  7. End of frame: addon serializes @export properties, broadcasts spawn RPC

ALL CLIENTS (including A):
  8. Receive spawn RPC with session_id validation
  9. Instantiate projectile, apply component data from RPC
  10. Local movement system simulates flight (no further sync)
  11. C_DeathTimer expires -> entity removed (despawn also synced)
```

## Animation Synchronization

### Why Not Native Sync for Animations?

Godot's `AnimationPlayer.current_animation` is **read-only**. Even writable properties cause timing drift between clients.

| Approach | Problem |
|---|---|
| Sync `current_animation` | Read-only, cannot be set remotely |
| Sync `assigned_animation` | Doesn't auto-play; timing drift |
| Sync `current_animation_position` | Read-only; would cause jitter |

### Recommended Strategy

**Movement animations (Idle/Run/Sprint):** Derive from synced velocity. Each client selects animations based on `C_Velocity` — zero extra bandwidth.

**One-shot animations (Attack/Hurt/Death):** Sync the animation name via a SyncComponent:

```gdscript
class_name C_AnimationState
extends SyncComponent

@export var current_animation: String = ""  # HIGH priority, "" = use velocity
```

Local systems set `current_animation` when triggering attacks/hurt. Remote clients read it and play the animation locally from frame 0 — no timing drift.

**Rig rotation:** Sync via `CN_SyncEntity.custom_properties`:

```gdscript
sync.custom_properties.append("Rig:rotation")  # Native ~60Hz sync
```

## Authority Transfer

Transfer entity ownership between peers at runtime:

```gdscript
# Server only
network_sync.transfer_authority(entity, new_peer_id)
```

Use cases:
- Player picks up item → transfer to player
- Player drops item → transfer to server (peer_id=0)
- Vehicle enter/exit → transfer ownership

## Troubleshooting

### Entity not syncing
1. Ensure entity has `CN_NetworkIdentity` in `define_components()`
2. Check peer_id is correct (0=server, 1=host, 2+=clients)
3. Verify NetworkSync is attached to the World

### Transform not syncing
1. Add `CN_SyncEntity` to the entity
2. Verify `sync_config.skip_component_types` includes your transform component
3. Check that `model_ready_component` is configured if using deferred model instantiation

### Spawn-only entity appears at origin
1. Set position AFTER `add_entity()`, not before
2. Ensure the position property has `@export`

### Spawn-only entity has default values
1. Set ALL component values AFTER `add_entity()`
2. `define_components()` creates instances with defaults — your values must come after

### Duplicate entities (ghost entities)
1. Call `network_sync.reset_for_new_game()` between game sessions
2. Session IDs in spawn RPCs prevent stale spawns

### Input not reaching server
1. Input component must extend `SyncComponent` (not `Component`)
2. Properties must be `@export`
3. Component must be in `SyncConfig.component_priorities` at HIGH priority
4. Client must have `CN_LocalAuthority` on their player entity

### Performance issues
1. Use priority-based batching (lower priority = less bandwidth)
2. Use `CN_SyncEntity` for transform data (native interpolation)
3. Use spawn-only sync for short-lived deterministic entities
4. Increase `reconciliation_interval` or disable reconciliation

## Architecture

### Two-Tier Synchronization

```
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

### Handler Architecture

The addon is split into focused handlers for maintainability:

| Handler | Responsibility |
|---|---|
| `network_sync.gd` | Orchestrator — RPC stubs, signals, public API |
| `sync_spawn_handler.gd` | Entity lifecycle — spawn/despawn broadcasts, world state serialization |
| `sync_native_handler.gd` | Native sync — MultiplayerSynchronizer setup, model instantiation |
| `sync_property_handler.gd` | Property sync — change detection, priority batching, polling |
| `sync_state_handler.gd` | State — authority markers, time sync, reconciliation |

All RPC methods remain on `NetworkSync` (Godot requirement) and delegate to handlers internally.

### File Structure

```
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
├── sync_component.gd          # Base class for synced components
├── icons/
│   ├── network_sync.svg
│   └── sync_config.svg
└── components/
    ├── cn_network_identity.gd # Required for all networked entities
    ├── cn_sync_entity.gd      # Opt-in native transform sync
    ├── cn_local_authority.gd   # Marker: local peer controls this
    ├── cn_remote_entity.gd     # Marker: remote peer controls this
    ├── cn_server_authority.gd  # Marker: server has authority
    └── cn_server_owned.gd      # Marker: server owns this entity
```

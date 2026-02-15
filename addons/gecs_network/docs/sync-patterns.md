# Sync Patterns

The addon supports two fundamentally different sync patterns. Choosing the right one is the most important architectural decision for each entity type.

## Spawn-Only Sync

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

## Continuous Sync

For entities with unpredictable movement that need real-time position/rotation updates. The addon auto-configures a Godot `MultiplayerSynchronizer` for native interpolation.

**How to use:** Include both `CN_NetworkIdentity` AND `CN_SyncEntity`.

```gdscript
# e_player.gd
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
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

## Choosing Between Patterns

| Entity Type | Pattern | Components | Why |
|---|---|---|---|
| Projectiles | Spawn-only | `CN_NetworkIdentity` only | Deterministic flight path, short-lived |
| AoE effects | Spawn-only | `CN_NetworkIdentity` only | Static position, timed lifetime |
| Players | Continuous | `+ CN_SyncEntity` | Unpredictable movement, long-lived |
| Enemies | Continuous | `+ CN_SyncEntity` | Server-controlled AI, position matters |
| Vehicles | Continuous | `+ CN_SyncEntity` | Physics-driven, unpredictable |
| Pickups | Spawn-only | `CN_NetworkIdentity` only | Static position, collected once |

## Implementing Spawn-Only Sync (Detailed)

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

### Rule 5: Entity Definition (No CN_SyncEntity)

```gdscript
# e_projectile.gd
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),  # 0 = server-owned
        C_Projectile.new(),
        C_Velocity.new(),
        C_Transform.new(),
        C_DeathTimer.new(3.0),
    ]
    # NO CN_SyncEntity - this is what makes it spawn-only!
```

### Complete Spawn-Only Flow

```text
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

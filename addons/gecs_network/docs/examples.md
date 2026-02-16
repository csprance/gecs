# Complete Examples

## Example 1: Player Entity (Continuous Sync)

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

## Example 2: Server-Owned Enemy (Continuous Sync)

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

## Example 3: Projectile (Spawn-Only Sync)

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

## Example 4: Server-Authoritative Weapon Spawning

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
    var entities_node = ECS.world.get_node("Entities")

    for i in entities.size():
        var weapon = weapons[i] as C_Weapon
        var input = inputs[i] as C_FiringInput
        var transform = transforms[i] as C_Transform

        # Server exclusively owns cooldown state
        weapon.time_since_shot += delta

        if input.is_firing and weapon.time_since_shot >= weapon.cooldown:
            var proj = _projectile_scene.instantiate()
            entities_node.add_child(proj)
            cmd.add_entity(proj)

            # Set values AFTER add_entity via CommandBuffer
            cmd.add_custom(func():
                proj.get_component(C_Velocity).direction = input.aim_direction * weapon.speed
                proj.get_component(C_Transform).position = transform.position
            )

            weapon.time_since_shot = 0.0
```

## Example 5: Ability with Continuous Input Flag

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

## Example 6: Complete Spawn-Only Flow

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

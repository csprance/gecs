# Components

## CN_NetworkIdentity

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

## CN_SyncEntity

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

## Marker Components (Auto-Assigned)

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

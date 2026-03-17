# Sync Patterns

**All synced entities require `CN_NetSync`**. Sync behavior — continuous vs spawn-only — is
declared by `@export_group` annotations on component properties, not by the presence or
absence of components.

> **Important:** Spawn-only is declared via `@export_group(CN_NetSync.SPAWN_ONLY)` on properties.
> `CN_NetSync` must be present on every entity that syncs data — including spawn-only entities.

---

## Priority Tiers

| Group name     | Rate           | Transport  | Use for                                |
| -------------- | -------------- | ---------- | -------------------------------------- |
| `"REALTIME"`   | ~60 Hz         | Unreliable | Critical real-time data (rare)         |
| `"HIGH"`       | 20 Hz          | Unreliable | Velocity, input flags, animation state |
| `"MEDIUM"`     | 10 Hz          | Reliable   | Health, AI state, XP                   |
| `"LOW"`        | 2 Hz (default) | Reliable   | Inventory, stats, upgrades             |
| `"SPAWN_ONLY"` | Once at spawn  | Reliable   | Projectile initial position/velocity   |
| `"LOCAL"`      | Never          | —          | Client-only state; never transmitted   |

Rates above 20 Hz use unreliable UDP (speed over reliability). 10 Hz and below use reliable
delivery. Adjust rates via ProjectSettings (`gecs/network/sync/high_hz`, etc.).

---

## Continuous Sync

For entities with ongoing state that must stay synchronized every tick (players, enemies, vehicles):

1. Add `CN_NetSync` to the entity
2. Annotate component properties with priority groups

```gdscript
# Component declaration — priority is inline, no external config
class_name C_NetVelocity
extends Component

@export_group(CN_NetSync.HIGH)
@export var direction: Vector3 = Vector3.ZERO  # Synced at 20 Hz
@export var speed: float = 0.0                 # Synced at 20 Hz

@export_group(CN_NetSync.LOCAL)
@export var predicted_position: Vector3 = Vector3.ZERO  # Never synced
```

```gdscript
# Entity definition
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        CN_NetSync.new(),           # Required for any property sync
        CN_NativeSync.new(),        # Optional: transform via MultiplayerSynchronizer
        C_NetVelocity.new(),        # HIGH group properties sync at 20 Hz
        C_PlayerInput.new(),        # HIGH group input syncs at 20 Hz
        C_PlayerNumber.new(),       # LOW group (join order, rarely changes)
    ]
```

`CN_NativeSync` adds a `MultiplayerSynchronizer` for position/rotation. Use it in addition
to `CN_NetSync` when you want Godot's built-in transform interpolation.

---

## Spawn-Only Sync

For entities with deterministic behavior after spawn (projectiles, effects, AoE zones): mark
relevant component properties with `@export_group(CN_NetSync.SPAWN_ONLY)`. The server broadcasts all
property values once at spawn; clients simulate locally with no further updates.

**`CN_NetSync` is still required** — the SPAWN_ONLY group is a property annotation, not a
signal to skip the component entirely.

```gdscript
# Component with SPAWN_ONLY properties
class_name C_NetPosition
extends Component

@export_group(CN_NetSync.SPAWN_ONLY)
@export var position: Vector3 = Vector3.ZERO   # Sent once at spawn, never continuous
```

```gdscript
# Projectile entity — spawn-only
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(0),   # 0 = server-owned
        CN_NetSync.new(),            # Required — SPAWN_ONLY group lives here
        C_NetPosition.new(),         # SPAWN_ONLY: position
        C_NetVelocity.new(),         # SPAWN_ONLY: initial velocity
        C_Projectile.new(),
    ]
```

**How spawn-only works internally:**

```text
1. Server: ECS.world.add_entity(projectile)
2. SpawnManager detects CN_NetworkIdentity → schedules call_deferred("_deferred_broadcast")
3. Your code sets component values (velocity, position) AFTER add_entity()
4. End of frame: _deferred_broadcast serializes SPAWN_ONLY + all @export properties
5. SpawnManager.rpc_broadcast_spawn() → sends payload to all clients
6. Clients instantiate entity, apply component data, simulate locally
7. No further property sync is sent for this entity
```

**Critical:** Set component values AFTER `add_entity()`:

```gdscript
func _spawn_projectile(position: Vector3, direction: Vector3) -> void:
    var proj = projectile_scene.instantiate()
    entities.add_child(proj)

    # add_entity() triggers define_components() with defaults
    ECS.world.add_entity(proj)

    # Set values AFTER — addon captures these at end of frame
    proj.get_component(C_NetPosition).position = position
    proj.get_component(C_NetVelocity).direction = direction
```

Setting values _before_ `add_entity()` causes `define_components()` to overwrite them with
defaults. The deferred broadcast captures values at end of frame, not at `add_entity()` time.

---

## LOCAL Properties

`@export_group(CN_NetSync.LOCAL)` marks properties that belong only to the declaring peer. They are
never included in any outbound payload:

```gdscript
class_name C_NetVelocity
extends Component

@export_group(CN_NetSync.HIGH)
@export var direction: Vector3 = Vector3.ZERO

@export_group(CN_NetSync.LOCAL)
@export var predicted_position: Vector3 = Vector3.ZERO   # Client-only, not synced
@export var smoothed_speed: float = 0.0                  # Display only, not synced
```

Use `LOCAL` for client-predicted state, UI-only values, or any data that should never leave
the declaring peer.

---

## Mixed Priorities on One Entity

A single entity can have components at multiple priority tiers. `CN_NetSync.scan_entity_components()`
discovers all tiers at spawn and the send pipeline handles each independently:

```gdscript
class_name C_PlayerInput
extends Component

@export_group(CN_NetSync.HIGH)
@export var move_direction: Vector2 = Vector2.ZERO  # Synced at 20 Hz

class_name C_PlayerNumber
extends Component

@export_group(CN_NetSync.LOW)
@export var player_number: int = 0                  # Synced at 2 Hz (default)
```

Both components on the same player entity sync independently. `SyncSender` checks HIGH every
~50 ms and LOW every ~500 ms.

---

## Choosing a Pattern

| Entity Type | Pattern                | Components                      | Reason                             |
| ----------- | ---------------------- | ------------------------------- | ---------------------------------- |
| Players     | Continuous + transform | `CN_NetSync` + `CN_NativeSync`  | Unpredictable movement, long-lived |
| Enemies     | Continuous + transform | `CN_NetSync` + `CN_NativeSync`  | Server-controlled AI               |
| Vehicles    | Continuous + transform | `CN_NetSync` + `CN_NativeSync`  | Physics-driven                     |
| Projectiles | Spawn-only             | `CN_NetSync` (SPAWN_ONLY props) | Deterministic flight, short-lived  |
| AoE effects | Spawn-only             | `CN_NetSync` (SPAWN_ONLY props) | Static position, timed lifetime    |
| Pickups     | Spawn-only             | `CN_NetSync` (SPAWN_ONLY props) | Static position, collected once    |

---

## Complete Spawn-Only Flow

```text
CLIENT A (firing):
  1. Holds fire button
  2. S_Input sets C_PlayerInput.move_direction (CN_LocalAuthority entity only)
  3. Input properties sync to server at HIGH priority (20 Hz)

SERVER:
  4. S_Shooting reads firing input on Client A's player entity
  5. Cooldown check passes → spawns projectile with CN_NetworkIdentity.new(0)
  6. Sets C_NetPosition.position and C_NetVelocity.direction AFTER add_entity()
  7. End of frame: SpawnManager serializes SPAWN_ONLY + all @export properties, broadcasts

ALL CLIENTS (including A):
  8. Receive spawn RPC with session_id validation
  9. Instantiate projectile, apply component data
  10. Local movement system simulates flight (C_NetVelocity read each frame)
  11. Projectile lifetime expires → despawn also synced via NetworkSync
```

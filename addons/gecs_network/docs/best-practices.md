# Best Practices

## Avoid Custom RPCs

**Never write custom RPC code for entity spawning.** The addon handles all spawn synchronization automatically:

```gdscript
# BAD - Custom RPC in game code
@rpc("authority", "call_remote", "reliable")
func _spawn_projectile_rpc(pos, dir, speed):
    _spawn_local(pos, dir, speed)

func fire():
    _spawn_local(pos, dir, speed)
    _spawn_projectile_rpc.rpc(pos, dir, speed)  # Don't do this!

# GOOD - Just add entity with CN_NetworkIdentity
func fire():
    var projectile = projectile_scene.instantiate()
    # Set component values...
    ECS.world.add_entity(projectile)  # Addon auto-broadcasts to clients
```

## Component Serialization

For spawn sync to work, properties must be `@export`:

```gdscript
class_name C_Projectile
extends Component

@export var damage: int = 0        # Synced at spawn
@export var speed: float = 10.0    # Synced at spawn
var owner_entity: Entity = null    # NOT synced (Entity refs don't serialize)
```

## Exclusive State Ownership (Cooldowns, Timers)

**Critical:** When splitting player abilities into server spawning + client feedback systems, state tracking (cooldowns, timers, counters) must have EXCLUSIVE ownership by ONE system.

```gdscript
# BAD - Both systems track cooldown (double-increment bug)
# S_WeaponSpawning (server):
weapon.time_since_shot += delta
if can_fire: weapon.time_since_shot = 0.0

# S_WeaponFeedback (client):
weapon.time_since_shot += delta  # ALSO increments - BUG!
if can_fire: weapon.time_since_shot = 0.0  # Steals reset from server!

# GOOD - Server EXCLUSIVELY owns cooldown state
# S_WeaponSpawning (server-authoritative):
weapon.time_since_shot += delta  # Only place that increments
if can_fire:
    _spawn_projectile()
    weapon.time_since_shot = 0.0  # Only place that resets

# S_WeaponFeedback (client feedback only):
# NO cooldown logic - just animation/audio
if firing_input.is_firing:
    _play_firing_animation()
```

**Why this matters:** Double-increment causes cooldown to tick 2x faster, and client stealing the reset prevents server from ever seeing `can_fire = true`.

## System Split Pattern for Player Abilities

When implementing player abilities with server-authoritative spawning:

| System | Group | Query | Responsibility |
|--------|-------|-------|----------------|
| `S_*Input` | input | `CN_LocalAuthority` | Read Input, set `is_firing` flag |
| `S_*Spawning` | server-authoritative | All players | Spawn entities, own cooldown |
| `S_*Feedback` | combat | `CN_LocalAuthority` | Animation, audio (NO state) |

## Animation Synchronization

### Why Not Native Sync for Animations?

Godot's `AnimationPlayer.current_animation` is **read-only**. Even writable properties cause timing drift between clients.

| Approach | Problem |
|---|---|
| Sync `current_animation` | Read-only, cannot be set remotely |
| Sync `assigned_animation` | Doesn't auto-play; timing drift |
| Sync `current_animation_position` | Read-only; would cause jitter |

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

Local systems set `current_animation` when triggering attacks/hurt. Remote clients read it and play the animation locally from frame 0 — no timing drift.

**Rig rotation:** Sync via `CN_SyncEntity.custom_properties`:

```gdscript
sync.custom_properties.append("Rig:rotation")  # Native ~60Hz sync
```

Then in your animation system:
```gdscript
# For remote players, check the synced animation state
if is_remote and anim_state.current_animation != "":
    if anim_player.current_animation != anim_state.current_animation:
        anim_player.play(anim_state.current_animation)
```

Each client plays the animation locally from frame 0 - no timing drift.

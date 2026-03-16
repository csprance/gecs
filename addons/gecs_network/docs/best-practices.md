# Best Practices

## Query Discipline: Always Use Authority Markers

Always include authority markers in queries so systems only process the entities they should.
Skipping authority filters causes redundant processing and logic bugs in multiplayer.

```gdscript
# BAD — processes remote entities on local peer (redundant + wrong)
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput])

# GOOD — only local player entity is processed by input system
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, CN_LocalAuthority])
```

```gdscript
# BAD — physics system moves remote entities (fought by native sync)
func query() -> QueryBuilder:
    return q.with_all([C_NetVelocity])

# GOOD — skip remote entities; native MultiplayerSynchronizer handles their position
func query() -> QueryBuilder:
    return q.with_all([C_NetVelocity]).with_none([CN_RemoteEntity])
```

---

## Bandwidth Discipline

### Use SPAWN_ONLY for Values That Do Not Change After Spawn

If a component property is set at spawn time and never changes (projectile initial velocity,
entity color, static stats), use `@export_group(CN_NetSync.SPAWN_ONLY)`:

```gdscript
class_name C_Projectile
extends Component

@export_group(CN_NetSync.SPAWN_ONLY)
@export var damage: int = 0
@export var color: Color = Color.WHITE   # Cosmetic, set at spawn, never changes
```

This eliminates all continuous bandwidth for those properties while still delivering them
reliably at spawn.

### Use LOCAL for Client-Only State

Properties that should never leave the declaring peer get `@export_group(CN_NetSync.LOCAL)`:

```gdscript
@export_group(CN_NetSync.LOCAL)
@export var predicted_position: Vector3 = Vector3.ZERO   # Local-only — never synced
@export var ui_health_display: float = 0.0               # Cached for HUD — never synced
```

### Use LOW for Slowly-Changing Values

Stats, inventory counts, and game state that changes rarely belong at LOW priority:

```gdscript
class_name C_PlayerNumber
extends Component

@export_group(CN_NetSync.LOW)
@export var player_number: int = 0    # Set once at join; synced at 1–2 Hz
```

---

## Echo-Loop Prevention

GECS Network automatically prevents received values from being re-broadcast using
`CN_NetSync._applying_network_data`. When `SyncReceiver` applies incoming data, it sets this
flag on the entity's `CN_NetSync` component. While the flag is `true`, `SyncSender` skips
dirty-checking for that component.

**Do not manually set properties inside sync callbacks** unless you fully understand
this guard. If you bypass it, you risk echo loops where every received value is immediately
re-broadcast back to the sender.

If you need to update a component property during network receive (e.g., blending), use a
**custom receive handler** (see `docs/custom-sync-handlers.md`). The framework calls
`update_cache_silent()` automatically after your handler — do not call it yourself.

---

## CommandBuffer + Networking

When structural changes (add/remove components, spawn entities) are needed during sync
callbacks or system processing, use the `cmd` buffer rather than calling `world.*` methods
directly:

```gdscript
func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        if should_despawn(entity):
            cmd.remove_entity(entity)   # Safe deferred removal
```

This is especially important when syncing triggers entity state changes — direct
`world.remove_entity()` calls during iteration can cause index corruption.

---

## Single NetworkSync per World

Attach exactly one `NetworkSync` per `World`. Multiple `NetworkSync` nodes on the same world
cause duplicate RPC registration and undefined sync behavior.

```gdscript
# WRONG — calling attach_to_world() twice on the same world
func _on_reconnect() -> void:
    _network_sync = NetworkSync.attach_to_world(world)   # Creates second NetworkSync!

# CORRECT — guard against double-attach
func _setup_network_sync() -> void:
    if _network_sync:
        return   # Already attached
    _network_sync = NetworkSync.attach_to_world(world)
```

---

## Set Component Values AFTER add_entity()

`SpawnManager` uses `call_deferred("_deferred_broadcast")` to serialize component state at
end of frame. Component values set before `add_entity()` are overwritten by
`define_components()`. Set values after `add_entity()` so they are captured by the broadcast:

```gdscript
func _spawn_projectile(pos: Vector3, dir: Vector3) -> void:
    var proj = projectile_scene.instantiate()
    entities.add_child(proj)

    ECS.world.add_entity(proj)           # define_components() runs here with defaults

    # Set values AFTER — these are captured by the deferred broadcast
    proj.get_component(C_NetPosition).position = pos
    proj.get_component(C_NetVelocity).direction = dir
```

---

## Avoid Custom RPCs

Do not write custom `@rpc` calls for entity spawning or component sync. The addon handles all
of this automatically:

```gdscript
# BAD — manual RPC for spawn
@rpc("authority", "call_remote", "reliable")
func _sync_spawn_rpc(pos: Vector3, dir: Vector3) -> void:
    _spawn_local(pos, dir)

func fire() -> void:
    _spawn_local(pos, dir)
    _sync_spawn_rpc.rpc(pos, dir)   # Never do this

# GOOD — just add the entity; NetworkSync handles the rest
func fire() -> void:
    var proj = projectile_scene.instantiate()
    entities.add_child(proj)
    ECS.world.add_entity(proj)
    proj.get_component(C_NetPosition).position = pos
    proj.get_component(C_NetVelocity).direction = dir
```

---

## Exclusive State Ownership

When splitting systems into server-authoritative and client-feedback pairs, cooldowns, timers,
and counters must be owned exclusively by ONE system. Dual-ownership causes double-increment
bugs:

```gdscript
# BAD — both systems increment the cooldown timer
# S_WeaponSpawning (server):
weapon.time_since_shot += delta

# S_WeaponFeedback (client):
weapon.time_since_shot += delta   # BUG: fires twice per frame on host

# GOOD — server exclusively owns cooldown
# S_WeaponSpawning (server-authoritative group):
weapon.time_since_shot += delta   # Only place that increments
if can_fire:
    _spawn_projectile()
    weapon.time_since_shot = 0.0  # Only place that resets

# S_WeaponFeedback (feedback only — no state mutation):
if weapon.is_firing:
    _play_firing_effect()
```

---

## Custom Handler Registration Timing

Register custom send/receive handlers in `System._ready()`, before the first network tick:

```gdscript
func _ready() -> void:
    var ns := ECS.world.get_node("NetworkSync") as NetworkSync
    if ns == null:
        push_error("%s: NetworkSync not found" % name)
        return
    ns.register_receive_handler("C_NetVelocity", _blend_velocity_correction)
```

The `null` guard is required because systems may initialize before the NetworkSync node is
added to the scene tree (e.g., in editor or test environments).

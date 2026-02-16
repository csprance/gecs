# Authority Patterns

Authority markers replace runtime `is_server()` checks with declarative query filtering. This keeps network logic out of your game systems.

## Pattern A: Local Player Only

For input handling, camera control, and local feedback:

```gdscript
# Only runs for the entity owned by the local peer
func query():
    return q.with_all([C_Velocity, C_Movement, CN_LocalAuthority])
```

## Pattern B: Skip Remote Entities

For physics systems where remote entities are positioned by native sync:

```gdscript
func query():
    return q.with_all([C_CharacterBody3D, C_Velocity])
        .with_none([CN_RemoteEntity, C_Dying, C_Dead])
```

## Pattern C: Server-Owned Entity Filtering

For systems that should only process server-owned entities (enemies, pickups) and only on the server:

```gdscript
func query():
    return q.with_all([C_EnemyAI, CN_ServerAuthority, CN_LocalAuthority])
```

**How this works:**
- **On server:** Server-owned entities have both `CN_ServerAuthority` AND `CN_LocalAuthority` -> query matches -> system processes
- **On client:** Server-owned entities have `CN_ServerAuthority` but NOT `CN_LocalAuthority` (they have `CN_RemoteEntity`) -> query fails -> skipped

This is more granular than system group gating — it filters at the entity level within a system that processes multiple entity types.

## Pattern D: Local vs Remote Subsystems

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

## Pattern E: System Group Gating

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

## Authority Transfer

Transfer entity ownership between peers at runtime:

```gdscript
# Server only
network_sync.transfer_authority(entity, new_peer_id)
```

Use cases:
- Player picks up item -> transfer to player
- Player drops item -> transfer to server (peer_id=0)
- Vehicle enter/exit -> transfer ownership

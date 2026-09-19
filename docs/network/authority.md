# Authority Model

## Overview

GECS Network uses three marker components to declare authority. `SpawnManager` assigns them
automatically when an entity with `CN_NetworkIdentity` enters the world — you never set them
manually.

| Marker               | Meaning                            | Assigned when                                  |
| -------------------- | ---------------------------------- | ---------------------------------------------- |
| `CN_LocalAuthority`  | Local peer controls this entity    | Entity's `peer_id` matches the local peer's ID |
| `CN_RemoteEntity`    | Remote peer controls this entity   | Entity's `peer_id` does NOT match local peer   |
| `CN_ServerAuthority` | Server-owned — `peer_id == 0` only | Entity's `peer_id` is exactly `0`              |

**Key distinction:** `CN_ServerAuthority` means `peer_id == 0` ONLY. The host player
(`peer_id == 1`) is NOT a server-authority entity. On the host machine, the host player gets
`CN_LocalAuthority`; on all clients, it gets `CN_RemoteEntity` — exactly like any other player.

---

## Marker Assignment per Peer Type

| Entity owner                 | On server                                  | On any client                             |
| ---------------------------- | ------------------------------------------ | ----------------------------------------- |
| Server (`peer_id=0`)         | `CN_LocalAuthority` + `CN_ServerAuthority` | `CN_RemoteEntity` + `CN_ServerAuthority`  |
| Host player (`peer_id=1`)    | `CN_LocalAuthority`                        | `CN_RemoteEntity`                         |
| Client player (`peer_id=2+`) | `CN_RemoteEntity`                          | `CN_LocalAuthority` (on that client only) |

`CN_ServerAuthority` is present on BOTH server and clients for server-owned entities. Use it
in queries to filter for server-owned entities regardless of which peer is running the query.

---

## Query Patterns

### Pattern A: Local Player Only

For input handling, camera control, and local feedback. Only the entity owned by the local peer
matches:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, CN_LocalAuthority])
```

On each peer this matches exactly one entity — the one that peer controls.

### Pattern B: Skip Remote Entities in Physics

For physics systems where remote entity positions are already handled by `MultiplayerSynchronizer`:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_NetVelocity]).with_none([CN_RemoteEntity])
```

Excludes all remote-owned entities. The local authority entity and all server-owned entities
(on the server) are processed.

### Pattern C: Server-Owned Processing (Server + Client Safe)

For systems that process server-owned entities (enemies, pickups, projectiles). Add BOTH
`CN_ServerAuthority` and `CN_LocalAuthority` so the system only runs on the machine that has
authority over those entities:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_EnemyAI, CN_ServerAuthority, CN_LocalAuthority])
```

- **On server:** Server-owned entities have both markers → query matches → system processes
- **On client:** Server-owned entities have `CN_ServerAuthority` + `CN_RemoteEntity` (not `CN_LocalAuthority`) → query fails → skipped

This is entity-level gating within a system that may process mixed entity types. See
Pattern E below for whole-system gating.

### Pattern D: Local vs Remote Subsystems

For systems that need different behavior per authority (full physics vs. animation-only):

```gdscript
func sub_systems() -> Array[Array]:
    return [
        # Local entities: full movement simulation
        [
            q.with_all([C_NetVelocity, CN_LocalAuthority]),
            _process_local
        ],
        # Remote entities: position via native sync; derive velocity for animation only
        [
            q.with_all([C_NetVelocity, CN_RemoteEntity]),
            _process_remote
        ]
    ]

func _process_local(entities, components, delta):
    # Apply physics, move_and_slide(), clamp to arena, etc.
    pass

func _process_remote(entities, components, delta):
    # No physics — MultiplayerSynchronizer handles position.
    # Use synced velocity for animation blending only.
    pass
```

### Pattern E: System Group Gating

For entire systems that must only run on the server (enemy spawning, loot drops, game logic):

```gdscript
# In your main scene _process():
func _process(delta: float) -> void:
    world.process(delta, "input")
    world.process(delta, "physics")

    if multiplayer.is_server():
        world.process(delta, "server-authoritative")  # Enemy AI, spawning, loot
```

Systems in `"server-authoritative"` need no `is_server()` guard in their own `process()` —
the group gating handles it.

**Important exception:** Godot Node callbacks (`_ready()`, signal handlers, Timer callbacks)
run on ALL peers regardless of system group. If a server-only system uses signals or timers,
those handlers require explicit guards:

```gdscript
# System in "server-authoritative" group
func _ready() -> void:
    GameState.state_changed.connect(_on_state_changed)  # Fires on ALL peers

func _on_state_changed(_old, new_state) -> void:
    if new_state == GameState.State.PLAYING:
        if not multiplayer.is_server():
            return   # Guard required — signal fires on clients too
        _start_spawning()
```

---

## Authority Injection (Automatic)

`SpawnManager._inject_authority_markers()` runs immediately after a new entity enters the
world and uses an idempotent remove-then-add pattern:

```text
1. Remove CN_LocalAuthority, CN_RemoteEntity, CN_ServerAuthority (if present)
2. Determine local peer ID vs entity peer_id
3. Add the correct markers
```

This means re-spawning the same entity (e.g., respawn on death) always produces a correct
marker state regardless of previous state.

You never need to call this manually. Do not add or remove authority markers directly in
game systems — always let `SpawnManager` manage them.

---

## Checking Authority at Runtime

Use ECS query methods rather than direct marker checks when possible:

```gdscript
# Preferred: query filter (most common use case)
q.with_all([C_PlayerInput, CN_LocalAuthority])

# OK: direct component check (for conditional logic inside a system)
if entity.has_component(CN_LocalAuthority):
    _do_local_only_work()

if entity.has_component(CN_ServerAuthority):
    _do_server_authoritative_work()
```

Avoid calling `CN_NetworkIdentity.is_server_owned()` for authority checks — it only tests
`peer_id == 0` and bypasses the marker system. The marker components are the source of truth.

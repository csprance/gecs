# Complete Examples

All examples below are drawn from the working `example_network/` project.
Run it in Godot to see each pattern in action.

---

## Example 1: Player Entity (Continuous Sync)

`example_network/entities/e_player.gd` — demonstrates continuous property sync via
`CN_NetSync` and transform sync via `CN_NativeSync`.

```gdscript
class_name Player
extends Entity
## Player entity for the network example.
## Demonstrates smooth network sync via CN_NetSync with velocity dead-reckoning
## and position correction for remote entities (see S_NetworkMovement).

func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(),
        CN_NetSync.new(),
        C_NetPosition.new(),
        C_NetVelocity.new(),
        C_PlayerInput.new(),
        C_PlayerNumber.new(),
        C_NewPlayer.new(),
    ]
```

---

## Example 2: Projectile Entity (Spawn-Only Sync)

`example_network/entities/e_projectile.gd` — demonstrates spawn-only sync via
`@export_group(CN_NetSync.SPAWN_ONLY)` on component properties. Uses
`CN_NetworkIdentity` and `CN_NetSync` like any other synced entity.

```gdscript
class_name E_Projectile
extends Entity
## Projectile entity for the network example.
## Demonstrates spawn-only sync via CN_NetSync with SPAWN_ONLY properties.
## Server spawns and broadcasts component values once; clients simulate locally.

func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(),
        CN_NetSync.new(),
        C_NetPosition.new(),
        C_NetVelocity.new(),
        C_Projectile.new(),
    ]
```

---

## Example 3: Components with Priority Annotations

`example_network/components/c_net_velocity.gd` — HIGH priority continuous sync:

```gdscript
class_name C_NetVelocity
extends Component
## Velocity component for network example.

@export_group(CN_NetSync.HIGH)
@export var direction: Vector3 = Vector3.ZERO   # Synced at 20 Hz
```

`example_network/components/c_player_input.gd` — HIGH priority input sync:

```gdscript
class_name C_PlayerInput
extends Component
## Player input component - synced to server for authoritative game state.
## Uses @export_group(CN_NetSync.HIGH) so CN_NetSync prioritizes at ~20 Hz.

@export_group(CN_NetSync.HIGH)
@export var move_direction: Vector2 = Vector2.ZERO
@export var is_shooting: bool = false
@export var shoot_direction: Vector3 = Vector3.FORWARD
```

---

## Example 4: World Setup (main.gd)

`example_network/main.gd` — setup with direct signal connections and reconciliation interval:

```gdscript
func _setup_network_sync() -> void:
    if _network_sync:
        return   # Guard against double-attach

    _network_sync = NetworkSync.attach_to_world(world)
    _network_sync.debug_logging = true

    # ADV-02: configure reconciliation interval (30 s periodic state correction)
    _network_sync.reconciliation_interval = 30.0

    # Connect NetworkSync signals directly — no middleware layer
    _network_sync.entity_spawned.connect(_on_entity_spawned)
    _network_sync.local_player_spawned.connect(_on_local_player_spawned)

func _on_entity_spawned(entity: Entity) -> void:
    print("[Main] Entity spawned via network: %s" % entity.name)

func _on_local_player_spawned(entity: Entity) -> void:
    print("[Main] Local player spawned: %s" % entity.name)
```

---

## Example 5: Custom Sync Handler (ADV-03)

`example_network/systems/s_movement.gd` — registers a receive handler to blend velocity
corrections smoothly instead of snapping.

```gdscript
class_name S_NetworkMovement
extends System
## ADV-03: Registers a custom receive handler for C_NetVelocity to blend corrections.

func _ready() -> void:
    var ns := ECS.world.get_node("NetworkSync") as NetworkSync
    if ns == null:
        return
    ns.register_receive_handler("C_NetVelocity", _blend_velocity_correction)

func _blend_velocity_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
    # Only blend on entities we have local authority over
    if not entity.has_component(CN_LocalAuthority):
        return false   # Fall through to default comp.set() for remote entities
    if props.has("direction"):
        var c := comp as C_NetVelocity
        c.direction = c.direction.lerp(props["direction"], 0.3)
    return true   # Framework calls update_cache_silent() automatically

func query() -> QueryBuilder:
    return q.with_all([C_NetVelocity, C_PlayerInput, CN_LocalAuthority]).iterate([C_NetVelocity, C_PlayerInput])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    var velocities = components[0]
    var inputs = components[1]
    for i in entities.size():
        var velocity = velocities[i] as C_NetVelocity
        var player_input = inputs[i] as C_PlayerInput
        var move_input = player_input.move_direction
        velocity.direction = Vector3(move_input.x, 0, move_input.y) * 5.0
        if entities[i] is Node3D:
            entities[i].global_position += velocity.direction * delta
```

---

## Example 6: Server-Only Shooting System (Spawn-Only Pattern)

`example_network/systems/s_shooting.gd` — server-only entity spawning. Clients receive
spawns via RPC; they never call `_spawn_projectile()` themselves.

```gdscript
class_name S_NetworkShooting
extends System

var _projectile_scene: PackedScene = preload("res://example_network/entities/e_projectile.tscn")
var _cooldown_tracker: Dictionary = {}

const FIRE_RATE := 0.3
const PROJECTILE_SPEED := 10.0

func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, C_PlayerNumber]).iterate([C_PlayerInput, C_PlayerNumber])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    var mp = ECS.world.get_tree().get_multiplayer()
    var is_in_multiplayer = mp.has_multiplayer_peer()
    var is_server = mp.is_server() if is_in_multiplayer else true

    for i in entities.size():
        var entity = entities[i]
        var player_input = components[0][i] as C_PlayerInput

        var cooldown = _cooldown_tracker.get(entity.id, FIRE_RATE)
        cooldown += delta
        _cooldown_tracker[entity.id] = cooldown

        if not player_input.is_shooting or cooldown < FIRE_RATE:
            continue

        # Spawn-only pattern: only server spawns; clients receive via RPC
        if is_in_multiplayer and not is_server:
            continue

        _spawn_projectile(entity, player_input.shoot_direction, components[1][i].player_number)
        _cooldown_tracker[entity.id] = 0.0

func _spawn_projectile(shooter: Entity, direction: Vector3, player_number: int) -> void:
    var projectile = _projectile_scene.instantiate() as Entity
    var spawn_pos = shooter.global_position + direction.normalized() * 1.0

    var entities_node = ECS.world.get_node("Entities")
    entities_node.add_child(projectile)
    projectile.global_position = spawn_pos

    # add_entity() triggers define_components() — sets defaults
    ECS.world.add_entity(projectile)

    # Set component values after add_entity() (components are created during add_entity)
    # NetworkSync captures these via call_deferred at end of frame
    projectile.get_component(C_NetPosition).position = spawn_pos
    projectile.get_component(C_NetVelocity).direction = direction.normalized() * PROJECTILE_SPEED
```

---

## Authority Query Reference

Three common authority query patterns used throughout the example:

```gdscript
# Input: only local player
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, CN_LocalAuthority])

# Physics: skip remote entities (their position comes from MultiplayerSynchronizer)
func query() -> QueryBuilder:
    return q.with_all([C_NetVelocity]).with_none([CN_RemoteEntity])

# Server-owned AI: only process on server
func query() -> QueryBuilder:
    return q.with_all([C_EnemyAI, CN_ServerAuthority, CN_LocalAuthority])
```

---

## Player Spawning Flow

How `main.gd` spawns players (host spawns on `peer_connected`; client's player is spawned
by the server for them):

```gdscript
func _spawn_player_for_peer(peer_id: int) -> void:
    if _spawned_peer_ids.has(peer_id):
        return

    var player_number = _next_player_number
    _next_player_number += 1

    var PlayerScene: PackedScene = preload(PLAYER_SCENE_PATH)
    var player = PlayerScene.instantiate() as Entity
    player.name = str(peer_id)

    # Add to ECS world with component overrides
    var player_num = C_PlayerNumber.new()
    player_num.player_number = player_number
    world.add_entity(player, [CN_NetworkIdentity.new(peer_id), player_num])

    # Set spawn position (must be after add_entity since that adds to tree)
    var spawn_offset = Vector3((player_number % 4) * 2.0 - 3.0, 0, 0)
    player.global_position = spawn_offset

    _spawned_peer_ids[peer_id] = player.id
```

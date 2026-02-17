# GECS Network Example

A minimal multiplayer example demonstrating the GECS Network addon's two synchronization patterns.

## Features Demonstrated

### 1. Continuous Sync (Players)
Players use `CN_SyncEntity` which enables Godot's native `MultiplayerSynchronizer` for real-time position updates.

```gdscript
# e_player.gd
func define_components() -> Array:
	return [
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		CN_SyncEntity.new(true, true, false),  # sync position + rotation
	]
```

### 2. Spawn-Only Sync (Projectiles)
Projectiles do NOT have `CN_SyncEntity`. The server spawns them and broadcasts component values once - then all clients simulate locally.

```gdscript
# e_projectile.gd
func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(0),  # Server-owned
		C_Projectile.new(),
		C_NetVelocity.new(),
		C_NetPosition.new(),       # Position synced at spawn
		# NO CN_SyncEntity - spawn-only pattern
	]
```

## How to Run

1. Open the project in Godot 4.5+
2. Open `example_network/main.tscn`
3. Run the scene (F5 or click Play)
4. Click **Host** to start a server
5. Run another instance and click **Join** (defaults to localhost)

## Controls

- **Arrow Keys**: Move
- **Space**: Shoot

## Architecture

```
example_network/
├── main.gd/tscn           # Entry point with lobby UI
├── config/
│   └── example_sync_config.gd  # Component sync priorities
├── network/
│   └── example_middleware.gd   # Visual setup for spawned entities
├── components/
│   ├── c_net_velocity.gd       # Movement velocity
│   ├── c_net_position.gd       # Position (synced at spawn)
│   ├── c_player_input.gd       # Synced input (SyncComponent)
│   └── c_projectile.gd         # Projectile data + color
├── entities/
│   ├── e_player.gd/tscn        # Player (continuous sync)
│   └── e_projectile.gd/tscn    # Projectile (spawn-only)
└── systems/
	├── s_input.gd              # Read keyboard → C_PlayerInput
	├── s_movement.gd           # Apply velocity (local only)
	├── s_shooting.gd           # Spawn projectiles (server only)
	└── s_projectile.gd         # Move projectiles (all peers)
```

## Key Patterns

### Server-Only Spawning (Spawn-Only Sync)
```gdscript
# s_shooting.gd - Only server spawns
if is_in_multiplayer and not is_server:
	continue  # Clients skip, wait for spawn RPC

# CRITICAL: Set component values AFTER add_entity()
# Only @export properties in components are synced!
ECS.world.add_entity(projectile)
projectile.get_component(C_NetPosition).position = spawn_pos  # Position must be in component
projectile.get_component(C_NetVelocity).direction = dir * speed
projectile.get_component(C_Projectile).projectile_color = color
```

**IMPORTANT**: Node3D properties like `global_position` are NOT synced. Use component properties with `@export` instead (like `C_NetPosition`).

### Local-Only Movement (Continuous Sync)
```gdscript
# s_movement.gd - Query with CN_LocalAuthority
func query() -> QueryBuilder:
	return q.with_all([C_NetVelocity, C_PlayerInput, CN_LocalAuthority])...
```

### Middleware Visual Setup
```gdscript
# example_middleware.gd
func _init(network_sync: NetworkSync):
	network_sync.entity_spawned.connect(_on_entity_spawned)

func _on_entity_spawned(entity: Entity):
	# Apply component data to Node3D and visuals
	_apply_position(entity)         # Component -> Node3D
	_apply_projectile_visual(entity)
	_apply_player_visual(entity)

func _apply_position(entity: Entity):
	var pos = entity.get_component(C_NetPosition)
	if pos and entity is Node3D:
		entity.global_position = pos.position
```

## Visual Indicators

Players are assigned fixed colors based on join order (max 4 players). Each player gets a sequential player number (1-4) independent of their peer_id:

1. **Blue**: Player 1 (Host)
2. **Red**: Player 2 (First to join)
3. **Green**: Player 3 (Second to join)
4. **Yellow**: Player 4 (Third to join)

Projectile colors match the shooting player's color.

**Note**: Peer IDs in ENet are random large numbers (except server which is always 1). The `C_PlayerNumber` component tracks join order separately to enable predictable color assignment.

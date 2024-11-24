## Player Controls System.
## Handles player input and updates the player
class_name PlayerControlsSystem
extends System

const AIM_OFFSET = Vector3(0, 1, 0)

func sub_systems():
	return [
		## Movement Subsystem
		[
			## Entity has a velocity and player movement component and is the player
			ECS.world.query.with_all([C_Velocity, C_PlayerMovement, C_Player]), 
			movement_subsystem
		],
		## Weapon Subsystem
		[
			## Entity has an active weapon and is the player
			ECS.world.query.with_all([C_HasActiveWeapon, C_Player]), 
			weapon_subsystem
		],
		## Item Subsystem
		[
			## Entity has an active item and is the player
			ECS.world.query.with_all([C_HasActiveItem, C_Player]), 
			item_subsystem
		],
		## Generic Input Subsystem
		[
			## Entity is the player
			ECS.world.query.with_all([C_Player]), 
			player_input_subsystem
		],
		## Player Direction
		[
			## Entity is the player and has a player direction component and a transform and look at component
			ECS.world.query.with_all([C_Player, C_PlayerDirection, C_Transform, C_LookAt]),
			player_direction_subsystem
		],
	]


func player_input_subsystem(_3d_playersentity: Entity, _delta: float) -> void:
	if Input.is_action_just_pressed('change_item'):
		# change to the next item in the list of the player's items
		Loggie.debug('Change Item')

	if Input.is_action_just_pressed('change_weapon'):
		Loggie.debug('Change Weapon')
	
	if Input.is_action_just_pressed('radar_toggle'):
		Loggie.debug('Toggle Radar')

	if Input.is_action_just_pressed('pause_toggle'):
		GameState.paused = not GameState.paused


func item_subsystem(entity: Entity, _delta: float) -> void:
	var player = entity as Player
	
	if Input.is_action_just_pressed('use_item'):
		var c_item = player.get_component(C_HasActiveItem) as C_HasActiveItem
		Loggie.debug('Using Item', c_item)


func weapon_subsystem(entity: Entity, _delta: float) -> void:
	var player = entity as Player

	if Input.is_action_just_pressed('use_weapon'):
		var c_weapon = player.get_component(C_HasActiveWeapon) as C_HasActiveWeapon
		Loggie.debug('Using Weapon', c_weapon)


func movement_subsystem(entity: Entity, _delta: float) -> void:
	var player = entity as Player
	# Get the velocity component from the entity
	var velocity = player.get_component(C_Velocity) as C_Velocity
	var movement = player.get_component(C_PlayerMovement) as C_PlayerMovement

	# Reset our movement
	movement.direction = Vector3.ZERO

	# Determine the move axis
	if Input.is_action_pressed('move_left'):
		movement.direction += Vector3.LEFT
	if Input.is_action_pressed('move_right'):
		movement.direction += Vector3.RIGHT
	if Input.is_action_pressed('move_up'):
		movement.direction += Vector3.FORWARD
	if Input.is_action_pressed('move_down'):
		movement.direction += Vector3.BACK

	if movement.direction != Vector3.ZERO:
		movement.direction = movement.direction.normalized()

	# Update velocity based on the move axis and speed
	velocity.direction = movement.direction
	velocity.speed = movement.speed if movement.direction != Vector3.ZERO else 0.0


func player_direction_subsystem(entity: Entity, _delta: float) -> void:
	# Get the camera
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return # no camera bail

	# Get the aim point
	var aim_point = ECS.world.query.with_any([C_AimPoint]).execute()[0] as AimPoint
	if not aim_point:
		return # no aim point bail
	
	var player = entity as Player
	var player_transform = (player.get_component(C_Transform) as C_Transform).transform
	var aim_point_screen_position = (aim_point.get_component(C_ScreenPosition) as C_ScreenPosition).position

	var ray_origin = camera.project_ray_origin(aim_point_screen_position)
	var ray_direction = camera.project_ray_normal(aim_point_screen_position)
	var player_y = player_transform.origin.y + AIM_OFFSET.y

	# Calculate t where the ray intersects y = player_y
	var t = (player_y - ray_origin.y) / ray_direction.y
	var aim_at = ray_origin + ray_direction * t
	
	# Get the player's C_LookAt component
	var c_look_at = entity.get_component(C_LookAt) as C_LookAt
	c_look_at.target = aim_at

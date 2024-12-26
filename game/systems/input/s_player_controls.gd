## Player Controls System.
## Handles player input and updates the player
class_name PlayerControlsSystem
extends System

const AIM_OFFSET = Vector3(0, 1, 0)

func setup():
	# Anytime the player controls system is run this hides the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)

func sub_systems():
	return [
		## Movement Subsystem
		[
			## Entity has a velocity and player movement component and is the player
			ECS.world.query.with_all([C_Player, C_Velocity, C_Movement]), 
			movement_subsystem
		],
		## Weapon Subsystem
		[
			## Entity has an active weapon and is the player
			ECS.world.query.with_all([C_Player, C_HasActiveWeapon]), 
			weapon_subsystem
		],
		## Item Subsystem
		[
			## Entity has an active item and is the player
			ECS.world.query.with_all([C_Player, C_HasActiveItem]), 
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


func player_input_subsystem(entity: Entity, _delta: float) -> void:
	if Input.is_action_just_pressed('change_item'):
		# change to the next item in the list of the player's items
		InventoryUtils.cycle_inventory_item()

	if Input.is_action_just_pressed('change_weapon'):
		InventoryUtils.cycle_inventory_weapon()
	
	if Input.is_action_just_pressed('radar_toggle'):
		GameState.radar_toggled.emit()

	if Input.is_action_just_pressed('pause_toggle'):
		GameState.paused = not GameState.paused
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if GameState.paused else Input.MOUSE_MODE_CONFINED_HIDDEN)

	var up_strength = Input.get_action_strength("cursor_up")
	var left_strength = Input.get_action_strength("cursor_left")
	var down_strength = Input.get_action_strength("cursor_down")
	var right_strength = Input.get_action_strength("cursor_right")
	var mouse_pos = get_viewport().get_mouse_position()
	mouse_pos += Vector2(right_strength - left_strength, down_strength - up_strength) * 25
	Input.warp_mouse(mouse_pos)


func item_subsystem(entity: Entity, _delta: float) -> void:
	if GameState.paused:
		return
	if Input.is_action_just_pressed('use_item'):
		if GameState.active_item:
			InventoryUtils.use_inventory_item(GameState.active_item, entity)


func weapon_subsystem(entity: Entity, _delta: float) -> void:
	if GameState.paused:
		return
	if Input.is_action_just_pressed('use_weapon'):
		if GameState.active_weapon:
			InventoryUtils.use_inventory_item(GameState.active_weapon, entity)


func movement_subsystem(entity: Entity, delta: float) -> void:
	var player = entity as Player
	var c_velocity = player.get_component(C_Velocity) as C_Velocity
	var c_movement = player.get_component(C_Movement) as C_Movement
	var y_vel := float(c_velocity.velocity.y)

	# Determine the input direction
	var input_direction = Vector3.ZERO
	if Input.is_action_pressed('move_left'):
		input_direction += Vector3.LEFT
	if Input.is_action_pressed('move_right'):
		input_direction += Vector3.RIGHT
	if Input.is_action_pressed('move_up'):
		input_direction += Vector3.FORWARD
	if Input.is_action_pressed('move_down'):
		input_direction += Vector3.BACK

	if input_direction != Vector3.ZERO:
		input_direction = input_direction.normalized()

	# Calculate the target velocity based on input
	var target_velocity = input_direction * c_movement.speed
	# if we're in the air we can't move as fast
	if not player.is_on_floor():
		target_velocity *= 0.1
	else:
		y_vel = 0.0
		
	# Adjust current velocity towards the target velocity using acceleration
	var acceleration = 150.0  # Adjust this value as needed
	c_velocity.velocity = c_velocity.velocity.move_toward(target_velocity, acceleration * delta)
	c_velocity.velocity.y = y_vel
	c_movement.direction = input_direction



# updates the player's direction based on the aim point in the game world.
# It calculates the direction the player should look at by projecting a ray from the camera
# through the aim point on the screen and finding the intersection with the player's y-coordinate.
# The resulting aim point is then set as the target for the player's C_LookAt component.
#
# [param entity]: The player entity whose direction is being updated.
# [param _delta]: The time elapsed since the last frame (not used in this function).
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

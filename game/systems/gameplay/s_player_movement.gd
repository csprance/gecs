## PlayerMovementSystem.
##
## Handles player input and updates the player's movement.
## Processes entities with `Velocity` and `PlayerMovement` components.
## Reads input actions to move the player entity left or right.
class_name PlayerMovementSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_PlayerMovement, C_Player])


func process(entity: Entity, _delta: float) -> void:
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

## PlayerMovementSystem.
##
## Handles player input and updates the player's movement.
## Processes entities with `Velocity` and `PlayerMovement` components.
## Reads input actions to move the player entity left or right.
class_name PlayerMovementSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_PlayerMovement])


func process(entity: Entity, _delta: float) -> void:
	# Get the velocity component from the entity
	var velocity = entity.get_component(C_Velocity) as C_Velocity
	var movement = entity.get_component(C_PlayerMovement) as C_PlayerMovement

	# Reset our movement
	movement.axis = Vector2.ZERO

	# Determine the move axis
	if Input.is_action_pressed('paddle_left'):
		movement.axis = Vector2.LEFT
	elif Input.is_action_pressed('paddle_right'):
		movement.axis = Vector2.RIGHT

	# Update velocity based the move axis and speed
	velocity.direction = movement.axis
	velocity.speed = movement.speed if movement.axis != Vector2.ZERO else 0.0

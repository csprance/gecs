class_name PlayerMovementSystem
extends System

func _init():
	required_components = [Velocity, PlayerMovement]


func process(entity: Entity, delta: float) -> void:
	# Get the velocity component from the entity
	var velocity = entity.get_component(Velocity) as Velocity
	var movement = entity.get_component(PlayerMovement) as PlayerMovement

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

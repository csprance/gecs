class_name PlayerMovementSystem
extends System

# Define constants for speed values
const PADDLE_SPEED := 1000.0

func on_process_entity(entity: Entity, delta: float) -> void:
	# Get the velocity component from the entity
	var velocity: Velocity = entity.get_component('velocity')
	
	# Determine movement direction based on player input
	var movement_direction := Vector2.ZERO
	
	if Input.is_action_pressed('paddle_left'):
		movement_direction = Vector2.LEFT
		
	elif Input.is_action_pressed('paddle_right'):
		movement_direction = Vector2.RIGHT
	
	# Update velocity based on input
	velocity.direction = movement_direction
	velocity.speed = PADDLE_SPEED if movement_direction != Vector2.ZERO else 0.0

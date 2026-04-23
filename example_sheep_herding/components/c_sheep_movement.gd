## Locomotion tuning for a sheep.
## Pairs with C_Velocity — systems write a direction/speed into C_Velocity;
## the velocity-integration system moves the body via CharacterBody3D.move_and_slide.
class_name C_SheepMovement
extends Component

@export_group("Speed")
## Casual wander movement speed (units/sec).
@export var walk_speed: float = 2.0
## Panic speed when fleeing from a shepherd.
@export var run_speed: float = 5.0

@export_group("Turning")
## How fast the sheep body rotates toward its movement direction.
@export var rotation_speed: float = 10.0

## Velocity Component.
##
## Represents the velocity of an entity, including its direction and speed.
## Used by the `VelocitySystem` to move entities each frame.
class_name Velocity
extends Component

# The Direction the entity is travelling
@export var direction := Vector2.ZERO
# The Speed the entity is travelling
@export var speed := 0.0

## Velocity Component.[br]
## Represents the velocity of an entity, including its direction and speed.
## Used by the [VelocitySystem] to move entities each frame.
class_name C_Velocity
extends Component

# The Normalized Direction the entity is travelling
@export var direction := Vector3.ZERO
# The Speed the entity is travelling
@export var speed := 0.0

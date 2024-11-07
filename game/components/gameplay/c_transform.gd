## Transform Component.[br]
## Represents the position, rotation, and scale of an entity.
## Used by the `TransformSystem` to synchronize the entity's transform in the scene.
class_name C_Transform
extends Component

@export var position := Vector2.ZERO
@export var rotation := 0.0
@export var scale := Vector2.ZERO

## Transform Component.
##
## Represents the position, rotation, and scale of an entity.
## Used by the `Transform2DSystem` to synchronize the entity's transform in the scene.
class_name Transform
extends Component

@export var position := Vector2.ZERO
@export var rotation := 0.0
@export var scale := Vector2.ZERO

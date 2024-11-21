## Transform Component.[br]
## Represents the position, rotation, and scale of an entity.
## Used by the `TransformSystem` to synchronize the entity's transform in the scene.
class_name C_Transform
extends Component

@export var transform := Transform3D.IDENTITY


var position := Vector3.ZERO :
    set(v):
        transform.origin = v
    get:
        return transform.origin
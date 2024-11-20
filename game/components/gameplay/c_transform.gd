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

var rotation := Vector3.ZERO :
    set(v):
        transform = transform.rotated(transform.basis.y, v.x)
        transform = transform.rotated(transform.basis.y, v.y)
        transform = transform.rotated(transform.basis.y, v.z)
    get:
        return transform.origin

var scale := Vector3.ONE :
    set(v):
        transform = transform.scaled(v)
    get:
        return Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length())
## Transform Component.[br]
## Represents the position, rotation, and scale of an entity.
## Used by the `TransformSystem` to synchronize the entity's transform in the scene.
@tool
class_name C_Transform
extends Component

@export var transform := Transform3D.IDENTITY

@export_tool_button('Node -> C_Transform') var sync_t_c_transform := _to_c_transform
@export_tool_button('C_Transform -> Node') var sync_from_c_transform := _from_c_transform

var position := Vector3.ZERO :
    set(v):
        transform.origin = v
    get:
        return transform.origin

func _init(_trs: Transform3D = transform) -> void:
    transform = _trs

func _to_c_transform():
    Utils.sync_selected_to_c_transform(self)

func _from_c_transform():
    Utils.sync_selected_from_c_transform(self)
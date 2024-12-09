@tool
class_name C_Lives
extends Component

@export_tool_button('Transform From Current Editor Position') var find_missing = _from_current_position

## How many lives the Entity has
@export var lives :int = 3
## How long it takes for the Entity to respawn
@export var respawn_time :float = 4.0
## Where the Entity will respawn
@export var respawn_location: Transform3D = Transform3D.IDENTITY

func _init(_lives: int = 3, _respawn_time: float = 4.0, location: Transform3D=Transform3D.IDENTITY) -> void:
    lives = _lives
    respawn_time = _respawn_time
    respawn_location = location

func _from_current_position():
    var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
    if selected_nodes.size() == 0:
        print('No Node Selected')
        return
    var selected_node: Node = selected_nodes[0]
    if selected_node.get_property_list().map(func(x): return x['name']).has('global_transform'):
        respawn_location = selected_node.global_transform
        print('Transform Set To: ', respawn_location)
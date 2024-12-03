## Indicates an entity is attacking another entity
class_name C_Attacking
extends Component

var target: Entity

func _init(_target: Entity = null):
    target = _target
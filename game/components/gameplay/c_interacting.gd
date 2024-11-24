class_name C_Interacting
extends Component

## The entity to attempt interaction with
var target: Entity

func _init(_target: Entity = null):
    target = _target

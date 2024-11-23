class_name C_Interested
extends Component

## What location is interesting
@export var target: Vector3
## How long should they entity be interested in the target before getting bored and losing interest
@export var bored_timer: float = 5.0

func _init(_target: Vector3):
    target = _target
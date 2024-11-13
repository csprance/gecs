## This is an event payload component for picking up a powerup
## To make sure we connect those to the right entities
class_name C_PowerupPickedUp
extends Component

var powerup: Component

func _init(_powerup: Component):
    powerup = _powerup

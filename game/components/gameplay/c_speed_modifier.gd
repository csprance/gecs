
class_name C_SpeedModifier
extends Component

## Speed multiplier (e.g., 0.5 for half speed)
@export var multiplier: float = 1.0 
## How long this lasts
@export var time: float = 5.0 

# Private variable used to store speed per entitiy
var original_speed := 0.0

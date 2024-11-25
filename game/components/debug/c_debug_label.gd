## Indicates this entity has a debug label and what the debug label says
class_name C_DebugLabel
extends Component

## The text label to display
@export var text: String = "Debug Label"
## The offset from the entity's C_Transform to display the label
@export var offset:= Vector3.ZERO
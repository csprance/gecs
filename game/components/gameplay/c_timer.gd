## Timers count up from 0 to the duration and call a callback when they're done
class_name C_Timer
extends Component

## Is the timer active
@export var active: bool = true
## How long the timer should last
@export var duration: float = 0.0
## The current value of the timer
@export var value: float = 0.0
## Should the timer repeat
@export var repeat: bool = false
## The function to call when the timer is done
@export var callback: Callable
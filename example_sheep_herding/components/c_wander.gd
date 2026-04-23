## Wander-behavior state. Note: mixes config (reach_distance, wander_radius,
## rest_time) with runtime state (target, time_left). Acceptable for an example;
## split into C_WanderConfig + C_WanderState if you ever serialize this to .tres.
class_name C_Wander
extends Component

## World-space point the sheep is currently meandering toward.
@export var target: Vector3 = Vector3.ZERO
## Distance considered "arrived".
@export var reach_distance: float = 0.4
## Horizontal radius within which a new wander target is picked.
@export var wander_radius: float = 6.0
## Seconds of standing still after reaching a target before picking the next one.
@export var rest_time: float = 2.0
## Countdown until the next target is picked. 0 means "move now".
@export var time_left: float = 0.0

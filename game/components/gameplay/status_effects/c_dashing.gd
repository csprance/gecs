class_name C_Dashing
extends Component

# The speed multiplier of the dash
@export var speed_mult: float = 1.5
# The cooldown of the dashing (How long between dashes[can Only have one Dash Component at a time])
@export var cooldown: float = 1.0
## The timer for the dash
var timer: float = 0.0
var original_speed := 0.0

func _init(_speed_mult = speed_mult, _cooldown= cooldown) -> void:
    speed_mult= _speed_mult
    cooldown= _cooldown

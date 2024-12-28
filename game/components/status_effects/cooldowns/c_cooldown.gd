class_name C_Cooldown
extends Component


@export var time: float = 0.0


func _init(duration: float = 0.0) -> void:
    if duration == 0.0:
        Loggie.warn('Cooldowns should have a duration')
    time = duration
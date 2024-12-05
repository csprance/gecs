class_name C_PlayAnimation
extends Component


@export var anim_name := ""
@export var anim_speed := 1.0
@export var loop := false
@export var callback: Callable

var time := 0.0
var finished := false


func _init(_anim_name=anim_name, _anim_speed=anim_speed, _loop=loop) -> void:
    anim_name = _anim_name
    anim_speed = _anim_speed
    loop = _loop
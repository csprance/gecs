## Just a small little visual fx that shows the ghost floating away after being killed
extends Node3D

@onready var animation_player: AnimationPlayer = %'AnimationPlayer'

func _ready():
    animation_player.play('float_away')
    animation_player.animation_finished.connect(func(_x): queue_free())

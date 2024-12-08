extends Node3D

@onready var animation_player: AnimationPlayer = %'AnimationPlayer'

func _ready():
    animation_player.play('rise')
    animation_player.animation_finished.connect(func(_x): queue_free())

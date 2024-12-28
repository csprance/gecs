extends Node3D

@export var points: int = 0

@onready var animation_player: AnimationPlayer = %'AnimationPlayer'
@onready var score: Label3D = %'score'


func _ready():
    score.text = str(points)
    animation_player.play('rise')
    animation_player.animation_finished.connect(func(_x): queue_free())

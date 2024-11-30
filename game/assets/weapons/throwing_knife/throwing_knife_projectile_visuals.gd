@tool
extends Node3D

@export var spinning: bool = true
@export var spin_speed: float = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if spinning:
		rotation.x += spin_speed * delta

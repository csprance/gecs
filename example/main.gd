## Sheep Herding — default GECS example.
##
## Drives the World's process groups in the expected order each frame:
##   input    -> read controls
##   gameplay -> flee decisions, wandering timers, pen detection, win check
##   physics  -> move_and_slide every CharacterBody3D entity
extends Node3D

@onready var world: World = $World


func _ready() -> void:
	ECS.world = world


func _process(delta: float) -> void:
	world.process(delta, "input")
	world.process(delta, "gameplay")


func _physics_process(delta: float) -> void:
	world.process(delta, "physics")

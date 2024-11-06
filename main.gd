extends Node

@onready var world: World = $World

func _ready() -> void:
	ECS.world = world

func _physics_process(delta: float) -> void:
	ECS.process(delta)

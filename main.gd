extends Node

@onready var world: World = $World

func _ready() -> void:
	ECS.world = world

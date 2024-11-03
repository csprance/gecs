extends Node

@onready var world: World = $World

func _ready() -> void:
	WorldManager.set_current_world(world)

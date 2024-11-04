extends Node

@onready var world: World = $World

func _ready() -> void:
	WorldManager.world = world

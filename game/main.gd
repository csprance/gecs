extends Node

@onready var world: World = $World

func _ready() -> void:
	ECS.world = world

	
func _process(delta: float) -> void:
	ECS.process(delta, 'gameplay')
	
func _physics_process(delta: float) -> void:
	ECS.process(delta, 'physics')

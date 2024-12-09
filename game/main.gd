extends Node

@onready var world: World = $World

func _ready() -> void:
	Bootstrap.bootstrap()
	ECS.world = world

func _process(delta):
	ECS.world.process(delta, 'input')
	if not GameState.paused:
		ECS.world.process(delta, 'gameplay')
		ECS.world.process(delta, 'ui')

func _physics_process(delta: float) -> void:
	if not GameState.paused:
		ECS.world.process(delta, 'physics')
	
	ECS.world.process(delta, 'debug')

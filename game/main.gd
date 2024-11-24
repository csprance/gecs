extends Node

@onready var world: World = $World

func _ready() -> void:
	Bootstrap.bootstrap()
	ECS.world = world

func _process(delta):
	ECS.process(delta, 'input')
	if not GameState.paused:
		ECS.process(delta, 'gameplay')
		ECS.process(delta, 'ui')

func _physics_process(delta: float) -> void:
	if not GameState.paused:
		ECS.process(delta, 'physics')

extends Node3D

@onready var world: World = $World

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ECS.world = world


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	world.process(delta, 'gameplay')
	world.process(delta, 'physics')


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# world.process(delta, 'physics')
	pass

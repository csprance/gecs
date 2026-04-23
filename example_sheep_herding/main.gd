extends Node

@onready var world: World = $World


func _ready() -> void:
	ECS.world = world
	# Observers (O_Penned, O_SheepEnteredPen) live under World/Systems in the
	# editor tree and are auto-registered by World on initialization.


func _physics_process(delta: float) -> void:
	world.process(delta, "sim")

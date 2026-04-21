extends Node3D

@onready var world: World = $World


func _ready() -> void:
	ECS.world = world
	# O_MMLifecycleDemo is placed as a child of World/Systems in multimesh_main.tscn
	# so it appears in the editor scene tree. The World auto-registers it from the
	# tree on initialization.


func _process(delta: float) -> void:
	world.process(delta, "physics")
	world.process(delta, "render")

func _physics_process(delta: float) -> void:
	world.process(delta, "gameplay")

extends Node3D

@onready var world: World = $World


func _ready() -> void:
	ECS.world = world
	# O_LifecycleDemo is placed as a child of World/Systems in main.tscn so it
	# appears in the editor scene tree alongside the other reactive logic. The
	# World auto-registers it from the tree on initialization — no code needed here.


func _process(delta: float) -> void:
	world.process(delta, "physics")


func _physics_process(delta: float) -> void:
	world.process(delta, "gameplay")

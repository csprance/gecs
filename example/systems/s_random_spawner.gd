class_name RandomSpawnerSystem
extends System

@export var random_mover_scene: PackedScene


func process(_es: Array, _cs: Array, _d: float):
	call_deferred('_spawn_ents')

func _spawn_ents():
	var entitya = random_mover_scene.instantiate() as Entity
	#var entityb = random_mover_scene.instantiate() as Entity
	ECS.world.add_entities([
		entitya, 
		#entityb
	])

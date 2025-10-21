class_name RandomSpawnerSystem
extends System

@export var random_mover_scene: PackedScene


func process_all(_es: Array, _d: float):
	call_deferred('_spawn_ents')

func _spawn_ents():
	var entity = random_mover_scene.instantiate() as Entity
	ECS.world.add_entity(entity)

class_name RandomSpawnerSystem
extends System

@export var batch_interval: float = 0.01 # Time between batches
@export var random_mover_scene: PackedScene

var timer = 0.1

func process_all(_es: Array, delta: float):
	timer -= delta
	if timer <= 0.0:
		timer = batch_interval
		ECS.world.add_entity(random_mover_scene.instantiate() as Entity)
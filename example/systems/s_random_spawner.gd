class_name RandomSpawnerSystem
extends System

@export var spawn_interval: float = 0.0001 # Time in seconds between spawns
@export var random_mover_scene: PackedScene

var timer = 5.0

func process_all(_es: Array, delta: float):
	timer -= delta
	if timer <= 0.0:
		timer = spawn_interval
		_spawn_entity()


func _spawn_entity() -> void:
	# just grab a random entity with a velocity component to clone
	var e_random_entity = ECS.world.query.with_all([C_Velocity]).execute_one()
	if e_random_entity == null:
		return
	
	ECS.world.add_entity(random_mover_scene.instantiate() as Entity)
	ECS.world.add_entity(random_mover_scene.instantiate() as Entity)

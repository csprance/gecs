class_name RandomSpawnerSystem
extends System

@export var target_entity_count: int = 10000 # Target number of entities to maintain
@export var batch_interval: float = 0.01 # Time between batches
@export var random_mover_scene: PackedScene

var timer = 5.0

func process_all(_es: Array, delta: float):
	timer -= delta
	if timer <= 0.0:
		timer = batch_interval
		_manage_entity_population()


func _manage_entity_population() -> void:
	# Get current entity count (entities with velocity components)
	var current_entities = ECS.world.query.execute()
	var current_count = current_entities.size()
	
	if current_count < target_entity_count:
		ECS.world.add_entity(random_mover_scene.instantiate() as Entity)

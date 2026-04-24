class_name SimpleRandomSpawnerSystem
extends System

@export var random_mover_scene: PackedScene
@export var spawn_area: float = 5.0


func setup():
	command_buffer_flush_mode = FlushMode.PER_GROUP
	safe_iteration = false


func process(_es: Array, _cs: Array, _d: float):
	var entity = random_mover_scene.instantiate() as Entity
	entity.color = Color(randf(), randf(), randf())
	var half = spawn_area / 2.0
	entity.position = Vector3(
		randf_range(-half, half),
		randf_range(-half, half),
		randf_range(-half, half),
	)
	cmd.add_entity(entity)

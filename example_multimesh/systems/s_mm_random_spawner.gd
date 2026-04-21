class_name MMRandomSpawnerSystem
extends System

## How many seconds between spawns (0 = every frame)
@export var spawn_interval: float = 0.05
@export var spawn_area: float = 5.0

func setup():
	command_buffer_flush_mode = FlushMode.PER_GROUP
	safe_iteration = false
	if spawn_interval > 0.0:
		set_tick_rate(spawn_interval)


func process(_es: Array, _cs: Array, _d: float):
	var entity = Entity.new()
	var half = spawn_area / 2.0
	entity.add_component(C_Transform.new(
		Vector3(randf_range(-half, half), randf_range(-half, half), randf_range(-half, half))
	))
	entity.add_component(C_Velocity.new(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))))
	entity.add_component(C_Lifetime.new(50.0,130.0))
	entity.add_component(C_Timer.new())
	entity.add_component(C_Color.new())
	entity.get_component(C_Color).color = Color(randf(), randf(), randf())

	cmd.add_entity(entity)

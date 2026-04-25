class_name SimpleRandomSpawnerSystem
extends System

@export var random_mover_scene: PackedScene
@export var spawn_area: float = 5.0
## Base spawn rate at t=0, in entities/second. Decoupled from framerate via the
## SystemTimer below.
@export var base_spawns_per_second: float = 20.0
## How fast the spawn rate grows per second of simulation time. With a ramp,
## entity count climbs monotonically past the lifetime-imposed steady state, so
## the benchmark exercises add+remove+modify at ever-increasing scale. Set to
## 0.0 to hold the base rate (steady-state benchmarking).
@export var ramp_per_second: float = 1.0
## How often the spawner fires. The real spawn count per tick is
## [code](base + ramp × t) / tick_rate_hz[/code] — fractional carries over so
## the target rate is hit exactly over time regardless of tick granularity.
@export var tick_rate_hz: float = 20.0

var _elapsed: float = 0.0
var _spawn_debt: float = 0.0


func setup():
	command_buffer_flush_mode = FlushMode.PER_GROUP
	safe_iteration = false
	if tick_rate_hz > 0.0:
		set_tick_rate(1.0 / tick_rate_hz)


func process(_es: Array, _cs: Array, _d: float):
	var dt: float = tick_source.interval
	_elapsed += dt
	var current_rate: float = base_spawns_per_second + ramp_per_second * _elapsed
	_spawn_debt += current_rate * dt
	while _spawn_debt >= 1.0:
		_spawn_debt -= 1.0
		_spawn_one()


func _spawn_one() -> void:
	var entity = random_mover_scene.instantiate() as Entity
	entity.color = Color(randf(), randf(), randf())
	var half = spawn_area / 2.0
	entity.position = Vector3(
		randf_range(-half, half),
		randf_range(-half, half),
		randf_range(-half, half),
	)
	cmd.add_entity(entity)


## Current spawn rate for HUD display.
func current_spawn_rate() -> float:
	return base_spawns_per_second + ramp_per_second * _elapsed


## Benchmark elapsed time (seconds) for HUD display.
func elapsed_time() -> float:
	return _elapsed

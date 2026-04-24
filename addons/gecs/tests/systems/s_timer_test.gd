class_name STimerTest
extends System

## Counter incremented each time process() runs — used to verify tick behavior in tests.
var run_count: int = 0


func query():
	process_empty = true
	return _world.query if _world else ECS.world.query


func process(_entities: Array[Entity], _components: Array, _delta: float):
	run_count += 1

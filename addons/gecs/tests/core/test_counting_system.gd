extends System

# Test system that counts how many times it runs

var run_count: int = 0


func tick() -> TickSource:
	return ECS.world.get_tick_source("test-tick") if ECS.world.get_tick_source("test-tick") else ECS.world.get_tick_source("shared-tick")


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	run_count += 1

extends System

# Test system that uses a tick source

func tick() -> TickSource:
	return ECS.world.get_tick_source("test-tick")


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	pass

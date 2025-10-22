## Traditional system approach for velocity-based movement
class_name S_VelocitySystem
extends System

var process_count: int = 0

func query():
	return ECS.world.query.with_all([C_TestPosition, C_TestVelocity])

func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		process_count += 1
		var pos = entity.get_component(C_TestPosition)
		var vel = entity.get_component(C_TestVelocity)

		# Update position based on velocity
		# Note: Direct assignment without using setter to avoid triggering observers
		pos.position = pos.position + vel.velocity * delta

func reset_count():
	process_count = 0

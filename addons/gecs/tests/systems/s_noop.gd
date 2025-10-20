## No-op system for measuring overhead
class_name NoOpSystem
extends System


func query():
	return ECS.world.query.with_all([C_Velocity])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		pass # Do nothing - used for measuring pure framework overhead

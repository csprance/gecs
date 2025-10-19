## No-op system for measuring overhead
class_name NoOpSystem
extends System


func query():
	return ECS.world.query.with_all([C_Velocity])


func process(entity: Entity, delta: float) -> void:
	pass # Do nothing - used for measuring pure framework overhead

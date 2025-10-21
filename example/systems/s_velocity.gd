class_name VelocitySystem
extends System

func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_Velocity]).enabled().iterate([C_Velocity])


## OPTIMIZED: Archetype mode for cache-friendly performance
func process_batch(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0] # C_Velocity (first in iterate)

	# Process all entities with component columns
	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i]
		if velocity:
			entity.position += velocity.velocity * delta
			entity.rotation += velocity.velocity * delta

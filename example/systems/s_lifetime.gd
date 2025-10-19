class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_Lifetime]).iterate([C_Lifetime])


## OPTIMIZED: Archetype mode for cache-friendly performance
func archetype(entities: Array[Entity], components: Array, delta: float) -> void:
	var lifetimes = components[0] # C_Lifetime (first in iterate)

	# Iterate backwards to safely remove entities
	for i in range(entities.size() - 1, -1, -1):
		var c_lifetime = lifetimes[i]
		if c_lifetime != null:
			c_lifetime.lifetime -= delta
			if c_lifetime.lifetime <= 0.0:
				ECS.world.remove_entity(entities[i])

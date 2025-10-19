class_name LifetimeSystem
extends System

var path = C_Lifetime.resource_path

func query() -> QueryBuilder:
	return q.with_all([C_Lifetime])

## OPTIMIZED: Column-based iteration
func process_all(entities: Array, delta: float) -> void:
	for archetype in query().archetypes():
		var lifetimes = archetype.get_column(path)
		var arch_entities = archetype.entities

		# Iterate backwards to safely remove entities
		for i in range(lifetimes.size() - 1, -1, -1):
			var c_lifetime = lifetimes[i]
			if c_lifetime != null:
				c_lifetime.lifetime -= delta
				if c_lifetime.lifetime <= 0.0:
					ECS.world.remove_entity(arch_entities[i])

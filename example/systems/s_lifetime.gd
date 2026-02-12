class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Lifetime]).iterate([C_Lifetime])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var lifetimes = components[0] # C_Lifetime (first in iterate)

	# Use forward iteration with CommandBuffer for cleaner code
	for i in range(entities.size()):
		var c_lifetime = lifetimes[i]
		if c_lifetime != null:
			c_lifetime.lifetime -= delta
			if c_lifetime.lifetime <= 0.0:
				# Queue entity removal - executed after system completes
				cmd.remove_entity(entities[i])

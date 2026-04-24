class_name SimpleLifetimeSystem
extends System


func setup():
	safe_iteration = false


func query() -> QueryBuilder:
	return q.with_all([C_Lifetime]).iterate([C_Lifetime])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var lifetimes = components[0]
	for i in range(entities.size()):
		var c_lifetime = lifetimes[i]
		if c_lifetime != null:
			c_lifetime.lifetime -= delta
			if c_lifetime.lifetime <= 0.0:
				cmd.remove_entity(entities[i])

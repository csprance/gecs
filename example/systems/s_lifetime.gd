class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Lifetime])

func process(entity: Entity, delta: float) -> void:
	var c_lifetime = entity.get_component(C_Lifetime) as C_Lifetime
	c_lifetime.lifetime -= delta
	if c_lifetime.lifetime <= 0.0:
		ECS.world.remove_entity(entity)

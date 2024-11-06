## Health System.
## Processes entities with the `Health` component.
## Plays a sound effect upon entity death.
class_name HealthSystem
extends System

func query(q: QueryBuilder) -> QueryBuilder:
	return q.with_all([Health])


func process(entity: Entity, delta: float) -> void:
	var health = entity.get_component(Health) as Health

	# If it's health is below 0 remove the entity
	if health.current <= 0:
		entity.add_component(Death.new())
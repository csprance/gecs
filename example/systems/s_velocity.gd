class_name VelocitySystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).enabled().iterate([C_Velocity])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0] # C_Velocity (first in iterate)

	# Process all entities with component columns
	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i]
		if velocity:
			var val = velocity.velocity * delta
			entity.position += val
			entity.rotation += val

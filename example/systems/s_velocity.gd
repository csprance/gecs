class_name SimpleVelocitySystem
extends System

func setup():
	safe_iteration = false


func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).iterate([C_Velocity])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	for i in entities.size():
		var velocity = velocities[i]
		if velocity:
			var val = velocity.velocity * delta
			entities[i].position += val
			entities[i].rotation += val

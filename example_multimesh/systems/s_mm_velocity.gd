class_name MMVelocitySystem
extends System


func setup():
	safe_iteration = false


func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Transform]).iterate([C_Velocity, C_Transform])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	var transforms = components[1]
	for i in entities.size():
		var velocity: C_Velocity = velocities[i]
		var t: C_Transform = transforms[i]
		if velocity and t:
			var val = velocity.velocity * delta
			t.position += val
			t.rotation += val

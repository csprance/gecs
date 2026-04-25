## Velocity-integration system.
## Reads C_Velocity, writes it to the CharacterBody3D and runs move_and_slide.
## Runs after steering systems (Wander/Flee/Shepherd) in the sim group so it
## sees the latest velocity written this frame.
class_name SheepVelocitySystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).iterate([C_Velocity])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var velocities: Array = components[0]
	for i in entities.size():
		var c_vel: C_Velocity = velocities[i]
		var body := entities[i] as Node as CharacterBody3D
		if c_vel == null or body == null:
			continue
		body.velocity = c_vel.velocity
		body.move_and_slide()

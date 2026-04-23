## Velocity-integration system.
## Reads C_Velocity and pushes the entity forward. CharacterBody3D entities
## go through move_and_slide for collision response; plain Node3D entities
## fall back to direct position integration (useful for trigger-style nodes).
##
## Runs after steering systems (Wander/Flee/Shepherd) in the sim group so it
## sees the latest velocity written this frame.
class_name SheepVelocitySystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).iterate([C_Velocity])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities: Array = components[0]

	for i in entities.size():
		var c_vel: C_Velocity = velocities[i]
		if c_vel == null:
			continue

		var as_node := entities[i] as Node
		var body := as_node as CharacterBody3D
		if body:
			body.velocity = c_vel.velocity
			body.move_and_slide()
			continue

		var node := as_node as Node3D
		if node:
			node.global_position += c_vel.velocity * delta

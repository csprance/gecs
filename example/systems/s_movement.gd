## Drives CharacterBody3D movement for both players and sheep. Uses sub_systems
## so each entity kind has its own focused per-frame handler while sharing the
## same MovementSystem node.
##
## Player velocity is already written each frame by PlayerInputSystem.
## Sheep velocity is derived here from their current state:
##   - Penned: zero velocity (they chill)
##   - Fleeing from the player (relationship): run away fast (C_FleeRange.panic_speed)
##   - Otherwise wandering: follow the rolling C_Wander direction at C_Speed.max_speed
class_name MovementSystem
extends System


func sub_systems() -> Array[Array]:
	return [
		[q.with_all([C_Player, C_Speed]), process_player],
		[q.with_all([C_Sheep, C_Speed]), process_sheep],
	]


func process_player(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var body := entity as CharacterBody3D
		if body != null:
			body.move_and_slide()


func process_sheep(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var player := ECS.world.query.with_all([C_Player]).execute_one()
	var player_pos := (player as Node3D).global_position if player != null else Vector3.ZERO
	var flee_rel_template := Relationship.new(C_FleeingFrom.new(), null)

	for entity in entities:
		var body := entity as CharacterBody3D
		if body == null:
			continue

		if entity.get_component(C_Penned) != null:
			body.velocity = Vector3.ZERO
			body.move_and_slide()
			continue

		var speed := entity.get_component(C_Speed) as C_Speed
		var dir := Vector3.ZERO

		if entity.has_relationship(flee_rel_template) and player != null:
			var away := (entity as Node3D).global_position - player_pos
			away.y = 0.0
			if away.length() > 0.001:
				dir = away.normalized()
			var flee_range := entity.get_component(C_FleeRange) as C_FleeRange
			var panic := flee_range.panic_speed if flee_range != null else speed.max_speed * 1.5
			body.velocity.x = dir.x * panic
			body.velocity.z = dir.z * panic
		else:
			var wander := entity.get_component(C_Wander) as C_Wander
			if wander != null:
				dir = wander.direction
			body.velocity.x = dir.x * speed.max_speed
			body.velocity.z = dir.z * speed.max_speed

		body.move_and_slide()

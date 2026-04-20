## Reads keyboard input and writes the desired horizontal velocity onto the
## player's CharacterBody3D every frame. The MovementSystem (physics group)
## will read that velocity back when it calls move_and_slide().
class_name PlayerInputSystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Player, C_Speed])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := Vector3(input_vec.x, 0.0, input_vec.y)

	for entity in entities:
		var body := entity as CharacterBody3D
		var speed := entity.get_component(C_Speed) as C_Speed
		if body == null or speed == null:
			continue
		body.velocity.x = dir.x * speed.max_speed
		body.velocity.z = dir.z * speed.max_speed

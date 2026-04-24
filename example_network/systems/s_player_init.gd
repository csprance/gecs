class_name PlayerInitSystem
extends System


func query() -> QueryBuilder:
	# Process all entities that have C_PlayerColor and C_NewPlayer (new/uninitialized players)
	return q.with_all([C_PlayerColor, C_NewPlayer]).iterate([C_PlayerColor])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var colors = components[0]

	for i in entities.size():
		var player = entities[i] as Player
		if player == null:
			continue
		player.set_visual_color(colors[i].color)
		cmd.remove_component(entities[i], C_NewPlayer)  # Deferred via CommandBuffer — safe during forward iteration

class_name PlayerInitSystem
extends System

func query() -> QueryBuilder:
	# Process all entities with C_PlayerNumber but no CN_NetworkIdentity (not yet initialized)
	return q.with_all([C_PlayerColor, C_NewPlayer]).iterate([C_PlayerColor])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var colors = components[0]

	for i in entities.size():
		var entity = entities[i] as Player
		entity.set_visual_color(colors[i].color)

		entity.remove_component(C_NewPlayer) # Remove flag component so we don't re-process

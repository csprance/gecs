## Reacts to C_PlayerColor on a Player and applies the visual color.
## Listens for both ADDED and CHANGED — on the client, the spawn payload
## adds the component with default color first, then sets the synced value
## via property setter, so we need both events to land on the right color.
class_name PlayerInitObserver
extends Observer


func query() -> QueryBuilder:
	return q.with_all([C_PlayerColor]).on_added().on_changed([&"color"])


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var player := entity as Player
	if player == null:
		return
	var color_component := entity.get_component(C_PlayerColor) as C_PlayerColor
	if color_component:
		player.set_visual_color(color_component.color)

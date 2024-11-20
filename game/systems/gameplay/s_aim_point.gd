
class_name AimPointSystem
extends System

func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([C_AimPoint, C_ScreenPosition]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	if entity is AimPoint:
		var screen_pos = entity.get_component(C_ScreenPosition) as C_ScreenPosition
		# Get the mouse position on screen
		screen_pos.position = get_viewport().get_mouse_position()
		# Use the mouse_position as needed
		entity.sprite_2d.position = screen_pos.position


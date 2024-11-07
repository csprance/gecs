class_name UiVisibilitySystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_UiVisibility]) # add required components


func process(entity: Entity, _delta: float) -> void:
	# Find all the UI with the visiblity component
	var ui: Ui = entity
	# Show them if it says true otherwise hide them
	if not ui.canvas_layer.visible:
		ui.canvas_layer.visible = true


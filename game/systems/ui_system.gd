class_name UiSystem
extends System


func query(q: QueryBuilder) -> QueryBuilder:
	return q.with_all([UiVisibility]) # add required components


func process(entity: Entity, delta: float) -> void:
	# Find all the UI with the visiblity component
	var ui: UiEntity = entity
	# Show them if it says true otherwise hide them
	if not ui.canvas_layer.visible:
		ui.canvas_layer.visible = true


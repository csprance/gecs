@tool
class_name GECSExplorerPropertyProxy
extends RefCounted
## Native property editors edit this local draft, never a runtime Resource.
signal staged(property: String, value: Variant)
var fields: Array = []
var values: Dictionary = {}

# This inspector edits a local draft. It must not create scene undo actions or
# retain a proxy whose selected remote property can change underneath an undo.
func _dont_undo_redo() -> bool:
	return true

func configure(definitions: Array) -> void:
	fields = definitions
	values.clear()
	for field in fields: values[field.name] = GECSExplorerCodec.decode(field.value)
	notify_property_list_changed()

func _get_property_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for field in fields:
		if field.get("writable", false):
			result.append({"name": field.name, "type": field.type, "hint": field.get("hint", 0), "hint_string": field.get("hint_string", ""), "usage": PROPERTY_USAGE_EDITOR})
	return result

func _get(property: StringName) -> Variant:
	return values.get(str(property))

func _set(property: StringName, value: Variant) -> bool:
	if not values.has(str(property)): return false
	values[str(property)] = value
	staged.emit(str(property), value)
	return true

class_name Utils

## Synchronize a Transform component with the current Entity Position
## This is usually run from _ready to sync node and component transforms together
static func sync_transform(entity: Entity):
	var trs: C_Transform = entity.get_component(C_Transform)
	if trs:
		trs.position = entity.position
		trs.rotation = entity.rotation
		trs.scale = entity.scale


static func all(arr: Array) -> bool:
	for element in arr:
		if not element:
			return false
	return true

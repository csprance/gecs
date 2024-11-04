class_name Utils

## Synchronize a Transform component with the current Entity Position
## This is usually run from _ready to sync node and component transforms together
static func sync_transform(entity: Entity):
	var trs: Transform = entity.get_component(Transform)
	if trs:
		trs.position = entity.position
		trs.rotation = entity.rotation
		trs.scale = entity.scale

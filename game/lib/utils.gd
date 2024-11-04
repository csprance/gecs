class_name Utils

## Synchronize a Transform component with the current Entity Position
## This is usually run from _ready to sync node and component transforms together
static func sync_transform(entity: Entity):
	var trs: Transform = entity.get_component(Transform)
	if trs:
		entity.position = trs.position
		entity.rotation = trs.rotation
		entity.scale = trs.scale

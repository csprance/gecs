class_name Utils

## Synchronize a Transform component with the current Entity Position
## This is usually run from _ready to sync node and component transforms together
static func sync_transform(entity: Entity):
	var trs: C_Transform = entity.get_component(C_Transform)
	if trs:
		trs.position = entity.position
		trs.rotation = entity.rotation
		trs.scale = entity.scale

static func sync_from_transform(entity: Entity):
	var trs: C_Transform = entity.get_component(C_Transform)
	entity.position = trs.position
	entity.rotation = trs.rotation
	entity.scale = trs.scale

static func all(arr: Array) -> bool:
	for element in arr:
		if not element:
			return false
	return true


## An event entity is an entity with the event component and other components attached to it that describe an event[br]
## Systems should clean up the event entity after processing the event
## [param components] - An array of extra components to attach to the event entity
static func create_ecs_event(extra_components = []):
	var entity = Entity.new()
	ECS.world.add_entity(entity)
	entity.add_components([C_Event.new()] + extra_components)
	
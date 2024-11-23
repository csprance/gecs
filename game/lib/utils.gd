class_name Utils

## Synchronize a Transform component with the position from the entity (node2d)
## This is usually run from _ready to sync node and component transforms together
## This is the opposite of [method Utils.sync_from_transform]
static func sync_transform(entity: Entity):
	var trs: C_Transform = entity.get_component(C_Transform) as C_Transform
	if trs:
		trs.transform = entity.global_transform


## Synchronize a transfrorm from the component to the entity
## This is the opposite of [method Utils.sync_transform]
static func sync_from_transform(entity: Entity):
	var trs: C_Transform = entity.get_component(C_Transform)
	if trs:
		entity.global_transform = trs.transform
	


## Python like all function. Goes through an array and if any of the values are nothing it's false
## Otherwise it's true if every value is something
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


## A common pattern is to add components to a query result. This allows that
static func add_components_to_query_results(query: QueryBuilder, components: Array[Component]):
	var entities = query.execute()
	for entity in entities:
		entity.add_components(components)


## Just like pythons Zip function, takes two sequences and zips them together
static func zip(sequence_x, sequence_y):
	var result = []
	for y in sequence_y:
		for x in sequence_x:
			result.append(Vector2(x, y))
	return result

static func add_inventory_item(c_item: C_Item, quantity: int = 1):
	var new_item = Item.new()
	new_item.add_components([c_item, C_InInventory.new(), C_Quantity.new(quantity)])
	ECS.world.add_entity(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', quantity)

static func has_los(from: Vector3, to: Vector3) -> bool:
	var ray = RayCast3D.new()
	ray.transform.origin = from
	ray.target_position = to
	ray.force_raycast_update()
	return ray.is_colliding()
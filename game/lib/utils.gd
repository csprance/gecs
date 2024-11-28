class_name Utils

## Synchronize a Transform component with the position from the entity (node2d)
## This is usually run from _ready to sync node and component transforms together
## This is the opposite of [method Utils.sync_from_transform]
static func sync_transform(entity: Entity):
	var c_position: CPosition = entity.get_component(CPosition) as CPosition
	if c_position:
		c_position.position = entity.global_transform.origin


## Synchronize a transfrorm from the component to the entity
## This is the opposite of [method Utils.sync_transform]
static func sync_from_transform(entity: Entity):
	var c_position: CPosition = entity.get_component(CPosition) as CPosition
	if c_position:
		entity.global_transform.origin = c_position.position
	


## Python like all function. Goes through an array and if any of the values are nothing it's false
## Otherwise it's true if every value is something
static func all(arr: Array) -> bool:
	for element in arr:
		if not element:
			return false
	return true


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


static func has_los(from: Vector3, to: Vector3) -> bool:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree is SceneTree:
		return false
	var space_state = scene_tree.root.get_world_3d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return result.has('collider')

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

## Can we see from one point to another
static func has_los(from: Vector3, to: Vector3, debug = false) -> bool:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree is SceneTree:
		return false
	var space_state = scene_tree.root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 2) # Only check against hitboxes
	var result = space_state.intersect_ray(query)
	if debug:
		DebugDraw3D.draw_line(from, to, Color(1, 0, 0) if result.has('collider') else Color(0, 1, 0), 15)
	return not result.has('collider')


static func entity_has_los(from: Entity, to: Entity, debug= false) -> bool:
	var c_trs_from = from.get_component(C_Transform) as C_Transform
	var c_trs_to = to.get_component(C_Transform) as C_Transform
	if not c_trs_from or not c_trs_to:
		return false
	var dir = (c_trs_to.transform.origin - c_trs_from.transform.origin).normalized()
	return has_los(c_trs_from.transform.origin + (dir*1.1), c_trs_to.transform.origin, debug)

# Calculates the direction an entity is facing based on the look-at component and TRS component.
static func calculate_entity_direction(entity: Entity) -> Vector3:
	var c_trs = entity.get_component(C_Transform) as C_Transform
	var c_lookat = entity.get_component(C_LookAt) as C_LookAt
	if not c_trs or not c_lookat:
		return Vector3.ZERO
	# Direction from the player to the look-at target, ignoring the y-axis.
	var dir = (c_lookat.target - c_trs.position).normalized()
	dir.y = 0
	return dir.normalized()

## Check if the angle between two points is less than the angle
static func angle_check(direction: Vector3, forward: Vector3, angle: float) -> bool:
	var dot_product = forward.dot(direction)
	var body_angle = rad_to_deg(acos(dot_product))
	return body_angle <= angle/2.0

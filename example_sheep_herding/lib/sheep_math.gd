## Small static helpers shared between sheep systems.
class_name SheepMath

## Cached shepherd reference for WanderSystem / FleeSystem. Re-queried on
## invalidation instead of per-frame to avoid repeated ECS lookups.
static var _shepherd: Shepherd


## Smoothly rotate [param node] toward [param direction] on the XZ plane.
## [param speed] is radians-per-second-ish (slerp weight), clamped per frame.
## Accepts a `Node` so callers can pass Sheep/Shepherd (Entity-typed at the
## static level, but Node3D-rooted at runtime) without an explicit cast.
static func face(node: Node, direction: Vector3, speed: float, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var node_3d := node as Node3D
	if node_3d == null:
		return
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	var weight: float = clamp(speed * delta, 0.0, 1.0)
	node_3d.global_transform.basis = node_3d.global_transform.basis.slerp(target_basis, weight)


## XZ-plane squared distance between two world positions (ignores Y).
static func xz_distance_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## Cached lookup for the (single) shepherd entity. Returns null if there is
## no active shepherd. Used by WanderSystem and FleeSystem.
static func get_shepherd() -> Shepherd:
	if _shepherd and is_instance_valid(_shepherd):
		return _shepherd
	_shepherd = ECS.world.query.with_all([C_Shepherd]).execute_one() as Shepherd
	return _shepherd


## Snap [param pos] to the closest reachable point on the NavigationAgent3D's
## map. Returns [param pos] unchanged if the agent has no map yet (pre-bake
## first frame), so callers always get a usable value.
static func snap_to_navmesh(agent: NavigationAgent3D, pos: Vector3) -> Vector3:
	if agent == null:
		return pos
	var map_rid := agent.get_navigation_map()
	if not map_rid.is_valid():
		return pos
	return NavigationServer3D.map_get_closest_point(map_rid, pos)

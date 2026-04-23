## Small static helpers shared between sheep systems.
class_name SheepMath


## Cached shepherd reference for WanderSystem / FleeSystem. Re-queried on
## invalidation instead of per-frame to avoid repeated ECS lookups.
static var _shepherd: Node3D


## Smoothly rotate [param node] toward [param direction] on the XZ plane.
## [param speed] is radians-per-second-ish (slerp weight), clamped per frame.
static func face(node: Node3D, direction: Vector3, speed: float, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	var weight: float = clamp(speed * delta, 0.0, 1.0)
	node.global_transform.basis = node.global_transform.basis.slerp(target_basis, weight)


## XZ-plane squared distance between two world positions (ignores Y).
static func xz_distance_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## Cached lookup for the (single) shepherd entity's Node3D. Returns null if
## there is no active shepherd. Used by WanderSystem and FleeSystem.
static func get_shepherd() -> Node3D:
	if _shepherd and is_instance_valid(_shepherd):
		return _shepherd
	var entity := ECS.world.query.with_all([C_Shepherd]).execute_one()
	if entity:
		_shepherd = (entity as Node) as Node3D
	else:
		_shepherd = null
	return _shepherd

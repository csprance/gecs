## Shepherd System.
## Reads WASD input, writes camera-relative movement into C_Velocity, rotates
## the shepherd to face its movement direction, and slides the main camera
## along with it. Movement integration happens in SheepVelocitySystem.
##
## The resulting velocity is clamped against the world's NavigationMesh so the
## player can't wander off the baked play area — the proposed next position is
## projected onto the closest mesh point via NavigationServer3D, and the
## velocity is rewritten to land exactly on that point this frame.
class_name ShepherdSystem
extends System

var _camera: Camera3D
var _camera_offset: Vector3
var _camera_offset_cached: bool = false

## Cached RID of the default 3D navigation map for the shepherd's world.
## Resolved lazily on the first process tick once the scene tree is ready.
var _nav_map: RID


func query() -> QueryBuilder:
	return q.with_all([C_Shepherd, C_Velocity])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if entities.is_empty():
		return
	var shepherd := entities[0] as Shepherd
	if shepherd == null:
		return

	_ensure_camera(shepherd)
	_ensure_nav_map(shepherd)

	var cfg := shepherd.get_component(C_Shepherd) as C_Shepherd
	var c_vel := shepherd.get_component(C_Velocity) as C_Velocity
	var move_dir := _camera_relative(_read_input_direction())

	if move_dir.length_squared() > 0.0:
		var speed := cfg.move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= cfg.sprint_multiplier
		c_vel.velocity = move_dir * speed
		SheepMath.face(shepherd, move_dir, cfg.rotation_speed, delta)
	else:
		c_vel.velocity = Vector3.ZERO

	_clamp_velocity_to_navmesh(shepherd, c_vel, delta)
	_follow_camera(shepherd)


func _ensure_camera(shepherd: Shepherd) -> void:
	if _camera and is_instance_valid(_camera):
		return
	_camera = shepherd.get_viewport().get_camera_3d()
	if _camera and not _camera_offset_cached:
		_camera_offset = _camera.global_position - shepherd.global_position
		_camera_offset_cached = true


func _ensure_nav_map(shepherd: Shepherd) -> void:
	if _nav_map.is_valid():
		return
	var world_3d: World3D = shepherd.get_world_3d()
	if world_3d:
		_nav_map = world_3d.navigation_map


## Rewrite [param c_vel].velocity so integrating it this frame lands the
## shepherd on the closest navmesh point. If the desired position is already
## on-mesh the velocity is unchanged; if it would cross a mesh edge the
## velocity is scaled back to stop at the edge.
func _clamp_velocity_to_navmesh(shepherd: Shepherd, c_vel: C_Velocity, delta: float) -> void:
	if not _nav_map.is_valid() or delta <= 0.0:
		return
	if c_vel.velocity.is_zero_approx():
		return
	var current: Vector3 = shepherd.global_position
	var desired := current + c_vel.velocity * delta
	var on_mesh := NavigationServer3D.map_get_closest_point(_nav_map, desired)
	# Preserve the shepherd's Y — the capsule sits above the navmesh surface,
	# and we only want to constrain horizontal movement.
	var corrected := Vector3(on_mesh.x, current.y, on_mesh.z)
	c_vel.velocity = (corrected - current) / delta


func _read_input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		dir += Vector3.LEFT
	if Input.is_key_pressed(KEY_D):
		dir += Vector3.RIGHT
	if Input.is_key_pressed(KEY_W):
		dir += Vector3.FORWARD
	if Input.is_key_pressed(KEY_S):
		dir += Vector3.BACK
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	return dir


func _camera_relative(input_dir: Vector3) -> Vector3:
	if input_dir == Vector3.ZERO or _camera == null:
		return input_dir
	var forward := -_camera.global_transform.basis.z
	var right := _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input_dir.x + forward * -input_dir.z).normalized()


func _follow_camera(shepherd: Shepherd) -> void:
	if _camera and _camera_offset_cached:
		_camera.global_position = shepherd.global_position + _camera_offset

## Shepherd System.
## Reads WASD input, writes camera-relative movement into C_Velocity, rotates
## the shepherd to face its movement direction, and slides the main camera
## along with it. Movement integration happens in SheepVelocitySystem.
class_name ShepherdSystem
extends System

var _camera: Camera3D
var _camera_offset: Vector3
var _camera_offset_cached: bool = false


func query() -> QueryBuilder:
	return q.with_all([C_Shepherd, C_Velocity])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if entities.is_empty():
		return
	var entity := entities[0]
	var shepherd := (entity as Node) as Node3D
	if shepherd == null:
		return

	_ensure_camera(shepherd)

	var cfg := entity.get_component(C_Shepherd) as C_Shepherd
	var c_vel := entity.get_component(C_Velocity) as C_Velocity
	var move_dir := _camera_relative(_read_input_direction())

	if move_dir.length_squared() > 0.0:
		var speed := cfg.move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= cfg.sprint_multiplier
		c_vel.velocity = move_dir * speed
		SheepMath.face(shepherd, move_dir, cfg.rotation_speed, delta)
	else:
		c_vel.velocity = Vector3.ZERO

	_follow_camera(shepherd)


func _ensure_camera(shepherd: Node3D) -> void:
	if _camera and is_instance_valid(_camera):
		return
	_camera = shepherd.get_viewport().get_camera_3d()
	if _camera and not _camera_offset_cached:
		_camera_offset = _camera.global_position - shepherd.global_position
		_camera_offset_cached = true


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


func _follow_camera(shepherd: Node3D) -> void:
	if _camera and _camera_offset_cached:
		_camera.global_position = shepherd.global_position + _camera_offset

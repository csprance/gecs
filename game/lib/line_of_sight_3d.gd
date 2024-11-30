@tool
class_name LineOfSight3D
extends ComponentArea3D


@export_group("Cone Settings")
## The Line of Sight angle
@export var angle: float = 45:
	set(value):
		angle = value
		if debug:
			_create_cone_mesh()
			_update_collision_shape()
	get:
		return angle
## The Line of Sight distance
@export var distance: float = 5:
	set(value):
		distance = value
		if debug:
			_create_cone_mesh()
			_update_collision_shape()
	get:
		return distance

@export_group("Debug")
## Should we debug this LOS in game
@export var debug: bool = true:
	set(value):
		debug = value
		if cone_mesh_instance:
			cone_mesh_instance.visible = debug
@export var cone_color: Color = Color(1, 0, 0, 0.5)


@onready var collision_shape_3d: CollisionShape3D = %CollisionShape3D

var cone_mesh_instance: MeshInstance3D

var bodies = {}  # Dictionary to track bodies and their LOS status

func enter_check(_body_rid: RID, body, _body_shape_index: int, _local_shape_index: int) -> bool:
	if not body is Player:
		return false
	bodies[body] = false  # Start tracking the body with LOS status false
	return false  # We'll handle enter logic in _process

func exit_check(_body_rid: RID, body, _body_shape_index: int, _local_shape_index: int) -> bool:
	if body in bodies:
		if bodies[body]:
			_run_on_exit(body, body.get_rid(), 0, 0)
		bodies.erase(body)
	return true

func _ready() -> void:
	super._ready()
	if debug:
		_create_cone_mesh()
		_update_collision_shape()

func _process(delta: float) -> void:
	for body in bodies.keys():
		var is_in_los = _check_line_of_sight(body)
		var was_in_los = bodies[body]
		if is_in_los and not was_in_los:
			_run_on_enter(body, body.get_rid(), 0, 0)
			bodies[body] = true
		elif not is_in_los and was_in_los:
			_run_on_exit(body, body.get_rid(), 0, 0)
			bodies[body] = false

func _check_line_of_sight(body) -> bool:
	var direction = (body.global_position - global_position).normalized()
	var forward = global_transform.basis.z.normalized()
	var angle_check = Utils.angle_check(direction, forward, angle)
	var los_check = Utils.entity_has_los(parent, body)
	return angle_check and los_check

func _create_cone_mesh() -> void:
	if cone_mesh_instance:
		cone_mesh_instance.queue_free()
	cone_mesh_instance = MeshInstance3D.new()
	var mesh = _generate_cone_mesh()
	cone_mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = cone_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = StandardMaterial3D.CULL_DISABLED  # This makes it double-sided
	cone_mesh_instance.material_override = material
	add_child(cone_mesh_instance)

func _generate_cone_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var colors = PackedColorArray()
	
	vertices.push_back(Vector3.ZERO)
	colors.push_back(cone_color)
	
	var angle_radians = deg_to_rad(angle)
	var half_angle = angle_radians / 2.0
	var segments = 16
	var segment_angle = angle_radians / segments

	for i in range(segments + 1):
		var current_angle = -half_angle + i * segment_angle
		var x = distance * sin(current_angle)
		var z = distance * cos(current_angle)
		vertices.push_back(Vector3(x, 0, z))
		colors.push_back(cone_color)

	for i in range(1, segments + 1):
		indices.push_back(0)
		indices.push_back(i)
		indices.push_back(i + 1)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _update_collision_shape() -> void:
	if not collision_shape_3d:
		return
	# Create cylinder shape
	var shape = CylinderShape3D.new()
	
	# Calculate radius at the far end of the cone
	var radius = distance * tan(deg_to_rad(angle) / 2.0)
	
	# Set cylinder dimensions
	# Height is distance, radius is calculated from angle
	shape.height = 5.0
	shape.radius = distance
	
	# Update collision shape
	collision_shape_3d.shape = shape



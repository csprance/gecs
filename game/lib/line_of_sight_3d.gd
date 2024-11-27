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


func enter_check(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> bool:
	# Now we do angle check since we're already in the collision area
	var to_body = (body.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	var dot_product = forward.dot(to_body)
	var body_angle = rad_to_deg(acos(dot_product))
	
	return body_angle <= angle/2 and Utils.entity_has_los(parent, body)

func _ready() -> void:
	if debug:
		_create_cone_mesh()
		_update_collision_shape()


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
	# Create cylinder shape
	var shape = CylinderShape3D.new()
	
	# Calculate radius at the far end of the cone
	var radius = distance * tan(deg_to_rad(angle) / 2.0)
	
	# Set cylinder dimensions
	# Height is distance, radius is calculated from angle
	shape.height = distance
	shape.radius = radius
	
	# Update collision shape
	collision_shape_3d.shape = shape
	
	# Move cylinder to correct position (half distance forward since pivot is in center)
	collision_shape_3d.position = Vector3(0, 0, distance/2)
	# Rotate cylinder to lay flat
	collision_shape_3d.rotation_degrees = Vector3(-90, 0, 0)



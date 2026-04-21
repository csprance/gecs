class_name MultiMeshRendererSystem
extends System

@export var mesh: Mesh
@export var max_instances: int = 5000

var _multi_mesh: MultiMesh
var _multi_mesh_instance: MultiMeshInstance3D

func setup():
	safe_iteration = false
	process_empty = true

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.instance_count = max_instances
	_multi_mesh.visible_instance_count = 0
	_multi_mesh.mesh = mesh

	_multi_mesh_instance = MultiMeshInstance3D.new()
	_multi_mesh_instance.multimesh = _multi_mesh
	ECS.world.get_parent().add_child(_multi_mesh_instance)


func query() -> QueryBuilder:
	return q.with_all([C_Transform, C_Color]).iterate([C_Transform, C_Color])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var transforms = components[0]
	var colors = components[1]
	var count = entities.size()

	if count > _multi_mesh.instance_count:
		_multi_mesh.instance_count = count + 500

	_multi_mesh.visible_instance_count = count

	for i in count:
		var t: C_Transform = transforms[i]
		var c: C_Color = colors[i]
		if t:
			var xform = Transform3D()
			xform = xform.rotated(Vector3.RIGHT, t.rotation.x)
			xform = xform.rotated(Vector3.UP, t.rotation.y)
			xform = xform.rotated(Vector3.FORWARD, t.rotation.z)
			xform.origin = t.position
			_multi_mesh.set_instance_transform(i, xform)
		if c:
			_multi_mesh.set_instance_color(i, c.color)

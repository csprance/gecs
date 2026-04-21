## Reactive observer: fires exactly once, when a sheep gains C_Penned.
##
## Observers complement systems — a system polls every frame, an observer only
## runs in response to a specific event (here, a component being added). This
## keeps one-time visual reactions out of the per-frame movement hot path.
class_name PennedObserver
extends Observer


func watch() -> Resource:
	return C_Penned


func match() -> QueryBuilder:
	return q.with_all([C_Sheep])


func on_component_added(entity: Entity, _component: Resource) -> void:
	var mesh := entity.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.85, 0.4, 1.0)
	mesh.material_override = mat

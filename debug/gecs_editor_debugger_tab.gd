@tool
class_name GECSEditorDebuggerTab
extends Control

@onready var query_builder_check_box: CheckBox = %QueryBuilderCheckBox
@onready var update_data_check_box: CheckBox = %UpdateDataCheckBox
@onready var update_interval_spin_box: SpinBox = %UpdateIntervalSpinBox

var ecs_data: Dictionary = {}
var default_system := {"path": "", "active": true, "metrics": {}, "group": ""}
var default_entity := {"path": "", "active": true, "components": {}, "relationships": {}}
var timer = 5
var active := false

@onready var code_edit: CodeEdit = %CodeEdit


func _ready() -> void:
	update_interval_spin_box.value_changed.connect(_on_time_update_interval_changed)
	timer = update_interval_spin_box.value


func _on_time_update_interval_changed():
	timer = update_interval_spin_box.value


func _process(delta: float) -> void:
	if not active or not update_data_check_box.button_pressed:
		return
	timer -= delta
	if timer <= 0:
		timer = 5
		code_edit.text = JSON.stringify(ecs_data, "  ", true, true)


# Helper to retrieve or create nested dictionary entries
func get_or_create_dict(dict: Dictionary, key, default_val = {}) -> Dictionary:
	if not dict.has(key):
		dict[key] = default_val
	return dict[key]


func world_init(world: int, world_path: NodePath):
	var world_dict = get_or_create_dict(ecs_data, "world")
	world_dict["id"] = world
	world_dict["path"] = world_path


func set_world(world: int, world_path: NodePath):
	var world_dict = get_or_create_dict(ecs_data, "world")
	if not world:
		world_dict["id"] = null
		world_dict["path"] = null
		return
	world_dict["id"] = world
	world_dict["path"] = world_path


func process_world(delta: float, group_name: String):
	var world_dict := get_or_create_dict(ecs_data, "world")
	world_dict["delta"] = delta
	world_dict["active_group"] = group_name


func exit_world():
	ecs_data["exited"] = true


func entity_added(ent: int, path: NodePath) -> void:
	var entities := get_or_create_dict(ecs_data, "entities")
	# Create a fresh entity dictionary with only the necessary fields, not a duplicate of default_entity
	entities[ent] = {"path": path, "active": true, "components": {}, "relationships": {}}


func entity_removed(ent: int, path: NodePath) -> void:
	var entities := get_or_create_dict(ecs_data, "entities")
	entities.erase(ent)


func entity_disabled(ent: int, path: NodePath) -> void:
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent):
		entities[ent]["active"] = false


func entity_enabled(ent: int, path: NodePath) -> void:
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent):
		entities[ent]["active"] = true


func system_added(
	sys: int, group: String, process_empty: bool, active: bool, paused: bool, path: NodePath
) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data[sys] = default_system.duplicate()
	systems_data[sys]["path"] = path
	systems_data[sys]["group"] = group
	systems_data[sys]["process_empty"] = process_empty
	systems_data[sys]["active"] = active
	systems_data[sys]["paused"] = paused


func system_removed(sys: int, path: NodePath) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data.erase(sys)


func system_metric(system: int, system_name: String, time: float):
	var systems_data := get_or_create_dict(ecs_data, "systems")
	var sys_entry := get_or_create_dict(systems_data, system, default_system.duplicate())
	var sys_metrics = ecs_data["systems"][system]["metrics"]
	if not sys_metrics:
		# Initialize metrics if not present
		sys_metrics = {"min_time": time, "max_time": time, "avg_time": time, "count": 1}

	sys_metrics["min_time"] = min(sys_metrics["min_time"], time)
	sys_metrics["max_time"] = max(sys_metrics["max_time"], time)
	sys_metrics["count"] += 1
	sys_metrics["avg_time"] = (
		((sys_metrics["avg_time"] * (sys_metrics["count"] - 1)) + time) / sys_metrics["count"]
	)
	ecs_data["systems"][system]["metrics"] = sys_metrics


func entity_component_added(ent: int, comp: int, comp_path: String, data: Dictionary):
	var entities := get_or_create_dict(ecs_data, "entities")
	var entity := get_or_create_dict(entities, ent)
	if not entity.has("components"):
		entity["components"] = {}
	entity["components"][comp] = data


func entity_component_removed(
	ent: int,
	comp: int,
):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		entities[ent]["components"].erase(comp)


func entity_component_property_changed(
	ent: int, comp: int, property_name: String, old_value: Variant, new_value: Variant
):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		var component = entities[ent]["components"].get(comp)
		if component:
			component[property_name] = new_value


func entity_relationship_added(ent: int, rel: int):
	var entities := get_or_create_dict(ecs_data, "entities")
	# Don't use default_entity when creating/retrieving an entity
	var entity := get_or_create_dict(entities, ent)
	var relationships := get_or_create_dict(entity, "relationships")
	relationships[rel] = {"some_data": "value"}  # Placeholder for actual relationship data


func entity_relationship_removed(ent: int, rel: int):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("relationships"):
		entities[ent]["relationships"].erase(rel)

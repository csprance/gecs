class_name GECSEditorDebuggerMessages

## A mapping of all the messages sent to the editor debugger.
const Msg = {
	"WORLD_INIT": "gecs:world_init",
	"SYSTEM_METRIC": "gecs:system_metric",
	"SYSTEM_LAST_RUN_DATA": "gecs:system_last_run_data",
	"SET_WORLD": "gecs:set_world",
	"PROCESS_WORLD": "gecs:process_world",
	"EXIT_WORLD": "gecs:exit_world",
	"ENTITY_ADDED": "gecs:entity_added",
	"ENTITY_REMOVED": "gecs:entity_removed",
	"ENTITY_DISABLED": "gecs:entity_disabled",
	"ENTITY_ENABLED": "gecs:entity_enabled",
	"SYSTEM_ADDED": "gecs:system_added",
	"SYSTEM_REMOVED": "gecs:system_removed",
	"ENTITY_COMPONENT_ADDED": "gecs:entity_component_added",
	"ENTITY_COMPONENT_REMOVED": "gecs:entity_component_removed",
	"ENTITY_RELATIONSHIP_ADDED": "gecs:entity_relationship_added",
	"ENTITY_RELATIONSHIP_REMOVED": "gecs:entity_relationship_removed",
	"COMPONENT_PROPERTY_CHANGED": "gecs:component_property_changed",
	"POLL_ENTITY": "gecs:poll_entity",
	"SELECT_ENTITY": "gecs:select_entity",
}


## Helper function to check if we can send messages to the editor debugger.
static func can_send_message() -> bool:
	return not Engine.is_editor_hint() and OS.has_feature("editor")


static func world_init(world: World) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.WORLD_INIT, [world.get_instance_id(),
				 world.get_path()
			])
	return true

static func system_metric(system: System, time: float) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.SYSTEM_METRIC, [system.get_instance_id(),
					 system.name,
					 time
				]
		)
	return true

static func system_last_run_data(system: System, last_run_data: Dictionary) -> bool:
	if can_send_message():
		# Send trimmed data to avoid excessive payload; include execution time and entity count primarily
		EngineDebugger.send_message(
			Msg.SYSTEM_LAST_RUN_DATA,
			[
				system.get_instance_id(),
				system.name,
				last_run_data.duplicate() # duplicate so caller's dictionary isn't mutated
			]
		)
	return true

static func set_world(world: World) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.SET_WORLD,
			[world.get_instance_id(),
					 world.get_path()
				]
			if world else []
	)
	return true

static func process_world(delta: float, group_name: String) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.PROCESS_WORLD, [delta, group_name])
	return true


static func exit_world() -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.EXIT_WORLD, [])
	return true

static func entity_added(ent: Entity, in_tree: bool = true) -> bool:
	if can_send_message():
		var path = ent.get_path() if in_tree else str(ent)
		EngineDebugger.send_message(Msg.ENTITY_ADDED, [ent.get_instance_id(), path])
	return true

static func entity_removed(ent_id: String) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.ENTITY_REMOVED, [ent_id])
	return true

static func entity_disabled(ent: Entity) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.ENTITY_DISABLED, [ent.get_instance_id(), ent.get_path()])
	return true

static func entity_enabled(ent: Entity) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.ENTITY_ENABLED, [ent.get_instance_id(), ent.get_path()])
	return true

static func system_added(sys: System) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.SYSTEM_ADDED,
			[
				sys.get_instance_id(),
				sys.group,
				sys.process_empty,
				sys.active,
				sys.paused,
				sys.get_path()
			]
		)
	return true

static func system_removed(sys: System) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.SYSTEM_REMOVED, [sys.get_instance_id(), sys.get_path()])
	return true

static func _get_type_name_for_debugger(obj) -> String:
	if obj == null:
		return "null"
	if obj is Resource or obj is Node:
		var script = obj.get_script()
		if script:
			# Try to get class_name first
			var type_name = script.get_class()
			if type_name and type_name != "GDScript":
				return type_name
			# Otherwise use the resource path (e.g., "res://components/C_Health.gd")
			if script.resource_path:
				return script.resource_path # Returns "C_Health"
		return obj.get_class()
	elif obj is Object:
		return obj.get_class()
	return str(typeof(obj))


static func entity_component_added(ent: Entity, comp: Resource) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.ENTITY_COMPONENT_ADDED,
			[
				ent.get_instance_id(),
				comp.get_instance_id(),
				_get_type_name_for_debugger(comp),
				comp.serialize()
			]
		)
	return true

static func entity_component_removed(ent: Entity, comp: Resource) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.ENTITY_COMPONENT_REMOVED, [ent.get_instance_id(),
					 comp.get_instance_id()
				]
		)
	return true

static func entity_component_property_changed(
	ent: Entity, comp: Resource, property_name: String, old_value: Variant, new_value: Variant
) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.COMPONENT_PROPERTY_CHANGED,
			[ent.get_instance_id(),
					 comp.get_instance_id(),
					 property_name,
					 old_value,
					 new_value
				]
		)
	return true

static func entity_relationship_added(ent: Entity, rel: Relationship) -> bool:
	if can_send_message():
		# Serialize relationship data for debugger display
		var rel_data = {
			"relation_type": _get_type_name_for_debugger(rel.relation) if rel.relation else "null",
			"relation_data": rel.relation.serialize() if rel.relation else {},
			"target_type": "",
			"target_data": {}
		}

		# Format target based on type
		if rel.target == null:
			rel_data["target_type"] = "null"
		elif rel.target is Entity:
			rel_data["target_type"] = "Entity"
			rel_data["target_data"] = {
				"id": rel.target.get_instance_id(),
				"path": str(rel.target.get_path())
			}
		elif rel.target is Component:
			rel_data["target_type"] = "Component"
			rel_data["target_data"] = {
				"type": _get_type_name_for_debugger(rel.target),
				"data": rel.target.serialize()
			}
		elif rel.target is Script:
			rel_data["target_type"] = "Archetype"
			rel_data["target_data"] = {
				"script_path": rel.target.resource_path
			}

		EngineDebugger.send_message(
			Msg.ENTITY_RELATIONSHIP_ADDED,
			[ent.get_instance_id(),
					 rel.get_instance_id(),
					 rel_data
				]
		)
	return true

static func entity_relationship_removed(ent: Entity, rel: Relationship) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.ENTITY_RELATIONSHIP_REMOVED, [ent.get_instance_id(),
					 rel.get_instance_id()
				]
		)
	return true

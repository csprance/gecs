class_name GECSEditorDebuggerMessages

## A mapping of all the messages sent to the editor debugger.
const Msg = {
	"WORLD_INIT": "gecs:world_init",
	"SYSTEM_METRIC": "gecs:system_metric",
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
}


## Helper function to check if we can send messages to the editor debugger.
static func can_send_message() -> bool:
	return not Engine.is_editor_hint() and OS.has_feature("editor")


static func world_init(world: World) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.WORLD_INIT, [world.get_instance_id(), world.get_path()])
	return true

static func system_metric(system: System, time: float) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.SYSTEM_METRIC, [system.get_instance_id(), system.name, time]
		)
	return true

static func set_world(world: World) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.SET_WORLD, [world.get_instance_id(), world.get_path()] if world else []
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

static func entity_added(ent: Entity) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.ENTITY_ADDED, [ent.get_instance_id(), ent.get_path()])
	return true

static func entity_removed(ent: Entity) -> bool:
	if can_send_message():
		EngineDebugger.send_message(Msg.ENTITY_REMOVED, [ent.get_instance_id(), ent.get_path()])
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
			return script.get_class()
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
			Msg.ENTITY_COMPONENT_REMOVED, [ent.get_instance_id(), comp.get_instance_id()]
		)
	return true

static func entity_component_property_changed(
	ent: Entity, comp: Resource, property_name: String, old_value: Variant, new_value: Variant
) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.COMPONENT_PROPERTY_CHANGED,
			[ent.get_instance_id(), comp.get_instance_id(), property_name, old_value, new_value]
		)
	return true

static func entity_relationship_added(ent: Entity, rel: Relationship) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.ENTITY_RELATIONSHIP_ADDED, [ent.get_instance_id(), rel.get_instance_id()]
		)
	return true

static func entity_relationship_removed(ent: Entity, rel: Relationship) -> bool:
	if can_send_message():
		EngineDebugger.send_message(
			Msg.ENTITY_RELATIONSHIP_REMOVED, [ent.get_instance_id(), rel.get_instance_id()]
		)
	return true
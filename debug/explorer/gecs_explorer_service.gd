class_name GECSExplorerService
extends RefCounted
## Per-world runtime endpoint. Commands are serviced between ECS calls, never in a batch.
signal response(payload: Dictionary)
signal changed(event: Dictionary)

const Snapshot = preload("res://addons/gecs/debug/explorer/gecs_explorer_snapshot.gd")
const VERSION := 1
const PAGE_SIZE := 100
const MAX_WATCHES := 64
const MAX_INCOMING_RELATIONSHIPS := 256
const MAX_PAYLOAD_BYTES := 8388608
const Codec = preload("res://addons/gecs/debug/explorer/gecs_explorer_codec.gd")

var world: World
var epoch := 1
var watches: Dictionary = {}
var run: Dictionary = {}
var _pending: Array = []
var _pumping := false
var _last_sample := 0
var _sequence := 0
var _watch_sequence := 0
var _notified: Dictionary = {}
var _restore_plan: Array = []
var _restore_snapshot: Dictionary = {}
var _restore_token := 0

func _init(owner: World) -> void:
	world = owner
	world.step_completed.connect(_after_step)

func identity(entity: Entity) -> Dictionary:
	return {"world": world.get_instance_id(), "epoch": epoch, "id": entity.id, "iid": entity.get_instance_id()}

func resolve(ref: Dictionary) -> Entity:
	if ref.get("world", 0) != world.get_instance_id() or ref.get("epoch", 0) != epoch:
		return null
	var entity := world.get_entity_by_id(int(ref.get("id", 0)))
	if not is_instance_valid(entity) or entity.get_instance_id() != int(ref.get("iid", 0)):
		return null
	return entity

func reset() -> void:
	_restore_plan.clear()
	_restore_snapshot.clear()
	_restore_token += 1
	epoch += 1
	watches.clear()
	run.clear()
	_pending.clear()

func handle_request(request: Dictionary) -> void:
	if int(request.get("version", 0)) != VERSION:
		_reply(request, {"error": "Unsupported explorer protocol"})
		return
	if request.get("op") == "hello":
		_reply(request, {"step_state": world.debug_stepper().state(), "catalogue": catalogue(), "world_path": str(world.get_path()) if world.is_inside_tree() else world.name})
		return
	if request.get("world", 0) != world.get_instance_id() or request.get("epoch", 0) != epoch:
		_reply(request, {"error": "World changed; reconnect before issuing commands"})
		return
	if _pending.size() >= 128:
		_reply(request, {"error": "Explorer request queue is full"})
		return
	_pending.append(request.duplicate(true))

func pump() -> void:
	if _pumping:
		return
	_pumping = true
	var pending := _pending
	_pending = []
	for request in pending:
		if request.get("epoch") != epoch:
			_reply(request, {"error": "World changed"})
			continue
		var args: Dictionary = request.get("args", {})
		var result: Dictionary
		match str(request.get("op", "")):
			"overview": result = overview(args)
			"_continue_run":
				if not run.is_empty(): world.debug_step(run.kind)
				continue
			"inspect": result = inspect(args.get("entity", {}))
			"resolve_saved": result = resolve_saved(args)
			"query": result = query(args)
			"apply": result = apply(args)
			"scratchpad": result = scratchpad(args)
			"watch": result = set_watch(args)
			"unwatch":
				watches.erase(str(args.get("key", "")))
				result = {}
			"snapshot_export": result = Snapshot.dump(self)
			"snapshot_preview": result = preview_restore(args.get("snapshot", {}))
			"snapshot_restore": result = restore_snapshot(int(args.get("token", -1)))
			"capture": result = capture(args)
			"run_until": result = run_until(args)
			"cancel_run":
				_stop_run("Cancelled")
				result = {}
			"breakpoint":
				var id := world.debug_add_breakpoint(args)
				result = {"id": id, "error": "" if id else "Invalid condition"}
			_: result = {"error": "Unknown explorer operation"}
		_reply(request, result)
	if not watches.is_empty() and Time.get_ticks_msec() - _last_sample >= 100 and not world.debug_is_paused():
		sample()
	_pumping = false

func _reply(request: Dictionary, result: Dictionary) -> void:
	if var_to_bytes(result).size() > MAX_PAYLOAD_BYTES:
		result = {"error": "Explorer payload exceeds 8 MiB; narrow the query or capture"}
	var payload := {"version": VERSION, "request_id": request.get("request_id", 0), "op": request.get("op", ""), "world": world.get_instance_id(), "epoch": epoch, "result": result}
	response.emit(payload)
	if GECSEditorDebuggerMessages.can_send_message():
		GECSEditorDebuggerMessages._send("gecs:explorer_response", [payload])

func _event(kind: String, data: Dictionary) -> void:
	_sequence += 1
	var event := {"version": VERSION, "world": world.get_instance_id(), "epoch": epoch, "sequence": _sequence, "kind": kind, "data": data}
	changed.emit(event)
	if GECSEditorDebuggerMessages.can_send_message():
		GECSEditorDebuggerMessages._send("gecs:explorer_event", [event])

func summary(entity: Entity) -> Dictionary:
	var component_names: Array = []
	for comp in entity.components.values():
		if is_instance_valid(comp): component_names.append(GECSStepper.type_name_of(comp))
	var relation_names: Array = []
	for rel in entity.relationships:
		if not is_instance_valid(rel): continue
		var target_name := str(rel.target.name) if rel.target is Entity and is_instance_valid(rel.target) else str(rel.target)
		relation_names.append(GECSStepper.type_name_of(rel.relation) + " → " + target_name)
	return {"component_names": component_names, "relationship_names": relation_names, "identity": identity(entity), "name": str(entity.name), "alias": str(entity.alias), "path": str(entity.get_path()) if entity.is_inside_tree() else "", "script": entity.get_script().resource_path if entity.get_script() else "", "enabled": entity.enabled}

func inspect(ref: Dictionary, include_incoming := true) -> Dictionary:
	var entity := resolve(ref)
	if entity == null:
		return {"error": "Entity no longer exists in this world"}
	var result := summary(entity)
	var components: Array = []
	for comp in entity.components.values():
		if not is_instance_valid(comp):
			continue
		var fields: Array = []
		for prop in comp.get_property_list():
			if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.name in ["parent", "script"]:
				continue
			var field: Dictionary = prop.duplicate()
			field["exported"] = bool(prop.usage & PROPERTY_USAGE_EDITOR)
			field["value"] = Codec.encode(comp.get(prop.name))
			field["writable"] = field.value.editable and not bool(prop.usage & PROPERTY_USAGE_READ_ONLY)
			fields.append(field)
		components.append({"iid": comp.get_instance_id(), "script": comp.get_script().resource_path, "name": GECSStepper.type_name_of(comp), "fields": fields})
	result["components"] = components
	var relationships: Array = []
	for rel in entity.relationships:
		if not is_instance_valid(rel):
			continue
		var target: Dictionary = identity(rel.target) if rel.target is Entity and is_instance_valid(rel.target) and rel.target._world == world else {}
		relationships.append({"iid": rel.get_instance_id(), "relation": GECSStepper.type_name_of(rel.relation), "target": target, "label": str(rel.target.name) if rel.target is Entity and is_instance_valid(rel.target) else str(rel.target), "data": Codec.encode(rel.relation.serialize() if rel.relation is Component else null)})
	result["relationships"] = relationships
	if include_incoming: result.merge(incoming_relationships(entity))
	return result

## Reverse links are derived from relationship-bearing archetypes, not stored
## on the target. Disabled sources count too. No index or idle polling is added.
func incoming_relationships(target: Entity) -> Dictionary:
	var rows: Array = []
	var suffix := "::entity#" + str(target.id)
	for archetype: Archetype in world.archetypes.values():
		if archetype.entities.is_empty(): continue
		var matches := false
		for key: String in archetype.relationship_types:
			if key.ends_with(suffix):
				matches = true
				break
		if not matches: continue
		for source in archetype.entities:
			if not is_instance_valid(source) or source._world != world: continue
			for relation in source.relationships:
				if not is_instance_valid(relation) or typeof(relation.target) != TYPE_OBJECT or not is_instance_valid(relation.target) or relation.target != target: continue
				if rows.size() == MAX_INCOMING_RELATIONSHIPS:
					return {"incoming_relationships": rows, "incoming_truncated": true}
				rows.append({"iid": relation.get_instance_id(), "relation": GECSStepper.type_name_of(relation.relation), "source": identity(source), "source_label": str(source.name), "source_enabled": source.enabled})
	return {"incoming_relationships": rows, "incoming_truncated": false}

func catalogue() -> Array:
	var entries := ProjectSettings.get_global_class_list()
	var bases := {"Component": true}
	for _pass in 16:
		for entry in entries:
			if bases.has(entry.base): bases[entry.class] = true
	var result: Array = []
	for entry in entries:
		if entry.class != "Component" and bases.has(entry.class):
			result.append({"name": entry.class, "path": entry.path})
	return result

func component_script(path: String) -> Script:
	var script := world._debug_class_script(path)
	var base: Script = script
	while base != null:
		if base.resource_path == "res://addons/gecs/ecs/component.gd": return script
		base = base.get_base_script()
	return null

func _expression(text: String) -> Dictionary:
	var names := PackedStringArray(["q", "world", "ECS"])
	var values: Array = [world.query, world, ECS]
	var identifiers := RegEx.new()
	identifiers.compile("[A-Za-z_][A-Za-z0-9_]*")
	var seen := {"q": true, "world": true, "ECS": true}
	var paths: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list(): paths[entry.class] = entry.path
	for found in identifiers.search_all(text):
		var name := found.get_string()
		if paths.has(name) and not seen.has(name):
			seen[name] = true
			names.append(name)
			values.append(load(paths[name]))
	var expression := Expression.new()
	if expression.parse(text, names) != OK: return {"error": expression.get_error_text()}
	var value: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed(): return {"error": expression.get_error_text()}
	return {"value": value}

func build_query(spec: Dictionary) -> Dictionary:
	var builder := world.query
	var grouped := {"all": {}, "any": {}, "none": {}}
	for key in grouped:
		for path in spec.get(key, []):
			var script := component_script(str(path))
			if script == null: return {"error": "Unknown component: " + str(path)}
			grouped[key][script] = {}
	for term in spec.get("properties", []):
		var group := str(term.get("group", "all"))
		if not group in ["all", "any"]: return {"error": "Property filters require All or Any; None excludes component types"}
		var script := component_script(str(term.get("component", "")))
		if script == null or not str(term.get("op", "_eq")) in ["_eq", "_ne", "_gt", "_gte", "_lt", "_lte"]:
			return {"error": "Invalid property query"}
		if not grouped[group].has(script): grouped[group][script] = {}
		var property := str(term.get("property", ""))
		var valid_property := false
		for prop in script.get_script_property_list():
			if prop.name == property and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: valid_property = true
		if not valid_property or not Codec.valid(term.get("value", {})): return {"error": "Invalid query property or value"}
		if not grouped[group][script].has(property): grouped[group][script][property] = {}
		grouped[group][script][property][str(term.get("op", "_eq"))] = Codec.decode(term.value)
	for group in grouped:
		var terms: Array = []
		for script in grouped[group]: terms.append({script: grouped[group][script]} if not grouped[group][script].is_empty() else script)
		match group:
			"all": builder.with_all(terms)
			"any": builder.with_any(terms)
			"none": builder.with_none(terms)
	var groups: Array[String] = []
	for group in spec.get("groups", []): groups.append(str(group))
	if not groups.is_empty(): builder.with_group(groups)
	match spec.get("enabled", "any"):
		"enabled": builder.enabled()
		"disabled": builder.disabled()
	var relationships: Array = []
	for term in spec.get("relationships", []):
		var script := component_script(str(term.get("component", "")))
		if script == null: return {"error": "Unknown relationship component"}
		var target: Variant = null
		if not term.get("target", {}).is_empty():
			target = resolve(term.target)
			if target == null: return {"error": "Relationship target no longer exists"}
		for method in script.get_script_method_list():
			if method.name == "_init" and method.args.size() > method.default_args.size(): return {"error": "Relationship constructor needs arguments; use a one-shot query"}
		relationships.append(Relationship.new(script.new(), target))
	if not relationships.is_empty(): builder.with_relationship(relationships)
	return {"value": builder}

func query(args: Dictionary) -> Dictionary:
	var evaluated: Dictionary = build_query(args.spec) if args.has("spec") else _expression(str(args.get("text", "")))
	if evaluated.has("error"): return evaluated
	var value: Variant = evaluated.value
	if value is QueryBuilder: value = value.execute()
	if not value is Array: return {"error": "Query must return a QueryBuilder or an Array of entities", "value": Codec.encode(value)}
	var found: Array = []
	var ids: Array = []
	var filter_text := str(args.get("filter", "")).to_lower()
	for entity in value:
		if not entity is Entity or not is_instance_valid(entity) or entity._world != world: continue
		if not filter_text.is_empty() and not str(entity.name).to_lower().contains(filter_text): continue
		ids.append(entity.get_instance_id())
		found.append(entity)
	var sort_name := str(args.get("sort", "name"))
	found.sort_custom(func(a: Entity, b: Entity):
		var av: Variant = str(a.name) if sort_name == "name" else _column_value(a, sort_name)
		var bv: Variant = str(b.name) if sort_name == "name" else _column_value(b, sort_name)
		var less: bool = av < bv if typeof(av) == typeof(bv) and typeof(av) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING] else str(av) < str(bv)
		return not less and av != bv if args.get("descending", false) else less
	)
	var rows: Array = []
	var offset := maxi(0, int(args.get("page", 0))) * PAGE_SIZE
	for entity in found.slice(offset, offset + PAGE_SIZE):
		var row := summary(entity)
		row["values"] = {}
		for column in args.get("columns", []).slice(0, 16): row.values[column] = Codec.encode(_column_value(entity, column))
		rows.append(row)
	return {"rows": rows, "total": found.size(), "page": offset / PAGE_SIZE, "ids": ids.slice(0, 10000)}

func _column_value(entity: Entity, column: String) -> Variant:
	var split := column.rfind(":")
	if split < 0: return null
	var script := component_script(column.left(split))
	if script == null: return null
	var comp: Variant = entity.components.get(script.get_instance_id())
	return comp.get(column.substr(split + 1)) if comp != null else null

func _component(entity: Entity, iid: int) -> Component:
	for comp in entity.components.values():
		if is_instance_valid(comp) and comp.get_instance_id() == iid: return comp
	return null

func _validate(entity: Entity, operation: Dictionary, force := false) -> String:
	match str(operation.get("op", "")):
		"set":
			var comp := _component(entity, int(operation.get("component", 0)))
			if comp == null: return "Component was removed or replaced"
			for prop in comp.get_property_list():
				if prop.name != operation.get("property"): continue
				if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_READ_ONLY or prop.name in ["parent", "script"]: return "Read-only property"
				var encoded: Dictionary = operation.get("value", {})
				var current := Codec.encode(comp.get(prop.name))
				if not Codec.valid(encoded) or not current.editable: return "Unsupported editable value"
				if prop.type != TYPE_NIL and typeof(Codec.decode(encoded)) != prop.type: return "Property type mismatch"
				var original: Variant = comp.get(prop.name)
				var replacement: Variant = Codec.decode(encoded)
				if original is Array and original.is_typed() and (not replacement.is_typed() or not original.is_same_typed(replacement)): return "Typed array schema mismatch"
				if original is Dictionary and original.is_typed() and (not replacement.is_typed() or not original.is_same_typed(replacement)): return "Typed dictionary schema mismatch"
				if not force and not Codec.equal(current, operation.get("expected", {})): return "Conflict: value changed since editing began"
				return ""
			return "Property no longer exists"
		"remove_component":
			return "" if _component(entity, int(operation.get("component", 0))) != null else "Component no longer exists"
		"add_component", "add_relationship":
			var script := component_script(str(operation.get("script", "")))
			if script == null: return "Unknown component script"
			for method in script.get_script_method_list():
				if method.name == "_init" and method.args.size() > method.default_args.size(): return "Constructor requires arguments; use Scratchpad"
			if operation.op == "add_component" and entity.components.has(script.get_instance_id()): return "Entity already has this component"
			if operation.op == "add_relationship" and not operation.get("target", {}).is_empty() and resolve(operation.target) == null: return "Relationship target no longer exists"
		"remove_relationship":
			for rel in entity.relationships:
				if rel.get_instance_id() == int(operation.get("relationship", 0)): return ""
			return "Relationship no longer exists"
		"enabled":
			if not force and operation.get("expected") != entity.enabled: return "Conflict: enabled state changed"
		_: return "Unknown edit operation"
	return ""

func apply(args: Dictionary) -> Dictionary:
	var entity := resolve(args.get("entity", {}))
	if entity == null: return {"error": "Stale entity identity"}
	var operations: Array = args.get("operations", [])
	if operations.size() > 128: return {"error": "Too many edits in one request"}
	if args.has("step") and not world.debug_is_paused(): return {"error": "Pause ECS before Apply & Step"}
	for operation in operations:
		var error := _validate(entity, operation, bool(args.get("force", false)))
		if error != "": return {"error": error, "applied": 0, "snapshot": inspect(args.entity)}
	var before := inspect(args.entity)
	var stepper := world.debug_stepper()
	var hook_before := world._step_hooks_active
	world._step_hooks_active = true
	stepper.push_cause("editor")
	var applied := 0
	var outcomes: Array = []
	var error := ""
	for operation in operations:
		entity = resolve(args.entity)
		if entity == null:
			error = "An earlier edit removed the entity"
			break
		error = _validate(entity, operation, bool(args.get("force", false)))
		if error != "": break
		match str(operation.op):
			"set":
				var comp := _component(entity, int(operation.component))
				var property := str(operation.property)
				var old: Variant = comp.get(property)
				var seen := [false]
				var tracker := func(_comp: Resource, name: String, _old: Variant, _new: Variant):
					if name == property: seen[0] = true
				comp.property_changed.connect(tracker)
				comp.set(property, Codec.decode(operation.value))
				if is_instance_valid(comp):
					comp.property_changed.disconnect(tracker)
					if not seen[0] and comp.get(property) != old and resolve(args.entity) != null and _component(entity, int(operation.component)) == comp:
						comp.property_changed.emit(comp, property, old, comp.get(property))
			"add_component": entity.add_component(component_script(operation.script).new())
			"remove_component": entity.remove_component(_component(entity, int(operation.component)))
			"enabled": entity.enabled = bool(operation.value)
			"add_relationship": entity.add_relationship(Relationship.new(component_script(operation.script).new(), resolve(operation.target) if not operation.get("target", {}).is_empty() else null))
			"remove_relationship":
				for rel in entity.relationships.duplicate():
					if rel.get_instance_id() == int(operation.relationship): entity.remove_relationship(rel)
		outcomes.append({"index": applied, "status": "applied"})
		applied += 1
	if error != "": outcomes.append({"index": applied, "status": "failed", "error": error})
	for index in range(applied + (1 if error != "" else 0), operations.size()): outcomes.append({"index": index, "status": "unapplied"})
	stepper.pop_cause()
	world._step_hooks_active = hook_before
	stepper._sweep.commit_noted()
	var after := inspect(args.entity)
	_event("edit", {"actor": "editor", "before": before, "after": after, "applied": applied, "error": error})
	sample()
	if error == "" and args.has("step"): world.debug_step(int(args.step))
	return {"applied": applied, "outcomes": outcomes, "error": error, "snapshot": after}

func scratchpad(args: Dictionary) -> Dictionary:
	var source := str(args.get("source", ""))
	if source.length() > 65536: return {"error": "Snippet is too large"}
	var entity := resolve(args.get("entity", {}))
	var selection: Array = []
	for ref in args.get("selection", []):
		var selected := resolve(ref)
		if selected != null: selection.append(selected)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nfunc execute(world, entity, selection):\n\tvar q = world.query\n"
	for line in source.split("\n"): script.source_code += "\t" + line + "\n"
	if script.reload() != OK: return {"error": "GDScript compilation failed. See Godot Errors for the source location."}
	var context: RefCounted = script.new()
	var stepper := world.debug_stepper()
	var hooks := world._step_hooks_active
	world._step_hooks_active = true
	stepper.push_cause("scratchpad")
	var result: Variant = context.call("execute", world, entity, selection)
	stepper.pop_cause()
	world._step_hooks_active = hooks
	_event("scratchpad", {"actor": "scratchpad", "result": Codec.encode(result)})
	sample()
	return {"value": Codec.encode(result)}

func set_watch(args: Dictionary) -> Dictionary:
	var key := str(args.get("key", ""))
	if key.is_empty(): return {"error": "Watch needs a key"}
	if not watches.has(key) and watches.size() >= MAX_WATCHES: return {"error": "Maximum 64 active watches"}
	if args.has("spec"):
		var built := build_query(args.spec)
		if built.has("error"): return built
	elif resolve(args.get("entity", {})) == null: return {"error": "Stale entity identity"}
	watches[key] = args.duplicate(true)
	sample()
	return {"key": key}

func sample() -> void:
	if watches.is_empty(): return
	_last_sample = Time.get_ticks_msec()
	_watch_sequence += 1
	var values: Dictionary = {}
	var bytes := 0
	for key in watches:
		var watch: Dictionary = watches[key]
		var value := query({"spec": watch.spec}) if watch.has("spec") else inspect(watch.get("entity", {}))
		bytes += var_to_bytes(value).size()
		values[key] = value if bytes <= MAX_PAYLOAD_BYTES / 2 else {"error": "Sample budget exceeded; reduce active watches"}
	_event("sample", {"samples": values, "time": _last_sample, "step": world.debug_stepper().step_counter, "sample": _watch_sequence})

func capture(args: Dictionary) -> Dictionary:
	var entities: Dictionary = {}
	var memberships: Dictionary = {}
	for ref in args.get("entities", []):
		var entity := resolve(ref)
		if entity != null: entities[str(entity.id)] = inspect(ref)
	for key in watches:
		var watch: Dictionary = watches[key]
		if watch.has("spec"):
			var built := build_query(watch.spec)
			if built.has("error"): continue
			var ids: Array = []
			for entity in built.value.execute():
				if entities.size() >= 1000: return {"error": "Capture exceeds 1000 entities; narrow the query"}
				entities[str(entity.id)] = inspect(identity(entity))
				ids.append(entity.id)
			memberships[key] = ids
		else:
			var entity := resolve(watch.get("entity", {}))
			if entity != null: entities[str(entity.id)] = inspect(identity(entity))
	var result := {"entities": entities, "memberships": memberships, "step": world.debug_stepper().step_counter, "time": Time.get_ticks_msec()}
	return {"error": "Capture exceeds limits; narrow the investigation"} if entities.size() > 1000 or var_to_bytes(result).size() > MAX_PAYLOAD_BYTES else result

func condition_value(condition: Dictionary) -> Dictionary:
	if condition.get("kind") == "query":
		if not str(condition.get("op", "")) in ["nonempty", "empty", "entered", "left"]: return {"error": "Invalid query condition"}
		var built := build_query(condition.get("spec", {}))
		if built.has("error"): return built
		var ids: Array = []
		for entity in built.value.execute(): ids.append(entity.id)
		ids.sort()
		return {"value": ids}
	if condition.get("kind") != "property" or not str(condition.get("op", "changed")) in ["changed", "eq", "neq", "gt", "gte", "lt", "lte"]: return {"error": "Invalid property condition"}
	if condition.get("op", "changed") != "changed" and not Codec.valid(condition.get("value", {})): return {"error": "Invalid comparison value"}
	var entity := resolve(condition.get("entity", {}))
	if entity == null: return {"error": "Condition entity no longer exists"}
	var comp := _component(entity, int(condition.get("component", 0)))
	if comp == null: return {"error": "Condition component no longer exists"}
	for prop in comp.get_property_list():
		if prop.name == condition.get("property") and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = comp.get(prop.name)
			if Codec.supported(value): return {"value": value}
	return {"error": "Unsupported condition property"}

func condition_matches(condition: Dictionary, current: Variant, previous: Variant) -> bool:
	var op := str(condition.get("op", "changed"))
	if condition.get("kind") == "query":
		match op:
			"nonempty": return not current.is_empty()
			"empty": return current.is_empty()
			"entered": return previous != null and current.any(func(id): return not previous.has(id))
			"left": return previous != null and previous.any(func(id): return not current.has(id))
		return false
	var expected: Variant = Codec.decode(condition.get("value", {}))
	match op:
		"changed": return previous != null and current != previous
		"eq": return current == expected
		"neq": return current != expected
		"gt", "gte", "lt", "lte":
			if not typeof(current) in [TYPE_INT, TYPE_FLOAT] or not typeof(expected) in [TYPE_INT, TYPE_FLOAT]: return false
			match op:
				"gt": return current > expected
				"gte": return current >= expected
				"lt": return current < expected
				"lte": return current <= expected
	return false

func run_until(args: Dictionary) -> Dictionary:
	if not run.is_empty(): return {"error": "Cancel the current Run Until first"}
	if not world.debug_stepper()._requests.is_empty(): return {"error": "Wait for the current step to finish"}
	var condition: Dictionary = args.get("condition", {})
	var initial := condition_value(condition)
	if initial.has("error"): return initial
	world.debug_pause()
	if condition_matches(condition, initial.value, null):
		_event("run", {"reason": "Condition already satisfied"})
		return {"reason": "Condition already satisfied"}
	run = {"condition": condition.duplicate(true), "previous": initial.value, "remaining": clampi(int(args.get("limit", 1000)), 1, 100000), "kind": clampi(int(args.get("kind", 2)), 0, 4), "count": 0}
	world.debug_step(run.kind)
	return {"running": true}

func _stop_run(reason: String) -> void:
	if run.is_empty(): return
	var count: int = run.count
	run.clear()
	if not world.debug_stepper()._servicing: world.debug_stepper()._requests.clear()
	_event("run", {"reason": reason, "count": count})

func _after_step(_kind: int, log: Dictionary) -> void:
	sample()
	if run.is_empty(): return
	run.count += 1
	run.remaining -= 1
	var current := condition_value(run.condition)
	if current.has("error"):
		_stop_run(current.error)
	elif run.has("failure"):
		_stop_run(run.failure)
	elif run.get("satisfied", false):
		_stop_run("Condition satisfied")
	elif not log.get("break_info", {}).is_empty():
		_stop_run("Breakpoint hit")
	elif condition_matches(run.condition, current.value, run.previous):
		_stop_run("Condition satisfied")
	elif run.remaining <= 0:
		_stop_run("Step limit reached")
	else:
		run.previous = current.value
		# Defer queuing to the next process call so Cancel remains responsive.
		_pending.append({"version": VERSION, "world": world.get_instance_id(), "epoch": epoch, "op": "_continue_run", "request_id": 0})

## Explicit stable rebinding, without a world-wide scan or previous session IDs.
func resolve_saved(args: Dictionary) -> Dictionary:
	var rows: Array = []
	for definition in args.get("definitions", []).slice(0, MAX_WATCHES):
		var entity: Entity
		if str(definition.get("alias", "")) != "":
			entity = world.get_entity_by_alias(StringName(definition.alias))
		elif world.is_inside_tree() and str(definition.get("path", "")) != "":
			entity = world.get_node_or_null(NodePath(definition.path)) as Entity
		if is_instance_valid(entity) and entity._world == world and (definition.get("script", "") == "" or entity.get_script().resource_path == definition.script):
			rows.append({"definition": definition, "entity": summary(entity)})
		else: rows.append({"definition": definition, "error": "Saved alias or node path is unresolved"})
	return {"rows": rows}

## Called at the same safe boundaries as ordinary conditional breakpoints.
func check_run_boundary() -> void:
	if run.is_empty() or run.get("satisfied", false): return
	var current := condition_value(run.condition)
	if current.has("error"):
		run["failure"] = current.error
	elif condition_matches(run.condition, current.value, run.previous):
		run["satisfied"] = true
	else:
		run.previous = current.value.duplicate(true) if current.value is Array or current.value is Dictionary else current.value
		return
	var stepper := world.debug_stepper()
	if not stepper.break_requested:
		stepper.break_requested = true
		stepper._break_info = {"label": current.get("error", "Run Until condition"), "op": "run_until"}

## Explicit dashboard request only. Reads membership and cached timings, never
## serializes component properties or enables additional runtime instrumentation.
func overview(args: Dictionary = {}) -> Dictionary:
	var limit := clampi(int(args.get("limit", 12)), 1, 48)
	var started := Time.get_ticks_usec()
	var component_counts := {}
	var component_total := 0
	var occupied := 0
	for archetype: Archetype in world.archetypes.values():
		var count := archetype.entities.size()
		if count == 0: continue
		occupied += 1
		for key in archetype.columns:
			component_counts[key] = int(component_counts.get(key, 0)) + count
			component_total += count
	var component_rows: Array = []
	for key in component_counts:
		var script := instance_from_id(int(key)) as Script
		if script != null:
			component_rows.append({"name": script.get_global_name() if script.get_global_name() != "" else script.resource_path.get_file().get_basename(), "script": script.resource_path, "count": component_counts[key]})
	var enabled := 0
	var relationships := 0
	var relation_counts := {}
	for entity in world.entities:
		if not is_instance_valid(entity): continue
		if entity.enabled: enabled += 1
		for relation in entity.relationships:
			if not is_instance_valid(relation): continue
			relationships += 1
			var label := GECSStepper.type_name_of(relation.relation)
			var path: String = relation.relation.get_script().resource_path if relation.relation is Component else ""
			var key := path if path != "" else label
			if not relation_counts.has(key): relation_counts[key] = {"name": label, "script": path, "count": 0}
			relation_counts[key].count += 1
	var system_rows: Array = []
	var active := 0
	var total_ms := 0.0
	var timed := 0
	for system in world.systems:
		if not is_instance_valid(system): continue
		var running := system.active and not system.paused
		if running: active += 1
		var data: Dictionary = system.lastRunData
		var measured := data.has("execution_time_ms")
		if running and measured:
			total_ms += float(data.execution_time_ms)
			timed += 1
		system_rows.append({"name": str(data.get("system_name", system.name)), "iid": system.get_instance_id(), "active": running, "measured": measured, "last_ms": float(data.get("execution_time_ms", 0.0)), "avg_ms": float(data.get("avg_ms", 0.0))})
	component_rows.sort_custom(func(a, b): return a.count > b.count if a.count != b.count else a.name < b.name)
	var relation_rows: Array = relation_counts.values()
	relation_rows.sort_custom(func(a, b): return a.count > b.count if a.count != b.count else a.name < b.name)
	system_rows.sort_custom(func(a, b): return a.last_ms > b.last_ms if a.last_ms != b.last_ms else a.name < b.name)
	return {"world_path": str(world.get_path()) if world.is_inside_tree() else str(world.name), "world": world.get_instance_id(), "epoch": epoch, "time": Time.get_ticks_msec(), "entities": world.entities.size(), "enabled": enabled, "components": component_total, "component_types": component_rows.size(), "relationships": relationships, "relationship_types": relation_rows.size(), "systems": system_rows.size(), "active_systems": active, "observers": world.observers.size(), "archetypes": occupied, "cached_queries": world._query_archetype_cache.size(), "system_ms": total_ms if timed > 0 else null, "component_rows": component_rows.slice(0, limit), "relationship_rows": relation_rows.slice(0, limit), "system_rows": system_rows.slice(0, limit), "collection_ms": (Time.get_ticks_usec() - started) / 1000.0}

func preview_restore(snapshot: Dictionary) -> Dictionary:
	_restore_token += 1
	_restore_plan.clear()
	_restore_snapshot.clear()
	var result := Snapshot.preview(self, snapshot)
	if result.has("error"): return result
	_restore_snapshot = snapshot.duplicate(true)
	_restore_plan = result.plan
	result.erase("plan")
	result["token"] = _restore_token
	return result

func restore_snapshot(token: int) -> Dictionary:
	if token != _restore_token or _restore_snapshot.is_empty(): return {"error": "Restore preview expired. Preview the file again."}
	var topology := Snapshot.preview(self, _restore_snapshot)
	var plan := _restore_plan
	_restore_plan = []
	_restore_snapshot = {}
	_restore_token += 1
	if topology.has("error"): return topology
	return Snapshot.restore(self, plan)

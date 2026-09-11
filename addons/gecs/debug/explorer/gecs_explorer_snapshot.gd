extends RefCounted
## Portable inspection dump and deliberately bounded value-only restoration.
const Codec = preload("res://addons/gecs/debug/explorer/gecs_explorer_codec.gd")
const FORMAT := "gecs-explorer-snapshot"
const MAX_ENTITIES := 1000
const MAX_BYTES := 8388608

static func dump(service) -> Dictionary:
	if not service.world.debug_is_paused(): return {"error": "Pause ECS before exporting a consistent snapshot."}
	if service.world.entities.size() > MAX_ENTITIES: return {"error": "Snapshot limit is 1,000 entities."}
	var entities: Array = []
	for entity in service.world.entities:
		if not is_instance_valid(entity): return {"error": "The world contains a freed entity. Refresh the world before saving."}
		# Every owned link is already captured once in a whole-world export.
		entities.append(service.inspect(service.identity(entity), false))
	var snapshot := {"format": FORMAT, "version": 1, "scope": "ECS inspection; restore supported component values and enabled states only", "created_at": Time.get_datetime_string_from_system(true), "world_path": str(service.world.get_path()), "entities": entities}
	if var_to_bytes(snapshot).size() > MAX_BYTES: return {"error": "Snapshot exceeds 8 MiB."}
	return {"snapshot": snapshot}

static func anchor(entity: Dictionary) -> String:
	if not str(entity.get("alias", "")).is_empty(): return "alias:" + str(entity.alias)
	if not str(entity.get("path", "")).is_empty(): return "path:" + str(entity.path)
	return ""

static func _relations(snapshot: Dictionary, anchors: Dictionary) -> Variant:
	var result: Array[String] = []
	for relation in snapshot.get("relationships", []):
		if not relation is Dictionary or not relation.get("target", {}) is Dictionary or not relation.get("data", {}) is Dictionary: return null
		var target: Dictionary = relation.get("target", {})
		var key := str(anchors.get(str(target.get("iid", "")), "")) if not target.is_empty() else str(relation.get("label", ""))
		if not target.is_empty() and key.is_empty(): return null
		# Relation data is not editable by this restore path. Require it to match.
		result.append(JSON.stringify([relation.get("relation", ""), key, relation.get("data", {}).get("value", ""), relation.get("data", {}).get("display", "")]))
	result.sort()
	return result

static func preview(service, snapshot: Dictionary) -> Dictionary:
	if not service.world.debug_is_paused(): return {"error": "Pause ECS before previewing a restore."}
	if snapshot.get("format") != FORMAT or snapshot.get("version") != 1 or not snapshot.get("entities") is Array:
		return {"error": "Not a supported GECS Explorer snapshot."}
	if snapshot.entities.size() > MAX_ENTITIES or var_to_bytes(snapshot).size() > MAX_BYTES: return {"error": "Snapshot exceeds the size limit."}
	var current_result: Dictionary = dump(service)
	if current_result.has("error"): return current_result
	var current: Array = current_result.snapshot.entities
	if current.size() != snapshot.entities.size(): return {"error": "Entity membership changed. Value restore does not create or delete entities."}
	var live_by_anchor := {}
	var live_anchors := {}
	var saved_anchors := {}
	var seen := {}
	for entity in current:
		var key := anchor(entity)
		if key.is_empty() or live_by_anchor.has(key): return {"error": "Every entity needs a unique alias or node path to restore."}
		live_by_anchor[key] = entity
		live_anchors[str(entity.identity.iid)] = key
	for entity in snapshot.entities:
		if not entity is Dictionary or not entity.get("identity") is Dictionary or not entity.get("components") is Array or not entity.get("relationships") is Array:
			return {"error": "Malformed entity in snapshot."}
		var key := anchor(entity)
		if key.is_empty() or seen.has(key) or not live_by_anchor.has(key): return {"error": "Cannot uniquely match saved entity: " + key}
		seen[key] = true
		var saved_id := str(entity.identity.get("iid", ""))
		if saved_id.is_empty() or saved_anchors.has(saved_id): return {"error": "Missing or duplicate saved entity identity."}
		saved_anchors[saved_id] = key
	var plan: Array = []
	var rows: Array = []
	var count := 0
	var skipped := 0
	for saved in snapshot.entities:
		var live: Dictionary = live_by_anchor[anchor(saved)]
		if saved.get("script") != live.get("script"): return {"error": "Entity script changed: " + str(live.name)}
		var relations: Variant = _relations(saved, saved_anchors)
		if relations == null or relations != _relations(live, live_anchors): return {"error": "Relationships changed on " + str(live.name) + ". Value restore cannot change relationships."}
		var components := {}
		for component in live.components: components[component.script] = component
		if saved.components.size() != components.size(): return {"error": "Component membership changed on " + str(live.name)}
		var operations: Array = []
		var component_seen := {}
		for saved_component in saved.components:
			if not saved_component is Dictionary or not saved_component.get("fields") is Array: return {"error": "Malformed component."}
			var path := str(saved_component.get("script", ""))
			if not components.has(path) or component_seen.has(path): return {"error": "Component membership changed on " + str(live.name)}
			component_seen[path] = true
			var component: Dictionary = components[path]
			var fields := {}
			for field in component.fields: fields[field.name] = field
			if fields.size() != saved_component.fields.size(): return {"error": "Property schema changed on " + str(component.name)}
			var field_seen := {}
			for saved_field in saved_component.fields:
				if not saved_field is Dictionary or not saved_field.get("value") is Dictionary: return {"error": "Malformed property."}
				var property := str(saved_field.get("name", ""))
				if not fields.has(property) or field_seen.has(property): return {"error": "Property schema changed: " + property}
				field_seen[property] = true
				var field: Dictionary = fields[property]
				if not field.writable or not saved_field.value.get("editable", false):
					skipped += 1
					continue
				if not Codec.valid(saved_field.value): return {"error": "Invalid typed value: " + property}
				if Codec.equal(field.value, saved_field.value): continue
				var operation := {"op": "set", "component": component.iid, "property": property, "expected": field.value, "value": saved_field.value}
				var error: String = service._validate(service.resolve(live.identity), operation)
				if not error.is_empty(): return {"error": error + ": " + str(live.name) + "/" + property}
				operations.append(operation)
				if rows.size() < 100: rows.append("%s / %s / %s: %s → %s" % [live.name, component.name, property, field.value.display, Codec.encode(Codec.decode(saved_field.value)).display])
		if saved.get("enabled") is not bool: return {"error": "Invalid enabled state."}
		if live.enabled != saved.enabled:
			operations.append({"op": "enabled", "expected": live.enabled, "value": saved.enabled})
			if rows.size() < 100: rows.append("%s / enabled: %s → %s" % [live.name, live.enabled, saved.enabled])
		if operations.size() > 128: return {"error": "Too many changed fields on " + str(live.name) + ". Limit: 128 per entity."}
		if not operations.is_empty(): plan.append({"entity": live.identity, "operations": operations})
		count += operations.size()
	return {"plan": plan, "changes": count, "skipped": skipped, "entities": current.size(), "rows": rows}

static func restore(service, plan: Array) -> Dictionary:
	if not service.world.debug_is_paused(): return {"error": "Pause ECS before restoring values."}
	# Revalidate every expected value before any mutation, including edits made
	# after the preview. Each apply also revalidates against observer side effects.
	for entry in plan:
		var entity: Entity = service.resolve(entry.entity)
		if entity == null: return {"error": "A previewed entity no longer exists. Preview again."}
		for operation in entry.operations:
			var error: String = service._validate(entity, operation)
			if not error.is_empty(): return {"error": error + ". Preview the restore again."}
	var applied := 0
	for entry in plan:
		var result: Dictionary = service.apply(entry)
		applied += int(result.get("applied", 0))
		if not str(result.get("error", "")).is_empty(): return {"error": result.error, "applied": applied, "partial": applied > 0}
	return {"applied": applied}

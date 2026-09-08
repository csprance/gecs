## GECSGraphState: builds the entity / relationship graph payload shown by the
## debugger tab's graph view.
##
## [method build] takes a set of watched entities and returns every included
## entity as a node (components inside), every relationship as an edge, and
## non-entity relationship targets (a Script archetype, a Component instance,
## the wildcard) as small nodes of their own. Entities that relate TO a watched
## entity are included as stubs so inbound edges are visible; [param depth]
## expands the neighbourhood by that many hops in both directions.[br]
## There is no reverse relationship index in GECS, so inbound edges come from
## a scan of [member World.entities]. That is fine for a debug pull while paused
## or at the tab's poll rate.
class_name GECSGraphState
extends RefCounted


## Build the graph for [param watched] (Entity instances or instance ids).
## Returns [code]{watched: [instance ids], nodes: [...], edges: [...]}[/code].[br]
## Node shapes:[br]
## - entity: [code]{key:"e:<iid>", kind:"entity", instance_id, id, name, path, enabled, watched, stub, dangling, components:[{id, type, data}]}[/code][br]
## - script: [code]{key:"s:<path>", kind:"script", label}[/code][br]
## - component: [code]{key:"c:<iid>", kind:"component", label, data}[/code][br]
## - wildcard: [code]{key:"w:*", kind:"wildcard", label:"*"}[/code][br]
## Edge shape: [code]{key:"r:<rel iid>", rel_id, from, to, relation_type, relation_data, target_type, target_data}[/code].
static func build(world: World, watched: Array, depth: int = 0) -> Dictionary:
	var included: Dictionary = {}
	var watched_ids: Dictionary = {}
	for item in watched:
		var entity := _resolve(item)
		if entity != null:
			included[entity.get_instance_id()] = entity
			watched_ids[entity.get_instance_id()] = true

	var frontier: Array = included.keys()
	for _round in range(maxi(0, depth)):
		var next_frontier: Array = []
		for iid in frontier:
			var entity: Entity = included[iid]
			for rel in entity.relationships:
				var target = rel.target
				if _is_live_entity(target) and not included.has(target.get_instance_id()):
					included[target.get_instance_id()] = target
					next_frontier.append(target.get_instance_id())
			for other in world.entities:
				if not is_instance_valid(other) or included.has(other.get_instance_id()):
					continue
				if _relates_to(other, entity):
					included[other.get_instance_id()] = other
					next_frontier.append(other.get_instance_id())
		frontier = next_frontier

	var nodes: Dictionary = {}
	var edges: Array = []
	for iid in included:
		var entity: Entity = included[iid]
		nodes[_entity_key(entity)] = _entity_node(entity, watched_ids.has(iid), false)

	# Outbound edges from every included entity.
	for iid in included:
		var entity: Entity = included[iid]
		var source_key := _entity_key(entity)
		for rel in entity.relationships:
			var target = rel.target
			var target_key := ""
			if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
				nodes[source_key]["dangling"] += 1
				continue
			elif target == null:
				target_key = "w:*"
				if not nodes.has(target_key):
					nodes[target_key] = {"key": target_key, "kind": "wildcard", "label": "*"}
			elif target is Entity:
				target_key = _entity_key(target)
				if not nodes.has(target_key):
					nodes[target_key] = _entity_node(target, false, true)
			elif target is Component:
				target_key = "c:%d" % target.get_instance_id()
				if not nodes.has(target_key):
					nodes[target_key] = {
						"key": target_key,
						"kind": "component",
						"label": GECSStepper.type_name_of(target),
						"data": _encode_data(target.serialize()),
					}
			elif target is Script:
				target_key = "s:" + target.resource_path
				if not nodes.has(target_key):
					nodes[target_key] = {
						"key": target_key,
						"kind": "script",
						"label": GECSStepper.script_label(target),
					}
			else:
				continue
			edges.append(_edge(rel, source_key, target_key))

	# Inbound edges from entities outside the included set (shown as stubs).
	for other in world.entities:
		if not is_instance_valid(other) or included.has(other.get_instance_id()):
			continue
		for rel in other.relationships:
			var target = rel.target
			if _is_live_entity(target) and included.has(target.get_instance_id()):
				var source_key := _entity_key(other)
				if not nodes.has(source_key):
					nodes[source_key] = _entity_node(other, false, true)
				edges.append(_edge(rel, source_key, _entity_key(target)))

	return {"watched": watched_ids.keys(), "nodes": nodes.values(), "edges": edges}


static func _resolve(item) -> Entity:
	if item is Entity:
		return item if is_instance_valid(item) else null
	if typeof(item) == TYPE_INT:
		var obj = instance_from_id(item)
		if obj is Entity and is_instance_valid(obj):
			return obj
	return null


static func _is_live_entity(value) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value is Entity


static func _relates_to(source: Entity, target: Entity) -> bool:
	for rel in source.relationships:
		var rel_target = rel.target
		if typeof(rel_target) == TYPE_OBJECT and is_instance_valid(rel_target) and rel_target == target:
			return true
	return false


static func _entity_key(entity: Entity) -> String:
	return "e:%d" % entity.get_instance_id()


static func _entity_node(entity: Entity, is_watched: bool, stub: bool) -> Dictionary:
	var node := {
		"key": _entity_key(entity),
		"kind": "entity",
		"instance_id": entity.get_instance_id(),
		"id": entity.id,
		"name": String(entity.name),
		"path": str(entity.get_path()) if entity.is_inside_tree() else "",
		"enabled": entity.enabled,
		"watched": is_watched,
		"stub": stub,
		"dangling": 0,
		"components": [],
	}
	if not stub:
		for comp in entity.components.values():
			if is_instance_valid(comp):
				node.components.append(
					{
						"id": comp.get_instance_id(),
						"type": GECSStepper.type_name_of(comp),
						"data": _encode_data(comp.serialize()),
					}
				)
	return node


static func _edge(rel: Relationship, from_key: String, to_key: String) -> Dictionary:
	var edge := GECSEditorDebuggerMessages.serialize_relationship(rel)
	edge["key"] = "r:%d" % rel.get_instance_id()
	edge["rel_id"] = rel.get_instance_id()
	edge["from"] = from_key
	edge["to"] = to_key
	edge["relation_data"] = _encode_data(edge.get("relation_data", {}))
	return edge


static func _encode_data(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[key] = GECSStepper.encode_value(data[key])
	return out

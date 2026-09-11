extends GdUnitTestSuite

const Codec = preload("res://addons/gecs/debug/explorer/gecs_explorer_codec.gd")
const Snapshot = preload("res://addons/gecs/debug/explorer/gecs_explorer_snapshot.gd")
var runner: GdUnitSceneRunner
var world: World
var service: GECSExplorerService
var entity: Entity
var comp: C_TestA

class Increment:
	extends System
	func query() -> QueryBuilder: return q.with_all([C_TestA])
	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities: e.get_component(C_TestA).value += 1

class Clamped:
	extends Component
	@export var value: int = 0:
		set(next):
			var old := value
			value = clampi(next, 0, 10)
			property_changed.emit(self, "value", old, value)

class RemoveOnChange:
	extends Observer
	func query() -> QueryBuilder: return q.with_all([C_TestA]).on_changed()
	func each(_event: Variant, e: Entity, _payload: Variant = null) -> void:
		e.remove_component(C_TestB)

func before() -> void:
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func before_test() -> void:
	service = world.debug_explorer()
	entity = Entity.new()
	entity.name = "Subject"
	comp = C_TestA.new(1)
	entity.add_component(comp)
	world.add_entity(entity, null, false)

func after_test() -> void:
	world.purge(false)

func _edit(value: int, target: Component = null) -> Dictionary:
	if target == null: target = comp
	return {"op": "set", "component": target.get_instance_id(), "property": "value", "expected": Codec.encode(target.get("value")), "value": Codec.encode(value)}

func _snapshot() -> Dictionary:
	entity.alias = &"subject"
	world.debug_pause()
	return JSON.parse_string(JSON.stringify(Snapshot.dump(service).snapshot))

func test_snapshot_preview_is_read_only_and_restore_requires_single_use_token() -> void:
	var saved := _snapshot()
	comp.value = 9
	entity.enabled = false
	var notifications: Array = []
	entity.component_property_changed.connect(func(_e, _c, _p, _old, _new): notifications.append(1))
	var preview := service.preview_restore(saved)
	assert_int(preview.changes).is_equal(2)
	assert_int(comp.value).is_equal(9)
	assert_bool(entity.enabled).is_false()
	assert_array(notifications).is_empty()
	assert_int(service.restore_snapshot(preview.token).applied).is_equal(2)
	assert_int(comp.value).is_equal(1)
	assert_bool(entity.enabled).is_true()
	assert_int(notifications.size()).is_equal(1)
	assert_bool(world.debug_is_paused()).is_true()
	assert_str(service.restore_snapshot(preview.token).error).contains("expired")

func test_snapshot_matches_alias_after_entity_replacement_not_old_instance_id() -> void:
	var saved := _snapshot()
	var old_id := entity.get_instance_id()
	world.remove_entity(entity)
	entity = Entity.new()
	entity.alias = &"subject"
	comp = C_TestA.new(8)
	entity.add_component(comp)
	world.add_entity(entity, null, false)
	assert_int(entity.get_instance_id()).is_not_equal(old_id)
	var preview := service.preview_restore(saved)
	assert_int(service.restore_snapshot(preview.token).applied).is_equal(1)
	assert_int(comp.value).is_equal(1)

func test_snapshot_conflict_and_structural_mismatch_do_not_apply() -> void:
	var saved := _snapshot()
	comp.value = 8
	var preview := service.preview_restore(saved)
	comp.value = 9
	assert_str(service.restore_snapshot(preview.token).error).contains("Conflict")
	assert_int(comp.value).is_equal(9)

	preview = service.preview_restore(saved)
	entity.add_component(C_TestB.new())
	assert_str(service.restore_snapshot(preview.token).error).contains("membership changed")
	assert_int(comp.value).is_equal(9)

func test_snapshot_rejects_malformed_nested_data_without_mutation() -> void:
	var saved := _snapshot()
	comp.value = 8
	var malformed := saved.duplicate(true)
	malformed.entities[0].relationships = [{"target": 42}]
	assert_bool(service.preview_restore(malformed).has("error")).is_true()
	malformed = saved.duplicate(true)
	malformed.entities[0].components[0].fields[0].value.value = [1, 2]
	assert_str(service.preview_restore(malformed).error).contains("Invalid typed value")
	malformed = saved.duplicate(true)
	malformed.entities[0].components[0].fields.clear()
	assert_str(service.preview_restore(malformed).error).contains("schema changed")
	assert_int(comp.value).is_equal(8)

func test_snapshot_rejects_live_restore_and_world_reset_invalidates_preview() -> void:
	var saved := _snapshot()
	comp.value = 8
	var preview := service.preview_restore(saved)
	world.debug_resume()
	assert_str(service.restore_snapshot(preview.token).error).contains("Pause ECS")
	assert_str(Snapshot.dump(service).error).contains("Pause ECS")
	world.debug_pause()
	preview = service.preview_restore(saved)
	service.reset()
	assert_str(service.restore_snapshot(preview.token).error).contains("expired")
	assert_int(comp.value).is_equal(8)

func test_snapshot_partial_restore_reports_observer_removal() -> void:
	entity.add_component(C_TestB.new(1))
	var saved := _snapshot()
	comp.value = 8
	entity.get_component(C_TestB).value = 8
	world.add_observer(RemoveOnChange.new())
	var preview := service.preview_restore(saved)
	var result := service.restore_snapshot(preview.token)
	assert_int(result.applied).is_equal(1)
	assert_bool(result.partial).is_true()
	assert_str(result.error).contains("removed")
	assert_int(comp.value).is_equal(1)

func test_snapshot_relationship_membership_and_data_must_match() -> void:
	var target := Entity.new()
	target.alias = &"target"
	world.add_entity(target, null, false)
	var relation := Relationship.new(C_TestB.new(2), target)
	entity.add_relationship(relation)
	var saved := _snapshot()
	comp.value = 9
	assert_int(service.preview_restore(saved).changes).is_equal(1)
	relation.relation.value = 3
	assert_str(service.preview_restore(saved).error).contains("Relationships changed")
	assert_int(comp.value).is_equal(9)

func test_codec_roundtrips_typed_variants_without_truncation() -> void:
	var array: Array[Vector3] = [Vector3.ONE, Vector3(1, 2, 3)]
	var decoded: Array = Codec.decode(Codec.encode(array))
	assert_bool(decoded.is_typed()).is_true()
	assert_array(decoded).is_equal(array)
	var long_text := "value".repeat(300)
	assert_str(Codec.decode(Codec.encode(long_text))).is_equal(long_text)
	assert_bool(Codec.encode(comp).editable).is_false()
	assert_bool(Codec.encode({"resource": comp}).editable).is_false()

func test_inspection_metadata_and_generational_identity() -> void:
	var result := service.inspect(service.identity(entity))
	assert_int(result.components.size()).is_equal(1)
	var fields: Array = result.components[0].fields
	assert_str(fields[0].name).is_equal("value")
	assert_bool(fields[0].exported).is_true()
	assert_bool(fields[0].writable).is_true()
	var ref := service.identity(entity)
	world.remove_entity(entity)
	assert_str(service.inspect(ref).error).contains("no longer exists")

func test_query_aliases_and_declarative_terms_agree() -> void:
	entity.add_component(C_TestB.new())
	for text in ["q.with_all([C_TestA])", "world.query.with_all([C_TestA])", "ECS.world.query.with_all([C_TestA]).execute()"]:
		assert_int(service.query({"text": text}).total).is_equal(1)
	var spec := {"all": ["C_TestB"], "properties": [{"component": "C_TestA", "property": "value", "op": "_gte", "value": Codec.encode(1)}]}
	assert_int(service.query({"spec": spec}).total).is_equal(1)
	entity.remove_component(C_TestB)
	assert_int(service.query({"spec": spec}).total).is_equal(0)

func test_mutations_wait_for_boundary_and_apply_before_step() -> void:
	var system := Increment.new()
	world.add_system(system)
	world.debug_pause()
	service.handle_request({"version": GECSExplorerService.VERSION, "request_id": 1, "op": "apply", "world": world.get_instance_id(), "epoch": service.epoch, "args": {"entity": service.identity(entity), "operations": [_edit(10)], "step": GECSStepper.Kind.SYSTEM}})
	assert_int(comp.value).is_equal(1)
	world.process(0.016)
	assert_int(comp.value).is_equal(11)

func test_conflict_rejects_whole_prevalidation_and_force_is_explicit() -> void:
	var edit := _edit(5)
	comp.value = 3
	var args := {"entity": service.identity(entity), "operations": [edit]}
	assert_str(service.apply(args).error).contains("Conflict")
	assert_int(comp.value).is_equal(3)
	args.force = true
	assert_int(service.apply(args).applied).is_equal(1)
	assert_int(comp.value).is_equal(5)

func test_silent_edit_emits_once_and_emitting_setter_is_not_doubled() -> void:
	var notifications: Array = []
	entity.component_property_changed.connect(func(_entity, _comp, _name, _old, _new): notifications.append(1))
	service.apply({"entity": service.identity(entity), "operations": [_edit(4)]})
	assert_int(notifications.size()).is_equal(1)
	var clamped := Clamped.new()
	entity.add_component(clamped)
	service.apply({"entity": service.identity(entity), "operations": [_edit(99, clamped)]})
	assert_int(clamped.value).is_equal(10)
	assert_int(notifications.size()).is_equal(2)

func test_structural_edits_and_stale_component_rejection() -> void:
	var ref := service.identity(entity)
	assert_int(service.apply({"entity": ref, "operations": [{"op": "add_component", "script": "C_TestB"}]}).applied).is_equal(1)
	var edit := _edit(5)
	entity.remove_component(comp)
	entity.add_component(C_TestA.new())
	assert_str(service.apply({"entity": ref, "operations": [edit]}).error).contains("replaced")
	assert_int(service.apply({"entity": ref, "operations": [{"op": "add_relationship", "script": "C_TestB", "target": {}}]}).applied).is_equal(1)
	assert_int(entity.relationships.size()).is_equal(1)
	assert_int(service.apply({"entity": ref, "operations": [{"op": "remove_relationship", "relationship": entity.relationships[0].get_instance_id()}]}).applied).is_equal(1)

func test_observer_side_effect_reports_partial_apply() -> void:
	entity.add_component(C_TestB.new())
	var other := entity.get_component(C_TestB)
	world.add_observer(RemoveOnChange.new())
	var result := service.apply({"entity": service.identity(entity), "operations": [_edit(3), _edit(4, other)]})
	assert_int(result.applied).is_equal(1)
	assert_str(result.error).contains("removed")

func test_epoch_rejects_requests_from_before_purge() -> void:
	var ref := service.identity(entity)
	service.reset()
	assert_object(service.resolve(ref)).is_null()

func test_scratchpad_returns_value_and_mutates_only_when_run() -> void:
	var result := service.scratchpad({"entity": service.identity(entity), "source": "entity.get_component(C_TestA).value = 7\nreturn q.with_all([C_TestA]).execute().size()"})
	assert_int(comp.value).is_equal(7)
	assert_int(Codec.decode(result.value)).is_equal(1)

func test_property_breakpoint_catches_silent_write_at_system_boundary() -> void:
	world.add_system(Increment.new())
	var id := world.debug_add_breakpoint({"kind": "property", "entity": service.identity(entity), "component": comp.get_instance_id(), "property": "value", "op": "gte", "value": Codec.encode(2)})
	assert_int(id).is_greater(0)
	world.process(0.016)
	assert_bool(world.debug_is_paused()).is_true()
	assert_int(comp.value).is_equal(2)

func test_query_condition_and_run_until_are_bounded() -> void:
	world.add_system(Increment.new())
	var condition := {"kind": "property", "entity": service.identity(entity), "component": comp.get_instance_id(), "property": "value", "op": "gte", "value": Codec.encode(4)}
	service.run_until({"condition": condition})
	for i in 8: world.process(0.016)
	assert_int(comp.value).is_equal(4)
	assert_bool(service.run.is_empty()).is_true()
	condition.value = Codec.encode(999)
	service.run_until({"condition": condition, "limit": 2})
	for i in 8: world.process(0.016)
	assert_int(comp.value).is_equal(6)
	assert_bool(service.run.is_empty()).is_true()

func test_already_satisfied_run_does_not_advance() -> void:
	world.add_system(Increment.new())
	var result := service.run_until({"condition": {"kind": "query", "spec": {"all": ["C_TestA"]}, "op": "nonempty"}})
	assert_str(result.reason).contains("already")
	world.process(0.016)
	assert_int(comp.value).is_equal(1)

func test_watch_capture_and_membership_diff() -> void:
	service.set_watch({"key": "subject", "entity": service.identity(entity)})
	service.set_watch({"key": "query", "spec": {"all": ["C_TestB"]}})
	var before := service.capture({})
	comp.value = 9
	entity.add_component(C_TestB.new())
	var after := service.capture({})
	var rows := GECSExplorerModel.compare(before, after)
	assert_int(rows.size()).is_greater_equal(3)
	assert_int(after.memberships.query.size()).is_equal(1)

func test_no_watch_means_no_sample_work() -> void:
	var events: Array = []
	service.changed.connect(func(event): events.append(event))
	service.pump()
	assert_dict(service.sample().get("samples", {})).is_empty()
	assert_bool(events.any(func(event): return event.kind == "sample")).is_false()

func test_world_overview_counts_disabled_entities_components_and_relationships() -> void:
	var target := Entity.new()
	world.add_entity(target, null, false)
	target.enabled = false
	entity.add_component(C_TestB.new())
	entity.add_relationship(Relationship.new(C_TestB.new(), target))
	world.add_system(Increment.new())
	var data := service.overview()
	assert_int(data.entities).is_equal(2)
	assert_int(data.enabled).is_equal(1)
	assert_int(data.components).is_equal(2)
	assert_int(data.component_types).is_equal(2)
	assert_int(data.relationships).is_equal(1)
	assert_int(data.relationship_types).is_equal(1)
	assert_int(data.systems).is_equal(1)
	assert_int(data.active_systems).is_equal(1)
	assert_int(data.archetypes).is_equal(2)
	assert_int(data.relationship_rows[0].count).is_equal(1)
	assert_bool(data.system_rows[0].measured).is_false()
	assert_bool(data.system_ms == null).is_true()
	assert_bool(data.component_rows[0].has("fields")).is_false()
	assert_dict(service.watches).is_empty()

func test_world_overview_uses_cached_system_timings_and_excludes_inactive_cost() -> void:
	var system := Increment.new()
	world.add_system(system)
	system.lastRunData = {"system_name": "Increment", "execution_time_ms": 2.5, "avg_ms": 1.25}
	var data := service.overview()
	assert_float(data.system_ms).is_equal(2.5)
	assert_float(data.system_rows[0].avg_ms).is_equal(1.25)
	system.active = false
	data = service.overview()
	assert_int(data.active_systems).is_equal(0)
	assert_bool(data.system_ms == null).is_true()
	assert_float(data.system_rows[0].last_ms).is_equal(2.5)

func test_world_overview_summary_limit_is_bounded() -> void:
	for i in 52:
		var system := Increment.new()
		system.name = "System%d" % i
		world.add_system(system)
	assert_int(service.overview().system_rows.size()).is_equal(12)
	assert_int(service.overview({"limit": 24}).system_rows.size()).is_equal(24)
	assert_int(service.overview({"limit": 999999}).system_rows.size()).is_equal(48)
	assert_int(service.overview({"limit": -5}).system_rows.size()).is_equal(1)


func test_query_summaries_include_components_and_relationship_targets() -> void:
	var target := Entity.new()
	target.name = "Target"
	world.add_entity(target, null, false)
	entity.add_relationship(Relationship.new(C_TestB.new(), target))
	var summary := service.summary(entity)
	assert_array(summary.component_names).contains("C_TestA")
	assert_array(summary.relationship_names).contains("C_TestB → Target")
	var snapshot := service.inspect(service.identity(entity))
	assert_str(snapshot.relationships[0].label).is_equal("Target")

func test_inspection_reports_incoming_links_without_adding_reverse_relationships() -> void:
	var hero := Entity.new()
	hero.name = "Hero"
	world.add_entity(hero, null, false)
	entity.name = "Coin"
	entity.enabled = false
	var owned := Relationship.new(C_TestB.new(), hero)
	entity.add_relationship(owned)
	entity.add_relationship(Relationship.new(C_TestA.new(), null))
	var coin := service.inspect(service.identity(entity))
	var result := service.inspect(service.identity(hero))
	assert_int(result.relationships.size()).is_equal(0)
	assert_int(result.incoming_relationships.size()).is_equal(1)
	assert_str(result.incoming_relationships[0].source_label).is_equal("Coin")
	assert_dict(result.incoming_relationships[0].source).is_equal(service.identity(entity))
	assert_bool(result.incoming_relationships[0].source_enabled).is_false()
	assert_int(hero.relationships.size()).is_equal(0)
	assert_int(coin.relationships.size()).is_equal(2)
	entity.remove_relationship(owned)
	assert_array(service.inspect(service.identity(hero)).incoming_relationships).is_empty()

func test_incoming_links_refresh_on_watch_and_focused_capture_and_source_removal() -> void:
	var target := Entity.new()
	world.add_entity(target, null, false)
	var ref := service.identity(target)
	service.set_watch({"key": "target", "entity": ref})
	var before := service.capture({})
	var events: Array = []
	service.changed.connect(func(event): events.append(event))
	entity.add_relationship(Relationship.new(C_TestB.new(), target))
	var sample := service.sample(["target"])
	assert_int(sample.samples.target.incoming_relationships.size()).is_equal(1)
	assert_array(events).is_empty()
	var after := service.capture({})
	var changes := GECSExplorerModel.compare(before, after)
	assert_bool(changes.any(func(row): return str(row.field).begins_with("Incoming relationship"))).is_true()
	world.remove_entity(entity)
	assert_array(service.inspect(ref).incoming_relationships).is_empty()

func test_incoming_self_links_are_bounded_and_stale_targets_are_rejected() -> void:
	entity.add_relationship(Relationship.new(C_TestB.new(), entity))
	var result := service.inspect(service.identity(entity))
	assert_int(result.relationships.size()).is_equal(1)
	assert_int(result.incoming_relationships.size()).is_equal(1)
	for i in 257:
		var source := Entity.new()
		world.add_entity(source, null, false)
		source.add_relationship(Relationship.new(C_TestB.new(), entity))
	result = service.inspect(service.identity(entity))
	assert_int(result.incoming_relationships.size()).is_equal(256)
	assert_bool(result.incoming_truncated).is_true()
	var ref := service.identity(entity)
	world.remove_entity(entity)
	assert_str(service.inspect(ref).error).contains("no longer exists")

func test_any_group_property_filters_match_generated_query_and_none_is_explicit() -> void:
	var spec := {"any": ["C_TestA"], "properties": [{"component": "C_TestA", "property": "value", "op": "_gt", "value": Codec.encode(5), "group": "any"}]}
	assert_int(service.query({"spec": spec}).total).is_equal(0)
	comp.value = 10
	assert_int(service.query({"spec": spec}).total).is_equal(1)
	assert_int(service.query({"text": "ECS.world.query.with_any([{C_TestA: {\"value\": {\"_gt\": 5}}}])"}).total).is_equal(1)
	spec.properties[0].group = "none"
	assert_str(service.build_query(spec).error).contains("None excludes")


func test_hello_includes_authoritative_pause_state() -> void:
	var replies: Array = []
	var callback := func(payload): replies.append(payload)
	service.response.connect(callback)
	world.debug_pause()
	service.handle_request({"version": GECSExplorerService.VERSION, "request_id": 901, "op": "hello"})
	assert_bool(replies.back().result.step_state.paused).is_true()
	world.debug_resume()
	service.handle_request({"version": GECSExplorerService.VERSION, "request_id": 902, "op": "hello"})
	assert_bool(replies.back().result.step_state.paused).is_false()
	service.response.disconnect(callback)


func test_pull_protocol_returns_systems_samples_graphs_and_bounded_history() -> void:
	var system := Increment.new()
	system.name = "Increment"
	world.add_system(system)
	world.process(0.016)
	var digest: Dictionary = service.systems().systems
	assert_bool(digest.has(system.get_instance_id())).is_true()
	assert_int(digest[system.get_instance_id()].last_run_data.execution_order).is_equal(0)
	assert_int(digest[system.get_instance_id()].last_run_data.sample_count).is_greater(0)
	service.set_watch({"key": "subject", "entity": service.identity(entity)})
	comp.value = 42 # silent write, visible without property_changed
	assert_int(Codec.decode(service.sample(["subject"]).samples.subject.components[0].fields[0].value)).is_equal(42)
	var stepper := world.debug_stepper()
	for i in 100: stepper._publish_log({"step_id": 0, "ops": [], "label": str(i)})
	var page := service.debugger_state({"after": 0})
	assert_bool(page.gap).is_true()
	assert_int(page.logs.size()).is_equal(service.LOG_PAGE_ENTRIES)
	assert_bool(page.more).is_true()
	var next := service.debugger_state({"after": page.after})
	assert_bool(next.gap).is_false()
	assert_int(next.logs[0].step_id).is_greater(page.after)
	assert_bool(next.more).is_false()
	stepper._publish_log({"step_id": 0, "ops": [], "label": "x".repeat(service.LOG_PAGE_BYTES + 1)})
	var oversized := service.debugger_state({"after": next.after})
	assert_int(oversized.omitted.size()).is_equal(1)
	assert_array(oversized.logs).is_empty()
	assert_int(oversized.after).is_equal(stepper.step_counter)
	var system_id := system.get_instance_id()
	world.remove_system(system)
	assert_bool(service.systems().systems.has(system_id)).is_false()

func test_large_world_event_volume_does_not_change_message_count() -> void:
	var old_sink := GECSEditorDebuggerMessages._test_sink
	var old_attached := GECSEditorDebuggerMessages.attached
	var messages: Array = []
	GECSEditorDebuggerMessages._test_sink = func(message, _data): messages.append(message)
	GECSEditorDebuggerMessages.attached = true
	for i in 100:
		var system := Increment.new()
		system.name = "System%d" % i
		world.add_system(system)
	for i in 9999:
		var e := Entity.new()
		e.add_component(C_TestA.new())
		world.add_entity(e, null, false)
	assert_int(world.entities.size()).is_equal(10000)
	for i in 3:
		for e in world.entities:
			var component: C_TestA = e.get_component(C_TestA)
			component.value += 1
			component.property_changed.emit(component, "value", component.value - 1, component.value)
	for i in 100:
		var e := Entity.new()
		e.add_component(C_TestA.new())
		world.add_entity(e, null, false)
		world.remove_entity(e)
	for i in 3: ECS._on_debugger_message("subscribe", [])
	assert_array(messages).is_empty()
	var replies: Array = []
	service.response.connect(func(reply): replies.append(reply))
	service.handle_request({"version": 2, "request_id": 1, "op": "systems", "world": world.get_instance_id(), "epoch": service.epoch})
	service.pump()
	assert_int(replies.size()).is_equal(1)
	assert_int(replies[0].result.systems.size()).is_equal(100)
	assert_int(messages.count("gecs:explorer_response")).is_equal(1)
	GECSEditorDebuggerMessages._test_sink = old_sink
	GECSEditorDebuggerMessages.attached = old_attached

func test_authoritative_watch_definitions_recover_lost_registration_and_removal() -> void:
	var definition := {"key": "subject", "entity": service.identity(entity)}
	assert_dict(service._sync_watches([definition])).is_empty()
	assert_bool(service.watches.has("subject")).is_true()
	assert_bool(service.sample(["subject"]).samples.subject.has("identity")).is_true()
	service._sync_watches([])
	assert_dict(service.watches).is_empty()

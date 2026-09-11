extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	QueryBuilder.set_execute_tracker(Callable())
	Entity.set_read_tracker(Callable())
	world.purge(false)
	await get_tree().process_frame


func _entity(components: Array = []) -> Entity:
	var entity: Entity = auto_free(Entity.new())
	entity.add_components(components)
	return entity


func test_source_only_preserves_order_duplicates_and_result_ownership():
	var a := _entity()
	var b := _entity()
	var source: Array[Entity] = [b, a, b]
	var query := QueryBuilder.new()
	assert_object(query.from(source)).is_same(query)
	assert_array(query.execute()).contains_exactly([b, a, b])
	assert_object(query.execute_one()).is_same(b)
	query.execute().clear()
	assert_array(source).contains_exactly([b, a, b])
	assert_array(QueryBuilder.new().from([]).execute()).is_empty()
	assert_object(QueryBuilder.new().from([]).execute_one()).is_null()
	assert_str(str(query)).contains("from(<3 candidates>)")


func test_component_filters_and_call_order():
	var a := _entity([C_TestA.new(10), C_TestB.new()])
	var b := _entity([C_TestA.new(20), C_TestB.new(), C_TestC.new()])
	var c := _entity([C_TestA.new(30)])
	var source := [a, b, c]
	var first := QueryBuilder.new().from(source).with_all([C_TestA]).with_any([C_TestB]).with_none(
		[C_TestC]
	)
	var last := (
		QueryBuilder.new().with_all([C_TestA]).with_any([C_TestB]).with_none([C_TestC]).from(source)
	)
	assert_array(first.execute()).contains_exactly([a])
	assert_array(last.execute()).contains_exactly([a])
	(
		assert_array(
			QueryBuilder.new().from(source).with_all([{C_TestA: {"value": {"_gt": 15}}}]).execute()
		)
		. contains_exactly([b, c])
	)


func test_mixed_any_predicates_match_plain_components():
	var a := _entity([C_TestA.new(10)])
	var b := _entity([C_TestB.new()])
	var c := _entity([C_TestA.new(1)])
	var query := QueryBuilder.new().from([a, b, c]).with_any(
		[{C_TestA: {"value": {"_gt": 5}}}, C_TestB]
	)
	assert_array(query.execute()).contains_exactly([a, b])
	c.get_component(C_TestA).value = 8
	assert_array(query.execute()).contains_exactly([a, b, c])


func test_live_array_rebinding_and_filter_changes():
	var a := _entity([C_TestA.new()])
	var b := _entity([C_TestA.new()])
	var buckets := {"idle": [a]}
	var query := QueryBuilder.new().from(buckets.idle).with_all([C_TestA])
	assert_array(query.execute()).contains_exactly([a])
	buckets.idle.append(b)
	buckets.idle.erase(a)
	assert_array(query.execute()).contains_exactly([b])
	buckets.idle = [a]
	assert_array(query.execute()).contains_exactly([b])
	query.from(buckets.idle)
	assert_array(query.execute()).contains_exactly([a])
	query.with_none([C_TestA])
	assert_array(query.execute()).is_empty()


func test_snapshot_survives_predicate_editing_source():
	var a := _entity([C_TestA.new(1)])
	var b := _entity([C_TestA.new(2)])
	var c := _entity([C_TestA.new(3)])
	var source := [a, b]
	var predicate := func(value):
		if value == 1:
			source.clear()
			source.append(c)
		return true
	var query := QueryBuilder.new().from(source).with_all(
		[{C_TestA: {"value": {"func": predicate}}}]
	)
	assert_array(query.execute()).contains_exactly([a, b])
	assert_array(query.execute()).contains_exactly([c])


func test_stale_and_queued_references_are_skipped():
	var a := _entity()
	var freed := Entity.new()
	var queued := Entity.new()
	var source := [null, freed, queued, a]
	freed.free()
	queued.queue_free()
	assert_array(QueryBuilder.new().from(source).execute()).contains_exactly([a])


func test_invalid_entries_report_and_preserve_valid_candidates():
	var entity := _entity()
	var result: Array = []
	await (
		assert_error(func(): result.assign(QueryBuilder.new().from([42, entity]).execute()))
		. is_push_error("QueryBuilder.from() expects Entity entries; invalid entry skipped.")
	)
	assert_array(result).contains_exactly([entity])


func test_predicate_can_free_later_candidate():
	var a := _entity([C_TestA.new()])
	var b := Entity.new()
	b.add_component(C_TestA.new())
	# Bound to a local first: Godot 4.6 can't parse a multiline lambda nested
	# inside a dictionary literal (4.7 can), and CI runs 4.6.
	var free_b := func(_v):
		b.free()
		return true
	var query := QueryBuilder.new().from([a, b]).with_all(
		[{C_TestA: {"value": {"func": free_b}}}]
	)
	assert_array(query.execute()).contains_exactly([a])


func test_groups_and_enabled_filters_without_world():
	var a := _entity()
	var b := _entity()
	var c := _entity()
	for entity in [a, b, c]:
		entity.add_to_group("source_idle")
	a.add_to_group("source_ready")
	b.add_to_group("source_blocked")
	c.enabled = false
	var source := [a, b, c]
	(
		assert_array(
			QueryBuilder.new().from(source).with_group(["source_idle", "source_ready"]).execute()
		)
		. contains_exactly([a])
	)
	(
		assert_array(
			QueryBuilder.new().from(source).without_group(["source_blocked"]).enabled().execute()
		)
		. contains_exactly([a])
	)
	assert_array(QueryBuilder.new().from(source).disabled().execute()).contains_exactly([c])
	assert_array(QueryBuilder.new().from(source).execute()).contains_exactly(source)


func test_relationship_filters_exact_wildcard_script_and_property():
	var target := _entity()
	var a := _entity()
	var b := _entity()
	a.add_relationship(Relationship.new(C_TestA.new(10), target))
	var source := [a, b]
	for relation in [
		Relationship.new(C_TestA.new(), target),
		Relationship.new(C_TestA.new(), ECS.wildcard),
		Relationship.new(C_TestA.new(), Entity),
		Relationship.new({C_TestA: {"value": {"_gt": 5}}}, target),
	]:
		(
			assert_array(QueryBuilder.new().from(source).with_relationship([relation]).execute())
			. contains_exactly([a])
		)
		(
			assert_array(QueryBuilder.new().from(source).without_relationship([relation]).execute())
			. contains_exactly([b])
		)
	var too_high := Relationship.new({C_TestA: {"value": {"_gt": 50}}}, target)
	assert_array(QueryBuilder.new().from(source).with_relationship([too_high]).execute()).is_empty()


func test_foreign_and_detached_candidates_do_not_require_membership():
	var foreign: World = auto_free(World.new())
	add_child(foreign)
	var foreign_entity := Entity.new()
	foreign_entity.add_component(C_TestA.new())
	foreign.add_entity(foreign_entity)
	var detached := _entity([C_TestA.new()])
	(
		assert_array(world.query.from([foreign_entity, detached]).with_all([C_TestA]).execute())
		. contains_exactly([foreign_entity, detached])
	)


func test_changed_uses_world_baseline_and_missing_tracking_fallback():
	var entity := Entity.new()
	entity.add_component(C_ObserverTest.new())
	world.add_entity(entity)
	var detached := _entity([C_ObserverTest.new()])
	var query := world.query.from([entity, detached]).with_all([C_ObserverTest]).changed()
	query.get_changed_keys()
	assert_array(query.execute()).contains_exactly([entity, detached])
	query.since(Archetype.global_change_tick)
	assert_array(query.execute()).contains_exactly([detached])
	Archetype.global_change_tick += 1
	entity.get_component(C_ObserverTest).value = 1
	assert_array(query.execute()).contains_exactly([entity, detached])
	(
		assert_array(
			(
				QueryBuilder
				. new()
				. from([detached])
				. with_all([C_ObserverTest])
				. changed()
				. since(100)
				. execute()
			)
		)
		. contains_exactly([detached])
	)


func test_cache_isolation_clear_and_combine():
	var a := Entity.new()
	a.add_component(C_TestA.new())
	world.add_entity(a)
	var b := _entity([C_TestA.new(), C_TestB.new()])
	var query := world.query.with_all([C_TestA])
	assert_array(query.execute()).contains_exactly([a])
	query.from([b])
	assert_array(query.execute()).contains_exactly([b])
	assert_array(world.query.from([a]).with_all([C_TestA]).execute()).contains_exactly([a])
	query.combine(world.query.from([a]).with_all([C_TestB]))
	assert_array(query.execute()).contains_exactly([b])
	var plain := world.query.combine(world.query.from([b]).with_all([C_TestA]))
	assert_array(plain.execute()).contains_exactly([a])
	query.clear()
	assert_array(query.execute()).contains_exactly([a])
	assert_str(str(query)).not_contains("from(")
	assert_array(query.from([]).execute()).is_empty()


func test_matches_ignores_bound_source_and_retains_legacy_filters():
	var a := _entity([C_TestA.new(1)])
	var b := _entity([C_TestA.new(2)])
	var query := QueryBuilder.new().from([a]).with_all([{C_TestA: {"value": {"_eq": 1}}}])
	assert_array(query.matches([b])).contains_exactly([b])
	assert_array(query.execute()).contains_exactly([a])


func test_execution_tracking_remains_active():
	var entity := _entity([C_TestA.new()])
	var query := QueryBuilder.new().from([entity]).with_all([C_TestA])
	var tracked := GECSTracker.track(func(): return query.execute())
	assert_array(tracked.result).contains_exactly([entity])
	assert_array(tracked.queries).contains_exactly([query])
	assert_array(tracked.reads).contains([C_TestA])


func test_archetypes_rejects_source_once():
	var query := world.query.from([])
	await (
		assert_error(func(): assert_array(query.archetypes()).is_empty())
		. is_push_error(
			"QueryBuilder.from() is not supported in archetypes(); use execute() or execute_one()."
		)
	)
	await assert_error(func(): assert_array(query.archetypes()).is_empty()).is_success()

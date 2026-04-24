## Verifies the fluent Observer event methods on [QueryBuilder] set the correct flags.
## Pure builder-level unit tests — no dispatch behavior yet (tested in later steps).
extends GdUnitTestSuite


func _make_query() -> QueryBuilder:
	return QueryBuilder.new(null)


func test_new_query_has_no_observer_events():
	var q = _make_query()
	assert_bool(q.has_observer_events()).is_false()
	assert_int(q._observer_events_mask).is_equal(0)
	assert_array(q._observer_event_names).is_empty()


func test_on_added_sets_mask():
	var q = _make_query().with_all([C_TestA]).on_added()
	assert_bool(q.has_event(Observer.Event.ADDED)).is_true()
	assert_bool(q.has_event(Observer.Event.REMOVED)).is_false()
	assert_bool(q.has_observer_events()).is_true()


func test_on_removed_sets_mask():
	var q = _make_query().with_all([C_TestA]).on_removed()
	assert_bool(q.has_event(Observer.Event.REMOVED)).is_true()
	assert_bool(q.has_event(Observer.Event.ADDED)).is_false()


func test_on_changed_with_no_filter():
	var q = _make_query().with_all([C_TestA]).on_changed()
	assert_bool(q.has_event(Observer.Event.CHANGED)).is_true()
	assert_array(q._observer_changed_props).is_empty()


func test_on_changed_with_property_filter():
	var q = _make_query().with_all([C_TestA]).on_changed([&"value"])
	assert_bool(q.has_event(Observer.Event.CHANGED)).is_true()
	assert_array(q._observer_changed_props).contains_exactly([&"value"])


func test_on_match_and_on_unmatch_flags():
	var q = _make_query().with_all([C_TestA]).on_match().on_unmatch()
	assert_bool(q.has_event(Observer.Event.MATCH)).is_true()
	assert_bool(q.has_event(Observer.Event.UNMATCH)).is_true()


func test_on_relationship_added_with_no_filter():
	var q = _make_query().on_relationship_added()
	assert_bool(q.has_event(Observer.Event.RELATIONSHIP_ADDED)).is_true()
	assert_array(q._observer_rel_add_types).is_empty()


func test_on_relationship_added_with_type_filter():
	var q = _make_query().on_relationship_added([C_TestA])
	assert_bool(q.has_event(Observer.Event.RELATIONSHIP_ADDED)).is_true()
	assert_array(q._observer_rel_add_types).contains_exactly([C_TestA])


func test_on_relationship_removed():
	var q = _make_query().on_relationship_removed([C_TestB])
	assert_bool(q.has_event(Observer.Event.RELATIONSHIP_REMOVED)).is_true()
	assert_array(q._observer_rel_remove_types).contains_exactly([C_TestB])


func test_on_event_single_name():
	var q = _make_query().on_event(&"damage_dealt")
	assert_bool(q.has_custom_event(&"damage_dealt")).is_true()
	assert_bool(q.has_custom_event(&"heal")).is_false()
	assert_bool(q.has_observer_events()).is_true()


func test_on_event_multiple_names():
	var q = _make_query().on_event(&"damage_dealt").on_event(&"heal")
	assert_bool(q.has_custom_event(&"damage_dealt")).is_true()
	assert_bool(q.has_custom_event(&"heal")).is_true()
	assert_int(q._observer_event_names.size()).is_equal(2)


func test_on_event_dedupes_same_name():
	var q = _make_query().on_event(&"damage_dealt").on_event(&"damage_dealt")
	assert_int(q._observer_event_names.size()).is_equal(1)


func test_fluent_chain_returns_self_for_all_methods():
	var q = _make_query()
	var chained = (
		q
		.with_all([C_TestA])
		.on_added()
		.on_removed()
		.on_changed([&"value"])
		.on_match()
		.on_unmatch()
		.on_relationship_added()
		.on_relationship_removed()
		.on_event(&"custom")
	)
	assert_object(chained).is_same(q)


func test_combined_events_mask():
	var q = _make_query().on_added().on_removed().on_match()
	# Event values are sequential (0, 1, 2, ...); the mask stores 1 << event bits.
	var expected = (
		(1 << Observer.Event.ADDED) | (1 << Observer.Event.REMOVED) | (1 << Observer.Event.MATCH)
	)
	assert_int(q._observer_events_mask).is_equal(expected)
	# Prefer has_event() over raw mask comparisons in new code.
	assert_bool(q.has_event(Observer.Event.ADDED)).is_true()
	assert_bool(q.has_event(Observer.Event.REMOVED)).is_true()
	assert_bool(q.has_event(Observer.Event.MATCH)).is_true()
	assert_bool(q.has_event(Observer.Event.CHANGED)).is_false()


func test_event_enum_values_are_sequential():
	# Locks in the sequential-value convention (not bit flags). Bit flags are derived
	# internally via (1 << event).
	assert_int(Observer.Event.ADDED).is_equal(0)
	assert_int(Observer.Event.REMOVED).is_equal(1)
	assert_int(Observer.Event.CHANGED).is_equal(2)
	assert_int(Observer.Event.MATCH).is_equal(3)
	assert_int(Observer.Event.UNMATCH).is_equal(4)
	assert_int(Observer.Event.RELATIONSHIP_ADDED).is_equal(5)
	assert_int(Observer.Event.RELATIONSHIP_REMOVED).is_equal(6)


func test_plain_filter_query_has_no_events():
	# Ensures a query used as a plain System filter (no on_* methods) does not accidentally declare events.
	var q = _make_query().with_all([C_TestA, C_TestB]).with_none([C_TestC]).enabled()
	assert_bool(q.has_observer_events()).is_false()


func test_component_sensitivity_captures_all_components():
	var q = _make_query().with_all([C_TestA]).with_any([C_TestB]).with_none([C_TestC])
	var paths = q._component_sensitivity()
	assert_array(paths).contains(
		[C_TestA.resource_path, C_TestB.resource_path, C_TestC.resource_path]
	)


func test_component_sensitivity_dedupes():
	var q = _make_query().with_all([C_TestA]).with_any([C_TestA])
	var paths = q._component_sensitivity()
	assert_int(paths.size()).is_equal(1)


func test_clear_resets_observer_event_state():
	var q = _make_query()
	q.with_all([C_TestA]).on_added().on_changed([&"value"]).on_event(&"custom")
	q.clear()
	assert_bool(q.has_observer_events()).is_false()
	assert_int(q._observer_events_mask).is_equal(0)
	assert_array(q._observer_changed_props).is_empty()
	assert_array(q._observer_event_names).is_empty()


## P2-2 regression: chained on_changed calls accumulate filter properties
## (append-and-dedup) rather than replacing. Mirrors on_event semantics.
func test_on_changed_chained_accumulates_and_dedupes():
	var q = _make_query().with_all([C_TestA]).on_changed([&"a"]).on_changed([&"b"]).on_changed(
		[&"a"]
	)  # duplicate — should be deduped
	assert_int(q._observer_changed_props.size()).is_equal(2)
	assert_bool(q._observer_changed_props.has(&"a")).is_true()
	assert_bool(q._observer_changed_props.has(&"b")).is_true()


## P2-2 regression: chained on_relationship_added/removed calls accumulate type
## filters (append-and-dedup) rather than replacing.
func test_on_relationship_added_chained_accumulates_and_dedupes():
	var q = (
		_make_query()
		.on_relationship_added([C_TestA])
		.on_relationship_added([C_TestB])
		.on_relationship_added([C_TestA])
	)  # duplicate — should be deduped
	assert_int(q._observer_rel_add_types.size()).is_equal(2)
	assert_bool(q._observer_rel_add_types.has(C_TestA)).is_true()
	assert_bool(q._observer_rel_add_types.has(C_TestB)).is_true()

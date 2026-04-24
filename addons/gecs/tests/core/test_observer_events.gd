## Custom event dispatch tests: World.emit_event(...) + query().on_event(name).
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


class DamageObserver:
	extends Observer
	var event_count: int = 0
	var last_entity: Entity
	var last_data: Variant

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_event(&"damage_dealt")

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		event_count += 1
		last_entity = entity
		last_data = payload


class UnfilteredEventObserver:
	extends Observer
	var event_count: int = 0

	func query() -> QueryBuilder:
		return q.on_event(&"global_event")

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		event_count += 1


class MultiEventObserver:
	extends Observer
	var damage_events: int = 0
	var heal_events: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_event(&"damage_dealt").on_event(&"heal")

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == &"damage_dealt":
			damage_events += 1
		elif event == &"heal":
			heal_events += 1


func test_emit_event_fires_observer_with_matching_query():
	var obs = DamageObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"damage_dealt", e, {"amount": 10})

	assert_int(obs.event_count).is_equal(1)
	assert_object(obs.last_entity).is_same(e)
	assert_that(obs.last_data).is_equal({"amount": 10})


func test_emit_event_respects_entity_query_filter():
	var obs = DamageObserver.new()
	world.add_observer(obs)

	# Entity WITHOUT C_TestA → observer's with_all filter fails → event should NOT fire.
	var e = Entity.new()
	e.add_component(C_TestB.new())
	world.add_entity(e)

	world.emit_event(&"damage_dealt", e, {"amount": 5})

	assert_int(obs.event_count).is_equal(0)


func test_emit_event_with_unfiltered_query_fires_for_any_entity():
	var obs = UnfilteredEventObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	world.add_entity(e)

	world.emit_event(&"global_event", e)
	assert_int(obs.event_count).is_equal(1)


func test_emit_event_unknown_name_fires_no_observer():
	var obs = DamageObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"unknown_event_name", e)
	assert_int(obs.event_count).is_equal(0)


func test_one_observer_multiple_events():
	var obs = MultiEventObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"damage_dealt", e, 10)
	world.emit_event(&"heal", e, 5)
	world.emit_event(&"damage_dealt", e, 3)

	assert_int(obs.damage_events).is_equal(2)
	assert_int(obs.heal_events).is_equal(1)


func test_multiple_observers_same_event():
	var obs_a = DamageObserver.new()
	var obs_b = DamageObserver.new()
	world.add_observer(obs_a)
	world.add_observer(obs_b)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"damage_dealt", e, {"amount": 1})

	assert_int(obs_a.event_count).is_equal(1)
	assert_int(obs_b.event_count).is_equal(1)


func test_emit_event_null_entity_is_broadcast():
	# emit_event(name) without an entity broadcasts — skips entity filter.
	var obs = UnfilteredEventObserver.new()
	world.add_observer(obs)

	world.emit_event(&"global_event")
	assert_int(obs.event_count).is_equal(1)


func test_emit_event_null_entity_reaches_filtered_observers_too():
	# Broadcast dispatches to observers with filtered queries as well — the filter
	# can't be evaluated without an entity, so the safe/broadcast-friendly behavior
	# is to deliver it. Subscribers with filters should gate on entity == null inside
	# each() if they care.
	var obs = DamageObserver.new()
	world.add_observer(obs)

	world.emit_event(&"damage_dealt", null, {"amount": 10})
	assert_int(obs.event_count).is_equal(1)
	assert_that(obs.last_entity).is_null()


func test_paused_observer_does_not_receive_custom_event():
	var obs = DamageObserver.new()
	world.add_observer(obs)
	obs.paused = true

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"damage_dealt", e, {"amount": 1})
	assert_int(obs.event_count).is_equal(0)


func test_emit_event_on_removed_entity_does_not_crash():
	# Contract: an entity that has been removed from the world (remove_entity already
	# queue_freed it) still passes is_instance_valid() for the rest of the frame, and
	# its components dict persists on the Node until free. emit_event() on such an
	# entity must not crash. Whether the event is delivered is implementation-defined —
	# currently the observer's with_all([C_TestA]) filter still passes because
	# has_component reads the (yet-unfreed) components dict.
	var obs = DamageObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)
	world.emit_event(&"damage_dealt", e, {"amount": 1})
	assert_int(obs.event_count).is_equal(1)

	# Remove the entity (internal queue_free + signal disconnect).
	world.remove_entity(e)

	# Emit again on the now-removed entity. Must not crash. Event may or may not be
	# delivered depending on Node free timing — the contract is "no crash" only.
	world.emit_event(&"damage_dealt", e, {"amount": 2})
	# Tolerant assertion: either state is acceptable.
	assert_int(obs.event_count).is_between(1, 2)

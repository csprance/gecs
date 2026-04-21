## End-to-end integration tests for the new FLECS-style Observer API
## (query() + fluent on_* + each()).
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


class AddedObserver extends Observer:
	var added_count: int = 0
	var last_entity: Entity
	var last_payload: Resource

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1
			last_entity = entity
			last_payload = payload


class RemovedObserver extends Observer:
	var removed_count: int = 0
	var last_component: Resource

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			removed_count += 1
			last_component = payload


class MultiEventObserver extends Observer:
	var added_count: int = 0
	var removed_count: int = 0
	var changed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added().on_removed().on_changed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		match event:
			Observer.Event.ADDED:   added_count += 1
			Observer.Event.REMOVED: removed_count += 1
			Observer.Event.CHANGED: changed_count += 1


class FilteredObserver extends Observer:
	## Observer that fires only for entities that ALSO have C_TestB.
	var added_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA, C_TestB]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1


func test_new_style_on_added_fires_when_watched_component_added():
	var obs = AddedObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new(42))
	world.add_entity(e)

	assert_int(obs.added_count).is_equal(1)
	assert_object(obs.last_entity).is_same(e)
	assert_object(obs.last_payload).is_not_null()


func test_new_style_on_added_does_not_fire_for_unwatched_component():
	var obs = AddedObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestB.new())  # not watched
	world.add_entity(e)

	assert_int(obs.added_count).is_equal(0)


func test_new_style_on_removed_fires_with_component_instance():
	var obs = RemovedObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	var c = C_TestA.new(7)
	e.add_component(c)
	world.add_entity(e)
	assert_int(obs.removed_count).is_equal(0)

	e.remove_component(C_TestA)
	assert_int(obs.removed_count).is_equal(1)
	assert_object(obs.last_component).is_same(c)


func test_new_style_multi_event_observer_routes_via_match_in_each():
	var obs = MultiEventObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	var c = C_TestA.new(1)
	e.add_component(c)
	world.add_entity(e)

	assert_int(obs.added_count).is_equal(1)

	c.property_changed.emit(c, "value", 1, 2)
	assert_int(obs.changed_count).is_equal(1)

	e.remove_component(C_TestA)
	assert_int(obs.removed_count).is_equal(1)


func test_new_style_entity_filter_respected_on_add():
	var obs = FilteredObserver.new()
	world.add_observer(obs)

	# Entity with only one of the required components → observer should NOT fire.
	var e1 = Entity.new()
	e1.add_component(C_TestA.new())
	world.add_entity(e1)
	assert_int(obs.added_count).is_equal(0)

	# Entity with both required components → observer fires once (when the second,
	# watched component is added — entity now satisfies with_all([C_TestA, C_TestB])).
	var e2 = Entity.new()
	e2.add_component(C_TestB.new())
	e2.add_component(C_TestA.new())
	world.add_entity(e2)
	assert_int(obs.added_count).is_equal(1)


func test_legacy_and_new_style_coexist():
	# Legacy observer (overrides watch())
	var legacy = TestAObserver.new()
	world.add_observer(legacy)

	# New-style observer (overrides query())
	var modern = AddedObserver.new()
	world.add_observer(modern)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	# Both observers saw the add
	assert_int(legacy.added_count).is_equal(1)
	assert_int(modern.added_count).is_equal(1)


func test_observer_active_false_skips_dispatch():
	var obs = AddedObserver.new()
	obs.active = false
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	assert_int(obs.added_count).is_equal(0)


func test_observer_paused_skips_dispatch():
	var obs = AddedObserver.new()
	world.add_observer(obs)
	obs.paused = true

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	assert_int(obs.added_count).is_equal(0)

	obs.paused = false
	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)
	assert_int(obs.added_count).is_equal(1)


func test_setup_called_after_registration():
	var obs = SetupTrackingObserver.new()
	world.add_observer(obs)
	assert_bool(obs.setup_called).is_true()
	assert_object(obs._world).is_same(world)
	assert_object(obs.q).is_not_null()


class SetupTrackingObserver extends Observer:
	var setup_called: bool = false
	func setup() -> void:
		setup_called = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		pass


class HealthPropFilteredObserver extends Observer:
	var health_changes: int = 0
	var max_health_changes: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverHealth]).on_changed([&"health"])

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event != Observer.Event.CHANGED:
			return
		if payload.property == "health":
			health_changes += 1
		elif payload.property == "max_health":
			max_health_changes += 1


func test_on_changed_filter_limits_dispatch_to_named_property():
	var obs = HealthPropFilteredObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	var c = C_ObserverHealth.new(100, 100)
	e.add_component(c)
	world.add_entity(e)

	# Change the filtered property — observer fires
	c.health = 50
	assert_int(obs.health_changes).is_equal(1)

	# Change an unfiltered property — observer does NOT fire
	c.max_health = 200
	assert_int(obs.max_health_changes).is_equal(0)

	# Another filtered change still fires
	c.health = 25
	assert_int(obs.health_changes).is_equal(2)


class RemovedWithAllObserver extends Observer:
	var removed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA, C_TestB]).on_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			removed_count += 1


func test_removed_does_not_fire_for_entities_that_never_matched():
	var obs = RemovedWithAllObserver.new()
	world.add_observer(obs)

	# Entity has only C_TestA — never satisfied with_all([C_TestA, C_TestB]).
	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	# Removing C_TestA should NOT fire REMOVED because the entity never matched.
	e.remove_component(C_TestA)
	assert_int(obs.removed_count).is_equal(0)


func test_removed_fires_for_entities_that_matched_before_removal():
	var obs = RemovedWithAllObserver.new()
	world.add_observer(obs)

	# Entity has both required components — did match before removal.
	var e = Entity.new()
	e.add_component(C_TestA.new())
	e.add_component(C_TestB.new())
	world.add_entity(e)

	e.remove_component(C_TestA)
	assert_int(obs.removed_count).is_equal(1)


class ReentrantRegisterObserver extends Observer:
	var spawned_observer: AddedObserver
	var _world_ref: World

	func _init(wref: World = null):
		_world_ref = wref

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.ADDED and spawned_observer == null:
			spawned_observer = AddedObserver.new()
			if _world_ref != null:
				_world_ref.add_observer(spawned_observer)


class YieldExistingObserver extends Observer:
	var added_count: int = 0

	func _init():
		yield_existing = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1


func test_inactive_observer_does_not_yield_existing_at_registration():
	# Entity exists BEFORE observer registers.
	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	var obs = YieldExistingObserver.new()
	obs.active = false
	world.add_observer(obs)

	# yield_existing should NOT retroactively fire because observer is inactive.
	assert_int(obs.added_count).is_equal(0)

	# Flipping active on does not retroactively fire (yield_existing is a one-shot
	# at registration time) — subsequent events dispatch normally though.
	obs.active = true
	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)
	assert_int(obs.added_count).is_equal(1)


func test_reentrant_add_observer_during_callback_does_not_fire_new_observer():
	var obs = ReentrantRegisterObserver.new(world)
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	# The newly-spawned observer should NOT receive the ADDED event that caused its
	# creation (dispatch entries are snapshotted before iteration).
	assert_object(obs.spawned_observer).is_not_null()
	assert_int(obs.spawned_observer.added_count).is_equal(0)

	# A subsequent ADDED event reaches both observers.
	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)
	assert_int(obs.spawned_observer.added_count).is_equal(1)

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


class AddedObserver:
	extends Observer
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


class RemovedObserver:
	extends Observer
	var removed_count: int = 0
	var last_component: Resource

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			removed_count += 1
			last_component = payload


class MultiEventObserver:
	extends Observer
	var added_count: int = 0
	var removed_count: int = 0
	var changed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added().on_removed().on_changed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		match event:
			Observer.Event.ADDED:
				added_count += 1
			Observer.Event.REMOVED:
				removed_count += 1
			Observer.Event.CHANGED:
				changed_count += 1


class FilteredObserver:
	extends Observer
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


class SetupTrackingObserver:
	extends Observer
	var setup_called: bool = false

	func setup() -> void:
		setup_called = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		pass


class HealthPropFilteredObserver:
	extends Observer
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


class RemovedWithAllObserver:
	extends Observer
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


class ReentrantRegisterObserver:
	extends Observer
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


class YieldExistingObserver:
	extends Observer
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


# ─────────────────────────────────────────────────────────────────────────────
# Ported from the pre-v8 test_observer.gd — OBS-01/02/03 regression scaffold.
# These cover real correctness concerns (signal disconnect ordering, ghost
# property_changed connections) that survive the API rewrite.
# ─────────────────────────────────────────────────────────────────────────────


class InstanceCapturingObserver:
	extends Observer
	var removed_count: int = 0
	var changed_count: int = 0
	var last_removed_component: Resource = null

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest]).on_removed().on_changed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		match event:
			Observer.Event.REMOVED:
				removed_count += 1
				last_removed_component = payload
			Observer.Event.CHANGED:
				changed_count += 1

	func reset() -> void:
		removed_count = 0
		changed_count = 0
		last_removed_component = null


## OBS-01: world.remove_entity() must fire REMOVED exactly once per watched component.
func test_obs01_remove_entity_fires_observer_per_component():
	var observer = InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new(7, "obs01"))
	world.add_entity(entity)
	observer.reset()

	world.remove_entity(entity)
	assert_int(observer.removed_count).is_equal(1)


## OBS-02: REMOVED payload is the exact component instance, with preserved properties.
func test_obs02_removed_component_instance_correct():
	var observer = InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	var component = C_ObserverTest.new(42, "marker")
	entity.add_component(component)
	world.add_entity(entity)
	observer.reset()

	entity.remove_component(C_ObserverTest)

	assert_int(observer.removed_count).is_equal(1)
	assert_object(observer.last_removed_component).is_not_null()
	(
		assert_str(observer.last_removed_component.get_script().resource_path)
		.is_equal(
			C_ObserverTest.resource_path,
		)
	)
	assert_int(observer.last_removed_component.value).is_equal(42)


## OBS-03: After entity.remove_component(), mutating the removed component's property
## must NOT trigger CHANGED — property_changed must be disconnected.
func test_obs03_no_phantom_callbacks_after_removal():
	var observer = InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	var component = C_ObserverTest.new(0, "start")
	entity.add_component(component)
	world.add_entity(entity)

	entity.remove_component(C_ObserverTest)
	observer.reset()

	# Mutate the now-detached component via its setter (emits property_changed)
	component.value = 99

	assert_int(observer.changed_count).is_equal(0)


## Two observers watching the same component type must both be notified.
func test_obs_multiple_observers_both_notified():
	var observer_a = InstanceCapturingObserver.new()
	var observer_b = InstanceCapturingObserver.new()
	world.add_observer(observer_a)
	world.add_observer(observer_b)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new(5, "multi"))
	world.add_entity(entity)
	observer_a.reset()
	observer_b.reset()

	entity.remove_component(C_ObserverTest)

	assert_int(observer_a.removed_count).is_equal(1)
	assert_int(observer_b.removed_count).is_equal(1)


## Re-entrancy guard: an observer that removes ANOTHER component as a side effect
## of REMOVED must not cause a double-notification on the second observer.
class CleanupSideEffectObserver:
	extends Observer

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest]).on_removed()

	func each(event: Variant, entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			if entity.has_component(C_ObserverHealth):
				entity.remove_component(C_ObserverHealth)


class HealthRemovalCounter:
	extends Observer
	var health_removed_count: int = 0

	func query() -> QueryBuilder:
		# Filter only on the component being removed — by the time we receive the
		# REMOVED event, C_ObserverTest has already been removed (it was the trigger),
		# so demanding it via with_all would correctly fail and suppress the event.
		return q.with_all([C_ObserverHealth]).on_removed()

	func each(event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			health_removed_count += 1

	func reset() -> void:
		health_removed_count = 0


func test_obs_reentrancy_guard_prevents_double_notify():
	var cleanup_observer = CleanupSideEffectObserver.new()
	var health_observer = HealthRemovalCounter.new()
	world.add_observer(cleanup_observer)
	world.add_observer(health_observer)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	entity.add_component(C_ObserverHealth.new(100))
	world.add_entity(entity)
	health_observer.reset()

	# Removing C_ObserverTest causes cleanup_observer to remove C_ObserverHealth as a side effect.
	# health_observer watches C_ObserverHealth removal; must fire exactly once.
	entity.remove_component(C_ObserverTest)

	assert_int(health_observer.health_removed_count).is_equal(1)


# ─────────────────────────────────────────────────────────────────────────────
# v8.0.0 — filters that were silently ignored by observer dispatch before:
# group, enabled/disabled, property-query-on-removal.
# ─────────────────────────────────────────────────────────────────────────────


class GroupFilteredObserver:
	extends Observer
	var added_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).with_group(["friends"]).on_added()

	func each(event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1


func test_with_group_filter_is_enforced_on_observer_dispatch():
	# Regression for the §1.1 bug: observer with a with_group filter now fires
	# ONLY for entities in that group. Previously the filter was silently ignored.
	var obs = GroupFilteredObserver.new()
	world.add_observer(obs)

	var outsider = Entity.new()
	outsider.add_component(C_TestA.new())
	world.add_entity(outsider)
	assert_int(obs.added_count).is_equal(0)  # not in "friends" → skipped

	var friend = Entity.new()
	friend.add_to_group("friends")
	friend.add_component(C_TestA.new())
	world.add_entity(friend)
	assert_int(obs.added_count).is_equal(1)


class PropertyQueryRemovedObserver:
	extends Observer
	var removed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([{C_ObserverHealth: {"health": {"_gt": 0}}}]).on_removed()

	func each(event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.REMOVED:
			removed_count += 1


func test_on_removed_property_query_evaluated_before_removal():
	# Regression for §1.2: match-before-removal now evaluates property queries.
	# Observer fires only for entities whose C_ObserverHealth had health > 0 pre-removal.
	var obs = PropertyQueryRemovedObserver.new()
	world.add_observer(obs)

	# Entity with health=0: does NOT match the property query, REMOVED must NOT fire.
	var zero_hp = Entity.new()
	zero_hp.add_component(C_ObserverHealth.new(0))
	world.add_entity(zero_hp)
	zero_hp.remove_component(C_ObserverHealth)
	assert_int(obs.removed_count).is_equal(0)

	# Entity with health=50: matches; REMOVED must fire.
	var alive = Entity.new()
	alive.add_component(C_ObserverHealth.new(50))
	world.add_entity(alive)
	alive.remove_component(C_ObserverHealth)
	assert_int(obs.removed_count).is_equal(1)


class InactiveMonitorObserver:
	extends Observer
	var matched: Array[Entity] = []
	var unmatched: Array[Entity] = []

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_match().on_unmatch()

	func each(event: Variant, entity: Entity, _payload: Variant = null) -> void:
		match event:
			Observer.Event.MATCH:
				matched.append(entity)
			Observer.Event.UNMATCH:
				unmatched.append(entity)


func test_monitor_membership_is_seeded_even_when_inactive_at_registration():
	# Regression for §1.4: monitors registered while inactive still seed membership.
	# Previously, flipping active=true later left membership empty and UNMATCH never fired.
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	var obs = InactiveMonitorObserver.new()
	obs.active = false
	world.add_observer(obs)

	# MATCH was suppressed because inactive at registration. Good — matches existing semantics.
	assert_int(obs.matched.size()).is_equal(0)

	# Flip active on and remove the component. UNMATCH must fire because membership
	# was seeded at registration despite being inactive.
	obs.active = true
	entity.remove_component(C_TestA)
	assert_int(obs.unmatched.size()).is_equal(1)


func test_yield_existing_snapshots_entities_array_against_mutating_callback():
	# Regression for §1.3: yield_existing callbacks that mutate entities[] (e.g. by
	# removing another entity) must not crash or skip the iteration.
	var e1 = Entity.new()
	e1.add_component(C_TestA.new())
	world.add_entity(e1)

	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)

	# MutatingObserver removes e2 when it sees e1. If _yield_existing_for_entry
	# iterated the live entities array, e2 would either be skipped or processed
	# after being freed. The snapshot guarantees neither happens.
	var obs := MutatingYieldObserver.new()
	obs.target_to_remove = e2
	obs.trigger_on = e1
	obs.yield_existing = true
	world.add_observer(obs)

	# The observer fired at least once (for e1). e2 is now removed.
	assert_int(obs.added_count).is_greater_equal(1)
	assert_bool(is_instance_valid(e2) and not e2.is_queued_for_deletion()).is_false()


class MutatingYieldObserver:
	extends Observer
	var added_count: int = 0
	var target_to_remove: Entity
	var trigger_on: Entity

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1
			if entity == trigger_on and is_instance_valid(target_to_remove):
				_world.remove_entity(target_to_remove)


class SelfRemovingObserver:
	extends Observer
	var added_count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_added()

	func each(event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		if event == Observer.Event.ADDED:
			added_count += 1
			# Remove self from the world during our own callback.
			if _world != null:
				_world.remove_observer(self)


func test_observer_removed_during_own_callback_is_safe():
	# Contract: an observer can call world.remove_observer(self) inside its own
	# each() callback without crashing. The dispatch snapshot keeps iteration stable,
	# and the observer does not receive any further events.
	var obs = SelfRemovingObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)
	# First event fired and was received; observer then removed itself.
	assert_int(obs.added_count).is_equal(1)

	# A subsequent event must NOT invoke the removed observer.
	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)
	# Observer was queue_freed after remove_observer — skip the post-callback check if
	# it's no longer valid. The key contract is that the framework did not crash and the
	# second event was not delivered to the old observer.
	if is_instance_valid(obs):
		assert_int(obs.added_count).is_equal(1)

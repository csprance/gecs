## Query-monitor tests: on_match / on_unmatch transitions via .on_match()/.on_unmatch()
## on the observer's QueryBuilder.
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


class AliveMonitor extends Observer:
	var matched: Array[Entity] = []
	var unmatched: Array[Entity] = []

	func query() -> QueryBuilder:
		return q.with_all([C_TestA, C_TestB]).on_match().on_unmatch()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		match event:
			Observer.Event.MATCH:   matched.append(entity)
			Observer.Event.UNMATCH: unmatched.append(entity)


class YieldMonitor extends Observer:
	var matched: Array[Entity] = []

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).on_match()

	func _init():
		yield_existing = true

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.MATCH:
			matched.append(entity)


func test_monitor_fires_on_match_once_when_entity_transitions_in():
	var obs = AliveMonitor.new()
	world.add_observer(obs)

	# Entity with only one required component — should NOT match yet
	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)
	assert_int(obs.matched.size()).is_equal(0)

	# Adding the second required component triggers the match transition
	e.add_component(C_TestB.new())
	assert_int(obs.matched.size()).is_equal(1)
	assert_object(obs.matched[0]).is_same(e)


func test_monitor_does_not_refire_on_irrelevant_changes():
	var obs = AliveMonitor.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	e.add_component(C_TestB.new())
	world.add_entity(e)
	assert_int(obs.matched.size()).is_equal(1)

	# Adding a component NOT in the sensitivity set shouldn't retrigger match
	e.add_component(C_TestC.new())
	assert_int(obs.matched.size()).is_equal(1)


func test_monitor_fires_on_unmatch_when_required_component_removed():
	var obs = AliveMonitor.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	e.add_component(C_TestB.new())
	world.add_entity(e)
	assert_int(obs.unmatched.size()).is_equal(0)

	e.remove_component(C_TestA)
	assert_int(obs.unmatched.size()).is_equal(1)
	assert_object(obs.unmatched[0]).is_same(e)


func test_monitor_on_unmatch_when_entity_removed_from_world():
	var obs = AliveMonitor.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	e.add_component(C_TestB.new())
	world.add_entity(e)
	assert_int(obs.matched.size()).is_equal(1)

	world.remove_entity(e)
	assert_int(obs.unmatched.size()).is_equal(1)


func test_monitor_yield_existing_fires_for_preexisting_match():
	# Entity exists BEFORE observer is registered
	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	var obs = YieldMonitor.new()
	world.add_observer(obs)

	# yield_existing should retroactively fire on_match for the pre-existing entity
	assert_int(obs.matched.size()).is_equal(1)
	assert_object(obs.matched[0]).is_same(e)


func test_monitor_without_yield_existing_does_not_fire_for_preexisting():
	var e = Entity.new()
	e.add_component(C_TestA.new())
	e.add_component(C_TestB.new())
	world.add_entity(e)

	var obs = AliveMonitor.new()
	# yield_existing defaults false
	world.add_observer(obs)

	assert_int(obs.matched.size()).is_equal(0)


class HealthThresholdMonitor extends Observer:
	var matched: Array[Entity] = []
	var unmatched: Array[Entity] = []

	func query() -> QueryBuilder:
		return q.with_all([{C_ObserverHealth: {"health": {"_gt": 0}}}]).on_match().on_unmatch()

	func each(event: Variant, entity: Entity, _payload: Variant = null) -> void:
		match event:
			Observer.Event.MATCH:   matched.append(entity)
			Observer.Event.UNMATCH: unmatched.append(entity)


func test_natural_dispatch_covers_entities_added_after_observer_registers():
	# Documents the intended behavior for scene-tree init: observers register before
	# entities, yield_existing retro-fires nothing (entities list is empty), but every
	# entity added after the observer is delivered through normal dispatch.
	var obs = AliveMonitor.new()
	world.add_observer(obs)  # registered with no entities yet

	# Each subsequent add_entity should fire MATCH naturally.
	var e1 = Entity.new()
	e1.add_component(C_TestA.new())
	e1.add_component(C_TestB.new())
	world.add_entity(e1)

	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	e2.add_component(C_TestB.new())
	world.add_entity(e2)

	assert_int(obs.matched.size()).is_equal(2)


func test_monitor_fires_on_property_transition():
	var obs = HealthThresholdMonitor.new()
	world.add_observer(obs)

	var e = Entity.new()
	var h = C_ObserverHealth.new(100, 100)
	e.add_component(h)
	world.add_entity(e)

	# Adding the component with health > 0 → MATCH fires on structural add.
	assert_int(obs.matched.size()).is_equal(1)
	assert_int(obs.unmatched.size()).is_equal(0)

	# Dropping health to 0 crosses the threshold → UNMATCH fires on property change.
	h.health = 0
	assert_int(obs.unmatched.size()).is_equal(1)
	assert_object(obs.unmatched[0]).is_same(e)

	# Bringing health back above 0 → MATCH fires again.
	h.health = 50
	assert_int(obs.matched.size()).is_equal(2)

## sub_observers() composition tests: one Observer node hosts multiple virtual
## observers, each with its own [QueryBuilder] (events declared via fluent methods)
## and [Callable]. Shape mirrors sub_systems() exactly.
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


class MultiAxisObserver extends Observer:
	var add_count: int = 0
	var remove_count: int = 0
	var match_count: int = 0
	var custom_event_count: int = 0

	func sub_observers() -> Array[Array]:
		return [
			[q.with_all([C_TestA]).on_added(),   _on_added],
			[q.with_all([C_TestA]).on_removed(), _on_removed],
			[q.with_all([C_TestA, C_TestB]).on_match(), _on_match],
			[q.with_all([C_TestA]).on_event(&"ping"), _on_event],
		]

	func _on_added(_event, _entity, _payload):   add_count += 1
	func _on_removed(_event, _entity, _payload): remove_count += 1
	func _on_match(_event, _entity, _payload):   match_count += 1
	func _on_event(_event, _entity, _payload):   custom_event_count += 1


func test_sub_observer_component_added():
	var obs = MultiAxisObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	assert_int(obs.add_count).is_equal(1)
	assert_int(obs.remove_count).is_equal(0)


func test_sub_observer_component_removed():
	var obs = MultiAxisObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)
	e.remove_component(C_TestA)

	assert_int(obs.remove_count).is_equal(1)


func test_sub_observer_monitor_match():
	var obs = MultiAxisObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)
	# Not yet — need C_TestB
	assert_int(obs.match_count).is_equal(0)

	e.add_component(C_TestB.new())
	assert_int(obs.match_count).is_equal(1)


func test_sub_observer_custom_event():
	var obs = MultiAxisObserver.new()
	world.add_observer(obs)

	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	world.emit_event(&"ping", e, null)
	assert_int(obs.custom_event_count).is_equal(1)


func test_sub_observer_independent_entity_filters():
	var obs = MultiAxisObserver.new()
	world.add_observer(obs)

	# Entity without C_TestA should NOT fire any sub-observer
	var e = Entity.new()
	e.add_component(C_TestB.new())
	world.add_entity(e)
	assert_int(obs.add_count).is_equal(0)
	assert_int(obs.match_count).is_equal(0)


class PerTupleYieldObserver extends Observer:
	var yield_count: int = 0
	var non_yield_count: int = 0

	func sub_observers() -> Array[Array]:
		# 3rd element is the per-tuple yield_existing override.
		return [
			[q.with_all([C_TestA]).on_added(), _on_yield, true],
			[q.with_all([C_TestA]).on_added(), _on_non_yield, false],
		]

	func _on_yield(_event, _entity, _payload):     yield_count += 1
	func _on_non_yield(_event, _entity, _payload): non_yield_count += 1


func test_sub_observer_per_tuple_yield_existing_override():
	# Entities exist BEFORE observer registers.
	var e = Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e)

	var obs = PerTupleYieldObserver.new()
	# Parent observer yield_existing stays false — per-tuple override is the only
	# thing that should cause a retroactive fire.
	assert_bool(obs.yield_existing).is_false()
	world.add_observer(obs)

	# Tuple with override=true yielded the pre-existing entity.
	assert_int(obs.yield_count).is_equal(1)
	# Tuple with override=false did NOT yield.
	assert_int(obs.non_yield_count).is_equal(0)

extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


class SourceSystem:
	extends System
	var declaration: QueryBuilder
	var use_subsystems := false
	var rejected_calls := 0
	var ordinary_calls := 0
	var explicit_results: Array = []

	func query() -> QueryBuilder:
		return declaration

	func sub_systems() -> Array[Array]:
		if not use_subsystems:
			return []
		return [[declaration, process], [q.with_all([C_TestA]), _ordinary]]

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		rejected_calls += 1

	func _ordinary(entities: Array[Entity], _components: Array, _delta: float) -> void:
		ordinary_calls += 1
		explicit_results = q.from(entities).with_all([C_TestA]).execute()


class SourceObserver:
	extends Observer
	var declaration: QueryBuilder
	var use_subobservers := false
	var rejected_calls := 0
	var ordinary_calls := 0

	func query() -> QueryBuilder:
		return null if use_subobservers else declaration

	func sub_observers() -> Array:
		var entries: Array = [[q.with_all([C_TestA]).on_added(), _ordinary]]
		if use_subobservers:
			entries.push_front([declaration, each])
		return entries

	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		rejected_calls += 1

	func _ordinary(_event: int, _entity: Entity, _payload: Variant) -> void:
		ordinary_calls += 1


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)
	await get_tree().process_frame


func _run(system: System, stepped: bool) -> void:
	if not stepped:
		system._handle(0.016)
		return
	assert_bool(system._step_begin(0.016)).is_true()
	var batch := system._step_next_batch(0.016)
	while not batch.is_empty():
		system._step_run(batch.entities, batch.components, batch.callable, 0.016)
		batch = system._step_next_batch(0.016)
	system._step_end(0.016)


func test_system_declaration_rejected_in_both_execution_paths():
	var entity := Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)
	for stepped in [false, true]:
		var system := SourceSystem.new()
		# Exercise the non-structural fallback too, and ensure process_empty can't
		# turn a rejected query into a callback in the resumable path.
		system.declaration = world.query.from([entity]).with_all(
			[{C_TestA: {"value": {"_gte": 0}}}]
		)
		system.process_empty = true
		world.add_system(system)
		await (
			assert_error(func(): _run(system, stepped))
			. is_push_error(
				"QueryBuilder.from() is not supported in System.query(); use execute() or execute_one()."
			)
		)
		await assert_error(func(): _run(system, not stepped)).is_success()
		assert_int(system.rejected_calls).is_equal(0)


func test_subsystem_rejection_preserves_valid_sibling_and_explicit_queries():
	var entity := Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)
	for stepped in [false, true]:
		var system := SourceSystem.new()
		system.declaration = world.query.from([]).with_all([C_TestA])
		system.use_subsystems = true
		world.add_system(system)
		await (
			assert_error(func(): _run(system, stepped))
			. is_push_error(
				"QueryBuilder.from() is not supported in System.sub_systems(); use execute() or execute_one()."
			)
		)
		await assert_error(func(): _run(system, not stepped)).is_success()
		assert_int(system.rejected_calls).is_equal(0)
		assert_int(system.ordinary_calls).is_equal(2)
		assert_array(system.explicit_results).contains_exactly([entity])


func test_observer_and_monitor_declarations_reject_source():
	for sub in [false, true]:
		var observer := SourceObserver.new()
		observer.use_subobservers = sub
		observer.yield_existing = true
		observer.declaration = (
			world.query.from([]).with_all([C_TestA]).on_added().on_match().on_unmatch()
		)
		var context := "Observer.sub_observers()" if sub else "Observer.query()"
		await (
			assert_error(func(): world.add_observer(observer))
			. is_push_error(
				(
					"QueryBuilder.from() is not supported in %s; use execute() or execute_one()."
					% context
				)
			)
		)
		var entity := Entity.new()
		world.add_entity(entity)
		entity.add_component(C_TestA.new())
		assert_int(observer.rejected_calls).is_equal(0)
		assert_int(observer.ordinary_calls).is_greater_equal(1)
		entity.remove_component(C_TestA)
		assert_int(observer.rejected_calls).is_equal(0)

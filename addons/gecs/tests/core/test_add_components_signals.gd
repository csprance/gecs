## Regression: Entity.add_components() (batch add) stored components without
## setting component.parent or connecting property_changed, so writes through
## emitting setters on batch-added components never reached the entity, the
## World, on_changed() observers or .changed() change detection. Fixed in 9.3.0.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


class PositionChangedObserver:
	extends Observer
	var events: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestPosition]).on_changed()

	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		events += 1


class ChangedPositionSystem:
	extends System
	var processed: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestPosition]).changed([C_TestPosition])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		processed += entities.size()


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_add_components_sets_parent():
	var e := Entity.new()
	world.add_entity(e)
	var pos := C_TestPosition.new()
	var vel := C_TestVelocity.new()

	e.add_components([pos, vel])

	assert_object(pos.parent).is_same(e)
	assert_object(vel.parent).is_same(e)


func test_add_components_forwards_property_changed_to_entity():
	var e := Entity.new()
	world.add_entity(e)
	var pos := C_TestPosition.new()
	e.add_components([pos])
	var seen := []
	e.component_property_changed.connect(
		func(_ent, comp, prop, old_value, new_value): seen.append([comp, prop, old_value, new_value])
	)

	pos.position = Vector3(1, 2, 3)

	assert_int(seen.size()).is_equal(1)
	assert_object(seen[0][0]).is_same(pos)
	assert_str(seen[0][1]).is_equal("position")
	assert_that(seen[0][2]).is_equal(Vector3.ZERO)
	assert_that(seen[0][3]).is_equal(Vector3(1, 2, 3))


func test_add_components_then_observer_on_changed_fires():
	var observer := PositionChangedObserver.new()
	world.add_observer(observer)
	var e := Entity.new()
	world.add_entity(e)
	var pos := C_TestPosition.new()
	e.add_components([pos])

	pos.position = Vector3(4, 5, 6)

	assert_int(observer.events).is_equal(1)


func test_add_components_then_changed_query_sees_write():
	var system := ChangedPositionSystem.new()
	world.add_system(system)
	var e := Entity.new()
	world.add_entity(e)
	var pos := C_TestPosition.new()
	e.add_components([pos])
	# First run: the add itself counts as a write, so the entity is processed.
	world.process(0.016)
	var after_add := system.processed
	# Second run without writes: skipped.
	world.process(0.016)
	assert_int(system.processed).is_equal(after_add)

	pos.position = Vector3(7, 8, 9)
	world.process(0.016)

	assert_int(system.processed).is_equal(after_add + 1)


func test_add_components_does_not_double_connect():
	var e := Entity.new()
	world.add_entity(e)
	var pos := C_TestPosition.new()
	e.add_component(pos)
	e.remove_component(C_TestPosition)
	e.add_components([pos])
	var count := [0]
	e.component_property_changed.connect(func(_ent, _c, _p, _o, _n): count[0] += 1)

	pos.position = Vector3.ONE

	assert_int(count[0]).is_equal(1)

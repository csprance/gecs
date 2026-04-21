## Relationship event dispatch tests: query().on_relationship_added/removed with
## optional relation-type filters.
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


class RelAddedObserver extends Observer:
	var added_count: int = 0
	var last_relationship: Relationship

	func query() -> QueryBuilder:
		return q.on_relationship_added()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.RELATIONSHIP_ADDED:
			added_count += 1
			last_relationship = payload


class RelRemovedObserver extends Observer:
	var removed_count: int = 0

	func query() -> QueryBuilder:
		return q.on_relationship_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.RELATIONSHIP_REMOVED:
			removed_count += 1


class FilteredRelObserver extends Observer:
	## Fires only for relationships whose relation component is C_TestA.
	var count: int = 0

	func query() -> QueryBuilder:
		return q.on_relationship_added([C_TestA])

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		count += 1


func test_on_relationship_added_fires_when_relationship_added():
	var obs = RelAddedObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	var rel = Relationship.new(C_TestA.new(), target)
	source.add_relationship(rel)

	assert_int(obs.added_count).is_equal(1)
	assert_object(obs.last_relationship).is_same(rel)


func test_on_relationship_removed_fires_when_relationship_removed():
	var obs = RelRemovedObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	var rel = Relationship.new(C_TestA.new(), target)
	source.add_relationship(rel)
	assert_int(obs.removed_count).is_equal(0)

	source.remove_relationship(rel)
	assert_int(obs.removed_count).is_equal(1)


class InstanceFilterRelObserver extends Observer:
	var count: int = 0

	func query() -> QueryBuilder:
		# Filter list contains an INSTANCE rather than the Script class — should still match.
		return q.on_relationship_added([C_TestA.new()])

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		count += 1


func test_relationship_type_filter_accepts_component_instance():
	var obs = InstanceFilterRelObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	# Filter with instance should behave the same as filter with Script class.
	source.add_relationship(Relationship.new(C_TestB.new(), target))
	assert_int(obs.count).is_equal(0)

	source.add_relationship(Relationship.new(C_TestA.new(), target))
	assert_int(obs.count).is_equal(1)


func test_relationship_type_filter_respected():
	var obs = FilteredRelObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	# A relationship with a DIFFERENT relation component (C_TestB) → observer should not fire
	source.add_relationship(Relationship.new(C_TestB.new(), target))
	assert_int(obs.count).is_equal(0)

	# A relationship with C_TestA → observer fires
	source.add_relationship(Relationship.new(C_TestA.new(), target))
	assert_int(obs.count).is_equal(1)

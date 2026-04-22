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


class PropertyQueryRelRemovedObserver extends Observer:
	## Fires only for C_TestA relationships whose value > 50.
	var removed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_relationship([
			Relationship.new({C_TestA: {"value": {"_gt": 50}}}, null)
		]).on_relationship_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.RELATIONSHIP_REMOVED:
			removed_count += 1


## P1-1 regression: match-before-removal now evaluates the removed relationship
## against the query rel's property criteria. A low-value removal must NOT fire
## REMOVED for an observer scoped to high-value rels.
func test_on_relationship_removed_property_query_evaluated_before_removal():
	var obs = PropertyQueryRelRemovedObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	# Low-value rel (10 !> 50): removing it must NOT fire REMOVED.
	var low = Relationship.new(C_TestA.new(10), target)
	source.add_relationship(low)
	source.remove_relationship(low)
	assert_int(obs.removed_count).is_equal(0)

	# High-value rel (100 > 50): removing it MUST fire REMOVED exactly once.
	var high = Relationship.new(C_TestA.new(100), target)
	source.add_relationship(high)
	source.remove_relationship(high)
	assert_int(obs.removed_count).is_equal(1)


class MultiRelRemovedObserver extends Observer:
	## Requires BOTH C_TestA and C_TestB relationships; fires on any removal.
	var removed_count: int = 0

	func query() -> QueryBuilder:
		return q.with_relationship([
			Relationship.new(C_TestA.new(), null),
			Relationship.new(C_TestB.new(), null),
		]).on_relationship_removed()

	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == Observer.Event.RELATIONSHIP_REMOVED:
			removed_count += 1


## P1-2 regression: Entity.remove_relationships emits per-rel as it removes, so
## multi-rel queries correctly see the first removal while the other rel is still
## present. The second removal correctly fails match-before (entity now missing
## the other rel) — that's the existing sequential semantic.
func test_batch_remove_relationships_fires_removed_for_multi_rel_query():
	var obs = MultiRelRemovedObserver.new()
	world.add_observer(obs)

	var source = Entity.new()
	var target = Entity.new()
	world.add_entity(source)
	world.add_entity(target)

	var rel_a = Relationship.new(C_TestA.new(), target)
	var rel_b = Relationship.new(C_TestB.new(), target)
	source.add_relationship(rel_a)
	source.add_relationship(rel_b)

	source.remove_relationships([rel_a, rel_b])

	# First removal fires: at that point rel_b is still present → match-before passes.
	# Second removal doesn't: entity no longer has A to satisfy with_all — correct.
	assert_int(obs.removed_count).is_equal(1)

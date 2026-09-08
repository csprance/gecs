## Regression: Entity.get_relationship() / get_relationships() drop relationships
## whose target was freed outside World.remove_entity(), but used to do so
## without notifying the World. The entity's archetype kept the stale pair key,
## so with_relationship() queries and Systems kept matching an entity whose
## relationship was already gone, and neither World.relationship_removed nor
## on_relationship_removed() observers fired. Also covers the companion World
## fix: a freed target has no slot key, so the removal handler must recompute
## the archetype instead of skipping the move (this bit remove_relationship()
## on a dangling target too). Fixed in 9.3.0.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


class RelationshipWatcherSystem:
	extends System
	var seen: Array = []

	func query() -> QueryBuilder:
		return q.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		seen = entities.duplicate()


class RelationshipRemovedObserver:
	extends Observer
	var events: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_TestB]).on_relationship_removed()

	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		events += 1


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func _make_entity(entity_name: String) -> Entity:
	var e := Entity.new()
	e.name = entity_name
	world.add_entity(e)
	return e


func _probe() -> Relationship:
	return Relationship.new(C_TestA.new(), null)


func test_get_relationship_dangling_target_notifies_world():
	var a := _make_entity("a")
	var b := _make_entity("b")
	a.add_relationship(Relationship.new(C_TestA.new(), b))
	var world_count := [0]
	var entity_count := [0]
	world.relationship_removed.connect(func(_e, _r): world_count[0] += 1)
	a.relationship_removed.connect(func(_e, _r): entity_count[0] += 1)

	# Free directly: bypasses remove_entity's _cleanup_relationships_to_target.
	b.free()
	var found = a.get_relationship(_probe())

	assert_object(found).is_null()
	assert_int(world_count[0]).is_equal(1)
	assert_int(entity_count[0]).is_equal(1)
	assert_array(a.relationships).is_empty()


func test_get_relationship_dangling_target_leaves_archetype():
	var a := _make_entity("a")
	var b := _make_entity("b")
	a.add_relationship(Relationship.new(C_TestA.new(), b))
	var watcher := RelationshipWatcherSystem.new()
	# process([]) must run on an empty match set so `seen` is rewritten each frame.
	watcher.process_empty = true
	world.add_system(watcher)
	world.process(0.016)
	assert_array(watcher.seen).contains([a])

	b.free()
	a.get_relationship(_probe())
	world.process(0.016)

	assert_array(watcher.seen).not_contains([a])
	assert_array(world.entity_to_archetype[a].relationship_types).is_empty()


func test_get_relationships_dangling_target_cleans_up():
	var a := _make_entity("a")
	var b := _make_entity("b")
	var c := _make_entity("c")
	a.add_relationship(Relationship.new(C_TestA.new(), b))
	a.add_relationship(Relationship.new(C_TestA.new(), c))
	var world_count := [0]
	world.relationship_removed.connect(func(_e, _r): world_count[0] += 1)

	b.free()
	var results := a.get_relationships(_probe())

	assert_int(results.size()).is_equal(1)
	assert_object(results[0].target).is_same(c)
	assert_int(a.relationships.size()).is_equal(1)
	assert_int(world_count[0]).is_equal(1)
	# The surviving pair key stays; only the dangling one is gone.
	assert_int(world.entity_to_archetype[a].relationship_types.size()).is_equal(1)


func test_remove_relationship_by_instance_with_dangling_target_moves_archetype():
	# Pattern matching deliberately never matches a freed target, so a dangling
	# relationship can only be removed by instance. That path notified the World,
	# but the World skipped the archetype move (no slot key for a freed target).
	var a := _make_entity("a")
	var b := _make_entity("b")
	var rel := Relationship.new(C_TestA.new(), b)
	a.add_relationship(rel)
	assert_int(world.entity_to_archetype[a].relationship_types.size()).is_equal(1)

	b.free()
	a.remove_relationship(rel)

	assert_array(a.relationships).is_empty()
	assert_array(world.entity_to_archetype[a].relationship_types).is_empty()


func test_observer_on_relationship_removed_fires_from_read_path():
	var a := _make_entity("a")
	a.add_component(C_TestB.new())
	var b := _make_entity("b")
	a.add_relationship(Relationship.new(C_TestA.new(), b))
	var observer := RelationshipRemovedObserver.new()
	world.add_observer(observer)

	b.free()
	a.get_relationship(_probe())

	assert_int(observer.events).is_equal(1)


func test_valid_relationships_are_untouched():
	var a := _make_entity("a")
	var b := _make_entity("b")
	var c := _make_entity("c")
	var to_b := Relationship.new(C_TestA.new(), b)
	a.add_relationship(to_b)
	a.add_relationship(Relationship.new(C_TestB.new(), c))
	var world_count := [0]
	world.relationship_removed.connect(func(_e, _r): world_count[0] += 1)

	var found = a.get_relationship(_probe())

	assert_object(found).is_same(to_b)
	assert_int(a.relationships.size()).is_equal(2)
	assert_int(world_count[0]).is_equal(0)


func test_read_path_on_disabled_entity_does_not_crash():
	var a := _make_entity("a")
	var b := _make_entity("b")
	a.add_relationship(Relationship.new(C_TestA.new(), b))
	world.disable_entity(a)
	var entity_count := [0]
	a.relationship_removed.connect(func(_e, _r): entity_count[0] += 1)

	b.free()
	var found = a.get_relationship(_probe())

	assert_object(found).is_null()
	assert_int(entity_count[0]).is_equal(1)
	assert_array(a.relationships).is_empty()

## Relationship Performance Tests
## Measures Entity.get_relationships(pattern) — the hot path used by the
## sheep-herding example's flocking helper. Compares pre-allocated vs
## per-call pattern (Relationship + Component) allocation at different
## flock sizes.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World

const NEIGHBORS: int = 10


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Build [param count] entities, each with [constant NEIGHBORS] outgoing
## C_TestA-typed relationships pointing to distinct other entities. Simulates
## the flocking topology (each sheep has K flockmates).
## Entities are added to the scene tree (default) so the GECS editor-debugger
## can resolve paths on relationship events when `ECS.debug` is true.
func _setup_relationship_web(count: int) -> Array:
	var entities: Array = []
	for i in count:
		var e := Entity.new()
		e.name = "RelEntity_%d" % i
		world.add_entity(e)
		entities.append(e)

	for i in count:
		var self_e: Entity = entities[i]
		for k in NEIGHBORS:
			var other_idx := (i + k + 1) % count
			if other_idx == i:
				continue
			self_e.add_relationship(Relationship.new(C_TestA.new(), entities[other_idx]))
	return entities


## Hot path: one get_relationships call per entity per frame, with a
## freshly-allocated relationship pattern each call (the pre-optimization
## pattern — allocates Relationship + Component every call).
func test_get_relationships_per_call_probe(
	scale: int,
	test_parameters := [[100], [1000]],
) -> void:
	var entities := _setup_relationship_web(scale)

	var time_ms := PerfHelpers.time_it(
		func():
			for e in entities:
				var probe := Relationship.new(C_TestA.new(), null)
				var _rels: Array = e.get_relationships(probe)
	)
	PerfHelpers.record_result("relationship_get_relationships_per_call", scale, time_ms)


## Hot path: same workload, but the relationship pattern is allocated ONCE
## and reused across all get_relationships calls (the post-optimization
## approach used in example_sheep_herding/lib/flocking.gd as R_AnyFlockmate).
func test_get_relationships_cached_probe(
	scale: int,
	test_parameters := [[100], [1000]],
) -> void:
	var entities := _setup_relationship_web(scale)

	var probe := Relationship.new(C_TestA.new(), null)
	var time_ms := PerfHelpers.time_it(
		func():
			for e in entities:
				var _rels: Array = e.get_relationships(probe)
	)
	PerfHelpers.record_result("relationship_get_relationships_cached", scale, time_ms)

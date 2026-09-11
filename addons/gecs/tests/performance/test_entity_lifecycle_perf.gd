## Comparable lifecycle measurements. No timing assertions: hardware and scheduling vary.
## See docs/ENTITY_LIFECYCLE_PERFORMANCE.md for boundaries and interpretation.
# GdUnit discovers parameter sets by this exact argument name.
# gdlint: disable=unused-argument
extends GdUnitTestSuite

const WARMUP := 2
const RUNS := 7
const FRAME_RUNS := 30

var world: World


func before_test():
	world = World.new()
	Engine.get_main_loop().root.add_child(world)
	ECS.world = world


func after_test():
	world.purge(false)
	ECS.world = null
	world.queue_free()
	await get_tree().process_frame


## Same scene-tree behavior, component composition and entity count for every API.
## Nodes provide an engine-only floor; resources measures initialization copying.
func test_lifecycle_phases(scale: int, test_parameters := [[100], [1000]]):
	for profile in ["nodes", "empty", "components", "resources"]:
		var modes := ["loop"] if profile == "nodes" else ["loop", "batch", "commands"]
		for mode in modes:
			await _measure_cycles(scale, profile, mode, RUNS)
			world.purge(false)
			await get_tree().process_frame


## Longer consecutive churn sample: includes a frame boundary and deferred deletion.
func test_churn_frames(scale: int, test_parameters := [[100], [1000]]):
	for mode in ["loop", "batch"]:
		await _measure_cycles(scale, "components", mode, FRAME_RUNS)
		world.purge(false)
		await get_tree().process_frame


## Same churn with 1,000 live residents left in the world throughout each run.
func test_churn_with_residents(scale: int, test_parameters := [[100], [1000]]):
	for mode in ["loop", "batch"]:
		world.add_entities(_make_nodes(1000, "components"))
		await _measure_cycles(scale, "components", mode, FRAME_RUNS)
		world.purge(false)
		await get_tree().process_frame


## Explicit opt-in keeps the normal suite short; uses identical methodology.
func test_large_burst():
	if OS.get_environment("GECS_CHURN_LARGE") != "1":
		return
	for mode in ["loop", "batch"]:
		await _measure_cycles(10000, "components", mode, RUNS)
		world.purge(false)
		await get_tree().process_frame


func _make_nodes(scale: int, profile: String) -> Array:
	var nodes: Array = []
	for i in scale:
		var node = Node.new() if profile == "nodes" else Entity.new()
		if profile == "components":
			node.add_component(C_TestA.new())
			node.add_component(C_TestB.new())
		elif profile == "resources":
			node.component_resources.append_array([C_TestA.new(), C_TestB.new()])
		nodes.append(node)
	return nodes


func _add(nodes: Array, profile: String, mode: String):
	if profile == "nodes":
		for node in nodes:
			world.add_child(node)
	elif mode == "batch":
		world.add_entities(nodes)
	elif mode == "commands":
		var commands := CommandBuffer.new(world)
		for entity in nodes:
			commands.add_entity(entity)
		commands.execute()
	else:
		for entity in nodes:
			world.add_entity(entity)


func _remove(nodes: Array, profile: String, mode: String):
	if profile == "nodes":
		for node in nodes:
			node.queue_free()
	elif mode == "batch":
		world.remove_entities(nodes)
	elif mode == "commands":
		var commands := CommandBuffer.new(world)
		for entity in nodes:
			commands.remove_entity(entity)
		commands.execute()
	else:
		for entity in nodes:
			world.remove_entity(entity)


func _measure_cycles(scale: int, profile: String, mode: String, runs: int):
	var samples := {"create": [], "add": [], "remove": [], "drain": [], "cycle": []}
	var residents := world.entities.size()
	# Start at a known boundary. Each next sample begins after the prior deletion flush.
	await get_tree().process_frame
	for iteration in WARMUP + runs:
		var start := Time.get_ticks_usec()
		var nodes := _make_nodes(scale, profile)
		var created := Time.get_ticks_usec()
		_add(nodes, profile, mode)
		var added := Time.get_ticks_usec()
		_remove(nodes, profile, mode)
		var removed := Time.get_ticks_usec()
		await get_tree().process_frame
		var drained := Time.get_ticks_usec()
		assert_int(nodes.size()).is_equal(scale)
		if nodes.size() != scale:
			return  # Never publish partial work as a successful timing sample.
		if iteration >= WARMUP:
			samples.create.append((created - start) / 1000.0)
			samples.add.append((added - created) / 1000.0)
			samples.remove.append((removed - added) / 1000.0)
			samples.drain.append((drained - removed) / 1000.0)
			samples.cycle.append((drained - start) / 1000.0)
		# Outside all measured intervals. Verify deletion actually completed.
		assert_int(world.entities.size()).is_equal(residents)
		if world.entities.size() != residents:
			return
		for node in nodes:
			assert_bool(is_instance_valid(node)).is_false()
			if is_instance_valid(node):
				return
	var kind := "churn" if runs == FRAME_RUNS else "phases"
	if residents > 0:
		kind = "resident_churn"
	for phase in samples:
		var values: Array[float] = []
		values.assign(samples[phase])
		PerfHelpers.record_samples(
			"lifecycle_%s_%s_%s_%s" % [kind, profile, mode, phase],
			scale,
			values,
			WARMUP,
			{
				"profile": profile,
				"mode": mode,
				"phase": phase,
				"in_tree": true,
				"components": 2 if profile in ["components", "resources"] else 0,
				"archetypes_after": world.archetypes.size(),
				"entities_per_cycle": scale,
				"residents": residents
			}
		)


## Pool activation is an alternative contract: entities/IDs/components remain alive.
## Game-specific reset, visuals, collision and timers are deliberately not simulated.
func test_pool_activation(scale: int, test_parameters := [[100], [1000]]):
	var nodes := _make_nodes(scale, "components")
	world.add_entities(nodes)
	world.disable_entities(nodes)
	var toggle := func():
		for entity in nodes:
			world.enable_entity(entity)
		world.disable_entities(nodes)
	PerfHelpers.bench(
		"lifecycle_pool_enable_disable",
		scale,
		toggle,
		Callable(),
		Callable(),
		WARMUP,
		RUNS,
		{"in_tree": true, "components": 2, "preserves_identity": true, "includes_game_reset": false}
	)
	assert_int(world.entities.size()).is_equal(scale)
	assert_int(world.query.with_all([C_TestA]).enabled().execute().size()).is_equal(0)


## Isolate removal's relationship scan using unrelated victims. Relationship setup
## is untimed, and each repetition starts with the same number of live archetypes.
func test_removal_with_relationship_archetypes(
	relationship_count: int, test_parameters := [[0], [100], [1000]]
):
	for i in relationship_count:
		var target := Entity.new()
		var holder := Entity.new()
		world.add_entities([target, holder])
		holder.add_relationship(Relationship.new(C_TestA.new(), target))
	var victims: Array = []
	var setup := func():
		victims.clear()
		for i in 100:
			var entity := Entity.new()
			world.add_entity(entity, null, false)
			victims.append(entity)
	PerfHelpers.bench(
		"lifecycle_unrelated_removal_relationships_%d" % relationship_count,
		100,
		func(): world.remove_entities(victims),
		setup,
		Callable(),
		WARMUP,
		RUNS,
		{
			"in_tree": false,
			"relationship_archetypes": relationship_count,
			"victims": 100,
			"victims_are_relationship_targets": false
		}
	)
	assert_int(world.entities.size()).is_equal(relationship_count * 2)

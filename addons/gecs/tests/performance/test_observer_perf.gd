## Observer Performance Tests
## Compares observers vs traditional systems for different use cases
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Setup entities with position and velocity for movement tests
func setup_velocity_entities(count: int) -> void:
	for i in count:
		var entity = Entity.new()
		entity.name = "VelocityEntity_%d" % i
		entity.add_component(C_TestPosition.new(Vector3(i, 0, 0)))
		entity.add_component(C_TestVelocity.new(Vector3(randf() * 10, randf() * 10, randf() * 10)))
		world.add_entity(entity, null, false)


## Setup entities for observer add/remove tests
func setup_observer_test_entities(count: int) -> void:
	for i in count:
		var entity = Entity.new()
		entity.name = "ObserverTestEntity_%d" % i
		entity.add_component(C_ObserverTest.new(i))
		world.add_entity(entity, null, false)


## Test traditional system approach for continuous processing (like velocity)
## This is the IDEAL use case for systems - they excel at continuous per-frame processing
func test_system_continuous_processing(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var system = S_VelocitySystem.new()
	world.add_system(system)

	var time_ms = PerfHelpers.time_it(func():
		# Simulate 60 frames of processing
		for i in range(60):
			world.process(0.016)
	)

	PerfHelpers.record_result("system_continuous_velocity", scale, time_ms)
	prints("System processed %d entities across 60 frames" % system.process_count)
	world.purge(false)


## Test observer detecting component additions
## This is an IDEAL use case for observers - they excel at reacting to state changes
func test_observer_component_additions(scale: int, test_parameters := [[100], [1000], [10000]]):
	var observer = O_PerformanceTest.new()
	world.add_observer(observer)

	var time_ms = PerfHelpers.time_it(func():
		# Add components to entities (observers react to additions)
		for i in range(scale):
			var entity = Entity.new()
			entity.add_component(C_ObserverTest.new(i))
			world.add_entity(entity, null, false)
	)

	PerfHelpers.record_result("observer_component_additions", scale, time_ms)
	prints("Observer detected %d additions" % observer.added_count)
	assert_int(observer.added_count).is_equal(scale)
	world.purge(false)


## Test observer detecting component removals
## Another IDEAL use case for observers - reacting to cleanup/removal events
func test_observer_component_removals(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var observer = O_PerformanceTest.new()
	world.add_observer(observer)

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Remove components (observers react to removals)
		for entity in entities:
			entity.remove_component(C_ObserverTest)
	)

	PerfHelpers.record_result("observer_component_removals", scale, time_ms)
	prints("Observer detected %d removals" % observer.removed_count)
	assert_int(observer.removed_count).is_equal(scale)
	world.purge(false)


## Test observer detecting property changes
## Good use case for observers - reacting to specific property changes
func test_observer_property_changes(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var observer = O_PerformanceTest.new()
	world.add_observer(observer)
	observer.reset_counts()

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Change properties (observers react to changes)
		for entity in entities:
			var comp = entity.get_component(C_ObserverTest)
			comp.value = comp.value + 1  # Triggers property_changed signal
	)

	PerfHelpers.record_result("observer_property_changes", scale, time_ms)
	prints("Observer detected %d property changes" % observer.changed_count)
	assert_int(observer.changed_count).is_equal(scale)
	world.purge(false)


## Test system approach for batch property reads
## Systems are better for batch operations without individual reactions
func test_system_batch_property_reads(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var system = PerformanceTestSystem.new()
	world.add_system(system)

	var time_ms = PerfHelpers.time_it(func():
		# Single process call reads all entities
		world.process(0.016)
	)

	PerfHelpers.record_result("system_batch_property_reads", scale, time_ms)
	prints("System processed %d entities in batch" % system.process_count)
	world.purge(false)


## Test observer overhead with multiple property changes per entity
## Shows cost of observers when entities change frequently
func test_observer_frequent_changes(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var observer = O_PerformanceTest.new()
	world.add_observer(observer)
	observer.reset_counts()

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Each entity changes multiple times
		for entity in entities:
			var comp = entity.get_component(C_ObserverTest)
			for j in range(10):  # 10 changes per entity
				comp.value = comp.value + 1
	)

	PerfHelpers.record_result("observer_frequent_changes", scale, time_ms)
	prints("Observer detected %d property changes (%d entities × 10 changes)" % [observer.changed_count, scale])
	assert_int(observer.changed_count).is_equal(scale * 10)
	world.purge(false)


## Test system processing the same frequent changes scenario
## Compares continuous polling vs reactive observation
func test_system_simulating_frequent_changes(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var system = PerformanceTestSystem.new()
	world.add_system(system)

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Make the changes
		for entity in entities:
			var comp = entity.get_component(C_ObserverTest)
			for j in range(10):
				# Direct property change without signal
				comp.value = comp.value + 1

		# System processes once (doesn't know about individual changes)
		world.process(0.016)
	)

	PerfHelpers.record_result("system_simulating_frequent_changes", scale, time_ms)
	prints("System processed %d entities once after changes" % system.process_count)
	world.purge(false)


## Test multiple observers watching the same component
## Shows overhead of multiple reactive systems
func test_multiple_observers_same_component(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var observer1 = O_PerformanceTest.new()
	var observer2 = O_PerformanceTest.new()
	var observer3 = O_PerformanceTest.new()
	world.add_observers([observer1, observer2, observer3])

	observer1.reset_counts()
	observer2.reset_counts()
	observer3.reset_counts()

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Change properties (all 3 observers react)
		for entity in entities:
			var comp = entity.get_component(C_ObserverTest)
			comp.value = comp.value + 1
	)

	PerfHelpers.record_result("multiple_observers_same_component", scale, time_ms)
	prints("3 observers each detected %d changes" % observer1.changed_count)
	assert_int(observer1.changed_count).is_equal(scale)
	assert_int(observer2.changed_count).is_equal(scale)
	assert_int(observer3.changed_count).is_equal(scale)
	world.purge(false)


## Test observer query filtering performance
## Shows cost of query evaluation for observers
func test_observer_with_complex_query(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Create entities with varying component combinations
	for i in range(scale):
		var entity = Entity.new()
		entity.add_component(C_ObserverTest.new(i))
		if i % 2 == 0:
			entity.add_component(C_ObserverHealth.new())
		world.add_entity(entity, null, false)

	# Observer with complex query (needs both components)
	var observer = O_HealthObserver.new()
	world.add_observer(observer)
	observer.reset()

	var entities_matching = world.query.with_all([C_ObserverTest, C_ObserverHealth]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Change health on matching entities
		for entity in entities_matching:
			var health = entity.get_component(C_ObserverHealth)
			health.health = health.health - 1
	)

	PerfHelpers.record_result("observer_complex_query", scale, time_ms)
	prints("Observer with complex query detected %d changes (out of %d total entities)" % [observer.health_changed_count, scale])
	world.purge(false)


## Test baseline: Empty observer overhead
## Measures the cost of just having observers in the system
func test_observer_baseline_overhead(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	# Add observer but don't trigger it
	var observer = O_PerformanceTest.new()
	world.add_observer(observer)

	var entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms = PerfHelpers.time_it(func():
		# Make changes WITHOUT triggering property_changed signals
		for entity in entities:
			var comp = entity.get_component(C_ObserverTest)
			# Direct property access without signal emission
			comp.value = comp.value + 1
	)

	PerfHelpers.record_result("observer_baseline_overhead", scale, time_ms)
	prints("Made %d changes without triggering observer" % scale)
	assert_int(observer.changed_count).is_equal(scale)  # Observer should have triggered
	world.purge(false)


## Test comparison: Observer vs System for sporadic changes
## Real-world scenario: only 10% of entities change per frame
func test_observer_vs_system_sporadic_changes(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_observer_test_entities(scale)

	var observer = O_PerformanceTest.new()
	world.add_observer(observer)
	observer.reset_counts()

	var entities = world.query.with_all([C_ObserverTest]).execute()
	var changes_per_frame = max(1, scale / 10)  # 10% of entities change

	var time_ms_observer = PerfHelpers.time_it(func():
		# Simulate 60 frames where only 10% of entities change per frame
		for frame in range(60):
			for i in range(changes_per_frame):
				var entity = entities[i % scale]
				var comp = entity.get_component(C_ObserverTest)
				comp.value = comp.value + 1  # Triggers observer
	)

	PerfHelpers.record_result("observer_sporadic_changes", scale, time_ms_observer)
	prints("Observer detected %d sporadic changes over 60 frames" % observer.changed_count)

	# Now test with system approach
	world.purge(false)
	setup_observer_test_entities(scale)

	var system = PerformanceTestSystem.new()
	world.add_system(system)

	entities = world.query.with_all([C_ObserverTest]).execute()

	var time_ms_system = PerfHelpers.time_it(func():
		# Same scenario but system processes ALL entities every frame
		for frame in range(60):
			# Make the same changes
			for i in range(changes_per_frame):
				var entity = entities[i % scale]
				var comp = entity.get_component(C_ObserverTest)
				comp.value = comp.value + 1

			# System processes ALL entities every frame
			world.process(0.016)
	)

	PerfHelpers.record_result("system_sporadic_changes", scale, time_ms_system)
	prints("System processed %d total entities over 60 frames (even though only 10%% changed)" % system.process_count)
	world.purge(false)

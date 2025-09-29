## Large-scale integration performance tests for GECS
## Tests realistic game scenarios with multiple systems and complex interactions
class_name PerformanceTestIntegration
extends PerformanceTestBase

var test_world: World
var test_entities: Array[Entity] = []
var movement_system: PerformanceTestSystem
var collision_system: ComplexPerformanceTestSystem
var render_system: PerformanceTestSystem


func before_test():
	super.before_test()
	test_world = create_test_world()
	test_entities.clear()

	# Create multiple systems for realistic scenarios
	movement_system = PerformanceTestSystem.new()
	movement_system.name = "MovementSystem"
	movement_system.group = "physics"

	collision_system = ComplexPerformanceTestSystem.new()
	collision_system.name = "CollisionSystem"
	collision_system.group = "physics"

	render_system = PerformanceTestSystem.new()
	render_system.name = "RenderSystem"
	render_system.group = "rendering"


func after_test():
	# Clean up test entities
	for entity in test_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	test_entities.clear()

	# Clean up systems
	var systems = [movement_system, collision_system, render_system]
	for system in systems:
		if system and is_instance_valid(system):
			system.queue_free()

	if test_world:
		test_world.purge()
		test_world = null


## Create a realistic game scenario with diverse entity types
func setup_game_scenario(entity_count: int):
	# Create different types of entities found in typical games
	# Player entities (1% of total)
	var player_count = max(1, entity_count / 100)
	for i in player_count:
		var entity = Entity.new()
		entity.name = "Player_%d" % i
		entity.add_component(C_TestA.new()) # Transform
		entity.add_component(C_TestB.new()) # Input/Controller
		entity.add_component(C_TestC.new()) # Health
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	# Enemy entities (20% of total)
	var enemy_count = entity_count / 5
	for i in enemy_count:
		var entity = Entity.new()
		entity.name = "Enemy_%d" % i
		entity.add_component(C_TestA.new()) # Transform
		entity.add_component(C_TestC.new()) # Health
		if i % 2 == 0:
			entity.add_component(C_TestB.new()) # AI
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	# Projectile entities (30% of total)
	var projectile_count = (entity_count * 3) / 10
	for i in projectile_count:
		var entity = Entity.new()
		entity.name = "Projectile_%d" % i
		entity.add_component(C_TestA.new()) # Transform
		if i % 3 == 0:
			entity.add_component(C_TestB.new()) # Physics
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	# Environment/Static entities (49% of total)
	var static_count = entity_count - player_count - enemy_count - projectile_count
	for i in static_count:
		var entity = Entity.new()
		entity.name = "Static_%d" % i
		entity.add_component(C_TestA.new()) # Transform
		if i % 4 == 0:
			entity.add_component(C_TestD.new()) # Renderer
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)


## Test realistic game loop performance
func test_realistic_game_loop_medium_scale():
	setup_game_scenario(MEDIUM_SCALE)

	# Add systems in typical game order
	test_world.add_system(movement_system)
	test_world.add_system(collision_system)
	test_world.add_system(render_system)

	var simulate_game_frame = func():
		# Simulate a typical game frame with multiple system groups
		test_world.process(0.016, "physics") # Physics systems
		test_world.process(0.016, "rendering") # Rendering systems
		test_world.process(0.016) # All remaining systems

	benchmark("Realistic_Game_Loop_Medium_Scale", simulate_game_frame)
	print_performance_results()

	# A realistic game frame should complete in under 16ms for 60 FPS
	assert_performance_threshold(
		"Realistic_Game_Loop_Medium_Scale", 16.0, "Game loop too slow for 60 FPS"
	)


func test_realistic_game_loop_large_scale():
	setup_game_scenario(LARGE_SCALE)

	# Add systems in typical game order
	test_world.add_system(movement_system)
	test_world.add_system(collision_system)
	test_world.add_system(render_system)

	var simulate_game_frame = func():
		# Simulate a typical game frame
		test_world.process(0.016, "physics")
		test_world.process(0.016, "rendering")
		test_world.process(0.016)

	benchmark("Realistic_Game_Loop_Large_Scale", simulate_game_frame)
	print_performance_results()

	# Large scale should still be reasonable (allowing more time for 10k entities)
	assert_performance_threshold(
		"Realistic_Game_Loop_Large_Scale", 50.0, "Large scale game loop too slow"
	)


## Test dynamic entity spawning/despawning during gameplay
func test_dynamic_entity_management():
	setup_game_scenario(SMALL_SCALE)
	test_world.add_system(movement_system)
	test_world.add_system(collision_system)

	var dynamic_spawn_despawn = func():
		# Simulate spawning projectiles during gameplay
		var new_entities: Array[Entity] = []
		for i in 20:
			var entity = Entity.new()
			entity.name = "DynamicProjectile_%d" % i
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			new_entities.append(entity)
			test_world.add_entity(entity, null, false)

		# Process systems with new entities
		test_world.process(0.016)

		# Remove some entities (simulate projectiles hitting targets)
		for i in range(0, 10):
			test_world.remove_entity(new_entities[i])

	benchmark("Dynamic_Entity_Management", dynamic_spawn_despawn)
	print_performance_results()

	# Dynamic entity management should be fast
	assert_performance_threshold(
		"Dynamic_Entity_Management", 20.0, "Dynamic entity management too slow"
	)


## Test component changes during processing
func test_dynamic_component_changes():
	setup_game_scenario(MEDIUM_SCALE)
	test_world.add_system(movement_system)
	test_world.add_system(collision_system)

	var dynamic_component_changes = func():
		# Simulate adding/removing components during gameplay
		var change_count = 0
		for entity in test_entities:
			if change_count >= 50: # Limit changes for consistent testing
				break

			if entity.has_component(C_TestC):
				var comp = entity.get_component(C_TestC)
				entity.remove_component(comp)
				change_count += 1
			elif change_count < 25:
				entity.add_component(C_TestC.new())
				change_count += 1

		# Process systems after changes
		test_world.process(0.016)

	benchmark("Dynamic_Component_Changes", dynamic_component_changes)
	print_performance_results()

	# Component changes should not significantly slow down processing
	assert_performance_threshold(
		"Dynamic_Component_Changes", 30.0, "Dynamic component changes too slow"
	)


## Test complex query scenarios during gameplay
func test_complex_query_scenarios():
	setup_game_scenario(MEDIUM_SCALE)

	var complex_queries = func():
		# Simulate various queries that might happen during gameplay
		# Find all players
		var players = test_world.query.with_all([C_TestA, C_TestB, C_TestC]).execute()

		# Find all enemies without AI
		var dumb_enemies = (
			test_world.query.with_all([C_TestA, C_TestC]).with_none([C_TestB]).execute()
		)

		# Find all moving objects
		var moving_objects = test_world.query.with_all([C_TestA]).with_any([C_TestB]).execute()

		# Find all static renderable objects
		var static_rendered = test_world.query.with_all([C_TestA, C_TestD]).execute()

		# Verify we got some results
		(
			assert_that(
				(
					players.size()
					+ dumb_enemies.size()
					+ moving_objects.size()
					+ static_rendered.size()
				)
			)
			.is_greater(0)
		)

	benchmark("Complex_Query_Scenarios", complex_queries)
	print_performance_results()

	# Complex queries should be fast even with many entities
	assert_performance_threshold(
		"Complex_Query_Scenarios", 25.0, "Complex query scenarios too slow"
	)


## Test memory pressure scenarios
func test_memory_pressure_scenario():
	# Create a large number of entities with many components
	var large_entity_count = LARGE_SCALE

	var memory_pressure_test = func():
		var entities: Array[Entity] = []

		# Create many entities quickly
		for i in large_entity_count:
			var entity = Entity.new()
			entity.name = "MemoryPressureEntity_%d" % i

			# Add multiple components to increase memory usage
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			entity.add_component(C_TestC.new())
			entity.add_component(C_TestD.new())

			entities.append(entity)
			test_world.add_entity(entity, null, false)

		# Add systems and process
		test_world.add_system(movement_system)
		test_world.add_system(collision_system)
		test_world.process(0.016)

		# Clean up entities
		for entity in entities:
			test_world.remove_entity(entity)

	benchmark("Memory_Pressure_Scenario", memory_pressure_test)
	print_performance_results()

	# Memory pressure scenario should complete in reasonable time
	assert_performance_threshold(
		"Memory_Pressure_Scenario", 500.0, "Memory pressure scenario too slow"
	)


## Test sustained performance over multiple frames
func test_sustained_performance():
	setup_game_scenario(MEDIUM_SCALE)
	test_world.add_system(movement_system)
	test_world.add_system(collision_system)
	test_world.add_system(render_system)

	var sustained_frames = func():
		# Simulate 60 frames (1 second at 60 FPS)
		for frame in 60:
			test_world.process(0.016, "physics")
			test_world.process(0.016, "rendering")

			# Occasionally spawn/despawn entities
			if frame % 10 == 0:
				var entity = Entity.new()
				entity.name = "SustainedEntity_%d" % frame
				entity.add_component(C_TestA.new())
				test_world.add_entity(entity, null, false)

			# Occasionally modify components
			if frame % 15 == 0 and test_entities.size() > 0:
				var entity = test_entities[frame % test_entities.size()]
				if not entity.has_component(C_TestD):
					entity.add_component(C_TestD.new())

	benchmark("Sustained_Performance_60_Frames", sustained_frames)
	print_performance_results()

	# 60 frames should complete in reasonable time (allowing for some overhead)
	assert_performance_threshold(
		"Sustained_Performance_60_Frames", 1000.0, "Sustained performance too slow"
	)


## Test worst-case query performance
func test_worst_case_query_performance():
	# Create entities where most queries will have to check many entities
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "WorstCaseEntity_%d" % i

		# Most entities have most components (worst case for exclusion queries)
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		entity.add_component(C_TestC.new())
		if i % 100 != 0: # Only 1% don't have TestD
			entity.add_component(C_TestD.new())

		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var worst_case_queries = func():
		# Query that excludes component most entities have (worst case)
		var rare_entities = test_world.query.with_all([C_TestA]).with_none([C_TestD]).execute()

		# Complex query with many conditions
		var complex_query = (
			test_world
			.query
			.with_all([C_TestA, C_TestB])
			.with_any([C_TestC, C_TestD])
			.with_none([C_TestE])
			.execute()
		)

		# Verify we got expected results
		assert_that(rare_entities.size()).is_between(MEDIUM_SCALE / 100 - MEDIUM_SCALE / 50, MEDIUM_SCALE / 100 + MEDIUM_SCALE / 50)

	benchmark("Worst_Case_Query_Performance", worst_case_queries)
	print_performance_results()

	# Even worst-case queries should be reasonable
	assert_performance_threshold(
		"Worst_Case_Query_Performance", 40.0, "Worst-case query performance too slow"
	)


## Run all integration performance tests
func after():
	# Save results
	save_performance_results("res://reports/integration_performance_results.json")

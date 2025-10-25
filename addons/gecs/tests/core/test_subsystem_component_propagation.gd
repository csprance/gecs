extends GdUnitTestSuite

## Test suite for subsystem component modification propagation
## Tests that when subsystem A modifies entity components (causing archetype moves),
## subsystem B can see those changes in the same frame

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## ===============================
## COMPONENT ADDITION PROPAGATION
## ===============================

## Test that components added by subsystem A are visible to subsystem B in the same frame
func test_subsystem_component_addition_propagation():
	# Create entities with only component A
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	entity1.add_component(C_OrderTestA.new())
	entity2.add_component(C_OrderTestA.new())
	entity3.add_component(C_OrderTestA.new())
	world.add_entities([entity1, entity2, entity3])

	# Create system with two subsystems:
	# Subsystem 1: Find entities with A, add B
	# Subsystem 2: Find entities with B, increment counter
	var system = ComponentAdditionPropagationSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Subsystem 1 processed 3 entities (added B to all of them)
	assert_int(system.subsystem1_count).is_equal(3)

	# Verify: Subsystem 2 processed 3 entities (saw all B components added by subsystem 1)
	assert_int(system.subsystem2_count).is_equal(3)

	# Verify: All entities now have both A and B
	assert_bool(entity1.has_component(C_OrderTestA)).is_true()
	assert_bool(entity1.has_component(C_OrderTestB)).is_true()
	assert_bool(entity2.has_component(C_OrderTestA)).is_true()
	assert_bool(entity2.has_component(C_OrderTestB)).is_true()
	assert_bool(entity3.has_component(C_OrderTestA)).is_true()
	assert_bool(entity3.has_component(C_OrderTestB)).is_true()


## Test that components removed by subsystem A are not visible to subsystem B in the same frame
func test_subsystem_component_removal_propagation():
	# Create entities with both A and B
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	entity1.add_component(C_OrderTestA.new())
	entity1.add_component(C_OrderTestB.new())
	entity2.add_component(C_OrderTestA.new())
	entity2.add_component(C_OrderTestB.new())
	entity3.add_component(C_OrderTestA.new())
	entity3.add_component(C_OrderTestB.new())
	world.add_entities([entity1, entity2, entity3])

	# Create system with two subsystems:
	# Subsystem 1: Find entities with A, remove A
	# Subsystem 2: Find entities with A, increment counter (should see none)
	var system = ComponentRemovalPropagationSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Subsystem 1 processed 3 entities (removed A from all of them)
	assert_int(system.subsystem1_count).is_equal(3)

	# Verify: Subsystem 2 processed 0 entities (no entities have A anymore)
	assert_int(system.subsystem2_count).is_equal(0)

	# Verify: All entities still have B but not A
	assert_bool(entity1.has_component(C_OrderTestA)).is_false()
	assert_bool(entity1.has_component(C_OrderTestB)).is_true()
	assert_bool(entity2.has_component(C_OrderTestA)).is_false()
	assert_bool(entity2.has_component(C_OrderTestB)).is_true()
	assert_bool(entity3.has_component(C_OrderTestA)).is_false()
	assert_bool(entity3.has_component(C_OrderTestB)).is_true()


## Test that component modifications causing archetype moves are handled correctly
func test_subsystem_archetype_move_propagation():
	# Create entities with different starting components
	var entity1 = Entity.new()  # Has A
	var entity2 = Entity.new()  # Has A
	var entity3 = Entity.new()  # Has B
	var entity4 = Entity.new()  # Has B
	entity1.add_component(C_OrderTestA.new())
	entity2.add_component(C_OrderTestA.new())
	entity3.add_component(C_OrderTestB.new())
	entity4.add_component(C_OrderTestB.new())
	world.add_entities([entity1, entity2, entity3, entity4])

	# Create system with three subsystems:
	# Subsystem 1: Find entities with A, add B (archetype move from A to A+B)
	# Subsystem 2: Find entities with B but not A, add A (archetype move from B to A+B)
	# Subsystem 3: Find entities with A+B, increment counter (should see all 4)
	var system = ArchetypeMovePropagationSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Subsystem 1 processed 2 entities (entity1, entity2)
	assert_int(system.subsystem1_count).is_equal(2)

	# Verify: Subsystem 2 processed 2 entities (entity3, entity4)
	assert_int(system.subsystem2_count).is_equal(2)

	# Verify: Subsystem 3 processed 4 entities (all entities now have A+B)
	assert_int(system.subsystem3_count).is_equal(4)

	# Verify: All entities now have both A and B
	assert_bool(entity1.has_component(C_OrderTestA)).is_true()
	assert_bool(entity1.has_component(C_OrderTestB)).is_true()
	assert_bool(entity2.has_component(C_OrderTestA)).is_true()
	assert_bool(entity2.has_component(C_OrderTestB)).is_true()
	assert_bool(entity3.has_component(C_OrderTestA)).is_true()
	assert_bool(entity3.has_component(C_OrderTestB)).is_true()
	assert_bool(entity4.has_component(C_OrderTestA)).is_true()
	assert_bool(entity4.has_component(C_OrderTestB)).is_true()


## Test that entities are not double-processed when moving between archetypes
func test_subsystem_no_double_processing():
	# Create entities with A
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.add_component(C_OrderTestA.new())
	entity2.add_component(C_OrderTestA.new())
	world.add_entities([entity1, entity2])

	# Create system with one subsystem that adds B to entities with A
	# This causes archetype move from A to A+B
	# System should NOT process the same entity twice
	var system = NoDoubleProcessingSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Each entity processed exactly once
	assert_int(system.entity1_process_count).is_equal(1)
	assert_int(system.entity2_process_count).is_equal(1)


## Test that multiple archetype moves in sequence are handled correctly
func test_subsystem_multiple_archetype_moves():
	# Create entity with A
	var entity = Entity.new()
	entity.add_component(C_OrderTestA.new())
	world.add_entity(entity)

	# Create system with subsystems that progressively add components:
	# Subsystem 1: A -> add B (A+B)
	# Subsystem 2: A+B -> add C (A+B+C)
	# Subsystem 3: A+B+C -> increment counter
	var system = MultipleArchetypeMovesSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Each subsystem processed the entity
	assert_int(system.subsystem1_count).is_equal(1)
	assert_int(system.subsystem2_count).is_equal(1)
	assert_int(system.subsystem3_count).is_equal(1)

	# Verify: Entity has all three components
	assert_bool(entity.has_component(C_OrderTestA)).is_true()
	assert_bool(entity.has_component(C_OrderTestB)).is_true()
	assert_bool(entity.has_component(C_OrderTestC)).is_true()


## Test with many entities to ensure archetype moves scale correctly
func test_subsystem_archetype_move_at_scale():
	# Create 100 entities with A
	var entities = []
	for i in 100:
		var entity = Entity.new()
		entity.add_component(C_OrderTestA.new())
		entities.append(entity)
	world.add_entities(entities)

	# Create system that adds B to all entities with A
	var system = ComponentAdditionPropagationSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: Subsystem 1 processed 100 entities
	assert_int(system.subsystem1_count).is_equal(100)

	# Verify: Subsystem 2 processed 100 entities (saw all B components)
	assert_int(system.subsystem2_count).is_equal(100)

	# Verify: All entities have both A and B
	for entity in entities:
		assert_bool(entity.has_component(C_OrderTestA)).is_true()
		assert_bool(entity.has_component(C_OrderTestB)).is_true()


## ===============================
## TEST HELPER SYSTEMS
## ===============================

## System that adds components in subsystem 1 and checks them in subsystem 2
class ComponentAdditionPropagationSystem extends System:
	var subsystem1_count = 0
	var subsystem2_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA]), add_component_b],
			[ECS.world.query.with_all([C_OrderTestB]), count_component_b]
		]

	func add_component_b(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.add_component(C_OrderTestB.new())
			subsystem1_count += 1

	func count_component_b(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - called once per archetype
		# So we need to accumulate the count across all archetype calls
		subsystem2_count += entities.size()


## System that removes components in subsystem 1 and checks them in subsystem 2
class ComponentRemovalPropagationSystem extends System:
	var subsystem1_count = 0
	var subsystem2_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA]), remove_component_a],
			[ECS.world.query.with_all([C_OrderTestA]), count_component_a]
		]

	func remove_component_a(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.remove_component(C_OrderTestA)
			subsystem1_count += 1

	func count_component_a(entities: Array[Entity], components: Array, delta: float):
		subsystem2_count += entities.size()


## System that moves entities between archetypes
class ArchetypeMovePropagationSystem extends System:
	var subsystem1_count = 0
	var subsystem2_count = 0
	var subsystem3_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA]).with_none([C_OrderTestB]), add_b_to_a],
			[ECS.world.query.with_all([C_OrderTestB]).with_none([C_OrderTestA]), add_a_to_b],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]), count_both]
		]

	func add_b_to_a(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.add_component(C_OrderTestB.new())
			subsystem1_count += 1

	func add_a_to_b(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.add_component(C_OrderTestA.new())
			subsystem2_count += 1

	func count_both(entities: Array[Entity], components: Array, delta: float):
		subsystem3_count += entities.size()


## System that tracks individual entity processing to detect double-processing
class NoDoubleProcessingSystem extends System:
	var entity1_process_count = 0
	var entity2_process_count = 0
	var tracked_entities = {}

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA]), process_entities]
		]

	func process_entities(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			# Track which entity is being processed
			if not tracked_entities.has(entity):
				tracked_entities[entity] = 0
			tracked_entities[entity] += 1

			# Count for first two entities
			var keys = tracked_entities.keys()
			if entity == keys[0]:
				entity1_process_count = tracked_entities[entity]
			elif keys.size() > 1 and entity == keys[1]:
				entity2_process_count = tracked_entities[entity]

			# Add B to trigger archetype move
			if not entity.has_component(C_OrderTestB):
				entity.add_component(C_OrderTestB.new())


## System that performs multiple sequential archetype moves
class MultipleArchetypeMovesSystem extends System:
	var subsystem1_count = 0
	var subsystem2_count = 0
	var subsystem3_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA]).with_none([C_OrderTestB]), add_b],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]).with_none([C_OrderTestC]), add_c],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB, C_OrderTestC]), count_all]
		]

	func add_b(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.add_component(C_OrderTestB.new())
			subsystem1_count += 1

	func add_c(entities: Array[Entity], components: Array, delta: float):
		for entity in entities:
			entity.add_component(C_OrderTestC.new())
			subsystem2_count += 1

	func count_all(entities: Array[Entity], components: Array, delta: float):
		subsystem3_count += entities.size()


## ===============================
## TEST HELPER COMPONENTS
## ===============================
## Using existing component classes from addons/gecs/tests/components/
## - C_OrderTestA
## - C_OrderTestB
## - C_OrderTestC

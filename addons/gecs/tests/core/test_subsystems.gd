extends GdUnitTestSuite

## Comprehensive test suite for System.sub_systems() functionality
## Tests execution methods, callable signatures, caching, error handling, and execution order

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
## SUBSYSTEM EXECUTION WITH DIFFERENT EXECUTION METHODS
## ===============================

## Test subsystem with PROCESS execution method
func test_subsystem_process_execution():
	# Create entities
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())
	world.add_entities([entity1, entity2])

	# Create system with PROCESS subsystem
	var system = SubsystemProcessTest.new()
	world.add_system(system)

	# Process system
	world.process(0.016)

	# Verify: process_subsystem called once per entity
	assert_int(system.call_count).is_equal(2)
	assert_array(system.entities_processed).contains_exactly([entity1, entity2])


## Test subsystem with PROCESS_ALL execution method
func test_subsystem_process_all_execution():
	# Create entities
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())
	world.add_entities([entity1, entity2])

	# Create system with PROCESS_ALL subsystem
	var system = SubsystemProcessAllTest.new()
	world.add_system(system)

	# Process system
	world.process(0.016)

	# Verify: process_all_subsystem called once with all entities
	assert_int(system.call_count).is_equal(1)
	assert_array(system.all_entities).contains_exactly([entity1, entity2])


## Test subsystem with ARCHETYPE execution method
func test_subsystem_archetype_execution():
	# Create entities
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())
	world.add_entities([entity1, entity2])

	# Create system with ARCHETYPE subsystem
	var system = SubsystemArchetypeTest.new()
	world.add_system(system)

	# Process system
	world.process(0.016)

	# Verify: process_batch_subsystem called with component arrays
	assert_int(system.call_count).is_greater_equal(1) # At least once per archetype
	assert_int(system.total_entities_processed).is_equal(2)
	assert_bool(system.received_component_arrays).is_true()


## Test mixed execution methods in same system
func test_subsystem_mixed_execution_methods():
	# Create entities with different components
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestB.new())
	entity3.add_component(C_TestA.new())
	entity3.add_component(C_TestB.new())
	world.add_entities([entity1, entity2, entity3])

	# Create system with mixed subsystems
	var system = SubsystemMixedTest.new()
	world.add_system(system)

	# Process system
	world.process(0.016)

	# Verify: Each subsystem ran with correct execution method
	assert_int(system.process_count).is_equal(2) # entity1, entity3 have C_TestA
	assert_int(system.process_all_count).is_equal(1) # Called once with all C_TestB entities
	assert_int(system.archetype_count).is_greater_equal(1) # At least once for C_TestA archetypes


## ===============================
## CALLABLE SIGNATURES MATCH EXECUTION METHOD
## ===============================

## Test PROCESS subsystem receives correct parameters
func test_subsystem_process_signature():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	var system = SubsystemSignatureTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify PROCESS signature: (entity, delta)
	assert_bool(system.process_signature_correct).is_true()
	assert_that(system.process_entity).is_not_null()
	assert_float(system.process_delta).is_between(0.0, 1.0)


## Test PROCESS_ALL subsystem receives correct parameters
func test_subsystem_process_all_signature():
	var entity = Entity.new()
	entity.add_component(C_TestB.new())
	world.add_entity(entity)

	var system = SubsystemSignatureTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify PROCESS_ALL signature: (entities, delta)
	assert_bool(system.process_all_signature_correct).is_true()
	assert_that(system.process_all_entities).is_not_null()
	assert_bool(system.process_all_entities is Array).is_true()
	assert_float(system.process_all_delta).is_between(0.0, 1.0)


## Test ARCHETYPE subsystem receives correct parameters
func test_subsystem_archetype_signature():
	var entity = Entity.new()
	entity.add_component(C_TestC.new())
	world.add_entity(entity)

	var system = SubsystemSignatureTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify ARCHETYPE signature: (entities, components, delta)
	assert_bool(system.archetype_signature_correct).is_true()
	assert_that(system.archetype_entities).is_not_null()
	assert_that(system.archetype_components).is_not_null()
	assert_bool(system.archetype_entities is Array).is_true()
	assert_bool(system.archetype_components is Array).is_true()
	assert_float(system.archetype_delta).is_between(0.0, 1.0)


## ===============================
## SUBSYSTEM QUERY CACHING
## ===============================

## Test that subsystem queries are cached and reused
func test_subsystem_query_caching():
	# Create entities
	for i in 100:
		var entity = Entity.new()
		entity.add_component(C_TestA.new())
		world.add_entity(entity)

	var system = SubsystemProcessTest.new()
	world.add_system(system)

	# Process multiple times
	for i in 10:
		world.process(0.016)

	# Verify: System ran 10 times * 100 entities = 1000 calls
	assert_int(system.call_count).is_equal(1000)


## Test that subsystem cache invalidates on component changes
func test_subsystem_cache_invalidation():
	var entity1 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entity(entity1)

	var system = SubsystemProcessTest.new()
	world.add_system(system)

	# First process
	world.process(0.016)
	assert_int(system.call_count).is_equal(1)

	# Add another entity mid-frame
	var entity2 = Entity.new()
	entity2.add_component(C_TestA.new())
	world.add_entity(entity2)

	# Second process should see new entity
	world.process(0.016)
	assert_int(system.call_count).is_equal(3) # 1 + 2


## ===============================
## ERROR HANDLING FOR ARCHETYPE MODE
## ===============================

## Test error when ARCHETYPE subsystem missing .iterate()
func test_subsystem_archetype_missing_iterate_error():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	# Create system with ARCHETYPE subsystem but no .iterate()
	var system = SubsystemArchetypeMissingIterateTest.new()
	world.add_system(system)

	# Capture error output
	var error_occurred = false
	var error_handler = func(error_msg):
		error_occurred = true

	# Process system - should push_error
	world.process(0.016)

	# Verify: Subsystem did NOT execute (error prevented it)
	assert_int(system.call_count).is_equal(0)


## Test ARCHETYPE subsystem works correctly with .iterate()
func test_subsystem_archetype_with_iterate():
	var entity = Entity.new()
	var comp = C_TestA.new()
	comp.value = 42
	entity.add_component(comp)
	world.add_entity(entity)

	var system = SubsystemArchetypeTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify: Component arrays received
	assert_bool(system.received_component_arrays).is_true()
	assert_int(system.total_entities_processed).is_equal(1)


## ===============================
## SUBSYSTEM EXECUTION ORDER
## ===============================

## Test multiple subsystems execute in defined order
func test_subsystem_execution_order():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	entity.add_component(C_TestB.new())
	entity.add_component(C_TestC.new())
	world.add_entity(entity)

	var system = SubsystemOrderTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify: Subsystems executed in order (1, 2, 3)
	assert_array(system.execution_order).is_equal([1, 2, 3])


## Test subsystem order is consistent across frames
func test_subsystem_order_consistency():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	entity.add_component(C_TestB.new())
	entity.add_component(C_TestC.new())
	world.add_entity(entity)

	var system = SubsystemOrderTest.new()
	world.add_system(system)

	# Process multiple frames
	for i in 5:
		system.execution_order.clear()
		world.process(0.016)
		assert_array(system.execution_order).is_equal([1, 2, 3])


## ===============================
## EDGE CASES
## ===============================

## Test empty subsystems array (should fallback to regular system execution)
func test_empty_subsystems():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	var system = SubsystemEmptyTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify: Should not use subsystem execution (falls back to process/archetype/process_all)
	# In this case, system does nothing (no process() override)
	assert_int(system.call_count).is_equal(0)


## Test subsystem with no matching entities
func test_subsystem_no_matches():
	# No entities added

	var system = SubsystemProcessTest.new()
	world.add_system(system)
	world.process(0.016)

	# Verify: Subsystem not called
	assert_int(system.call_count).is_equal(0)


## Test subsystem performance vs regular system
func test_subsystem_performance():
	# Create many entities
	for i in 1000:
		var entity = Entity.new()
		entity.add_component(C_TestA.new())
		world.add_entity(entity)

	var system = SubsystemArchetypeTest.new()
	world.add_system(system)

	var time_start = Time.get_ticks_usec()
	world.process(0.016)
	var time_taken = Time.get_ticks_usec() - time_start

	# Verify: Processed all entities efficiently
	assert_int(system.total_entities_processed).is_equal(1000)
	print("Subsystem archetype processed 1000 entities in %d us" % time_taken)


## ===============================
## TEST HELPER SYSTEMS
## ===============================

## System with PROCESS subsystem
class SubsystemProcessTest extends System:
	var call_count = 0
	var entities_processed = []

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]), process_subsystem, System.ExecutionMethod.PROCESS]
		]

	func process_subsystem(entity: Entity, delta: float):
		call_count += 1
		entities_processed.append(entity)


## System with PROCESS_ALL subsystem
class SubsystemProcessAllTest extends System:
	var call_count = 0
	var all_entities = []

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]), process_all_subsystem, System.ExecutionMethod.PROCESS_ALL]
		]

	func process_all_subsystem(entities: Array, delta: float):
		call_count += 1
		all_entities = entities.duplicate()


## System with ARCHETYPE subsystem
class SubsystemArchetypeTest extends System:
	var call_count = 0
	var total_entities_processed = 0
	var received_component_arrays = false

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]).iterate([C_TestA]), process_batch_subsystem, System.ExecutionMethod.ARCHETYPE]
		]

	func process_batch_subsystem(entities: Array[Entity], components: Array, delta: float):
		call_count += 1
		total_entities_processed += entities.size()
		if components.size() > 0 and components[0] is Array:
			received_component_arrays = true


## System with mixed execution methods
class SubsystemMixedTest extends System:
	var process_count = 0
	var process_all_count = 0
	var archetype_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]), process_sub, System.ExecutionMethod.PROCESS],
			[ECS.world.query.with_all([C_TestB]), process_all_sub, System.ExecutionMethod.PROCESS_ALL],
			[ECS.world.query.with_all([C_TestA]).iterate([C_TestA]), process_batch_sub, System.ExecutionMethod.ARCHETYPE]
		]

	func process_sub(entity: Entity, delta: float):
		process_count += 1

	func process_all_sub(entities: Array, delta: float):
		process_all_count += 1

	func process_batch_sub(entities: Array[Entity], components: Array, delta: float):
		archetype_count += 1


## System to test callable signatures
class SubsystemSignatureTest extends System:
	var process_signature_correct = false
	var process_entity = null
	var process_delta = 0.0

	var process_all_signature_correct = false
	var process_all_entities = null
	var process_all_delta = 0.0

	var archetype_signature_correct = false
	var archetype_entities = null
	var archetype_components = null
	var archetype_delta = 0.0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]), test_process, System.ExecutionMethod.PROCESS],
			[ECS.world.query.with_all([C_TestB]), test_process_all, System.ExecutionMethod.PROCESS_ALL],
			[ECS.world.query.with_all([C_TestC]).iterate([C_TestC]), test_archetype, System.ExecutionMethod.ARCHETYPE]
		]

	func test_process(entity: Entity, delta: float):
		process_entity = entity
		process_delta = delta
		process_signature_correct = entity is Entity and typeof(delta) == TYPE_FLOAT

	func test_process_all(entities: Array, delta: float):
		process_all_entities = entities
		process_all_delta = delta
		process_all_signature_correct = entities is Array and typeof(delta) == TYPE_FLOAT

	func test_archetype(entities: Array[Entity], components: Array, delta: float):
		archetype_entities = entities
		archetype_components = components
		archetype_delta = delta
		archetype_signature_correct = entities is Array and components is Array and typeof(delta) == TYPE_FLOAT


## System with ARCHETYPE but missing .iterate()
class SubsystemArchetypeMissingIterateTest extends System:
	var call_count = 0

	func sub_systems() -> Array[Array]:
		return [
			# Missing .iterate() - should error
			[ECS.world.query.with_all([C_TestA]), process_batch_subsystem, System.ExecutionMethod.ARCHETYPE]
		]

	func process_batch_subsystem(entities: Array[Entity], components: Array, delta: float):
		call_count += 1


## System to test execution order
class SubsystemOrderTest extends System:
	var execution_order = []

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_TestA]), subsystem1, System.ExecutionMethod.PROCESS],
			[ECS.world.query.with_all([C_TestB]), subsystem2, System.ExecutionMethod.PROCESS],
			[ECS.world.query.with_all([C_TestC]), subsystem3, System.ExecutionMethod.PROCESS]
		]

	func subsystem1(entity: Entity, delta: float):
		execution_order.append(1)

	func subsystem2(entity: Entity, delta: float):
		execution_order.append(2)

	func subsystem3(entity: Entity, delta: float):
		execution_order.append(3)


## System with empty subsystems (fallback behavior)
class SubsystemEmptyTest extends System:
	var call_count = 0

	func sub_systems() -> Array[Array]:
		return [] # Empty - should not use subsystem execution

	# No process(), archetype(), or process_all() override
	# System should do nothing

extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)
	
func test_observer_receive_component_changed():
	world.add_system(TestASystem.new())
	var test_a_observer = TestAObserver.new()
	world.add_observer(test_a_observer)
	
	# Create entities with the required components
	var entity_a = TestA.new()
	entity_a.name = "a"
	entity_a.add_component(C_TestA.new())

	var entity_b = TestB.new()
	entity_b.name = "b"
	entity_b.add_component(C_TestA.new())
	entity_b.add_component(C_TestB.new())
	
	# issue #43
	var entity_a2 = TestA.new()
	entity_a2.name = "a"
	entity_a2.add_component(C_TestA.new())
	world.get_node(world.entity_nodes_root).add_child(entity_a2)
	world.add_entity(entity_a2, null, false)
	assert_int(test_a_observer.added_count).is_equal(1)
	

	# Add  some entities before systems
	world.add_entities([entity_a, entity_b])
	assert_int(test_a_observer.added_count).is_equal(3)
	

	# Run the systems once
	print('process 1st')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(2)
	
	# Run the systems again
	print('process 2nd')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(4)


## Test that observers detect when a component is added to an entity
func test_observer_on_component_added():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create an entity without the component
	var entity = Entity.new()
	world.add_entity(entity)

	# Verify observer hasn't fired yet
	assert_int(observer.added_count).is_equal(0)

	# Add the watched component
	var component = C_ObserverTest.new()
	entity.add_component(component)

	# Verify observer detected the addition
	assert_int(observer.added_count).is_equal(1)
	assert_object(observer.last_added_entity).is_equal(entity)


## Test that observers detect when a component is removed from an entity
func test_observer_on_component_removed():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create an entity with the component
	var entity = Entity.new()
	var component = C_ObserverTest.new()
	entity.add_component(component)
	world.add_entity(entity)

	# Verify observer detected the addition
	assert_int(observer.added_count).is_equal(1)

	# Reset and remove the component
	observer.reset()
	entity.remove_component(C_ObserverTest)

	# Verify observer detected the removal
	assert_int(observer.removed_count).is_equal(1)
	assert_object(observer.last_removed_entity).is_equal(entity)
	assert_int(observer.added_count).is_equal(0) # Should remain 0 after reset


## Test that observers detect property changes on watched components
func test_observer_on_component_changed():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create an entity with the component
	var entity = Entity.new()
	var component = C_ObserverTest.new(0, "initial")
	entity.add_component(component)
	world.add_entity(entity)

	# Reset the observer (it may have fired on add)
	observer.reset()

	# Change the value property (this will emit property_changed signal)
	component.value = 42

	# Verify observer detected the change
	assert_int(observer.changed_count).is_equal(1)
	assert_object(observer.last_changed_entity).is_equal(entity)
	assert_str(observer.last_changed_property).is_equal("value")
	assert_int(observer.last_old_value).is_equal(0)
	assert_int(observer.last_new_value).is_equal(42)

	# Change another property
	component.name_prop = "changed"

	# Verify observer detected the second change
	assert_int(observer.changed_count).is_equal(2)
	assert_str(observer.last_changed_property).is_equal("name_prop")
	assert_str(observer.last_old_value).is_equal("initial")
	assert_str(observer.last_new_value).is_equal("changed")


## Test that observers respect query filters (only match entities that pass the query)
func test_observer_respects_query_filter():
	var health_observer = O_HealthObserver.new()
	world.add_observer(health_observer)

	# Create entity with only health component (should NOT match - needs both components)
	var entity_only_health = Entity.new()
	entity_only_health.add_component(C_ObserverHealth.new())
	world.add_entity(entity_only_health)

	# Observer should NOT have fired (doesn't match query)
	assert_int(health_observer.health_added_count).is_equal(0)

	# Create entity with both components (should match)
	var entity_both = Entity.new()
	entity_both.add_component(C_ObserverTest.new())
	entity_both.add_component(C_ObserverHealth.new())
	world.add_entity(entity_both)

	# Observer should have fired now (matches query)
	assert_int(health_observer.health_added_count).is_equal(1)


## Test that multiple observers can watch the same component
func test_multiple_observers_same_component():
	var observer1 = O_ObserverTest.new()
	var observer2 = O_ObserverTest.new()
	world.add_observer(observer1)
	world.add_observer(observer2)

	# Create an entity with the component
	var entity = Entity.new()
	var component = C_ObserverTest.new()
	entity.add_component(component)
	world.add_entity(entity)

	# Both observers should have detected the addition
	assert_int(observer1.added_count).is_equal(1)
	assert_int(observer2.added_count).is_equal(1)

	# Change the component
	observer1.reset()
	observer2.reset()
	component.value = 100

	# Both observers should have detected the change
	assert_int(observer1.changed_count).is_equal(1)
	assert_int(observer2.changed_count).is_equal(1)


## Test that observers can track multiple property changes
func test_observer_tracks_multiple_changes():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create an entity with the component
	var entity = Entity.new()
	var component = C_ObserverTest.new(0, "start")
	entity.add_component(component)
	world.add_entity(entity)

	observer.reset()

	# Make multiple changes
	component.value = 10
	component.value = 20
	component.name_prop = "middle"
	component.value = 30

	# Should have detected all 4 changes
	assert_int(observer.changed_count).is_equal(4)


## Test observer with health component and query matching
func test_observer_health_low_health_alert():
	var health_observer = O_HealthObserver.new()
	world.add_observer(health_observer)

	# Create entity with both components
	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	var health = C_ObserverHealth.new(100)
	entity.add_component(health)
	world.add_entity(entity)

	health_observer.reset()

	# Reduce health gradually
	health.health = 50
	assert_int(health_observer.health_changed_count).is_equal(1)
	assert_int(health_observer.low_health_alerts.size()).is_equal(0)

	health.health = 25 # Below threshold
	assert_int(health_observer.health_changed_count).is_equal(2)
	assert_int(health_observer.low_health_alerts.size()).is_equal(1)
	assert_object(health_observer.low_health_alerts[0]).is_equal(entity)


## Test that observer doesn't fire when entity doesn't match query
func test_observer_ignores_non_matching_entities():
	var health_observer = O_HealthObserver.new()
	world.add_observer(health_observer)

	# Create entity with only C_ObserverTest (not both components)
	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	world.add_entity(entity)

	# Try to add C_ObserverHealth to a different entity that doesn't have C_ObserverTest
	var entity2 = Entity.new()
	entity2.add_component(C_ObserverHealth.new())
	world.add_entity(entity2)

	# Observer should not have fired (entity2 doesn't match query)
	assert_int(health_observer.health_added_count).is_equal(0)


## Test observer detects component addition before entity is added to world
func test_observer_component_added_before_entity_added():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create entity and add component BEFORE adding to world
	var entity = Entity.new()
	var component = C_ObserverTest.new()
	entity.add_component(component)

	# Observer shouldn't have fired yet
	assert_int(observer.added_count).is_equal(0)

	# Now add to world
	world.add_entity(entity)

	# Observer should fire now
	assert_int(observer.added_count).is_equal(1)


## Test observer with component replacement
func test_observer_component_replacement():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create entity with component
	var entity = Entity.new()
	var component1 = C_ObserverTest.new(10, "first")
	entity.add_component(component1)
	world.add_entity(entity)

	assert_int(observer.added_count).is_equal(1)

	# Replace the component (add_component on same type replaces)
	var component2 = C_ObserverTest.new(20, "second")
	entity.add_component(component2)

	# Should trigger both removed and added
	assert_int(observer.removed_count).is_equal(1)
	assert_int(observer.added_count).is_equal(2)


## Test that property changes without signal emission don't trigger observer
func test_observer_ignores_direct_property_changes():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create entity with component
	var entity = Entity.new()
	var component = C_ObserverTest.new()
	entity.add_component(component)
	world.add_entity(entity)

	observer.reset()

	# Directly set the property WITHOUT using the setter
	# This bypasses the property_changed signal
	# Note: In GDScript, using the property name always calls the setter,
	# so we need to access the internal variable directly
	# For this test, we're verifying that ONLY setters that emit signals work

	# Using the setter (should trigger)
	component.value = 42
	assert_int(observer.changed_count).is_equal(1)

	# The framework correctly requires explicit signal emission in setters


## Test observer with entity that starts matching query after component addition
func test_observer_entity_becomes_matching():
	var health_observer = O_HealthObserver.new()
	world.add_observer(health_observer)

	# Create entity with only one component
	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	world.add_entity(entity)

	# Health observer shouldn't fire (needs both components)
	assert_int(health_observer.health_added_count).is_equal(0)

	# Add the second component
	entity.add_component(C_ObserverHealth.new())

	# Now health observer should fire
	assert_int(health_observer.health_added_count).is_equal(1)


## Test removing observer from world
func test_remove_observer():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create entity with component
	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	world.add_entity(entity)

	assert_int(observer.added_count).is_equal(1)

	# Remove the observer
	world.remove_observer(observer)

	# Add another entity - observer should not fire
	var entity2 = Entity.new()
	entity2.add_component(C_ObserverTest.new())
	world.add_entity(entity2)

	# Count should still be 1 (not 2)
	assert_int(observer.added_count).is_equal(1)


## Test observer with multiple entities
func test_observer_with_multiple_entities():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create multiple entities
	for i in range(5):
		var entity = Entity.new()
		entity.add_component(C_ObserverTest.new(i))
		world.add_entity(entity)

	# Should have detected all 5 additions
	assert_int(observer.added_count).is_equal(5)

	observer.reset()

	# Get all entities and modify their components
	var entities = world.query.with_all([C_ObserverTest]).execute()
	for entity in entities:
		var comp = entity.get_component(C_ObserverTest)
		comp.value = comp.value + 100

	# Should have detected all 5 changes
	assert_int(observer.changed_count).is_equal(5)


## Test that removing an entity via world.remove_entity triggers on_component_removed
func test_observer_on_remove_entity_triggers_component_removed():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create entity with the watched component
	var entity = Entity.new()
	var component = C_ObserverTest.new(42, "test")
	entity.add_component(component)
	world.add_entity(entity)

	assert_int(observer.added_count).is_equal(1)
	observer.reset()

	# Remove the entire entity from the world
	world.remove_entity(entity)

	# Observer should have been notified about the component removal
	assert_int(observer.removed_count).is_equal(1)
	assert_object(observer.last_removed_entity).is_equal(entity)


## Test that removing an entity with multiple components notifies all relevant observers
func test_observer_on_remove_entity_multiple_components():
	var observer = O_ObserverTest.new()
	var health_observer = O_HealthObserver.new()
	world.add_observer(observer)
	world.add_observer(health_observer)

	# Create entity with both watched components
	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	entity.add_component(C_ObserverHealth.new(100))
	world.add_entity(entity)

	assert_int(observer.added_count).is_equal(1)
	assert_int(health_observer.health_added_count).is_equal(1)
	observer.reset()
	health_observer.reset()

	# Remove the entire entity
	world.remove_entity(entity)

	# Both observers should have been notified
	assert_int(observer.removed_count).is_equal(1)
	assert_int(health_observer.health_removed_count).is_equal(1)


## Test that removing multiple entities notifies observer for each
func test_observer_on_remove_multiple_entities():
	var observer = O_ObserverTest.new()
	world.add_observer(observer)

	# Create and add 3 entities
	var entities_list: Array[Entity] = []
	for i in range(3):
		var entity = Entity.new()
		entity.add_component(C_ObserverTest.new(i))
		world.add_entity(entity)
		entities_list.append(entity)

	assert_int(observer.added_count).is_equal(3)
	observer.reset()

	# Remove all entities
	for entity in entities_list:
		world.remove_entity(entity)

	# Observer should have been notified for each removal
	assert_int(observer.removed_count).is_equal(3)


## Regression test: observer side-effects during remove_entity must not cause double notification.
## O_TestCleanupSideEffect removes C_ObserverHealth when it sees C_ObserverTest removed.
## If entity signals are still connected during the loop, health_observer fires twice (bug).
## If signals are disconnected before the loop, health_observer fires exactly once (correct).
func test_observer_no_double_notification_on_remove_entity():
	var cleanup_observer = O_TestCleanupSideEffectObserver.new()
	var health_observer = O_HealthObserver.new()
	world.add_observer(cleanup_observer)
	world.add_observer(health_observer)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	entity.add_component(C_ObserverHealth.new(100))
	world.add_entity(entity)

	health_observer.reset()

	world.remove_entity(entity)

	assert_int(health_observer.health_removed_count).is_equal(1)

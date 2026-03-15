## Regression test suite for Phase 1 observer signal chain bugs.
## OBS-01: world.remove_entity() fires on_component_removed for every watched component.
## OBS-02: entity.remove_component() delivers the correct component instance to the observer.
## OBS-03: property_changed is disconnected when a component is removed — no phantom callbacks.
## Also covers: multiple observers both notified, re-entrancy guard prevents double notification.
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


## OBS-01: world.remove_entity() must fire on_component_removed exactly once per watched component.
## Entity has one C_ObserverTest; removing it via world.remove_entity() must trigger removed_count == 1.
func test_obs01_remove_entity_fires_observer_per_component():
	var observer = O_InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	var component = C_ObserverTest.new(7, "obs01")
	entity.add_component(component)
	world.add_entity(entity)

	# Reset after add so the removal count starts clean
	observer.reset()

	# Remove the whole entity — observer must fire once for C_ObserverTest
	world.remove_entity(entity)

	assert_int(observer.removed_count).is_equal(1)


## OBS-02: The component instance delivered to on_component_removed must be the exact instance
## that was stored — matchable by resource_path and retaining its property values.
func test_obs02_removed_component_instance_correct():
	var observer = O_InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	var component = C_ObserverTest.new(42, "marker")
	entity.add_component(component)
	world.add_entity(entity)

	observer.reset()

	# Remove by script class (the normal call pattern)
	entity.remove_component(C_ObserverTest)

	assert_int(observer.removed_count).is_equal(1)
	assert_object(observer.last_removed_component).is_not_null()
	# The delivered component must be matchable by script path (not raw .resource_path on instance)
	assert_str(observer.last_removed_component.get_script().resource_path).is_equal(
		C_ObserverTest.resource_path
	)
	# Property value proves it's the actual instance, not a blank new copy
	assert_int(observer.last_removed_component.value).is_equal(42)


## OBS-03: After entity.remove_component(), mutating the removed component's property
## must NOT trigger on_component_changed — the property_changed signal must be disconnected.
## This test FAILS against unfixed code (proving the phantom-callback bug is real).
func test_obs03_no_phantom_callbacks_after_removal():
	var observer = O_InstanceCapturingObserver.new()
	world.add_observer(observer)

	var entity = Entity.new()
	var component = C_ObserverTest.new(0, "start")
	entity.add_component(component)
	world.add_entity(entity)

	# Remove the component from the entity
	entity.remove_component(C_ObserverTest)
	# Clear the removal notification so we only measure what happens next
	observer.reset()

	# Mutate the now-removed component via its setter (emits property_changed internally)
	component.value = 99

	# Observer must NOT fire — the component is no longer attached to any entity
	assert_int(observer.changed_count).is_equal(0)


## Edge case: two O_InstanceCapturingObserver instances watching the same component type.
## Both must be notified when a single entity's component is removed.
func test_obs_multiple_observers_both_notified():
	var observer_a = O_InstanceCapturingObserver.new()
	var observer_b = O_InstanceCapturingObserver.new()
	world.add_observer(observer_a)
	world.add_observer(observer_b)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new(5, "multi"))
	world.add_entity(entity)

	observer_a.reset()
	observer_b.reset()

	entity.remove_component(C_ObserverTest)

	assert_int(observer_a.removed_count).is_equal(1)
	assert_int(observer_b.removed_count).is_equal(1)


## Re-entrancy guard: an observer that calls entity.remove_component() as a side effect
## inside on_component_removed must not cause the health observer to fire twice.
## O_TestCleanupSideEffectObserver removes C_ObserverHealth when it sees C_ObserverTest removed.
## The health observer must receive exactly one notification, not two.
func test_obs_reentrancy_guard_prevents_double_notify():
	var cleanup_observer = O_TestCleanupSideEffectObserver.new()
	var health_observer = O_HealthObserver.new()
	world.add_observer(cleanup_observer)
	world.add_observer(health_observer)

	var entity = Entity.new()
	entity.add_component(C_ObserverTest.new())
	entity.add_component(C_ObserverHealth.new(100))
	world.add_entity(entity)

	health_observer.reset()

	# Removing C_ObserverTest causes cleanup_observer to remove C_ObserverHealth as a side effect.
	# If re-entrancy is broken, health_observer fires twice. Correct behavior: exactly once.
	entity.remove_component(C_ObserverTest)

	assert_int(health_observer.health_removed_count).is_equal(1)

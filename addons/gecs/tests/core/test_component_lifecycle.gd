class_name TestComponentLifecycle
extends GdUnitTestSuite

## Regression tests for COMP-01 and COMP-03: non-@export property preservation.
##
## COMP-01: entity.add_entity() path — world._initialize() calls res.duplicate(true)
##          which resets non-@export vars to their script default.
## COMP-03: world.add_entities() batch path shares the same code path.
##
## These tests are intentionally RED on the unpatched codebase.
## They turn GREEN when Plan 04-02 replaces duplicate(true) with a shallow copy.


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## COMP-01 regression: non-@export value must survive world.add_entity().
## Currently FAILS because duplicate(true) resets non_exported_value to 0.
func test_non_export_property_preserved_through_add_entity():
	var comp = C_LifecycleTest.new(10, 42)
	var entity = Entity.new()
	entity.component_resources.append(comp)
	world.add_entity(entity)

	var stored = entity.get_component(C_LifecycleTest)
	assert_int(stored.exported_value).is_equal(10)       # passes — duplicate(true) copies @export
	assert_int(stored.non_exported_value).is_equal(42)   # RED: fails — duplicate(true) resets to 0


## COMP-03 regression: non-@export value must survive world.add_entities() batch path.
## Currently FAILS for the same reason as COMP-01.
func test_non_export_property_preserved_through_add_entities():
	var comp = C_LifecycleTest.new(10, 42)
	var entity = Entity.new()
	entity.component_resources.append(comp)
	world.add_entities([entity])

	var stored = entity.get_component(C_LifecycleTest)
	assert_int(stored.exported_value).is_equal(10)       # passes — duplicate(true) copies @export
	assert_int(stored.non_exported_value).is_equal(42)   # RED: fails — duplicate(true) resets to 0

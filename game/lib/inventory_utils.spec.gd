extends GdUnitTestSuite

var runner : GdUnitSceneRunner
var world: World
var c_key = preload("res://game/data/items/i_key.tres")
var c_health_kit = preload("res://game/data/items/i_healthkit.tres")

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	world.purge(false)
	

func test_check_get_item_not_exist():
	var player = Entity.new()
	ECS.world.add_entity(player)
	var new_entity = c_health_kit.make_entity(1)
	new_entity.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	ECS.world.add_entity(new_entity)
	
	var sec_entity = c_health_kit.make_entity(1)
	sec_entity.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	ECS.world.add_entity(sec_entity)
	
	InventoryUtils.consolidate_inventory()

	var item = InventoryUtils.get_item(player, c_key)
	assert_that(item).is_null()
	
	var sec_item = InventoryUtils.get_item(player, c_health_kit)
	assert_that(sec_item).is_not_null()
	

func test_check_get_item_exists():
	var player = Entity.new()
	ECS.world.add_entity(player)
	
	var new_entity = c_health_kit.make_entity(1)
	new_entity.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	ECS.world.add_entity(new_entity)
	
	var sec_entity = c_key.make_entity(1)
	sec_entity.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	ECS.world.add_entity(sec_entity)
	
	InventoryUtils.consolidate_inventory()

	var item = InventoryUtils.get_item(player, c_health_kit)
	assert_that(item).is_not_null()
	var sec_item = InventoryUtils.get_item(player, c_key)
	assert_that(sec_item).is_not_null()
	

extends GdUnitTestSuite

## Test suite for CN_SyncEntity
## Tests sync target resolution, has_sync_properties, and get_property_paths.

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var world: World


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world


func after_test():
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null


# ============================================================================
# SYNC TARGET
# ============================================================================


func test_get_sync_target_returns_target_node_when_set():
	var sync = CN_SyncEntity.new()
	var entity = Entity.new()
	world.add_entity(entity)
	var target = Node3D.new()
	entity.add_child(target)
	sync.target_node = target
	assert_object(sync.get_sync_target(entity)).is_same(target)
	# Note: target is freed by entity cleanup in after_test()


func test_get_sync_target_falls_back_to_entity():
	var sync = CN_SyncEntity.new()
	var entity = Entity.new()
	world.add_entity(entity)
	# target_node is null, should return entity
	assert_object(sync.get_sync_target(entity)).is_same(entity)


func test_get_sync_target_returns_null_when_both_null():
	var sync = CN_SyncEntity.new()
	assert_object(sync.get_sync_target(null)).is_null()


# ============================================================================
# HAS SYNC PROPERTIES
# ============================================================================


func test_has_sync_properties_true_with_defaults():
	var sync = CN_SyncEntity.new()
	# Default: sync_position=true, sync_rotation=true
	assert_bool(sync.has_sync_properties()).is_true()


func test_has_sync_properties_false_when_all_disabled():
	var sync = CN_SyncEntity.new(false, false, false)
	sync.custom_properties.clear()
	assert_bool(sync.has_sync_properties()).is_false()


func test_has_sync_properties_true_with_only_custom():
	var sync = CN_SyncEntity.new(false, false, false)
	sync.custom_properties.append("health")
	assert_bool(sync.has_sync_properties()).is_true()


func test_has_sync_properties_true_with_velocity_only():
	var sync = CN_SyncEntity.new(false, false, true)
	assert_bool(sync.has_sync_properties()).is_true()


# ============================================================================
# GET PROPERTY PATHS
# ============================================================================


func test_get_property_paths_default():
	var sync = CN_SyncEntity.new()
	var entity = Entity.new()
	world.add_entity(entity)
	var paths = sync.get_property_paths(entity)
	assert_bool("global_position" in paths).is_true()
	assert_bool("global_rotation" in paths).is_true()


func test_get_property_paths_includes_custom():
	var sync = CN_SyncEntity.new()
	sync.custom_properties.append("health")
	sync.custom_properties.append("score")
	var entity = Entity.new()
	world.add_entity(entity)
	var paths = sync.get_property_paths(entity)
	assert_bool("health" in paths).is_true()
	assert_bool("score" in paths).is_true()


func test_get_property_paths_no_duplicate_custom():
	var sync = CN_SyncEntity.new()
	sync.custom_properties.append("global_position")  # Already included by sync_position
	var entity = Entity.new()
	world.add_entity(entity)
	var paths = sync.get_property_paths(entity)
	# Should not have duplicate
	var count = 0
	for p in paths:
		if p == "global_position":
			count += 1
	assert_int(count).is_equal(1)


func test_get_property_paths_empty_when_all_disabled():
	var sync = CN_SyncEntity.new(false, false, false)
	var entity = Entity.new()
	world.add_entity(entity)
	var paths = sync.get_property_paths(entity)
	assert_array(paths).is_empty()


# ============================================================================
# INIT
# ============================================================================


func test_init_defaults():
	var sync = CN_SyncEntity.new()
	assert_bool(sync.sync_position).is_true()
	assert_bool(sync.sync_rotation).is_true()
	assert_bool(sync.sync_velocity).is_false()


func test_init_with_params():
	var sync = CN_SyncEntity.new(false, true, true)
	assert_bool(sync.sync_position).is_false()
	assert_bool(sync.sync_rotation).is_true()
	assert_bool(sync.sync_velocity).is_true()

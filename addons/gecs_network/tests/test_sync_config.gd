extends GdUnitTestSuite

## Test suite for SyncConfig
## Tests priority methods, filtering (blacklist/whitelist), entity categorization,
## and static helper methods.

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var config: SyncConfig
var world: World


func before_test():
	config = SyncConfig.new()
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world


func after_test():
	config = null
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null


# ============================================================================
# PRIORITY METHODS
# ============================================================================


func test_get_priority_returns_medium_default_for_unknown_component():
	var comp = C_TestA.new()
	var priority = config.get_priority(comp)
	assert_int(priority).is_equal(SyncConfig.Priority.MEDIUM)


func test_get_priority_returns_configured_value():
	config.component_priorities["C_TestA"] = SyncConfig.Priority.HIGH
	var comp = C_TestA.new()
	var priority = config.get_priority(comp)
	assert_int(priority).is_equal(SyncConfig.Priority.HIGH)


func test_get_priority_returns_low_when_configured():
	config.component_priorities["C_TestB"] = SyncConfig.Priority.LOW
	var comp = C_TestB.new()
	var priority = config.get_priority(comp)
	assert_int(priority).is_equal(SyncConfig.Priority.LOW)


func test_get_priority_by_name():
	config.component_priorities["C_TestA"] = SyncConfig.Priority.REALTIME
	assert_int(config.get_priority_by_name("C_TestA")).is_equal(SyncConfig.Priority.REALTIME)
	assert_int(config.get_priority_by_name("NonExistentComponent")).is_equal(
		SyncConfig.Priority.MEDIUM
	)


func test_get_priority_component_without_script():
	# Component base class without a script assigned
	var comp = Component.new()
	var priority = config.get_priority(comp)
	assert_int(priority).is_equal(SyncConfig.Priority.MEDIUM)


# ============================================================================
# FILTERING - BLACKLIST MODE
# ============================================================================


func test_should_skip_returns_true_for_blacklisted_type():
	config.skip_component_types = ["C_TestA"]
	assert_bool(config.should_skip("C_TestA")).is_true()


func test_should_skip_returns_false_for_unlisted_or_empty():
	config.skip_component_types = ["C_TestA"]
	assert_bool(config.should_skip("C_TestB")).is_false()
	config.skip_component_types = []
	assert_bool(config.should_skip("C_TestA")).is_false()


func test_should_skip_component_returns_true_for_null():
	assert_bool(config.should_skip_component(null)).is_true()


func test_should_skip_component_blacklists_by_class_name():
	config.skip_component_types = ["Component"]
	var comp = Component.new()
	assert_bool(config.should_skip_component(comp)).is_true()


func test_should_skip_component_returns_false_for_valid_component():
	var comp = C_TestA.new()
	assert_bool(config.should_skip_component(comp)).is_false()


func test_should_skip_component_returns_true_for_blacklisted():
	config.skip_component_types = ["C_TestA"]
	var comp = C_TestA.new()
	assert_bool(config.should_skip_component(comp)).is_true()


# ============================================================================
# FILTERING - WHITELIST MODE
# ============================================================================


func test_whitelist_should_skip_returns_false_for_listed_type():
	config.sync_only_components = ["C_TestA"]
	assert_bool(config.should_skip("C_TestA")).is_false()


func test_whitelist_should_skip_returns_true_for_unlisted_type():
	config.sync_only_components = ["C_TestA"]
	assert_bool(config.should_skip("C_TestB")).is_true()


func test_whitelist_overrides_blacklist():
	config.skip_component_types = ["C_TestA"]
	config.sync_only_components = ["C_TestA"]
	# Whitelist mode: C_TestA is in whitelist, so it should NOT be skipped
	assert_bool(config.should_skip("C_TestA")).is_false()


# ============================================================================
# ENTITY CATEGORIZATION
# ============================================================================


func test_get_entity_category_matches_by_component():
	config.entity_categories = {"enemy": ["C_TestA"]}
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)
	var category = config.get_entity_category(entity)
	assert_str(category).is_equal("enemy")


func test_get_entity_category_fallback_peer_id_player():
	# No categories configured, peer_id > 0 => "player"
	config.entity_categories = {}
	var entity = Entity.new()
	entity.add_component(CN_NetworkIdentity.new(2))
	world.add_entity(entity)
	var category = config.get_entity_category(entity)
	assert_str(category).is_equal("player")


func test_get_entity_category_fallback_peer_id_other():
	# No categories configured, peer_id = 0 => "other"
	config.entity_categories = {}
	var entity = Entity.new()
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)
	var category = config.get_entity_category(entity)
	assert_str(category).is_equal("other")


func test_get_entity_category_returns_other_for_no_match():
	config.entity_categories = {"enemy": ["C_TestA"]}
	var entity = Entity.new()
	entity.add_component(C_TestB.new())
	world.add_entity(entity)
	var category = config.get_entity_category(entity)
	assert_str(category).is_equal("other")


# ============================================================================
# STATIC METHODS
# ============================================================================


func test_get_interval_for_each_priority():
	assert_float(SyncConfig.get_interval(SyncConfig.Priority.REALTIME)).is_equal(0.0)
	assert_float(SyncConfig.get_interval(SyncConfig.Priority.HIGH)).is_equal(0.05)
	assert_float(SyncConfig.get_interval(SyncConfig.Priority.MEDIUM)).is_equal(0.1)
	assert_float(SyncConfig.get_interval(SyncConfig.Priority.LOW)).is_equal(1.0)


func test_should_sync_realtime_always_true():
	assert_bool(SyncConfig.should_sync(SyncConfig.Priority.REALTIME, 0.0)).is_true()
	assert_bool(SyncConfig.should_sync(SyncConfig.Priority.REALTIME, 100.0)).is_true()


func test_should_sync_high_respects_interval():
	# HIGH interval = 0.05, so 0.04 should be false, 0.05 should be true
	assert_bool(SyncConfig.should_sync(SyncConfig.Priority.HIGH, 0.04)).is_false()
	assert_bool(SyncConfig.should_sync(SyncConfig.Priority.HIGH, 0.05)).is_true()


func test_get_reliability_for_each_priority():
	assert_int(SyncConfig.get_reliability(SyncConfig.Priority.REALTIME)).is_equal(
		SyncConfig.Reliability.UNRELIABLE
	)
	assert_int(SyncConfig.get_reliability(SyncConfig.Priority.HIGH)).is_equal(
		SyncConfig.Reliability.UNRELIABLE
	)
	assert_int(SyncConfig.get_reliability(SyncConfig.Priority.MEDIUM)).is_equal(
		SyncConfig.Reliability.RELIABLE
	)
	assert_int(SyncConfig.get_reliability(SyncConfig.Priority.LOW)).is_equal(
		SyncConfig.Reliability.RELIABLE
	)


# ============================================================================
# LEGACY ALIAS
# ============================================================================


func test_priorities_alias_reads_component_priorities():
	config.component_priorities["C_TestA"] = SyncConfig.Priority.HIGH
	assert_int(config.priorities["C_TestA"]).is_equal(SyncConfig.Priority.HIGH)


func test_priorities_alias_writes_component_priorities():
	config.priorities = {"C_TestA": SyncConfig.Priority.LOW}
	assert_int(config.component_priorities["C_TestA"]).is_equal(SyncConfig.Priority.LOW)

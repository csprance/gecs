class_name TestArchetypeRelationships
extends GdUnitTestSuite
## Test suite for archetype relationship slot key handling
##
## Verifies that Archetype correctly handles rel:// prefixed slot keys
## alongside component int keys (ARCH-01 through ARCH-05).


# Test component keys (script instance ids, initialized in before())
var COMP_A: int
var COMP_B: int

var _script_a: GDScript = preload("res://addons/gecs/tests/components/c_test_a.gd")
var _script_b: GDScript = preload("res://addons/gecs/tests/components/c_test_b.gd")

func before():
	COMP_A = _script_a.get_instance_id()
	COMP_B = _script_b.get_instance_id()

# Relationship slot keys using the rel:// format
const REL_A_ENTITY := "rel://res://addons/gecs/tests/components/c_test_a.gd::entity#99999"
const REL_B_COMP := "rel://res://addons/gecs/tests/components/c_test_b.gd::comp://res://addons/gecs/tests/components/c_test_a.gd"
const REL_A_WILDCARD := "rel://res://addons/gecs/tests/components/c_test_a.gd::*"
const REL_B_SCRIPT := "rel://res://addons/gecs/tests/components/c_test_b.gd::script://res://example/entities/random_mover.gd"


## Test 1 (ARCH-01 + ARCH-03): Columns exist only for component paths, NOT for rel:// keys
func test_columns_exclude_rel_keys():
	var arch = Archetype.new(1, [COMP_A, REL_A_ENTITY, COMP_B, REL_B_COMP])

	# Component paths should have columns
	assert_bool(arch.columns.has(COMP_A)).is_true()
	assert_bool(arch.columns.has(COMP_B)).is_true()

	# rel:// keys should NOT have columns
	assert_bool(arch.columns.has(REL_A_ENTITY)).is_false()
	assert_bool(arch.columns.has(REL_B_COMP)).is_false()

	# Total column count should be 2 (only components)
	assert_int(arch.columns.size()).is_equal(2)


## Test 2 (ARCH-02): Slot key format accepted and sorted correctly in component_types
func test_rel_key_format_and_sorting():
	var arch = Archetype.new(2, [REL_B_COMP, COMP_B, REL_A_ENTITY, COMP_A])

	# component_types should contain all 4 entries
	assert_int(arch.component_types.size()).is_equal(4)

	# component_types is a mix of ints (components) and Strings (rel:// keys)
	# After sorting: ints come before Strings in Godot's Variant comparison
	for ct in arch.component_types:
		assert_bool(
			ct is int or (ct is String and (ct as String).begins_with("rel://"))
		).is_true()

	# Should contain all keys
	assert_bool(arch.component_types.has(COMP_A)).is_true()
	assert_bool(arch.component_types.has(COMP_B)).is_true()
	assert_bool(arch.component_types.has(REL_A_ENTITY)).is_true()
	assert_bool(arch.component_types.has(REL_B_COMP)).is_true()


## Test 3 (ARCH-04): relationship_types returns exactly the rel:// subset
func test_relationship_types_returns_rel_subset():
	var arch = Archetype.new(3, [COMP_A, REL_A_ENTITY, COMP_B, REL_B_COMP])

	assert_int(arch.relationship_types.size()).is_equal(2)
	assert_bool(arch.relationship_types.has(REL_A_ENTITY)).is_true()
	assert_bool(arch.relationship_types.has(REL_B_COMP)).is_true()

	# Should NOT contain component paths
	assert_bool(arch.relationship_types.has(COMP_A)).is_false()
	assert_bool(arch.relationship_types.has(COMP_B)).is_false()


## Test 4 (ARCH-04 zero case): Component-only archetype has empty relationship_types
func test_relationship_types_empty_for_component_only():
	var arch = Archetype.new(4, [COMP_A, COMP_B])

	assert_int(arch.relationship_types.size()).is_equal(0)
	assert_array(arch.relationship_types).is_empty()


## Test 5 (ARCH-05): matches_relationship_query returns true when all required present, none excluded
func test_matches_relationship_query_positive():
	var arch = Archetype.new(5, [COMP_A, REL_A_ENTITY, COMP_B, REL_B_COMP])

	# Required keys present, no exclusions
	assert_bool(arch.matches_relationship_query([REL_A_ENTITY], [])).is_true()
	assert_bool(arch.matches_relationship_query([REL_A_ENTITY, REL_B_COMP], [])).is_true()

	# Empty required = always matches (no requirement)
	assert_bool(arch.matches_relationship_query([], [])).is_true()


## Test 6 (ARCH-05 negative): matches_relationship_query returns false when required key missing
func test_matches_relationship_query_missing_required():
	var arch = Archetype.new(6, [COMP_A, REL_A_ENTITY, COMP_B])

	# REL_B_COMP is not in this archetype
	assert_bool(arch.matches_relationship_query([REL_B_COMP], [])).is_false()
	assert_bool(arch.matches_relationship_query([REL_A_ENTITY, REL_B_COMP], [])).is_false()


## Test 7 (ARCH-05 exclusion): matches_relationship_query returns false when excluded key present
func test_matches_relationship_query_exclusion():
	var arch = Archetype.new(7, [COMP_A, REL_A_ENTITY, COMP_B, REL_B_COMP])

	# Exclude REL_A_ENTITY which is present
	assert_bool(arch.matches_relationship_query([], [REL_A_ENTITY])).is_false()

	# Require REL_A_ENTITY but exclude REL_B_COMP (which is present)
	assert_bool(arch.matches_relationship_query([REL_A_ENTITY], [REL_B_COMP])).is_false()

	# Exclude a key that is NOT present — should pass
	assert_bool(arch.matches_relationship_query([REL_A_ENTITY], [REL_A_WILDCARD])).is_true()


## Test 8 (regression): Component-only archetype works identically to before
func test_component_only_regression():
	var arch = Archetype.new(8, [COMP_A, COMP_B])

	# Create entity with components
	var entity = auto_free(Entity.new())
	var comp_a = C_TestA.new()
	var comp_b = C_TestB.new()
	entity.components[COMP_A] = comp_a
	entity.components[COMP_B] = comp_b

	# Add entity
	arch.add_entity(entity)
	assert_int(arch.size()).is_equal(1)
	assert_bool(arch.has_entity(entity)).is_true()

	# Verify columns populated correctly
	assert_int(arch.columns[COMP_A].size()).is_equal(1)
	assert_object(arch.columns[COMP_A][0]).is_same(comp_a)
	assert_int(arch.columns[COMP_B].size()).is_equal(1)
	assert_object(arch.columns[COMP_B][0]).is_same(comp_b)

	# Add second entity for swap-remove test
	var entity2 = auto_free(Entity.new())
	var comp_a2 = C_TestA.new()
	var comp_b2 = C_TestB.new()
	entity2.components[COMP_A] = comp_a2
	entity2.components[COMP_B] = comp_b2
	arch.add_entity(entity2)
	assert_int(arch.size()).is_equal(2)

	# Remove first entity (triggers swap-remove)
	arch.remove_entity(entity)
	assert_int(arch.size()).is_equal(1)
	assert_bool(arch.has_entity(entity)).is_false()
	assert_bool(arch.has_entity(entity2)).is_true()

	# Verify columns are consistent after swap-remove
	assert_int(arch.columns[COMP_A].size()).is_equal(1)
	assert_object(arch.columns[COMP_A][0]).is_same(comp_a2)
	assert_int(arch.columns[COMP_B].size()).is_equal(1)
	assert_object(arch.columns[COMP_B][0]).is_same(comp_b2)

	# entity_to_index should be correct
	assert_int(arch.entity_to_index[entity2]).is_equal(0)


## Test 9 (mixed add/remove): Columns stay in sync with mixed component + rel:// keys
func test_mixed_add_remove_columns_sync():
	var arch = Archetype.new(9, [COMP_A, REL_A_ENTITY, COMP_B, REL_B_COMP])

	# Add first entity
	var entity1 = auto_free(Entity.new())
	entity1.components[COMP_A] = C_TestA.new(10)
	entity1.components[COMP_B] = C_TestB.new(20)
	arch.add_entity(entity1)

	# Add second entity
	var entity2 = auto_free(Entity.new())
	entity2.components[COMP_A] = C_TestA.new(30)
	entity2.components[COMP_B] = C_TestB.new(40)
	arch.add_entity(entity2)

	# Add third entity
	var entity3 = auto_free(Entity.new())
	entity3.components[COMP_A] = C_TestA.new(50)
	entity3.components[COMP_B] = C_TestB.new(60)
	arch.add_entity(entity3)

	# Verify: columns exist only for components
	assert_int(arch.columns.size()).is_equal(2)
	assert_int(arch.columns[COMP_A].size()).is_equal(3)
	assert_int(arch.columns[COMP_B].size()).is_equal(3)

	# No columns for rel:// keys
	assert_bool(arch.columns.has(REL_A_ENTITY)).is_false()
	assert_bool(arch.columns.has(REL_B_COMP)).is_false()

	# Remove middle entity (entity1 at index 0 — swap with last)
	arch.remove_entity(entity1)
	assert_int(arch.size()).is_equal(2)

	# Columns should still have 2 entries each
	assert_int(arch.columns[COMP_A].size()).is_equal(2)
	assert_int(arch.columns[COMP_B].size()).is_equal(2)

	# Remaining entities should be entity2 and entity3
	assert_bool(arch.has_entity(entity2)).is_true()
	assert_bool(arch.has_entity(entity3)).is_true()

	# Clear
	arch.clear()
	assert_int(arch.size()).is_equal(0)
	assert_int(arch.columns[COMP_A].size()).is_equal(0)
	assert_int(arch.columns[COMP_B].size()).is_equal(0)

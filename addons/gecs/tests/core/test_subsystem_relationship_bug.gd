extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_Interacting = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_HasActiveItem = preload("res://addons/gecs/tests/components/c_test_d.gd")

var runner: GdUnitSceneRunner
var world: World
var test_system: TestSubsystemRelationships

# Track what was found in each subsystem for assertions
var subsystem1_found = []
var subsystem2_found = []

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	subsystem1_found.clear()
	subsystem2_found.clear()
	world.purge(false)

# Test system that uses subsystems (like InteractionsSystem)
class TestSubsystemRelationships extends System:
	var test_suite

	func sub_systems():
		return [
			# Subsystem 1: Check for entities with C_TestB and NO C_Interacting
			[ECS.world.query.with_relationship([Relationship.new(C_TestB.new())]).with_none([C_Interacting]), process_can_interact],
			# Subsystem 2: Check for entities with C_TestA (any)
			[ECS.world.query.with_relationship([Relationship.new(C_TestA.new())]), process_being_interacted],
		]

	func process_can_interact(entities: Array[Entity], components: Array, delta: float):
		print("Subsystem 1 processing: ", entities.size(), " entities")
		for entity in entities:
			print("  - Subsystem 1 found: ", entity.name)
			test_suite.subsystem1_found.append(entity)

	func process_being_interacted(entities: Array[Entity], components: Array, delta: float):
		print("Subsystem 2 processing: ", entities.size(), " entities")
		for entity in entities:
			print("  - Subsystem 2 found: ", entity.name)
			test_suite.subsystem2_found.append(entity)

func test_subsystem_with_existing_relationship_blocks_new_relationship_query():
	# Exact scenario: Player has C_HasActiveItem, walks into area getting C_CanInteractWith
	# Subsystem queries for C_CanInteractWith but doesn't find player!
	
	# Create and add our test system with subsystems
	test_system = TestSubsystemRelationships.new()
	test_system.test_suite = self
	world.add_system(test_system)

	var target = Entity.new()
	target.name = "interactable"
	world.add_entity(target)

	var player = Entity.new()
	player.name = "player"
	world.add_entity(player)

	print("\n=== Phase 1: Player has C_HasActiveItem (simulating equipped weapon) ===")
	# Player already has a relationship (simulating C_HasActiveItem from equipped weapon)
	player.add_relationship(Relationship.new(C_HasActiveItem.new(1), target))
	print("Player relationships: ", player.relationships.size())

	# Process subsystems - should find nothing yet
	subsystem1_found.clear()
	subsystem2_found.clear()
	world.process(0.016)

	print("\nAfter first process:")
	print("Subsystem1 found (C_TestB): ", subsystem1_found.size())
	print("Subsystem2 found (C_TestA): ", subsystem2_found.size())

	print("\n=== Phase 2: Player walks into area, gets C_CanInteractWith (C_TestB) ===")
	# Player walks into interaction area and gets C_CanInteractWith relationship
	player.add_relationship(Relationship.new(C_TestB.new(99), target))
	print("Player relationships: ", player.relationships.size())
	print("Player has C_TestB: ", player.has_relationship(Relationship.new(C_TestB.new())))

	# Process subsystems again - BUG: might not find player in subsystem1!
	subsystem1_found.clear()
	subsystem2_found.clear()
	world.process(0.016)

	print("\nAfter second process:")
	print("Subsystem1 found (C_TestB): ", subsystem1_found.size())
	for ent in subsystem1_found:
		print("  - ", ent.name)
	print("Subsystem2 found (C_TestA): ", subsystem2_found.size())

	# CRITICAL: Subsystem1 should have found the player!
	assert_bool(subsystem1_found.has(player)).is_true()

func test_subsystem_without_existing_relationship_works():
	# Control test: Same scenario but WITHOUT the C_HasActiveItem first
	# This should work fine
		# Create and add our test system with subsystems
	test_system = TestSubsystemRelationships.new()
	test_system.test_suite = self
	world.add_system(test_system)
	var target = Entity.new()
	target.name = "interactable"
	world.add_entity(target)

	var player = Entity.new()
	player.name = "player"
	world.add_entity(player)

	print("\n=== Control: Player gets C_TestB WITHOUT existing C_HasActiveItem ===")
	# Player walks into interaction area and gets C_CanInteractWith relationship
	player.add_relationship(Relationship.new(C_TestB.new(99), target))
	print("Player relationships: ", player.relationships.size())
	print("Player has C_TestB: ", player.has_relationship(Relationship.new(C_TestB.new())))

	# Process subsystems - should find player!
	subsystem1_found.clear()
	subsystem2_found.clear()
	world.process(0.016)

	print("\nAfter process:")
	print("Subsystem1 found (C_TestB): ", subsystem1_found.size())
	for ent in subsystem1_found:
		print("  - ", ent.name)

	# This should work
	assert_bool(subsystem1_found.has(player)).is_true()

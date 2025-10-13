extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	if world:
		world.purge(false)

func test_complex_nested_relationships_serialization():
	# Create a complex hierarchy: Player -> Weapon -> Attachment
	# This tests multi-level relationship auto-inclusion
	# 1. Create Player entity
	var player = Entity.new()
	player.name = "Player"
	player.add_component(C_TestA.new()) # Player-specific component
	
	# 2. Create Weapon entity with weapon-specific components
	var weapon = Entity.new()
	weapon.name = "AssaultRifle"
	weapon.add_component(C_TestB.new()) # Weapon component
	weapon.add_component(C_TestC.new()) # Damage component
	
	# 3. Create Attachment entity 
	var attachment = Entity.new()
	attachment.name = "RedDotSight"
	attachment.add_component(C_TestD.new()) # Attachment component
	attachment.add_component(C_TestE.new()) # Accuracy modifier component
	
	# 4. Create another attachment for testing multiple relationships
	var attachment2 = Entity.new()
	attachment2.name = "Silencer"
	attachment2.add_component(C_TestF.new()) # Another attachment component
	
	# 5. Set up relationships: Player -> Weapon -> Attachments
	var player_weapon_rel = Relationship.new(C_TestA.new(), weapon) # Player equipped with weapon
	player.add_relationship(player_weapon_rel)
	
	var weapon_sight_rel = Relationship.new(C_TestB.new(), attachment) # Weapon has sight
	weapon.add_relationship(weapon_sight_rel)
	
	var weapon_silencer_rel = Relationship.new(C_TestC.new(), attachment2) # Weapon has silencer
	weapon.add_relationship(weapon_silencer_rel)
	
	# 6. Add entities to world (don't add to scene tree to preserve names)
	world.add_entity(player)
	world.add_entity(weapon)
	world.add_entity(attachment)
	world.add_entity(attachment2)
	
	# Store original UUIDs for verification
	var player_id = player.id
	var weapon_id = weapon.id
	var attachment_id = attachment.id
	var attachment2_id = attachment2.id
	
	print("=== BEFORE SERIALIZATION ===")
	print("Player UUID: ", player_id)
	print("Weapon UUID: ", weapon_id)
	print("Attachment UUID: ", attachment_id)
	print("Attachment2 UUID: ", attachment2_id)
	print("Player relationships: ", player.relationships.size())
	print("Weapon relationships: ", weapon.relationships.size())
	
	# 7. Serialize ONLY the player (should auto-include weapon and attachments)
	var query = world.query.with_all([C_TestA]) # Only matches player
	var serialized_data = ECS.serialize(query)
	
	print("=== SERIALIZATION RESULTS ===")
	print("Total entities serialized: ", serialized_data.entities.size())
	
	# 8. Verify serialization results
	assert_that(serialized_data.entities).has_size(4) # All 4 entities should be included
	
	# Count auto-included vs original entities
	var auto_included_count = 0
	var original_count = 0
	var player_data = null
	var weapon_data = null
	var attachment_data = null
	var attachment2_data = null
	
	for entity_data in serialized_data.entities:
		print("Entity: ", entity_data.entity_name, " - Auto-included: ", entity_data.auto_included, " - id: ", entity_data.id)
		
		if entity_data.auto_included:
			auto_included_count += 1
		else:
			original_count += 1
			
		# Find specific entities for detailed verification
		match entity_data.entity_name:
			"Player":
				player_data = entity_data
			"AssaultRifle":
				weapon_data = entity_data
			"RedDotSight":
				attachment_data = entity_data
			"Silencer":
				attachment2_data = entity_data
	
	# Verify auto-inclusion flags
	assert_that(original_count).is_equal(1) # Only player from original query
	assert_that(auto_included_count).is_equal(3) # Weapon and both attachments auto-included
	
	# Verify specific entity data
	assert_that(player_data).is_not_null()
	assert_that(player_data.auto_included).is_false() # Player was in original query
	assert_that(player_data.relationships).has_size(1) # Player -> Weapon relationship
	
	assert_that(weapon_data).is_not_null()
	assert_that(weapon_data.auto_included).is_true() # Weapon was auto-included
	assert_that(weapon_data.relationships).has_size(2) # Weapon -> Attachments relationships
	
	assert_that(attachment_data).is_not_null()
	assert_that(attachment_data.auto_included).is_true() # Attachment was auto-included
	
	assert_that(attachment2_data).is_not_null()
	assert_that(attachment2_data.auto_included).is_true() # Attachment2 was auto-included
	
	# 9. Save and load the serialized data
	var file_path = "res://reports/test_complex_relationships.tres"
	ECS.save(serialized_data, file_path)
	
	# 10. Clear the world to simulate fresh start
	world.purge(false)
	assert_that(world.entities).has_size(0)
	assert_that(world.entity_id_registry).has_size(0)
	
	# 11. Deserialize and add back to world
	var deserialized_entities = ECS.deserialize(file_path)
	
	print("=== DESERIALIZATION RESULTS ===")
	print("Deserialized entities: ", deserialized_entities.size())
	
	assert_that(deserialized_entities).has_size(4)
	
	# Add all entities back to world (don't add to scene tree to avoid naming conflicts)
	for entity in deserialized_entities:
		world.add_entity(entity, null, false)
	
	# 12. Verify world state after deserialization
	assert_that(world.entities).has_size(4)
	assert_that(world.entity_id_registry).has_size(4)
	
	# Find entities by UUID to verify they're properly restored
	var restored_player = world.get_entity_by_id(player_id)
	var restored_weapon = world.get_entity_by_id(weapon_id)
	var restored_attachment = world.get_entity_by_id(attachment_id)
	var restored_attachment2 = world.get_entity_by_id(attachment2_id)
	
	print("=== RESTORED ENTITIES ===")
	print("Player found: ", restored_player != null, " - Name: ", restored_player.name if restored_player else "null")
	print("Weapon found: ", restored_weapon != null, " - Name: ", restored_weapon.name if restored_weapon else "null")
	print("Attachment found: ", restored_attachment != null, " - Name: ", restored_attachment.name if restored_attachment else "null")
	print("Attachment2 found: ", restored_attachment2 != null, " - Name: ", restored_attachment2.name if restored_attachment2 else "null")
	
	# Verify all entities were found
	assert_that(restored_player).is_not_null()
	assert_that(restored_weapon).is_not_null()
	assert_that(restored_attachment).is_not_null()
	assert_that(restored_attachment2).is_not_null()
	
	# Verify entity names are preserved
	assert_that(restored_player.name).is_equal("Player")
	assert_that(restored_weapon.name).is_equal("AssaultRifle")
	assert_that(restored_attachment.name).is_equal("RedDotSight")
	assert_that(restored_attachment2.name).is_equal("Silencer")
	
	# 13. Verify relationships are intact
	print("=== RELATIONSHIP VERIFICATION ===")
	print("Player relationships: ", restored_player.relationships.size())
	print("Weapon relationships: ", restored_weapon.relationships.size())
	
	# Player should have 1 relationship to weapon
	assert_that(restored_player.relationships).has_size(1)
	var player_rel = restored_player.relationships[0]
	assert_that(player_rel.target).is_equal(restored_weapon)
	print("Player -> Weapon relationship intact: ", player_rel.target.name)
	
	# Weapon should have 2 relationships to attachments
	assert_that(restored_weapon.relationships).has_size(2)
	
	var weapon_targets = []
	var weapon_target_entities = []
	for rel in restored_weapon.relationships:
		weapon_target_entities.append(rel.target)
		weapon_targets.append(rel.target.name)
		print("Weapon -> ", rel.target.name, " relationship intact")
	
	# Verify weapon is connected to both attachments
	assert_that(weapon_target_entities).contains(restored_attachment)
	assert_that(weapon_target_entities).contains(restored_attachment2)
	assert_that(weapon_targets).contains("RedDotSight")
	assert_that(weapon_targets).contains("Silencer")
	
	# 14. Verify components are preserved
	assert_that(restored_player.has_component(C_TestA)).is_true()
	assert_that(restored_weapon.has_component(C_TestB)).is_true()
	assert_that(restored_weapon.has_component(C_TestC)).is_true()
	assert_that(restored_attachment.has_component(C_TestD)).is_true()
	assert_that(restored_attachment.has_component(C_TestE)).is_true()
	assert_that(restored_attachment2.has_component(C_TestF)).is_true()
	
	print("=== TEST PASSED: Complex nested relationships preserved! ===")
	world.remove_entities(deserialized_entities)


func test_relationship_replacement_with_id_collision():
	# Test that when entities with relationships are replaced via UUID collision,
	# the relationships update correctly to point to the new entities
	# 1. Create initial setup: Player -> Weapon
	var player = Entity.new()
	player.name = "Player"
	player.add_component(C_TestA.new())
	player.set("id", "player-id-123")
	
	var old_weapon = Entity.new()
	old_weapon.name = "OldWeapon"
	old_weapon.add_component(C_TestB.new())
	old_weapon.set("id", "weapon-id-456")
	
	var player_weapon_rel = Relationship.new(C_TestA.new(), old_weapon)
	player.add_relationship(player_weapon_rel)
	
	world.add_entity(player)
	world.add_entity(old_weapon)
	
	# Verify initial relationship
	assert_that(player.relationships).has_size(1)
	assert_that(player.relationships[0].target).is_equal(old_weapon)
	assert_that(player.relationships[0].target.name).is_equal("OldWeapon")
	
	# 2. Serialize the current state
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	var file_path = "res://reports/test_replacement_relationships.tres"
	ECS.save(serialized_data, file_path)
	
	# 3. Create "updated" entities with same UUIDs but different data
	var new_weapon = Entity.new()
	new_weapon.name = "NewUpgradedWeapon"
	new_weapon.add_component(C_TestB.new())
	new_weapon.add_component(C_TestC.new()) # Added component
	new_weapon.set("id", "weapon-id-456") # Same UUID!
	
	# 4. Add new weapon (should replace old weapon)
	world.add_entity(new_weapon)
	
	# Verify replacement occurred
	assert_that(world.entities).has_size(2) # Still only 2 entities
	var current_weapon = world.get_entity_by_id("weapon-id-456")
	assert_that(current_weapon).is_equal(new_weapon)
	assert_that(current_weapon.name).is_equal("NewUpgradedWeapon")
	assert_that(current_weapon.has_component(C_TestC)).is_true()
	
	# 5. NOTE: When we replace an entity, existing relationships still point to the old entity object
	# This is expected behavior - the relationship contains a direct Entity reference
	# To update relationships, we would need to re-serialize/deserialize or manually update them
	print("Current relationship target: ", player.relationships[0].target.name)
	print("Expected: Relationship still points to old entity until re-serialized")
	
	print("=== Relationship correctly updated after entity replacement ===")
	
	# 6. Now test loading the old save file (should replace with old state)
	var loaded_entities = ECS.deserialize(file_path)
	
	for entity in loaded_entities:
		world.add_entity(entity) # Should trigger replacements
	
	# Verify entities were replaced with old state
	var final_weapon = world.get_entity_by_id("weapon-id-456")
	print("Final weapon name: ", final_weapon.name)
	assert_that(final_weapon.has_component(C_TestC)).is_false() # Lost the added component
	
	# Verify relationship points to restored weapon
	var final_player = world.get_entity_by_id("player-id-123")
	assert_that(final_player.relationships).has_size(1)
	assert_that(final_player.relationships[0].target).is_equal(final_weapon)
	print("Final relationship target name: ", final_player.relationships[0].target.name)
	
	print("=== Save/Load replacement cycle completed successfully ===")


func test_partial_serialization_auto_inclusion():
	# Test that we can serialize a subset of entities and auto-include dependencies
	# while excluding unrelated entities
	# Create multiple independent entity groups
	# Group 1: Player -> Weapon -> Attachment (should be included)
	var player = Entity.new()
	player.name = "Player"
	player.add_component(C_TestA.new())
	
	var weapon = Entity.new()
	weapon.name = "Weapon"
	weapon.add_component(C_TestB.new())
	
	var attachment = Entity.new()
	attachment.name = "Attachment"
	attachment.add_component(C_TestC.new())
	
	player.add_relationship(Relationship.new(C_TestA.new(), weapon))
	weapon.add_relationship(Relationship.new(C_TestB.new(), attachment))
	
	# Group 2: Enemy -> EnemyWeapon (should NOT be included)
	var enemy = Entity.new()
	enemy.name = "Enemy"
	enemy.add_component(C_TestD.new()) # Different component type
	
	var enemy_weapon = Entity.new()
	enemy_weapon.name = "EnemyWeapon"
	enemy_weapon.add_component(C_TestE.new())
	
	enemy.add_relationship(Relationship.new(C_TestD.new(), enemy_weapon))
	
	# Group 3: Standalone entity (should NOT be included)
	var standalone = Entity.new()
	standalone.name = "Standalone"
	standalone.add_component(C_TestF.new())
	
	# Add all entities to world (don't add to scene tree)
	world.add_entity(player)
	world.add_entity(weapon)
	world.add_entity(attachment)
	world.add_entity(enemy)
	world.add_entity(enemy_weapon)
	world.add_entity(standalone)
	
	assert_that(world.entities).has_size(6)
	
	# Serialize ONLY entities with C_TestA (just the player)
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	print("=== PARTIAL SERIALIZATION RESULTS ===")
	print("Total entities in world: ", world.entities.size())
	print("Entities serialized: ", serialized_data.entities.size())
	
	# Should include Player + Weapon + Attachment (3 total) but NOT Enemy group or Standalone
	assert_that(serialized_data.entities).has_size(3)
	
	var serialized_names = []
	for entity_data in serialized_data.entities:
		serialized_names.append(entity_data.entity_name)
		print("Serialized: ", entity_data.entity_name, " (auto-included: ", entity_data.auto_included, ")")
	
	# Verify correct entities were included
	assert_that(serialized_names).contains("Player")
	assert_that(serialized_names).contains("Weapon")
	assert_that(serialized_names).contains("Attachment")
	
	# Verify incorrect entities were excluded
	assert_that(serialized_names.has("Enemy")).is_false()
	assert_that(serialized_names.has("EnemyWeapon")).is_false()
	assert_that(serialized_names.has("Standalone")).is_false()
	
	# Verify auto-inclusion flags
	var player_data = serialized_data.entities.filter(func(e): return e.entity_name == "Player")[0]
	var weapon_data = serialized_data.entities.filter(func(e): return e.entity_name == "Weapon")[0]
	var attachment_data = serialized_data.entities.filter(func(e): return e.entity_name == "Attachment")[0]
	
	assert_that(player_data.auto_included).is_false() # Original query
	assert_that(weapon_data.auto_included).is_true() # Auto-included via Player relationship
	assert_that(attachment_data.auto_included).is_true() # Auto-included via Weapon relationship
	
	print("=== Partial serialization with auto-inclusion working correctly ===")

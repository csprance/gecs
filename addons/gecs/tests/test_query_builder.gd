extends GutTest

func test_query_entities_with_all_components():
	var world = World.new()
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()

	# Entity1 has Velocity and Transform
	entity1.add_component(test_a)
	entity1.add_component(test_b)
	# Entity2 has TestA only
	entity2.add_component(test_a.duplicate())
	# Entity3 has all three components
	entity3.add_component(test_a.duplicate())
	entity3.add_component(test_b.duplicate())
	entity3.add_component(test_c.duplicate())

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query entities with both Velocity and Transform components
	var result = QueryBuilder.new(world).with_all([C_TestA]).execute()
	assert_eq(result.size(), 3, "All entities with C_TestA should be returned.")
	
	result = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).execute()
	assert_eq(result.size(), 2, "Entities with both C_TestA and C_TestB should be returned.")
	assert_true(result.has(entity1), "Entity1 should be in the result.")
	assert_true(result.has(entity3), "Entity3 should be in the result.")
	assert_false(result.has(entity2), "Entity2 should not be in the result.")

# func test_query_entities_with_any_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()

# 	var velocity_component = Velocity.new()
# 	var health_component = Health.new()
# 	var transform_component = Transform.new()

# 	# Entity1 has Velocity
# 	entity1.add_component(velocity_component)
# 	# Entity2 has Health
# 	entity2.add_component(health_component)
# 	# Entity3 has Transform
# 	entity3.add_component(transform_component)

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)

# 	# Query entities with any of Velocity, Health
# 	var result = QueryBuilder.new(world).with_any([Velocity, Health]).execute()
# 	assert_eq(result.size(), 2, "Entities with Velocity or Health should be returned.")
# 	assert_true(result.has(entity1), "Entity1 should be in the result.")
# 	assert_true(result.has(entity2), "Entity2 should be in the result.")
# 	assert_false(result.has(entity3), "Entity3 should not be in the result.")

# func test_query_entities_excluding_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()

# 	var velocity_component = Velocity.new()
# 	var health_component = Health.new()

# 	# Entity1 has Velocity
# 	entity1.add_component(velocity_component)
# 	# Entity2 has Velocity and Health
# 	entity2.add_component(velocity_component.duplicate())
# 	entity2.add_component(health_component)
# 	# Entity3 has no components

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)

# 	# Query entities with Velocity but excluding those with Health
# 	var result = QueryBuilder.new(world).with_all([Velocity]).with_none([Health]).execute()
# 	assert_eq(result.size(), 1, "Only entities with Velocity and without Health should be returned.")
# 	assert_true(result.has(entity1), "Entity1 should be in the result.")
# 	assert_false(result.has(entity2), "Entity2 should not be in the result.")
# 	assert_false(result.has(entity3), "Entity3 should not be in the result.")

# func test_query_entities_with_all_and_any_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()
# 	var entity4 = Entity.new()

# 	var velocity_component = Velocity.new()
# 	var transform_component = Transform.new()
# 	var health_component = Health.new()
# 	var friction_component = Friction.new()

# 	# Entity1 has Velocity and Transform
# 	entity1.add_component(velocity_component)
# 	entity1.add_component(transform_component)
# 	# Entity2 has Velocity, Transform, and Health
# 	entity2.add_component(velocity_component.duplicate())
# 	entity2.add_component(transform_component.duplicate())
# 	entity2.add_component(health_component)
# 	# Entity3 has Velocity, Transform, and Friction
# 	entity3.add_component(velocity_component.duplicate())
# 	entity3.add_component(transform_component.duplicate())
# 	entity3.add_component(friction_component)
# 	# Entity4 has Velocity only
# 	entity4.add_component(velocity_component.duplicate())

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)
# 	world.add_entity(entity4)

# 	# Query entities with Velocity and Transform, and any of Health or Friction
# 	var result = world.query(
# 		[Velocity, Transform],
# 		[Health, Friction]
# 	)
# 	assert_eq(result.size(), 2, "Entities with Velocity and Transform, and any of Health or Friction should be returned.")
# 	assert_true(result.has(entity2), "Entity2 should be in the result.")
# 	assert_true(result.has(entity3), "Entity3 should be in the result.")
# 	assert_false(result.has(entity1), "Entity1 should not be in the result.")
# 	assert_false(result.has(entity4), "Entity4 should not be in the result.")

# func test_query_entities_with_any_and_exclude_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()
# 	var entity4 = Entity.new()

# 	var Health = preload("res://game/components/health.gd")
# 	var Bounce = preload("res://game/components/bounce.gd")
# 	var Friction = preload("res://game/components/friction.gd")

# 	var health_component = Health.new()
# 	var bounce_component = Bounce.new()
# 	var friction_component = Friction.new()

# 	# Entity1 has Health
# 	entity1.add_component(health_component)
# 	# Entity2 has Friction
# 	entity2.add_component(friction_component)
# 	# Entity3 has Bounce
# 	entity3.add_component(bounce_component)
# 	# Entity4 has Health and Friction
# 	entity4.add_component(health_component.duplicate())
# 	entity4.add_component(friction_component.duplicate())

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)
# 	world.add_entity(entity4)

# 	# Query entities with any of Health or Friction, excluding Bounce
# 	var result = world.query(
# 		[Health, Friction],
# 		[Bounce]
# 	)
# 	assert_eq(result.size(), 3, "Entities with Health or Friction, excluding those with Bounce should be returned.")
# 	assert_true(result.has(entity1), "Entity1 should be in the result.")
# 	assert_true(result.has(entity2), "Entity2 should be in the result.")
# 	assert_true(result.has(entity4), "Entity4 should be in the result.")
# 	assert_false(result.has(entity3), "Entity3 should not be in the result.")

# func test_query_entities_with_all_any_and_exclude_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()
# 	var entity4 = Entity.new()
# 	var entity5 = Entity.new()

# 	var Velocity = preload("res://game/components/velocity.gd")
# 	var Transform = preload("res://game/components/transform.gd")
# 	var Health = preload("res://game/components/health.gd")
# 	var Bounce = preload("res://game/components/bounce.gd")
# 	var Friction = preload("res://game/components/friction.gd")

# 	var velocity_component = Velocity.new()
# 	var transform_component = Transform.new()
# 	var health_component = Health.new()
# 	var bounce_component = Bounce.new()
# 	var friction_component = Friction.new()

# 	# Entity1 has Velocity, Transform, Bounce
# 	entity1.add_component(velocity_component)
# 	entity1.add_component(transform_component)
# 	entity1.add_component(bounce_component)
# 	# Entity2 has Velocity, Transform, Health
# 	entity2.add_component(velocity_component.duplicate())
# 	entity2.add_component(transform_component.duplicate())
# 	entity2.add_component(health_component)
# 	# Entity3 has Velocity, Transform, Friction
# 	entity3.add_component(velocity_component.duplicate())
# 	entity3.add_component(transform_component.duplicate())
# 	entity3.add_component(friction_component)
# 	# Entity4 has Transform, Health
# 	entity4.add_component(transform_component.duplicate())
# 	entity4.add_component(health_component.duplicate())
# 	# Entity5 has Velocity, Transform, Health, Bounce
# 	entity5.add_component(velocity_component.duplicate())
# 	entity5.add_component(transform_component.duplicate())
# 	entity5.add_component(health_component.duplicate())
# 	entity5.add_component(bounce_component.duplicate())

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)
# 	world.add_entity(entity4)
# 	world.add_entity(entity5)

# 	# Query entities with Velocity and Transform, any of Health or Friction, excluding Bounce
# 	var result = world.query(
# 		[Velocity, Transform],
# 		[Health, Friction],
# 		[Bounce]
# 	)
# 	assert_eq(result.size(), 1, "Only Entity3 should match the query.")
# 	assert_true(result.has(entity3), "Entity3 should be in the result.")
# 	assert_false(result.has(entity1), "Entity1 should not be in the result (has Bounce).")
# 	assert_false(result.has(entity2), "Entity2 should not be in the result (has Bounce).")
# 	assert_false(result.has(entity4), "Entity4 should not be in the result (missing Velocity).")
# 	assert_false(result.has(entity5), "Entity5 should not be in the result (has Bounce).")

# func test_query_entities_with_no_components():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	world.add_entity(entity1)
# 	world.add_entity(entity2)

# 	# Query with no components specified should return all entities
# 	var result = world.query()
# 	assert_eq(result.size(), 2, "All entities should be returned when no components are specified.")
# 	assert_true(result.has(entity1), "Entity1 should be in the result.")
# 	assert_true(result.has(entity2), "Entity2 should be in the result.")

# func test_query_entities_excluding_only():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()

# 	var Health = preload("res://game/components/health.gd")
# 	var health_component = Health.new()

# 	# Entity1 has Health
# 	entity1.add_component(health_component)
# 	# Entity2 and Entity3 have no components

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)

# 	# Query excluding entities with Health
# 	var result = world.query([], [], [Health])
# 	assert_eq(result.size(), 2, "Entities without Health should be returned.")
# 	assert_true(result.has(entity2), "Entity2 should be in the result.")
# 	assert_true(result.has(entity3), "Entity3 should be in the result.")
# 	assert_false(result.has(entity1), "Entity1 should not be in the result.")

# func test_query_with_no_matching_entities():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()

# 	var Velocity = preload("res://game/components/velocity.gd")
# 	var Health = preload("res://game/components/health.gd")

# 	var velocity_component = Velocity.new()
# 	var health_component = Health.new()

# 	# Entity1 has Velocity
# 	entity1.add_component(velocity_component)
# 	# Entity2 has Health
# 	entity2.add_component(health_component)

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)

# 	# Query entities with both Velocity and Health (no entity has both)
# 	var result = world.query([Velocity, Health])
# 	assert_eq(result.size(), 0, "No entities should match the query.")
# 	world = World.new()
# 	var entity = Entity.new()

# 	var velocity_component1 = Velocity.new()
# 	var velocity_component2 = Velocity.new()

# 	# Add two Velocity components to the same entity (edge case)
# 	entity.add_component(velocity_component1)
# 	entity.add_component(velocity_component2)

# 	world.add_entity(entity)

# 	# Query entities with Velocity
# 	result = world.query([Velocity])
# 	assert_eq(result.size(), 1, "Entity with duplicate components should still be returned.")
# 	assert_true(result.has(entity), "Entity should be in the result.")
# 	# Assuming you have components that inherit from other components
# 	world = World.new()
# 	entity = Entity.new()

# func test_query_entities_with_multiple_excludes():
# 	var world = World.new()
# 	var entity1 = Entity.new()
# 	var entity2 = Entity.new()
# 	var entity3 = Entity.new()

# 	var Health = preload("res://game/components/health.gd")
# 	var Velocity = preload("res://game/components/velocity.gd")
# 	var Bounce = preload("res://game/components/bounce.gd")

# 	var health_component = Health.new()
# 	var velocity_component = Velocity.new()
# 	var bounce_component = Bounce.new()

# 	# Entity1 has Health
# 	entity1.add_component(health_component)
# 	# Entity2 has Velocity and Bounce
# 	entity2.add_component(velocity_component)
# 	entity2.add_component(bounce_component)
# 	# Entity3 has Bounce only
# 	entity3.add_component(bounce_component.duplicate())

# 	world.add_entity(entity1)
# 	world.add_entity(entity2)
# 	world.add_entity(entity3)

# 	# Query excluding entities with Health or Bounce
# 	var result = world.query([], [],[Health, Bounce])
# 	assert_eq(result.size(), 0, "No entities should be returned when all are excluded.")
# 	# Now add an entity without excluded components
# 	var entity4 = Entity.new()
# 	world.add_entity(entity4)
# 	result = world.query([], [],[Health, Bounce])
# 	assert_eq(result.size(), 1, "Entities without Health or Bounce should be returned.")
# 	assert_true(result.has(entity4), "Entity4 should be in the result.")


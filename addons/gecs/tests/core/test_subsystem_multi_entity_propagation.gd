extends GdUnitTestSuite

## Test suite for multi-entity subsystem propagation (projectile scenario)
## Tests that when subsystem A adds components to MULTIPLE entities,
## subsystem B sees ALL of them in the same frame

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Test the exact projectile scenario: travelling entities that collide get C_Collision added,
## then collision subsystem processes all entities with C_Collision
func test_projectile_collision_propagation():
	# Create 3 "projectiles" with base components (simulating travelling projectiles)
	var projectile1 = Entity.new()
	var projectile2 = Entity.new()
	var projectile3 = Entity.new()

	projectile1.add_component(C_OrderTestA.new())  # Represents C_Projectile
	projectile1.add_component(C_OrderTestB.new())  # Represents C_Velocity
	projectile2.add_component(C_OrderTestA.new())
	projectile2.add_component(C_OrderTestB.new())
	projectile3.add_component(C_OrderTestA.new())
	projectile3.add_component(C_OrderTestB.new())

	world.add_entities([projectile1, projectile2, projectile3])

	# System simulates: travelling_subsys adds collision, then collision_subsys processes them
	var system = ProjectileCollisionSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: travelling_subsys saw 3 entities
	assert_int(system.travelling_count).is_equal(3)

	# Verify: travelling_subsys added collision to all 3
	assert_int(system.collisions_added).is_equal(3)

	# CRITICAL: collision_subsys should see ALL 3 entities with collision
	assert_int(system.collision_count).is_equal(3)

	# Verify: All entities have the collision component
	assert_bool(projectile1.has_component(C_OrderTestC)).is_true()
	assert_bool(projectile2.has_component(C_OrderTestC)).is_true()
	assert_bool(projectile3.has_component(C_OrderTestC)).is_true()


## Test with many entities (10 projectiles) to ensure it scales
func test_projectile_collision_propagation_at_scale():
	var projectiles = []

	# Create 10 projectiles
	for i in 10:
		var projectile = Entity.new()
		projectile.add_component(C_OrderTestA.new())
		projectile.add_component(C_OrderTestB.new())
		projectiles.append(projectile)

	world.add_entities(projectiles)

	var system = ProjectileCollisionSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: travelling_subsys saw 10 entities
	assert_int(system.travelling_count).is_equal(10)

	# Verify: travelling_subsys added collision to all 10
	assert_int(system.collisions_added).is_equal(10)

	# CRITICAL: collision_subsys should see ALL 10 entities
	assert_int(system.collision_count).is_equal(10)

	# Verify: All entities have collision
	for projectile in projectiles:
		assert_bool(projectile.has_component(C_OrderTestC)).is_true()


## Test when only SOME entities collide (partial propagation)
func test_projectile_partial_collision_propagation():
	var projectile1 = Entity.new()
	var projectile2 = Entity.new()
	var projectile3 = Entity.new()
	var projectile4 = Entity.new()

	# All start with A+B
	projectile1.add_component(C_OrderTestA.new())
	projectile1.add_component(C_OrderTestB.new())
	projectile2.add_component(C_OrderTestA.new())
	projectile2.add_component(C_OrderTestB.new())
	projectile3.add_component(C_OrderTestA.new())
	projectile3.add_component(C_OrderTestB.new())
	projectile4.add_component(C_OrderTestA.new())
	projectile4.add_component(C_OrderTestB.new())

	world.add_entities([projectile1, projectile2, projectile3, projectile4])

	# System that only adds collision to SOME entities
	var system = ProjectilePartialCollisionSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: travelling_subsys saw 4 entities
	assert_int(system.travelling_count).is_equal(4)

	# Verify: only 2 collisions added (system logic adds every other)
	assert_int(system.collisions_added).is_equal(2)

	# CRITICAL: collision_subsys should see exactly 2 entities
	assert_int(system.collision_count).is_equal(2)


## Test entities that add collision and then get removed in collision handler
func test_projectile_collision_then_removal():
	var projectiles = []

	# Create 5 projectiles
	for i in 5:
		var projectile = Entity.new()
		projectile.add_component(C_OrderTestA.new())
		projectile.add_component(C_OrderTestB.new())
		projectiles.append(projectile)

	world.add_entities(projectiles)

	var system = ProjectileCollisionRemovalSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: travelling_subsys saw 5 entities
	assert_int(system.travelling_count).is_equal(5)

	# Verify: collision_subsys saw 5 entities
	assert_int(system.collision_count).is_equal(5)

	# Verify: All 5 entities were removed
	assert_int(system.entities_removed.size()).is_equal(5)

	# Verify: Entities are no longer in the world
	var remaining = world.query.with_all([C_OrderTestA]).execute()
	assert_int(remaining.size()).is_equal(0)


## Test EXACT projectile scenario: travelling adds collision, collision subsys processes and removes
## This tests with multiple entities being processed together and removed in batch
func test_exact_projectile_scenario_with_batch_removal():
	var projectiles = []

	# Create 5 projectiles (simulating multiple projectiles fired)
	for i in 5:
		var projectile = Entity.new()
		projectile.name = "Projectile_%d" % i
		projectile.add_component(C_OrderTestA.new())  # C_Projectile
		projectile.add_component(C_OrderTestB.new())  # C_Velocity
		projectiles.append(projectile)

	world.add_entities(projectiles)

	# System that mimics your exact code structure
	var system = ExactProjectileSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: All projectiles were seen in travelling
	assert_int(system.travelling_count).is_equal(5)

	# CRITICAL: All projectiles should be seen in collision subsystem
	assert_int(system.collision_count).is_equal(5)

	# Verify: All projectiles were removed
	var remaining_projectiles = world.query.with_all([C_OrderTestA]).execute()
	assert_int(remaining_projectiles.size()).is_equal(0)

	# Verify: No projectiles with collision component remain either
	var remaining_with_collision = world.query.with_all([C_OrderTestA, C_OrderTestC]).execute()
	assert_int(remaining_with_collision.size()).is_equal(0)


## Test multiple frames to see if entities accumulate (your actual bug)
func test_multiple_frames_with_projectiles():
	# Frame 1: Fire 3 projectiles
	var frame1_projectiles = []
	for i in 3:
		var p = Entity.new()
		p.name = "Frame1_Projectile_%d" % i
		p.add_component(C_OrderTestA.new())
		p.add_component(C_OrderTestB.new())
		frame1_projectiles.append(p)
	world.add_entities(frame1_projectiles)

	var system = ExactProjectileSystem.new()
	world.add_system(system)

	# Process frame 1
	world.process(0.016)
	assert_int(world.query.with_all([C_OrderTestA]).execute().size()).is_equal(0)

	# Frame 2: Fire 4 more projectiles
	var frame2_projectiles = []
	for i in 4:
		var p = Entity.new()
		p.name = "Frame2_Projectile_%d" % i
		p.add_component(C_OrderTestA.new())
		p.add_component(C_OrderTestB.new())
		frame2_projectiles.append(p)
	world.add_entities(frame2_projectiles)

	# Process frame 2
	world.process(0.016)
	assert_int(world.query.with_all([C_OrderTestA]).execute().size()).is_equal(0)

	# Frame 3: Fire 5 more projectiles (this is where it might break)
	var frame3_projectiles = []
	for i in 5:
		var p = Entity.new()
		p.name = "Frame3_Projectile_%d" % i
		p.add_component(C_OrderTestA.new())
		p.add_component(C_OrderTestB.new())
		frame3_projectiles.append(p)
	world.add_entities(frame3_projectiles)

	# Process frame 3
	world.process(0.016)

	# CRITICAL: All projectiles should be removed, none should accumulate
	var remaining = world.query.with_all([C_OrderTestA]).execute()
	assert_int(remaining.size()).is_equal(0)


## REGRESSION TEST: Cache invalidation when removing entities
## This test ensures that _remove_entity_from_archetype() invalidates the query cache.
## Without cache invalidation, queries in subsequent frames would return stale archetype references.
##
## BUG: If _remove_entity_from_archetype() doesn't call _invalidate_cache(), then:
## 1. Frame N: Entities removed, cache still points to old archetype state
## 2. Frame N+1: Query uses stale cache, processes wrong/deleted entities
func test_cache_invalidation_on_entity_removal():
	# Frame 1: Create and remove entities
	var frame1_entities = []
	for i in 3:
		var e = Entity.new()
		e.name = "Frame1_Entity_%d" % i
		e.add_component(C_OrderTestA.new())
		frame1_entities.append(e)
	world.add_entities(frame1_entities)

	# Verify entities exist
	var query_result = world.query.with_all([C_OrderTestA]).execute()
	assert_int(query_result.size()).is_equal(3)

	# Remove all entities - this MUST invalidate the cache
	world.remove_entities(frame1_entities)

	# Verify entities are gone
	query_result = world.query.with_all([C_OrderTestA]).execute()
	assert_int(query_result.size()).is_equal(0)

	# Frame 2: Create NEW entities with same components
	var frame2_entities = []
	for i in 5:
		var e = Entity.new()
		e.name = "Frame2_Entity_%d" % i
		e.add_component(C_OrderTestA.new())
		frame2_entities.append(e)
	world.add_entities(frame2_entities)

	# CRITICAL: Query should return ONLY the 5 new entities, not stale references
	query_result = world.query.with_all([C_OrderTestA]).execute()
	assert_int(query_result.size()).is_equal(5)

	# Verify the entities in the result are the NEW ones, not deleted ones
	for entity in query_result:
		assert_bool(frame2_entities.has(entity)).is_true()
		assert_str(entity.name).starts_with("Frame2_Entity_")


## Test with entities in different starting archetypes (some have extra components)
func test_projectile_mixed_archetypes():
	# 2 basic projectiles (A+B)
	var projectile1 = Entity.new()
	var projectile2 = Entity.new()
	projectile1.add_component(C_OrderTestA.new())
	projectile1.add_component(C_OrderTestB.new())
	projectile2.add_component(C_OrderTestA.new())
	projectile2.add_component(C_OrderTestB.new())

	# 2 "special" projectiles with extra component (different archetype)
	var projectile3 = Entity.new()
	var projectile4 = Entity.new()
	var extra_comp1 = C_DomainTestA.new()
	var extra_comp2 = C_DomainTestA.new()
	projectile3.add_component(C_OrderTestA.new())
	projectile3.add_component(C_OrderTestB.new())
	projectile3.add_component(extra_comp1)
	projectile4.add_component(C_OrderTestA.new())
	projectile4.add_component(C_OrderTestB.new())
	projectile4.add_component(extra_comp2)

	world.add_entities([projectile1, projectile2, projectile3, projectile4])

	var system = ProjectileCollisionSystem.new()
	world.add_system(system)

	# Process system once
	world.process(0.016)

	# Verify: ALL 4 entities were processed despite different starting archetypes
	assert_int(system.travelling_count).is_equal(4)
	assert_int(system.collisions_added).is_equal(4)
	assert_int(system.collision_count).is_equal(4)


## ===============================
## TEST HELPER SYSTEMS
## ===============================

## Simulates the ProjectileSystem: travelling_subsys adds collision, collision_subsys processes
class ProjectileCollisionSystem extends System:
	var travelling_count = 0
	var collisions_added = 0
	var collision_count = 0

	func sub_systems() -> Array[Array]:
		return [
			# Travelling subsystem: entities with A+B (no C yet)
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]), travelling_subsys],
			# Collision subsystem: entities with A+B+C
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB, C_OrderTestC]), collision_subsys]
		]

	func travelling_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - called once per archetype
		# Accumulate count across all archetype calls
		travelling_count += entities.size()
		# Simulate all entities colliding and getting C_Collision (OrderTestC)
		for entity in entities:
			entity.add_component(C_OrderTestC.new())
			collisions_added += 1

	func collision_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - called once per archetype
		# Accumulate count across all archetype calls
		collision_count += entities.size()
		# Just count how many we see


## System where only SOME entities collide
class ProjectilePartialCollisionSystem extends System:
	var travelling_count = 0
	var collisions_added = 0
	var collision_count = 0

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]), travelling_subsys],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB, C_OrderTestC]), collision_subsys]
		]

	func travelling_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - accumulate across archetype calls
		travelling_count += entities.size()
		# Only add collision to every other entity
		var collide = true
		for entity in entities:
			if collide:
				entity.add_component(C_OrderTestC.new())
				collisions_added += 1
			collide = !collide

	func collision_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - accumulate across archetype calls
		collision_count += entities.size()


## System that removes entities after collision handling
class ProjectileCollisionRemovalSystem extends System:
	var travelling_count = 0
	var collision_count = 0
	var entities_removed = []

	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]), travelling_subsys],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB, C_OrderTestC]), collision_subsys]
		]

	func travelling_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - accumulate across archetype calls
		travelling_count += entities.size()
		for entity in entities:
			entity.add_component(C_OrderTestC.new())

	func collision_subsys(entities: Array[Entity], components: Array, delta: float):
		# Subsystems work like regular systems - accumulate across archetype calls
		collision_count += entities.size()
		# Track entities and remove them (simulating projectile destruction)
		for entity in entities:
			entities_removed.append(entity)
		# Remove all at once (like your real code does)
		ECS.world.remove_entities(entities)


## System that exactly mirrors your ProjectileSystem structure
class ExactProjectileSystem extends System:
	var travelling_count = 0
	var collision_count = 0

	func sub_systems() -> Array[Array]:
		return [
			# IMPORTANT: Travelling MUST run first to add collision component
			# Then collision handler can see all entities with collision
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB]), travelling_subsys],
			[ECS.world.query.with_all([C_OrderTestA, C_OrderTestB, C_OrderTestC]), projectile_collision_subsys]
		]

	func travelling_subsys(entities: Array[Entity], components: Array, delta: float):
		travelling_count = entities.size()
		# Simulate all projectiles colliding
		for e_projectile in entities:
			# Add collision component (simulating move_and_slide collision)
			e_projectile.add_component(C_OrderTestC.new())

	func projectile_collision_subsys(entities: Array[Entity], components: Array, delta: float):
		collision_count = entities.size()
		# Remove all projectiles that collided (matching your exact code)
		ECS.world.remove_entities(entities)

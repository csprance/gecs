## Behavioral guardrails for future bulk lifecycle optimizations.
extends GdUnitTestSuite


class LifecycleEntity:
	extends Entity
	var events: Array = []

	func on_ready():
		events.append("ready")

	func on_destroy():
		events.append("destroy")


var world: World


func before_test():
	world = World.new()
	Engine.get_main_loop().root.add_child(world)
	ECS.world = world


func after_test():
	world.purge(false)
	ECS.world = null
	world.queue_free()
	await get_tree().process_frame


func test_batch_initializes_independent_components_and_preserves_callbacks():
	var events: Array = []
	var nodes: Array = []
	var template := C_TestA.new(42)
	for i in 8:
		var entity := LifecycleEntity.new()
		entity.events = events
		nodes.append(entity)
	world.entity_added.connect(func(_entity): events.append("added"))
	world.component_removed.connect(
		func(entity, component):
			assert_bool(is_instance_valid(entity)).is_true()
			assert_bool(entity.has_component(component.get_script())).is_true()
			events.append("component_removed")
	)
	world.entity_removed.connect(func(_entity): events.append("removed"))
	world.add_entities(nodes, [template])
	assert_int(events.count("ready")).is_equal(8)
	assert_int(events.count("added")).is_equal(8)
	for entity in nodes:
		assert_int(entity.get_component(C_TestA).value).is_equal(42)
		assert_object(entity.get_component(C_TestA)).is_not_same(template)
	nodes[0].get_component(C_TestA).value = 99
	assert_int(nodes[1].get_component(C_TestA).value).is_equal(42)
	events.clear()
	world.remove_entities(nodes)
	var expected: Array = []
	for i in 8:
		expected.append_array(["component_removed", "removed", "destroy"])
	assert_array(events).is_equal(expected)
	assert_int(world.entities.size()).is_equal(0)
	for entity in nodes:
		assert_bool(entity.is_queued_for_deletion()).is_true()
	await get_tree().process_frame
	for entity in nodes:
		assert_bool(is_instance_valid(entity)).is_false()


func test_partial_batch_removal_keeps_queries_indices_and_ids_consistent():
	var nodes: Array = []
	var ids: Array[int] = []
	for i in 12:
		var entity := Entity.new()
		entity.add_component(C_TestA.new(i))
		if i % 2 == 0:
			entity.add_component(C_TestB.new())
		nodes.append(entity)
	world.add_entities(nodes)
	for entity in nodes:
		ids.append(entity.id)
	var query := world.query.with_all([C_TestA])
	assert_int(query.execute().size()).is_equal(12)
	# Deliberately remove head, tail and interior rows in non-sorted order.
	var removed := [nodes[0], nodes[11], nodes[4], nodes[7]]
	world.remove_entities(removed)
	assert_int(query.execute().size()).is_equal(8)
	for i in world.entities.size():
		var entity := world.entities[i]
		assert_int(entity._entities_index).is_equal(i)
		assert_object(world.get_entity_by_id(entity.id)).is_same(entity)
		assert_bool(world.entity_to_archetype.has(entity)).is_true()
	for index in [0, 11, 4, 7]:
		assert_bool(world.is_alive(ids[index])).is_false()
	world.remove_entities(world.entities.duplicate())
	assert_int(query.execute().size()).is_equal(0)
	assert_int(world.entity_id_registry.size()).is_equal(0)
	assert_int(world.entity_to_archetype.size()).is_equal(0)


func test_churn_reuses_archetype_without_reviving_old_handles():
	var query := world.query.with_all([C_TestA, C_TestB])
	var old_ids: Array[int] = []
	var archetype: Archetype
	for cycle in 4:
		var nodes: Array = []
		for i in 16:
			var entity := Entity.new()
			entity.add_components([C_TestA.new(), C_TestB.new()])
			nodes.append(entity)
		world.add_entities(nodes)
		assert_int(query.execute().size()).is_equal(16)
		if cycle == 0:
			archetype = world.entity_to_archetype[nodes[0]]
		else:
			assert_object(world.entity_to_archetype[nodes[0]]).is_same(archetype)
		for id in old_ids:
			assert_bool(world.is_alive(id)).is_false()
		for entity in nodes:
			old_ids.append(entity.id)
		world.remove_entities(nodes)
		assert_int(query.execute().size()).is_equal(0)
		assert_int(archetype.entities.size()).is_equal(0)
		await get_tree().process_frame
		for entity in nodes:
			assert_bool(is_instance_valid(entity)).is_false()


func test_batch_target_removal_cleans_surviving_relationships():
	var targets := [Entity.new(), Entity.new()]
	var survivor := Entity.new()
	survivor.add_component(C_TestB.new())
	world.add_entities(targets + [survivor])
	for target in targets:
		survivor.add_relationship(Relationship.new(C_TestA.new(), target))
	var query := world.query.with_all([C_TestB])
	assert_int(query.execute().size()).is_equal(1)
	world.remove_entities(targets)
	assert_int(survivor.relationships.size()).is_equal(0)
	assert_array(query.execute()).is_equal([survivor])
	assert_int(world.entity_to_archetype[survivor].relationship_types.size()).is_equal(0)


func test_pool_toggle_preserves_identity_and_component_state():
	var nodes := [Entity.new(), Entity.new()]
	world.add_entities(nodes, [C_TestA.new(42)])
	var ids := [nodes[0].id, nodes[1].id]
	var component = nodes[0].get_component(C_TestA)
	var query := world.query.with_all([C_TestA]).enabled()
	for cycle in 3:
		world.disable_entities(nodes)
		assert_int(query.execute().size()).is_equal(0)
		assert_int(world.entities.size()).is_equal(2)
		for i in nodes.size():
			assert_object(world.get_entity_by_id(ids[i])).is_same(nodes[i])
			world.enable_entity(nodes[i])
		assert_int(query.execute().size()).is_equal(2)
		assert_object(nodes[0].get_component(C_TestA)).is_same(component)
		assert_int(component.value).is_equal(42)

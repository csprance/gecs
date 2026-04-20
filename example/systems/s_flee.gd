## Dynamically adds/removes Relationship(C_FleeingFrom, player) on sheep as the
## player moves in and out of each sheep's C_FleeRange radius.
##
## Showcases:
##   - Relationship add/remove during iteration via CommandBuffer
##   - Query for the singleton player entity with with_all([C_Player])
class_name FleeSystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Sheep, C_FleeRange]).with_none([C_Penned])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var player := ECS.world.query.with_all([C_Player]).execute_one()
	if player == null:
		return

	var player_pos := (player as Node3D).global_position
	var flee_rel := Relationship.new(C_FleeingFrom.new(), player)

	for entity in entities:
		var range_comp := entity.get_component(C_FleeRange) as C_FleeRange
		var dist := (entity as Node3D).global_position.distance_to(player_pos)
		var should_flee := dist < range_comp.radius
		var currently_fleeing := entity.has_relationship(flee_rel)

		if should_flee and not currently_fleeing:
			cmd.add_relationship(entity, Relationship.new(C_FleeingFrom.new(), player))
		elif not should_flee and currently_fleeing:
			cmd.remove_relationship(entity, Relationship.new(C_FleeingFrom.new(), player), 1)

class_name SpawnerSystem
extends System

func sub_systems():
	return [
		[ECS.world.query.with_all([C_Transform, C_SpawnPoint, C_Player]).with_any([C_Player1, C_Player2]), spawn_player_subsys],
	]


func spawn_player_subsys(entity: Entity, _delta: float):
	var c_trs = entity.get_component(C_Transform) as C_Transform
	# spawn the player at the position.
	var player = Constants.player_scene.instantiate()
	player.global_transform =  c_trs.transform
	ECS.world.add_entity(player)
	Utils.sync_transform(player)
	#  Remove the Spawn point
	ECS.world.remove_entity(entity)

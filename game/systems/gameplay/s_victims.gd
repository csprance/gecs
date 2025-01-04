class_name VictimSystem
extends System

@export var ghost_vfx_packed_scene: PackedScene
@export var score_vfx_packed_scene: PackedScene

func sub_systems():
	return [
		[ECS.world.query.with_all([C_Victim, C_Death]), victim_death_subsys],
		[ECS.world.query.with_all([C_Victim, C_Saved]), victim_saved_subsys],
	]

func victim_death_subsys(entity, _delta: float):
	GameState.victims -= 1
	# Spawn the ghost visuals
	var ghost_vfx = ghost_vfx_packed_scene.instantiate()
	ghost_vfx.global_position = entity.global_position
	add_child(ghost_vfx)

	if GameState.victims == 0:
		await spawn_exit_door(entity)
	
	entity.add_component(C_IsPendingDelete.new())

func victim_saved_subsys(entity, _delta: float):
	# Spawn the score visuals
	var c_reward = entity.get_component(C_Reward) as C_Reward
	if c_reward:
		GameState.score += c_reward.points
		var score_vfx = score_vfx_packed_scene.instantiate()
		score_vfx.points = c_reward.points
		score_vfx.global_position = entity.global_position + Vector3(0, 3, 0)   
		add_child(score_vfx)
	
	for child in entity.get_children():
		child.queue_free()
	
	entity.remove_component(C_Saved)
	
	GameState.victims -= 1
	if GameState.victims == 0:
		await spawn_exit_door(entity)
	


func spawn_exit_door(entity: Entity):
	var c_trs = entity.get_component(C_Transform)
	if GameState.victims == 0:
		await get_tree().create_timer(2.0).timeout
		ECS.world.add_entity(Constants.exit_door_scene.instantiate(), [c_trs])

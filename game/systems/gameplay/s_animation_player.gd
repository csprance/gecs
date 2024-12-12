## This system is responsible for playing animations on the player entity
class_name AnimationPlayerSystem
extends System

func sub_systems():
	return [
		[ECS.world.query.with_all([C_AnimationPlayer, C_PlayAnimation]), anim_player_subsy],
		[ECS.world.query.with_all([C_AnimationTree, C_AnimTreeCommand]), anim_tree_subsy],
	]

func anim_tree_subsy(entity: Entity, delta: float) -> void:
	var c_anim_tree = entity.get_component(C_AnimationTree) as C_AnimationTree
	var c_anim_tree_cmd = entity.get_component(C_AnimTreeCommand) as C_AnimTreeCommand
	var anim_tree = entity.get_node(c_anim_tree.anim_tree) as AnimationTree
	var state_machine = anim_tree["parameters/playback"]
	state_machine.travel(c_anim_tree_cmd.command)


func anim_player_subsy(entity: Entity, delta: float) -> void:
	var c_play_animation = entity.get_component(C_PlayAnimation) as C_PlayAnimation
	if c_play_animation.time == 0.0:
		var c_anim_player: C_AnimationPlayer = entity.get_component(C_AnimationPlayer)
		var anim_player = entity.get_node(c_anim_player.player) as AnimationPlayer
		anim_player.play(c_play_animation.anim_name, c_play_animation.time)

	c_play_animation.time += delta * c_play_animation.anim_speed
	
	if c_play_animation.time >= 1.0:
		c_play_animation.finished = true
		c_play_animation.time = 0.0
		if c_play_animation.callback:
			c_play_animation.callback.call()
		if not c_play_animation.loop:
			entity.remove_component(C_PlayAnimation)

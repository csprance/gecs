## this plays an animation on the searchable and drops the specified item
class_name OpenSearchableInteraction
extends Interaction

func _interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
	# Make sure we're a door. 
	# play an animation to open the door
	interactable.add_component(C_PlayAnimation.new("open"))
	for i in interactors:
		i.remove_component(C_Interacting)
	# searchables only work once
	interactable.remove_component(C_Interactable)
	# drop the item
	var c_item_spawner = interactable.get_component(C_ItemSpawner) as C_ItemSpawner
	var items = c_item_spawner.get_items_to_spawn()
	for c_item in items:
		var c_trs = interactable.get_component(C_Transform) as C_Transform
		var e_pickup = Pickup.make_pickup(c_item, 1)
		e_pickup.global_transform = c_trs.transform.translated(Vector3(1.7, 0, 1.1))
		# overide the pickups transform
		# get the position of the interact and drop the item there in front of it a bit
		ECS.world.add_entity(e_pickup)
		Utils.sync_transform(e_pickup)
		# just spawn one
		break
	
	return true

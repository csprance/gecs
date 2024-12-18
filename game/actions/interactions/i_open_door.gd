class_name OpenDoorInteraction
extends Interaction

@export var locked := false
## Define the item it requires to open this. It could be any item
@export_file("*.tres") var key_path

func _interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
	if locked:
		var key = load(key_path)
		assert(key, "Key Type on Door Interation is not set or invalid on Entity: %s" % interactable)
		# check to see if at least one of the interactors has a key
		var e_key: Entity
		for i in interactors:
			e_key = InventoryUtils.get_item(i, key)
			if e_key:
				break
		
		if not e_key:
			Loggie.debug("No key found")
			return false
		
		# remove the key from the world
		InventoryUtils.remove_inventory_item(e_key, 1)
	
	# play an animation to open the door
	interactable.add_component(C_PlayAnimation.new("open_door"))
	for i in interactors:
		i.remove_component(C_Interacting)
	 # doors only work once
	interactable.remove_component(C_Interactable)
	return true
	

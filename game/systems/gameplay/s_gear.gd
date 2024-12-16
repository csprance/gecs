class_name GearSystem
extends System


func query():
	return q.with_all([C_Gear]).with_none([C_HasGear])


func process(entity: Entity, delta: float):
	var c_gear = entity.get_component(C_Gear) as C_Gear
	# Go through each gear item and set the skeleton to the entity skeleton
	for gear_item in c_gear.gear_items:
		var gear: Gear = gear_item.instantiate()
		if not gear is Gear:
			# If it's not a gear skip it
			Loggie.error('Gear scene is not of type Gear, Skipping', gear_item)
			continue
		gear.skeleton_path = c_gear.skeleton_path
		entity.add_child(gear)
		
		

	entity.add_component(C_HasGear.new())

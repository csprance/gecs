class_name GearSystem
extends System

func query():
	# Select entities that have a C_Gear component but lack a C_HasGear component.
	return q.with_all([C_Gear]).with_none([C_HasGear])

func process(entity: Entity, delta: float):
	# Get the C_Gear component from the entity.
	var c_gear = entity.get_component(C_Gear) as C_Gear
	# Create a root Gear node and attach it to the entity.
	var root_gear = Gear.new()
	root_gear.skeleton_path = c_gear.skeleton_path
	root_gear.entity = entity
	root_gear.name = "RootGear"
	# Add 'Inputs' and 'Outputs' nodes to the root gear.
	var inputs_node = Node.new()
	inputs_node.name = "Inputs"
	root_gear.add_child(inputs_node)

	var outputs_node = Node.new()
	outputs_node.name = "Outputs"
	root_gear.add_child(outputs_node)

	entity.add_child(root_gear)
	# Iterate over each gear item to set up and assemble.
	for gear_item in c_gear.gear_items:
		# Instantiate the gear item.
		var gear: Gear = gear_item.instantiate()
		if not gear is Gear:
			# If it's not a valid Gear instance, skip it.
			Loggie.error('Gear scene is not of type Gear, Skipping', gear_item)
			continue
		# Attach the gear to the root gear.
		root_gear.add_child(gear)
		# Assemble the gear by connecting inputs and outputs.
		gear.connect_inputs_outputs(root_gear)
	# Mark that the entity now has gear.
	entity.add_component(C_HasGear.new())

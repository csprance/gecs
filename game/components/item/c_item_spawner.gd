class_name C_ItemSpawner
extends Component

## The name of the spawner
@export var name: String = "Spawner Name"
## The Items that can be spawned. The chance to spawn will be normalized
## There are Items: Which spawn one item, Groups: Which spawn all items in the group, Spawners: which can combine other spawners together and then run the spawn logic on that collection
@export var spawner_items: Array[C_ItemSpawnerVariants] = []


func get_items_to_spawn() -> Array[C_Item]:
	var index = get_weighted_random_index(spawner_items.map(func(x): return x.spawn_chance))
	if index >= 0:
		var spawner_variant = spawner_items[index]
		var c_items: Array[C_Item] = []
		if spawner_variant is C_ItemSpawnerItem:
			c_items.push_front(spawner_variant.item)
		if spawner_variant is C_ItemSpawnerGroup:
			c_items.append_array(spawner_variant.group)

		return c_items

	return []


# Returns an index from the given array of weights, chosen based on each weight's relative size.
# This technique is known as "weighted random selection." If no index is found, it returns -1.
func get_weighted_random_index(weights: Array) -> int:
	# Calculate the total sum of all weights.
	var total_weight = weights.reduce(func(acc, x):
		return acc + x,
		0.0
	)

	# Generate a random value between 0 and the total weight.
	var random_value = randf() * total_weight
	# Keep a running total of the weights checked so far.
	var cumulative_weight = 0.0

	# Iterate through each weight in the array.
	for i in range(weights.size()):
		# Add the current weight to the running total.
		cumulative_weight += weights[i]
		# If our random value is within the current cumulative total,
		# this index is the result.
		if random_value <= cumulative_weight:
			return i

	# Return -1 as a fallback if no index is chosen.
	return -1

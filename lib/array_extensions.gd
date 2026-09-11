class_name ArrayExtensions

## Intersects two arrays of entities.[br]
## In common terms, use this to find items appearing in both arrays.
## [param array1] The first array to intersect.[br]
## [param array2] The second array to intersect.[br]
## [b]return Array[/b] The intersection of the two arrays.
static func intersect(array1: Array, array2: Array) -> Array:
	# Optimize by using the smaller array for lookup
	if array1.size() > array2.size():
		return intersect(array2, array1)

	# Use dictionary for O(1) lookup instead of O(n) Array.has()
	var lookup := {}
	for entity in array2:
		lookup[entity] = true

	var result: Array = []
	for entity in array1:
		if lookup.has(entity):
			result.append(entity)
	return result

## Unions two arrays of entities.[br]
## In common terms, use this to combine items without duplicates.[br]
## [param array1] The first array to union.[br]
## [param array2] The second array to union.[br]
## [b]return Array[/b] The union of the two arrays.
static func union(array1: Array, array2: Array) -> Array:
	# Use dictionary to track uniqueness for O(1) lookups
	var seen := {}
	var result: Array = []

	# Add all from array1
	for entity in array1:
		if not seen.has(entity):
			seen[entity] = true
			result.append(entity)

	# Add unique items from array2
	for entity in array2:
		if not seen.has(entity):
			seen[entity] = true
			result.append(entity)

	return result

## Differences two arrays of entities.[br]
## In common terms, use this to find items only in the first array.[br]
## [param array1] The first array to difference.[br]
## [param array2] The second array to difference.[br]
## [b]return Array[/b] The difference of the two arrays (entities in array1 not in array2).
static func difference(array1: Array, array2: Array) -> Array:
	# Use dictionary for O(1) lookup instead of O(n) Array.has()
	var lookup := {}
	for entity in array2:
		lookup[entity] = true

	var result: Array = []
	for entity in array1:
		if not lookup.has(entity):
			result.append(entity)
	return result

## systems_by_group is a dictionary of system groups and their systems
## { "Group1": [SystemA, SystemB], "Group2": [SystemC, SystemD] }
static func topological_sort(systems_by_group: Dictionary) -> void:
	# Iterate over each group key in 'systems_by_group'
	for group in systems_by_group.keys():
		var systems = systems_by_group[group]
		# If the group has 1 or fewer systems, no sorting is needed
		if systems.size() <= 1:
			continue

		# Create two data structures:
		# 1) adjacency: stores, for a given system, which systems must come after it
		# 2) indegree: tracks how many "prerequisite" systems each system has
		var adjacency = {}
		var indegree = {}
		var wildcard_front = []
		var wildcard_back = []
		for s in systems:
			adjacency[s] = []
			indegree[s] = 0

		# Build adjacency and indegree counts based on dependencies returned by s.deps()
		for s in systems:
			var deps_dict = s.deps()

			# Check for Runs.Before array on s
			# If present, each item in s.Runs.Before means "s must run before that item"
			# So we add the item to adjacency[s], and increment the item's indegree
			# If item is null or ECS.wildcard, we treat it as "run before everything" by pushing 's' onto wildcard_front
			if deps_dict.has(System.Runs.Before):
				for b in deps_dict[System.Runs.Before]:
					if b == null:
						# ECS.wildcard AKA 'null' means s should run before all systems
						wildcard_front.append(s)
					else:
						# Find system instance that matches the dependency type
						var target_system = _find_system_by_type(systems, b)
						if target_system:
							# Normal dependency within the group
							adjacency[s].append(target_system)
							indegree[target_system] += 1

			# Check for Runs.After array on s
			# If present, each item in s.Runs.After means "s must run after that item"
			# So we add 's' to adjacency[item], and increment s's indegree
			# If item is null or ECS.wildcard, we treat it as "run after everything" by pushing 's' onto wildcard_back
			if deps_dict.has(System.Runs.After):
				for a in deps_dict[System.Runs.After]:
					if a == null:
						# ECS.wildcard AKA 'null' means s should run after all systems
						wildcard_back.append(s)
					else:
						# Find system instance that matches the dependency type
						var dependency_system = _find_system_by_type(systems, a)
						if dependency_system:
							# Normal dependency within the group
							adjacency[dependency_system].append(s)
							indegree[s] += 1

		# Kahn's Algorithm begins:
		# 1) Insert all systems with zero indegree into a queue
		# 2) Pop from the queue, add to sorted_result
		# 3) Decrement indegree for each adjacent system
		# 4) Any adjacent system that reaches zero indegree is appended to the queue
		var queue = []

		# Adjust for wildcard_front and wildcard_back:
		# wildcard_front: s runs before everything -> point s -> other
		for w in wildcard_front:
			for other in systems:
				if other != w and not adjacency[w].has(other):
					adjacency[w].append(other)
					indegree[other] += 1

		# wildcard_back: s runs after everything -> point other -> s
		for w in wildcard_back:
			for other in systems:
				if other != w and not adjacency[other].has(w):
					adjacency[other].append(w)
					indegree[w] += 1

		# Collect all systems with zero indegree into the queue as our starting point
		for s in systems:
			if indegree[s] == 0:
				queue.append(s)

		var sorted_result = []

		# While there are systems with no remaining prerequisites
		while queue.size() > 0:
			var current = queue.pop_front()
			# Add that system to the sorted list
			sorted_result.append(current)
			# For each system that depends on 'current'
			for nxt in adjacency[current]:
				# Decrement its indegree because 'current' is now accounted for
				indegree[nxt] -= 1
				# If it has no more prerequisites, add it to the queue
				if indegree[nxt] == 0:
					queue.append(nxt)

		# If we successfully placed all systems, overwrite the original array with sorted_result
		if sorted_result.size() == systems.size():
			systems_by_group[group] = sorted_result
		else:
			assert(
				false,
				(
					"Topological sort failed for group '%s'. Possible cycle or mismatch in dependencies."
					% group
				)
			)
			# Otherwise, we found a cycle or mismatch. Fallback to the original unsorted array
			systems_by_group[group] = systems

	# The function modifies 'systems_by_group' in-place with a topologically sorted order

## Helper function to find a system instance by its type/class
static func _find_system_by_type(systems: Array, target_type) -> System:
	for system in systems:
		# Check if the system is an instance of the target type
		if system.get_script() == target_type:
			return system
		# Also check class name matching for backward compatibility
		if system.get_script() and system.get_script().get_global_name() == str(target_type).get_file().get_basename():
			return system
	return null

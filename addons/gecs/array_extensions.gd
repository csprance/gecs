class_name ArrayExtensions

## Intersects two arrays of entities.[br]
## [param array1] The first array to intersect.[br]
## [param array2] The second array to intersect.[br]
## [b]return Array[/b] The intersection of the two arrays.
static func intersect(array1: Array, array2: Array) -> Array:
	var result: Array = []
	for entity in array1:
		if array2.has(entity):
			result.append(entity)
	return result

## Unions two arrays of entities.[br]
## [param array1] The first array to union.[br]
## [param array2] The second array to union.[br]
## [b]return Array[/b] The union of the two arrays.
static func union(array1: Array, array2: Array) -> Array:
	var result = array1.duplicate()
	for entity in array2:
		if not result.has(entity):
			result.append(entity)
	return result

## Differences two arrays of entities.[br]
## [param array1] The first array to difference.[br]
## [param array2] The second array to difference.[br]
## [b]return Array[/b] The difference of the two arrays (entities in array1 not in array2).
static func difference(array1: Array, array2: Array) -> Array:
	var result: Array = []
	for entity in array1:
		if not array2.has(entity):
			result.append(entity)
	return result
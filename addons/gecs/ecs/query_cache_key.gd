## QueryCacheKey
## ------------------------------------------------------------------------------
## PURPOSE
##   Build a structural query signature (cache key) that is:
##     * Order-insensitive inside each domain (with_all / with_any / with_none)
##     * Order-sensitive ACROSS domains (the same component in different domains => different key)
##     * Extremely fast (single allocation + contiguous integer writes)
##     * Stable for the lifetime of loaded component scripts (uses script.instance_id)
##
## WHY NOT JUST MERGE & SORT?
##   A naive approach merges all component IDs + domain markers then sorts. That destroys
##   domain boundaries and lets these collide:
##       with_all([A,B])    vs   with_any([A,B])
##   After a full sort both become the same multiset {1,2,3,A,B}. We prevent that by
##   emitting DOMAIN MARKER then COUNT then the sorted IDs for that domain – preserving
##   domain structure while still being permutation-insensitive within the domain.
##
## LAYOUT (integers in final array):
##   [ 1, |count_all|,   sorted(all_ids)...,
##     2, |count_any|,   sorted(any_ids)...,
##     3, |count_none|,  sorted(ex_ids)... ]
##   1/2/3   : domain sentinels (ALL / ANY / NONE)
##   count_* : disambiguates empty vs non-empty ( [] vs [X] ) and prevents boundary ambiguity
##   sorted(ids) : order-insensitivity; identical sets different order => same run of ints
##
## COMPLEXITY
##   Sorting dominates: O(a log a + y log y + n log n). Typical domain sizes are tiny.
##   Allocation: exactly one integer array sized to final layout.
##   Hash: Godot's native Array.hash() (64-bit) – very fast.
##
## COLLISION PROFILE
##   64-bit space (~1.84e19). Even 1,000,000 distinct structural queries => ~2.7e-8 collision probability.
##   Practically zero for real ECS usage. See PERFORMANCE_CACHE_KEY_NOTE.md for math.
##
## EXTENSION POINTS
##   * Add a leading VERSION marker if the format evolves.
##   * Add extra domains (e.g. relationship structure) by appending new marker + count + IDs.
##   * Add enabled-state separation by injecting a synthetic domain marker (kept separate currently).
##
## INLINE COMMENT LEGEND
##   all_ids / any_ids / ex_ids : per-domain sorted component script instance IDs
##   total : exact integer count used for one-shot allocation (prevents incremental reallocation)
##   layout[i] = marker/count/id : sequential write building final signature array
##
class_name QueryCacheKey
extends RefCounted

static func build(all_components: Array, any_components: Array, exclude_components: Array) -> int:
	# Collect & sort per-domain IDs (order-insensitive inside each domain)
	var all_ids: Array[int] = []
	for c in all_components: all_ids.append(c.get_instance_id())
	all_ids.sort()
	var any_ids: Array[int] = []
	for c in any_components: any_ids.append(c.get_instance_id())
	any_ids.sort()
	var ex_ids: Array[int] = []
	for c in exclude_components: ex_ids.append(c.get_instance_id())
	ex_ids.sort()

	# Compute exact total length: (marker + count) per domain + IDs
	var total = 1 + 1 + all_ids.size() # ALL marker + count + ids
	total += 1 + 1 + any_ids.size() # ANY marker + count + ids
	total += 1 + 1 + ex_ids.size() # NONE marker + count + ids

	# Single allocation for final signature layout
	var layout: Array[int] = []
	layout.resize(total)

	var i := 0
	# --- Domain: ALL ---
	layout[i] = 1; i += 1 # Marker for ALL domain
	layout[i] = all_ids.size(); i += 1 # Count (disambiguates empty vs non-empty)
	for id in all_ids:
		layout[i] = id; i += 1 # Sorted ALL component IDs

	# --- Domain: ANY ---
	layout[i] = 2; i += 1 # Marker for ANY domain
	layout[i] = any_ids.size(); i += 1 # Count
	for id in any_ids:
		layout[i] = id; i += 1 # Sorted ANY component IDs

	# --- Domain: NONE (exclude) ---
	layout[i] = 3; i += 1 # Marker for NONE domain
	layout[i] = ex_ids.size(); i += 1 # Count
	for id in ex_ids:
		layout[i] = id; i += 1 # Sorted EXCLUDE component IDs

	# Hash the structural layout -> 64-bit key
	return layout.hash()
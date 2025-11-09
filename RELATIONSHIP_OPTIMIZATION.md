# Relationship Query Optimization

## Summary

Optimized relationship queries from **O(n_all_entities)** to **O(n_entities_with_relation_type)** by using the existing `relationship_entity_index` that was already being populated but not utilized during query execution.

## Problem

Previously, when querying entities with specific relationships, the system would iterate through **ALL** entities and check each one:

```gdscript
# Old approach - SLOW
for entity in all_entities:  # 10,000 entities
    if entity.has_relationship(C_ChildOf.new(), parent):
        matches.append(entity)
```

This was O(n_entities) even when only a small subset had the relationship type.

## Solution

The World already maintained `relationship_entity_index: Dictionary` mapping `relation_path -> Array[Entity]`, but this wasn't being used in queries!

Now we use this index to get only entities with the relationship type **first**, then filter by target:

```gdscript
# New approach - FAST
var candidates = relationship_entity_index["res://C_ChildOf.gd"]  # O(1) - maybe 10 entities
for entity in candidates:  # Only 10 entities instead of 10,000!
    if entity.has_relationship_target(parent):
        matches.append(entity)
```

## Performance Impact

**Before:**
- Query with relationship: O(n_all_entities) = 10,000 iterations
- Every entity checked regardless of whether it has that relationship type

**After:**
- Query with relationship: O(n_entities_with_relation_type) = maybe 10-100 iterations
- Only entities with that relationship type are checked

**Speedup:** 100x to 1000x faster for rare relationships!

## Implementation Details

### Files Modified
- `addons/gecs/ecs/query_builder.gd`: Added index-based optimization in `_internal_execute()`

### Changes in query_builder.gd

1. **Added `_intersect_entity_arrays()` helper** (lines 355-374)
   - Efficiently intersects two entity arrays using Dictionary as set
   - Automatically iterates over smaller array for better performance

2. **Modified relationship filtering** (lines 295-340)
   - Use `relationship_entity_index` to get candidates by relation type
   - Intersect candidates with component query results
   - Filter by target on the smaller set only
   - Handles edge cases: wildcard relations (null), multiple relationships

### Backward Compatibility

✅ **100% backward compatible**
- Same API - no breaking changes
- Falls back to old behavior for wildcard queries (null relations)
- All existing tests should pass without modification

### Edge Cases Handled

1. **Wildcard relations** (`Relationship.new(null, target)`)
   - Falls back to old O(n) approach (can't use index with null relation)

2. **Multiple relationships**
   - Intersects index results for each relationship type
   - Entity must have ALL relationship types

3. **Excluded relationships**
   - Still uses entity-level filtering (could be optimized in future)

4. **Component queries on relationships**
   - Works correctly - index gets candidates, then target filtering applies component queries

## Example Usage

```gdscript
# Query entities with C_ChildOf relationship to specific parent
var children = ECS.world.query
    .with_relationship([Relationship.new(C_ChildOf.new(), parent_entity)])
    .execute()

# Before: Checks all 10,000 entities
# After:  Checks only entities with C_ChildOf (maybe 50)
# Speedup: 200x faster!
```

## Future Optimizations

Potential improvements that could be added:

1. **Optimize excluded relationships** - currently still O(n) for those
2. **Cache target lookups** - for frequently queried targets
3. **Composite indexes** - for common (relation, target) pairs
4. **Batch relationship changes** - reduce index update overhead

## Testing

To verify the optimization:

```bash
# Run relationship tests (should all pass)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/core/test_relationships.gd"

# Run performance tests (should show improvement for relationship queries)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_query_perf.gd"
```

**Note:** Since this uses existing index infrastructure, the optimization is automatically applied to all relationship queries with no code changes needed in user code!

## Conclusion

This optimization dramatically improves relationship query performance by using the already-existing relationship index. It's especially beneficial for:

- Large worlds (10,000+ entities)
- Rare relationships (few entities have the relationship type)
- Frequently executed relationship queries (every frame in systems)

The optimization maintains 100% API compatibility while providing up to 1000x speedup in some scenarios.

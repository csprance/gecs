# Architecture: Structural Relationships in the GECS Archetype System

**Domain:** Archetype-based ECS relationship indexing
**Researched:** 2026-03-18
**Confidence:** HIGH (based entirely on codebase analysis of existing integration points)

## Problem Statement

Currently, `with_relationship()` queries are **post-filters** applied to entities already selected by component-based archetype matching. The filtering path is:

1. `System._run_process` calls `_query_cache.archetypes()` -- structural, O(1) cached
2. Gathers all entities from matching archetypes into a flat array
3. Calls `_filter_entities_global()` which iterates every entity calling `entity.has_relationship()` -- O(N*M*K)
4. `entity.has_relationship()` calls `get_relationship()` which linearly scans `entity.relationships: Array[Relationship]`

The goal: make `(Relation, Target)` pairs part of the archetype signature so relationship queries resolve via the same O(1) archetype bucket lookup as component queries.

## Current Architecture (Relevant Parts)

### Archetype Signature

- `_calculate_entity_signature(entity)` in `world.gd:1199` computes a hash from `entity.components.keys()` (sorted resource paths) via `QueryCacheKey.build(comp_scripts, [], [])`
- `QueryCacheKey.build()` in `query_cache_key.gd` uses a domain-structured layout: `[MARKER, COUNT, sorted_ids...]` per domain (ALL/ANY/NONE/RELATIONSHIPS/etc.), then `.hash()` on the full int array
- Archetype identity is `signature: int` (the hash). `component_types: Array` holds sorted resource paths for matching
- **Relationships are NOT included in the signature today**

### Archetype Storage

- `Archetype.component_types` -- sorted array of component resource paths
- `Archetype.columns` -- SoA storage: `component_path -> Array[Component]`
- `Archetype.add_edges / remove_edges` -- keyed by component_path string, used for O(1) transitions
- No relationship storage exists in Archetype

### Entity Relationship Storage

- `entity.relationships: Array[Relationship]` -- flat array, not indexed
- Each `Relationship` has `.relation` (Component instance), `.target` (Entity|Component|Script|null), `.source` (Entity backref)
- `entity.add_relationship()` appends and emits `relationship_added` signal
- `entity.remove_relationship()` pattern-matches via `rel.matches()`, erases, emits `relationship_removed`

### World Signal Handlers

- `_on_entity_relationship_added()` at `world.gd:768`: updates `relationship_entity_index` (a loose `relation.resource_path -> Array[Entity]` map), does **not** invalidate cache or move archetypes
- `_on_entity_relationship_removed()` at `world.gd:787`: same pattern, no archetype movement

### Query Cache Key

- `QueryBuilder.get_cache_key()` calls `QueryCacheKey.build(_all_components, _any_components, _exclude_components)` -- **relationships excluded**
- Comment on line 31 of query_builder.gd: `# (Retained for entity-level filtering only; NOT part of cache key)`
- `QueryCacheKey.build()` already has `relationships` and `exclude_relationships` parameters but they are **passed as empty arrays** by the caller

### System Processing Path

- `System._query_has_non_structural_filters()` returns `true` if relationships exist, forcing the slow `_filter_entities_global` path
- The structural fast path (lines 344-379 of system.gd) iterates archetypes directly with column access -- this is what relationship queries should use after this change

## Recommended Architecture

### Encoding (Relation, Target) Pairs in the Archetype Signature

Each unique `(Relation, Target)` pair becomes a **relationship slot** in the archetype, analogous to a component slot. The slot key is a stable string derived from the pair.

**Relationship Slot Key Format:**

```
"rel://<relation_resource_path>::<target_key>"
```

Where `<target_key>` is:

- Entity target: `"entity#<instance_id>"` (identity-based -- each specific entity target creates a unique slot)
- Component target: `"comp://<component_resource_path>"` (type-based -- matches by component script type)
- Script target: `"script://<script_resource_path>"` (archetype target)
- Null target: `"*"` (wildcard -- only used in queries, never stored in archetype)

**Examples:**

- `rel://res://c_child_of.gd::entity#12345` -- ChildOf relationship targeting a specific entity
- `rel://res://c_damage.gd::comp://res://c_fire.gd` -- Damage relationship with a fire component type

**Why strings, not just hashed ints:** The archetype needs to store the slot keys in `component_types` (the sorted array used by `matches_query()`). String keys allow uniform handling alongside component resource paths in the existing matching logic. The hash computation already goes through `QueryCacheKey.build()` which converts to ints for hashing.

### Component Boundary: What Changes Where

#### 1. Archetype (`archetype.gd`)

**Changes:** Minimal. The existing infrastructure handles this if relationship slot keys are treated identically to component paths.

- `component_types` array already stores strings and is sorted -- relationship slot keys like `"rel://..."` naturally sort after `"res://..."` component paths, maintaining a stable ordering
- `matches_query()` already does `component_types.has(comp_type)` -- works for relationship slot keys
- `columns` dictionary: relationship slots do NOT need column storage (no SoA iteration over relationship data). The archetype should **skip** creating columns for `rel://` prefixed keys in `_init()` and `add_entity()`/`remove_entity()`
- `add_edges` / `remove_edges`: extend to use relationship slot keys as edge keys (same mechanism as component paths)

**New field (optional but recommended):**

```gdscript
var relationship_types: Array = []  # Sorted relationship slot keys (subset of component_types for fast iteration)
```

This allows `matches_query` to check relationship criteria against only the relationship subset rather than the full component_types array.

**New method:**

```gdscript
func matches_relationship_query(required_rel_keys: Array, excluded_rel_keys: Array) -> bool
```

#### 2. World (`world.gd`)

**This is the heaviest change area.**

**`_calculate_entity_signature(entity)`** -- Must include relationship pairs:

```
1. Collect component resource paths (existing)
2. Collect relationship slot keys from entity.relationships
3. Combine into unified sorted key set
4. Hash via QueryCacheKey.build() with relationship info included
```

The key function is computing slot keys from `entity.relationships`:

```gdscript
func _relationship_slot_key(rel: Relationship) -> String:
    var rel_path = rel.relation.get_script().resource_path
    var target_key: String
    if rel.target is Entity:
        target_key = "entity#" + str(rel.target.get_instance_id())
    elif rel.target is Component:
        target_key = "comp://" + rel.target.get_script().resource_path
    elif rel.target is Script:
        target_key = "script://" + rel.target.resource_path
    else:
        target_key = "*"  # Should not happen for stored relationships
    return "rel://" + rel_path + "::" + target_key
```

**`_on_entity_relationship_added(entity, relationship)`** -- Must trigger archetype transition:

```
1. Compute slot key for the new relationship
2. Call _move_entity_to_new_archetype_fast(entity, old_archetype, slot_key, true)
3. Invalidate cache
```

**`_on_entity_relationship_removed(entity, relationship)`** -- Must trigger archetype transition:

```
1. Compute slot key for the removed relationship
2. Call _move_entity_to_new_archetype_fast(entity, old_archetype, slot_key, false)
3. Invalidate cache
```

**`_get_or_create_archetype(signature, component_types)`** -- `component_types` now includes relationship slot keys. No structural change needed if Archetype handles `rel://` prefixed keys correctly.

**`_move_entity_to_new_archetype_fast()`** -- Already works with string keys. Relationship slot keys are just strings. The edge caching mechanism (`add_edges`/`remove_edges`) works identically.

**`relationship_entity_index`** -- Can be **removed or kept as a supplementary index**. The primary lookup is now via archetype matching. However, it may still be useful for the wildcard query optimization (see below).

**New index -- Relation-Type Archetype Index:**

```gdscript
# Maps relation resource_path -> Array[Archetype] (archetypes that contain ANY relationship with this relation type)
var _relation_type_archetype_index: Dictionary = {}  # String -> Array[Archetype]
```

This enables O(1) wildcard queries: "find all entities with any (C_ChildOf, \*) relationship" without scanning all archetypes.

#### 3. Entity (`entity.gd`)

**`add_relationship()`** -- No change needed. It already emits `relationship_added` signal. World's handler does the archetype move.

**`remove_relationship()`** -- Minor change: must emit `relationship_removed` for **each** removed relationship individually (it already does this in the `for rel in to_remove` loop). World's handler does the archetype move for each.

**Concern -- Batch relationship adds:** Unlike `add_components()` which has a batching optimization to avoid N archetype transitions, `add_relationships()` currently calls `add_relationship()` in a loop. A `add_relationships()` batch optimization should be added (same pattern as `add_components()`): add all to the array, compute final signature once, move once, emit signals after.

#### 4. QueryBuilder (`query_builder.gd`)

**`get_cache_key()`** -- Must include relationship pairs in the cache key:

```gdscript
func get_cache_key() -> int:
    if not _cache_key_valid:
        if _world:
            _cache_key = QueryCacheKey.build(
                _all_components, _any_components, _exclude_components,
                _relationships, _exclude_relationships  # NOW PASSED
            )
            _cache_key_valid = true
        else:
            return -1
    return _cache_key
```

**`with_relationship()`** -- Must invalidate cache key:

```gdscript
func with_relationship(relationships: Array = []) -> QueryBuilder:
    _relationships = relationships
    _cache_valid = false
    _cache_key_valid = false  # ADD THIS (currently missing)
    return self
```

**`_internal_execute()`** -- The relationship filtering block (lines 285-302) becomes the **archetype-level matching path** instead of entity-level:

- Convert each query relationship to a slot key
- Include slot keys in the archetype matching criteria passed to `World._query()`
- Property-based relationship queries (those with non-empty `relation_query` or `target_query`) remain as post-filters

**`System._query_has_non_structural_filters()`** -- Relationship presence **no longer** marks a query as non-structural (unless property queries are involved). This is the key change that unlocks the fast archetype path.

#### 5. QueryCacheKey (`query_cache_key.gd`)

Already has relationship and group parameters. The existing implementation computes relationship IDs from `rel.relation.get_script().get_instance_id()` and target IDs. This is sufficient for the cache key. **However**, the IDs must now encode exact `(relation, target)` pairs to distinguish between different targets of the same relation type.

Current code sorts relation+target IDs into a flat array -- this loses the pair structure. Must change to:

```
For each relationship:
    pair_hash = hash([relation_script_id, target_id])
    rel_ids.append(pair_hash)
rel_ids.sort()
```

This ensures `(C_ChildOf, entityA)` and `(C_ChildOf, entityB)` produce different cache keys.

### Wildcard Query Resolution

Wildcard queries (`with_relationship([Relationship.new(C_ChildOf.new(), null)])`) match **any** entity that has a `C_ChildOf` relationship regardless of target. This cannot be encoded as a single archetype slot key because the archetype contains specific `rel://c_child_of.gd::entity#123` keys.

**Resolution strategy -- Relation-Type Archetype Index:**

```gdscript
# In World, maintained alongside archetypes dict:
var _relation_type_archetype_index: Dictionary = {}  # relation_resource_path -> Set[Archetype]
```

Updated when archetypes are created/deleted. When a query has a wildcard relationship:

1. Look up `_relation_type_archetype_index[relation_resource_path]` -- returns all archetypes containing any `(Relation, *)` pair
2. Intersect with component-matched archetypes
3. Return the result set

This is still O(1) lookup + set intersection (typically small sets), not per-entity scanning.

**For non-wildcard queries:** The relationship slot key is computed from the query relationship and included in the archetype matching criteria directly.

### Data Flow: Relationship Add -> Archetype Transition

```
1. User calls entity.add_relationship(Relationship.new(C_ChildOf.new(), parent))
2. Entity appends to entity.relationships, emits relationship_added signal
3. World._on_entity_relationship_added() receives signal
4. World computes slot_key = "rel://res://c_child_of.gd::entity#<parent_id>"
5. World calls _move_entity_to_new_archetype_fast(entity, old_arch, slot_key, true)
6.   Check old_arch.add_edges[slot_key] -- if cached, O(1) transition
7.   Otherwise: compute new signature including all components + all relationship slot keys
8.   Get or create new archetype with that signature
9.   Cache edge: old_arch.set_add_edge(slot_key, new_arch)
10.  Move entity: old_arch.remove_entity() -> new_arch.add_entity()
11.  Update entity_to_archetype[entity] = new_arch
12. World invalidates query cache
13. World updates _relation_type_archetype_index if new archetype created
14. World emits relationship_added signal (for observers/network)
```

### Backward Compatibility

| Surface                             | Compatibility                 | Notes                                                                             |
| ----------------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| `entity.add_relationship()`         | No API change                 | Signal already emitted; World handler changes internally                          |
| `entity.remove_relationship()`      | No API change                 | Same signal pattern                                                               |
| `with_relationship()`               | No API change                 | Internally switches from post-filter to structural                                |
| `without_relationship()`            | No API change                 | Same internal switch                                                              |
| Property-based relationship queries | No API change                 | Remain as post-filter (property values cannot be archetype-keyed)                 |
| `Archetype.matches_query()`         | Extended signature            | New `matches_relationship_query` method or extended `matches_query` params        |
| `QueryCacheKey.build()`             | Already accepts relationships | Pair encoding needs fixing (currently loses pair structure)                       |
| `_calculate_entity_signature()`     | Internal change               | Now includes relationship slot keys                                               |
| `relationship_entity_index`         | Deprecated/replaced           | Superseded by archetype-level index                                               |
| Observers                           | No change needed              | Observer signals fire after archetype transition, same as components              |
| CommandBuffer                       | No change needed              | `cmd.add_relationship()` / `cmd.remove_relationship()` already queue operations   |
| Serialization (GECSIO)              | Needs review                  | Relationship serialization may need to preserve slot key info for deserialization |
| Network sync                        | No change needed              | Out of scope per PROJECT.md                                                       |

### Archetype Proliferation Concern

Entity-targeted relationships create **per-target-entity archetypes**. If 100 entities each have `(C_ChildOf, parent_X)` where each parent is different, that is 100 distinct archetypes (assuming same component set). This is the FLECS model -- it works because:

1. Most relationship patterns are "many children, few parents" (e.g., 100 entities all ChildOf the SAME parent = 1 archetype)
2. Archetype transitions are cached via edges, so the cost is amortized
3. Query matching is O(archetype_count), not O(entity_count) -- a large number of archetypes with few entities each is still faster than scanning all entities

**Mitigation if proliferation becomes a problem:**

- Monitor archetype count in debug mode
- Consider "tag-only" relationships that use type-only matching (no per-entity target) for common patterns
- The existing `relationship_entity_index` could serve as a fallback index for high-cardinality relationship types

## Build Order

The changes have strict dependencies:

### Phase 1: Archetype Extension (Foundation)

1. Add `relationship_types` array to Archetype
2. Modify `_init()` to skip column creation for `rel://` prefixed keys
3. Modify `add_entity()`/`remove_entity()` to skip column operations for relationship slots
4. Add `matches_relationship_query()` or extend `matches_query()` to handle relationship slot keys
5. Verify: existing component tests still pass (relationship slots are additive)

### Phase 2: Signature Computation

1. Add `_relationship_slot_key()` helper to World
2. Modify `_calculate_entity_signature()` to include relationship slot keys
3. Verify: archetype creation with relationships produces correct signatures
4. Add `_relation_type_archetype_index` to World

### Phase 3: Archetype Transitions on Relationship Mutation

1. Modify `_on_entity_relationship_added()` to call `_move_entity_to_new_archetype_fast()`
2. Modify `_on_entity_relationship_removed()` to call `_move_entity_to_new_archetype_fast()`
3. Add batch optimization for `add_relationships()` (same pattern as `add_components()`)
4. Add cache invalidation on relationship add/remove
5. Verify: entities move to correct archetypes when relationships change

### Phase 4: Query Integration

1. Modify `QueryBuilder.get_cache_key()` to pass relationships to `QueryCacheKey.build()`
2. Fix `QueryCacheKey.build()` pair encoding (hash pairs, not flat sort)
3. Modify `get_matching_archetypes()` / `_query()` to include relationship slot keys in archetype matching
4. Implement wildcard query resolution via `_relation_type_archetype_index`
5. Modify `System._query_has_non_structural_filters()` to NOT flag pure type-match relationships as non-structural
6. Verify: `with_relationship()` queries resolve via archetype lookup, not post-filter

### Phase 5: Property Query Preservation

1. Ensure property-based relationship queries (with `relation_query` or `target_query` dicts) remain as post-filters
2. `_query_has_non_structural_filters()` still returns true for property-based relationship queries
3. Verify: all existing relationship tests pass unchanged

### Phase 6: Cleanup and Performance

1. Deprecate or remove `relationship_entity_index` (replaced by archetype index)
2. Add performance benchmarks comparing old vs new relationship query path
3. Add debug metrics for relationship archetype proliferation monitoring

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Relationship Data in Archetype Columns

**What:** Creating SoA columns for relationship slots (like component columns)
**Why bad:** Relationships are structural markers, not iterable data. Column storage wastes memory and complicates add/remove entity logic.
**Instead:** Relationship slot keys participate in signature hashing and `matches_query()` only. Relationship data stays on `entity.relationships`.

### Anti-Pattern 2: Separate Relationship Archetype System

**What:** Creating a parallel archetype system just for relationships
**Why bad:** Doubles the query machinery, creates cache coherency issues between two systems, complicates cache invalidation.
**Instead:** Relationship slot keys are part of the SAME archetype signature as components. One unified system.

### Anti-Pattern 3: Wildcard Slots in Archetypes

**What:** Storing `rel://c_child_of.gd::*` as an actual archetype slot key
**Why bad:** An entity with `(C_ChildOf, entity#123)` would need to be in BOTH the exact archetype and the wildcard archetype -- impossible without duplicating entities.
**Instead:** Wildcard resolution uses the `_relation_type_archetype_index` side-index at query time.

### Anti-Pattern 4: Invalidating Cache on Every Relationship Property Change

**What:** Treating relationship component property changes as structural changes
**Why bad:** Property changes are frequent and do not affect archetype membership.
**Instead:** Only relationship ADD/REMOVE triggers archetype transitions. Property changes on relationship components trigger observer notifications but no archetype movement (same as regular component property changes).

## Sources

- `addons/gecs/ecs/archetype.gd` -- Archetype class with signature, columns, edges
- `addons/gecs/ecs/world.gd` -- World archetype registry, signal handlers, query dispatch
- `addons/gecs/ecs/entity.gd` -- Entity relationship storage and signals
- `addons/gecs/ecs/query_builder.gd` -- QueryBuilder cache key, relationship filtering
- `addons/gecs/ecs/query_cache_key.gd` -- FNV-1a cache key builder with domain layout
- `addons/gecs/ecs/relationship.gd` -- Relationship matching, target types
- `addons/gecs/ecs/system.gd` -- System processing path, structural vs non-structural detection
- `.planning/PROJECT.md` -- Requirements and constraints for structural relationships
- `.planning/codebase/ARCHITECTURE.md` -- Full architecture overview

---

_Architecture analysis: 2026-03-18_

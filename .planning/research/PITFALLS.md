# Domain Pitfalls: Structural Relationships in GECS

**Domain:** Making (Relation, Target) pairs structural in a GDScript ECS archetype system
**Researched:** 2026-03-18
**Codebase:** GECS v7.x (Godot 4.x addon)

---

## Critical Pitfalls

Mistakes that cause rewrites, data corruption, or order-of-magnitude performance regressions.

---

### Pitfall 1: Archetype Explosion from Per-Entity Target Identity

**What goes wrong:** Each unique `(Relation, Target)` pair becomes a distinct slot in the archetype signature. When the target is an Entity instance (identified by `get_instance_id()`), every entity-to-entity relationship creates a globally unique archetype key fragment. An entity with N relationships to N distinct entity targets lives in an archetype shared by no other entity. 100 entities each having 3 unique entity-target relationships = 100 singleton archetypes. The archetype index balloons, cache miss rates climb toward 100%, and every structural change triggers a full archetype scan because no two entities share a bucket.

**Why it happens:** FLECS uses integer entity IDs that double as type IDs in a flat ID space, so `(ChildOf, parent_42)` is cheap. GECS uses Godot `get_instance_id()` (64-bit Object pointer hash). The `_to_string()` method on Relationship already uses `Entity#<instance_id>` for entity targets, and `QueryCacheKey.build()` feeds `target.get_instance_id()` directly into the hash (line 83-84 of `query_cache_key.gd`). If these IDs flow into the archetype signature via `_calculate_entity_signature()`, each distinct entity target creates a unique signature.

**Consequences:**
- Archetype count grows O(E * R) where E = entities, R = average entity-target relationships per entity
- Query archetype cache (`_query_archetype_cache`) becomes useless: cache hit rate drops as archetype count grows
- `_query()` archetype scan (lines 1003-1005 of world.gd) becomes O(A) per query miss where A = archetype count
- The archetype edge graph (add/remove edges) becomes sparse and unhelpful -- most transitions create new archetypes
- Memory overhead from empty or near-empty Archetype objects (each has `entities`, `entity_to_index`, `columns`, `enabled_bitset`, `add_edges`, `remove_edges`, `neighbors`)

**Prevention:**
- Use the **target entity's archetype signature or script type** as the pair key, not instance ID. This groups all `(ChildOf, <any PlayerEntity>)` into one archetype bucket. Trades per-instance query precision for manageable archetype counts.
- Alternatively, introduce **pair "tags"** that are structural (included in archetype signature) vs **pair "links"** that are indexed separately (not in archetype signature). Entity-target relationships would be links, while type-target relationships (e.g., `(Damages, C_Fire)`) would be tags.
- Cap archetype count with a monitoring threshold and push_warning when it exceeds a budget (e.g., 500 archetypes). Add this to the debug perf stats already in `get_cache_stats()`.
- Consider: FLECS uses "relationship targets" as first-class types. For GECS, only make **component-type targets and script-type targets** structural. Entity-instance targets should use a secondary index (dictionary lookup, not archetype bucketing).

**Detection:** Archetype count in `get_cache_stats()` growing linearly with entity count instead of plateauing. Cache hit rate dropping below 50%. Frame time regression on relationship-heavy scenes.

**Phase relevance:** Must be decided in the first implementation phase. This is an architectural choice that permeates every subsequent change.

---

### Pitfall 2: Freed Entity Targets Create Dangling Archetype References

**What goes wrong:** An entity-target relationship `(ChildOf, parent_entity)` is baked into the archetype signature. When `parent_entity` is freed (via `world.remove_entity()`), every child entity still lives in an archetype whose signature references the freed entity's instance ID. The signature is now meaningless -- no new entity can ever match it, and the archetype becomes a zombie that only loses members as children are individually cleaned up.

**Why it happens:** The existing `Relationship.valid()` method (line 238-257 of `relationship.gd`) checks `is_instance_valid(target)` for entity targets and returns false for freed targets. But `valid()` is only called lazily during `get_relationship()` and `get_relationships()` -- never proactively. The archetype signature is computed once at entity placement time and is never revalidated. There is no mechanism to move entities out of a stale archetype when its signature references a freed object.

**Consequences:**
- Zombie archetypes accumulate, wasting memory and slowing archetype scans
- Queries for `(ChildOf, parent_entity)` after parent is freed return no results (correct) but the child entities still occupy archetype slots keyed to the dead parent (incorrect membership)
- If a new entity happens to get the same `get_instance_id()` as the freed parent (Godot recycles Object IDs), the zombie archetype suddenly "matches" queries for the new entity -- catastrophic false positives
- `_delete_archetype()` edge cleanup (lines 1279-1308 of world.gd) won't fire until the archetype is empty, which requires all children to be individually re-archetypified or removed

**Prevention:**
- When `world.remove_entity(entity)` is called, check if `entity` is the target of any structural relationship. If so, move all source entities to new archetypes with the relationship removed (or with a null/tombstone target). This is the FLECS `OnDelete` cleanup policy.
- Add a **cascade or cleanup policy** per relationship type: `CASCADE` (delete children), `REMOVE` (remove the relationship pair, move entity to new archetype), `ORPHAN` (leave entity in current archetype with an invalid target -- current behavior, but now actively harmful).
- Hook into the existing `entity_removed` signal on World (line 416 of world.gd). Currently this signal exists but nothing uses it to clean up relationship targets.
- For the secondary index approach (Pitfall 1 prevention), this is simpler: just remove the entry from the index. But if entity-target pairs ARE structural, this becomes a mandatory archetype migration on entity removal.

**Detection:** After removing an entity that is a relationship target, check `archetypes.size()` -- zombie archetypes will not be reclaimed. Test: create parent, add 10 children with `(ChildOf, parent)`, remove parent, assert children moved to archetype without the relationship.

**Phase relevance:** Must be addressed in the same phase as the core structural relationship implementation. Leaving this for later will cause silent data corruption in any test or game that removes entities.

---

### Pitfall 3: Archetype Signature Hash Collision Between Component-Only and Component+Pair Keys

**What goes wrong:** The current `_calculate_entity_signature()` (line 1199 of world.gd) calls `QueryCacheKey.build(comp_scripts, [], [])` using only component scripts. If relationship pairs are added to the signature, the hash must change format. During migration, a signature that was `hash([C_Transform, C_Velocity])` must never collide with `hash([C_Transform, C_Velocity, (C_ChildOf, parent)])`. If the pair key is injected into the same domain as components, or if the domain marker system in `QueryCacheKey` is not extended correctly, two different archetypes can hash to the same signature.

**Why it happens:** `QueryCacheKey.build()` uses domain markers (1=ALL, 2=ANY, 3=NONE, 4=RELATIONSHIPS, etc.) to separate domains in the hash layout. But `_calculate_entity_signature()` only passes components to the ALL domain and leaves relationships empty. If the new code adds relationship data but uses a different code path than `QueryCacheKey.build()`, the hash formats diverge. Alternatively, if relationship IDs are appended to the component ID array in domain 1 (ALL) instead of domain 4 (RELATIONSHIPS), the separator structure breaks.

**Consequences:**
- Two entities with the same components but different relationships get the same archetype signature
- They are placed in the same archetype, defeating the purpose of structural relationships
- Queries that match on relationship pairs will return entities that don't have those relationships
- The archetype `columns` dictionary won't have entries for relationship pair data (since the archetype was created for the component-only case first), causing null access errors

**Prevention:**
- Extend `_calculate_entity_signature()` to pass the entity's relationships into `QueryCacheKey.build()` via the existing `relationships` parameter (already accepted but currently never passed for entity signatures).
- Ensure the relationship IDs in the entity signature use the SAME encoding as the query cache key. Currently `QueryCacheKey.build()` encodes relationship targets using `get_instance_id()` for entities and `get_script().get_instance_id()` for components. The entity signature must use identical encoding.
- Add an assertion: when placing an entity into an archetype, verify that the archetype's `component_types` array matches the entity's components. This already implicitly works for components; extend it to cover relationship pairs.
- Write a specific test: create two entities with identical components but different relationships, assert they land in different archetypes.

**Detection:** Hash collision would manifest as entities appearing in query results they shouldn't match. Unit test with `assert(entity_a_archetype != entity_b_archetype)` when they differ only by relationships.

**Phase relevance:** Core implementation phase. This is a one-time design decision in `_calculate_entity_signature()` and `QueryCacheKey.build()`.

---

### Pitfall 4: Cache Invalidation Storm from Relationship Mutations

**What goes wrong:** Currently, `_on_entity_relationship_added()` (line 768 of world.gd) explicitly does NOT invalidate the archetype cache, with a comment: "Relationships do not alter archetype membership." Once relationships become structural, every `add_relationship()` and `remove_relationship()` must trigger archetype transitions AND cache invalidation, exactly like `_on_entity_component_added()` does. If this is enabled naively, systems that add many relationships per frame (e.g., damage-over-time applying `(Damage, target)` to multiple entities) will thrash the cache.

**Why it happens:** The existing codebase was designed with relationships as non-structural post-filters. The comment at line 774 explicitly says "Do NOT invalidate archetype cache on relationship changes." Flipping this flag is the core of the structural relationship change, but the performance implications are significant.

**Consequences:**
- Each `add_relationship()` call triggers `_invalidate_cache()`, clearing `_query_archetype_cache` entirely
- N relationship additions = N full cache clears = N cache rebuild passes on the next query
- With the existing `_begin_suppress`/`_end_suppress` pattern, only batch operations (via `add_entities()`) are protected. Individual `entity.add_relationship()` calls in a system's `process()` are not batched.
- CommandBuffer partially mitigates this (its `execute()` wraps in `_begin_suppress`/`_end_suppress`), but only for deferred operations

**Prevention:**
- Ensure `_on_entity_relationship_added/removed` use the same `_move_entity_to_new_archetype_fast()` pattern as component add/remove. This naturally uses the edge graph for O(1) transitions.
- Add batch relationship operations: `entity.add_relationships()` (already exists at line 376 of entity.gd but it loops `add_relationship()` individually -- it needs the same batched-archetype-transition optimization as `add_components()`).
- Make `CommandBuffer.add_relationship()` the recommended path for in-system relationship mutations. The command buffer's `execute()` already wraps in suppression brackets.
- Extend archetype edges to include relationship pair keys, so `_move_entity_to_new_archetype_fast()` can cache the transition: "archetype A + pair (C_ChildOf, parent) = archetype B."

**Detection:** Profile `_cache_invalidation_count` (already tracked in debug mode) before and after enabling structural relationships. If invalidations-per-frame increase by more than 2x, batching is insufficient.

**Phase relevance:** Core implementation phase, but batch optimization can be deferred to a follow-up performance phase. The initial implementation should at minimum use suppress/end_suppress around the transition.

---

### Pitfall 5: Wildcard Queries Require a Separate Index, Not Archetype Matching

**What goes wrong:** A wildcard query `with_relationship([Relationship.new(C_ChildOf.new(), null)])` means "any entity with ANY ChildOf relationship, regardless of target." If each distinct target creates a unique archetype (Pitfall 1), the wildcard query must match ALL archetypes that contain any `(C_ChildOf, *)` pair. This requires scanning every archetype and checking if any of its relationship pairs have relation type `C_ChildOf` -- which is O(A * P) where A = archetype count and P = average pairs per archetype. This defeats the O(1) lookup goal.

**Why it happens:** Archetype matching currently works by checking if the archetype's `component_types` array contains specific paths. Relationship pairs are more complex: a wildcard query matches any pair where the relation component type matches, regardless of the target. The current `Archetype.matches_query()` has no concept of partial-pair matching.

**Consequences:**
- Wildcard relationship queries degrade to O(A) archetype scan, not O(1)
- Since wildcard queries are the most common relationship query pattern (the PROJECT.md explicitly calls this out as a key use case), the performance improvement from structural relationships is undermined for the primary use case
- If the archetype count is high (Pitfall 1), wildcard queries become slower than the current linear entity scan

**Prevention:**
- Maintain a **relation-type index**: `Dictionary[String, Array[Archetype]]` mapping relation component `resource_path` to all archetypes that contain any pair with that relation type. When a new archetype is created with relationship pairs, register it in this index.
- Wildcard queries consult the relation-type index for O(1) lookup of matching archetypes, then union those archetype entity arrays.
- This is explicitly called out in PROJECT.md as the intended approach ("Wildcard queries (null target) use a relation-type index bucket").
- The index must be invalidated/updated when archetypes are created or deleted. Hook into `_get_or_create_archetype()` and `_delete_archetype()`.

**Detection:** Benchmark wildcard relationship queries with increasing archetype counts. If query time scales linearly with archetype count rather than being constant, the index is missing or broken.

**Phase relevance:** Core implementation phase. The relation-type index should be built alongside the archetype signature changes, not deferred.

---

## Moderate Pitfalls

---

### Pitfall 6: CommandBuffer Relationship Operations Now Cause Structural Transitions

**What goes wrong:** Currently, `CommandBuffer.add_relationship()` delegates to `entity.add_relationship()`, which appends to the entity's `relationships` array and emits a signal. This is non-structural -- no archetype transition occurs. Once relationships are structural, `CommandBuffer.add_relationship()` will trigger `_move_entity_to_new_archetype_fast()`, which modifies `entity_to_archetype`, `archetype.entities`, and `archetype.columns`. If a system is iterating an archetype's entities array when a deferred command buffer executes (e.g., PER_GROUP mode where a later system's buffer executes while an earlier system's archetype references are still alive), the iteration state is corrupted.

**Prevention:**
- This is already handled correctly for component mutations: CommandBuffer wraps `execute()` in `_begin_suppress`/`_end_suppress`, and systems get fresh archetype references from the query cache after invalidation.
- Verify that the system's `_run_process()` method does not hold references to archetype entity arrays across command buffer execution boundaries. Currently it re-queries on every `_handle(delta)` call, so this should be safe for PER_SYSTEM mode.
- For PER_GROUP mode, all systems in the group process before any buffer executes. But if System A's `process()` captured a reference to `archetype.entities` (which is a live array, not a copy), and System B's PER_SYSTEM buffer executes and moves entities between archetypes, System A's reference now points at a modified array. **Check if systems hold archetype entity array references across system boundaries within a group.**
- Add a test: System A queries relationship entities and stores a reference. System B's PER_SYSTEM buffer adds a relationship to one of those entities. Verify System A is not corrupted.

**Detection:** Sporadic "entity not found in archetype" errors during multi-system processing with relationship mutations.

**Phase relevance:** Testing phase. The existing CommandBuffer architecture handles this pattern, but relationship-specific tests are needed.

---

### Pitfall 7: Observer System Has No Hooks for Relationship Events

**What goes wrong:** The Observer class (observer.gd) only supports `watch()` for a single component type and callbacks for `on_component_added`, `on_component_removed`, `on_component_changed`. There are no `on_relationship_added` or `on_relationship_removed` callbacks. If relationship add/remove now triggers archetype transitions (just like component add/remove), users will expect observer support for relationship lifecycle events. Without it, there is no reactive way to respond to relationship changes.

**Why it happens:** The Observer was designed when relationships were non-structural. World already emits `relationship_added` and `relationship_removed` signals (lines 32-33 of world.gd), but the Observer dispatch code (`_handle_observer_component_added`, `_handle_observer_component_removed`) only handles component events.

**Prevention:**
- Add `on_relationship_added(entity, relationship)` and `on_relationship_removed(entity, relationship)` virtual methods to Observer.
- Add a `watch_relationship()` virtual method that returns a Relationship pattern to watch for.
- Wire World's `_on_entity_relationship_added` and `_on_entity_relationship_removed` to dispatch to observers, mirroring the component observer dispatch pattern.
- This is a **public API addition** (not a break), so it fits within the v7.1.0 semver constraint.

**Detection:** Users asking "why doesn't my observer fire when a relationship is added?" Feature gap, not a bug -- but will be expected once relationships are structural.

**Phase relevance:** Can be deferred to a follow-up phase after the core structural change, since it is additive. But should be planned in the roadmap.

---

### Pitfall 8: Entity Serialization (GECSIO) Does Not Account for Structural Relationship Pairs

**What goes wrong:** `GECSIO` serializes entities by iterating their components and producing a data dictionary. Relationships are stored separately in `entity.relationships`. If relationship pairs are now part of the archetype signature, deserialization must reconstruct the pairs and place the entity in the correct archetype. If deserialization adds components first (creating one archetype), then adds relationships (causing N archetype transitions), the entity bounces through N intermediate archetypes during load.

**Prevention:**
- Extend the deserialization path to collect all relationships before archetype placement, similar to how `_initialize()` uses `_begin_suppress`/`_end_suppress` to batch component additions.
- Ensure serialization format includes relationship pairs in a way that can be bulk-restored.
- Test round-trip: serialize entity with 5 relationships, deserialize, verify it lands in the correct archetype with a single transition (not 5).

**Detection:** Deserialization performance regression. Profile entity load times before and after the structural relationship change.

**Phase relevance:** Follow-up phase. Serialization correctness should work automatically (just slowly); optimization is a separate concern.

---

### Pitfall 9: Network Sync Unaware of Structural Relationship Transitions

**What goes wrong:** The PROJECT.md marks "Network sync changes -- not affected by this milestone" as out of scope. But `NetworkSync` observes World signals including `relationship_added` and `relationship_removed`. Once these events trigger archetype transitions and cache invalidation, the timing and ordering of network sync events may change. If `SyncRelationshipHandler` processes a relationship add RPC while the entity is mid-archetype-transition, it may access stale archetype data.

**Prevention:**
- Verify that `SyncRelationshipHandler` does not read archetype data during relationship mutation. It currently operates on `entity.relationships` directly, which is the entity's own array and not archetype-dependent.
- The real risk is performance: if the network layer adds many relationships per frame (e.g., batch sync of 50 relationship adds), each one now triggers an archetype transition. Ensure the network code paths use batch operations or CommandBuffer.
- Add a network-specific test: spawn 10 entities via RPC, each with 3 relationships, verify no archetype corruption.

**Detection:** Network desync after relationship-heavy operations. Entities appearing in wrong query results on the client.

**Phase relevance:** Validation phase. Requires testing but likely no code changes if the sync layer operates on entity-level APIs.

---

### Pitfall 10: Archetype Edge Graph Complexity Increases Quadratically with Pair Count

**What goes wrong:** The current archetype edge graph caches transitions like "archetype A + component C = archetype B." With structural relationships, edges must also encode "archetype A + pair (R, T) = archetype B." If an entity has 5 components and 3 relationship pairs, the archetype has 8 dimensions of possible transitions. The edge graph for that archetype needs up to 8 add-edges and 8 remove-edges. More importantly, the number of distinct archetypes reachable from any given archetype grows combinatorially with the number of relationship pair types in the system.

**Prevention:**
- The edge graph is already a lazy cache (edges are created on first transition, not eagerly). This naturally limits growth to actually-observed transitions.
- Monitor edge count per archetype in debug mode. Add to `_to_string()` on Archetype.
- Consider: if relationship pair edges are rarely reused (because targets are entity-specific), the edge graph provides no benefit for relationship transitions. In that case, skip edge caching for relationship-pair transitions and always fall through to `_calculate_entity_signature()` + `_get_or_create_archetype()`.
- If only type-based targets (Component or Script targets) are structural, the edge graph remains useful because the number of distinct pair types is bounded by the number of component/script types in the project.

**Detection:** Memory growth from edge dictionaries. Profile `add_edges.size()` and `remove_edges.size()` per archetype.

**Phase relevance:** Performance optimization phase, not blocking for initial implementation.

---

## Minor Pitfalls

---

### Pitfall 11: `_to_string()` on Relationship Uses Instance IDs That Change Between Runs

**What goes wrong:** `Relationship._to_string()` uses `target.get_instance_id()` for Entity targets. If this string representation is used as part of cache keys or debug logging, it will differ between runs and between editor/runtime. This is fine for runtime cache keys (they're session-scoped) but problematic for any serialization or cross-session comparison.

**Prevention:** Already not a blocking issue for runtime. Just ensure no code path uses `_to_string()` for persistent storage or cross-session comparison. For serialization, use entity IDs (`entity.id`) instead.

**Phase relevance:** No specific phase. Document as a known behavior.

---

### Pitfall 12: `add_relationships()` on Entity Does Not Batch Archetype Transitions

**What goes wrong:** `Entity.add_relationships()` (line 376) loops and calls `add_relationship()` individually. Unlike `add_components()` (which has a batched archetype transition optimization at line 185), `add_relationships()` will trigger N separate archetype transitions for N relationships.

**Prevention:** Mirror the `add_components()` batching pattern for `add_relationships()`: add all relationships to the entity's array first, then compute the final archetype signature once and do a single transition.

**Detection:** Frame time spikes when adding multiple relationships to an entity in a single call.

**Phase relevance:** Core implementation phase. Easy to implement alongside the structural transition code.

---

### Pitfall 13: Property-Based Relationship Queries Must Remain Non-Structural

**What goes wrong:** Someone attempts to make property-based relationship queries (e.g., `Relationship.new({C_Damage: {'amount': {"_gte": 50}}}, target)`) structural. Runtime property values cannot be hashed into archetype keys because they change without triggering archetype transitions. If property query relationships leak into the archetype signature, entities would need to change archetypes every time a relationship component's property changes.

**Prevention:** The PROJECT.md already marks this as out of scope. Enforce it in code: when computing the archetype signature from an entity's relationships, skip any relationship where `_is_query_relationship == true`. Add an assertion that `_is_query_relationship` relationships are never stored on entities (this assertion already exists at line 367-370 of entity.gd).

**Detection:** Test that adding a relationship with property query values to an entity triggers the existing assertion.

**Phase relevance:** No action needed beyond the existing assertion. Just maintain awareness.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Archetype signature design | Pitfall 1 (explosion), Pitfall 3 (hash collision) | Decide entity-target vs type-target structural policy FIRST. Write hash collision tests before implementation. |
| Entity lifecycle integration | Pitfall 2 (freed targets), Pitfall 4 (cache invalidation storm) | Implement cleanup policy alongside `remove_entity()`. Use suppress/end_suppress around transitions. |
| Query system changes | Pitfall 5 (wildcard index) | Build relation-type index alongside archetype registration. Test wildcard queries with 100+ archetypes. |
| CommandBuffer integration | Pitfall 6 (structural transitions during deferred execution) | Verify existing suppression brackets cover relationship mutations. Add relationship-specific buffer tests. |
| Observer extension | Pitfall 7 (no relationship hooks) | Plan as additive API in a follow-up phase. |
| Serialization/Network | Pitfall 8 (GECSIO), Pitfall 9 (NetworkSync) | Test round-trip serialization and network sync. Likely works but slowly. |
| Performance optimization | Pitfall 10 (edge graph), Pitfall 12 (batch relationships) | Implement batch `add_relationships()` early. Defer edge graph optimization. |

---

## Sources

- Direct codebase analysis of GECS v7.x (all file references are line-accurate to the current codebase state)
- GECS PROJECT.md milestone specification for structural relationships
- GECS ARCHITECTURE.md and CONCERNS.md for existing known issues
- FLECS architectural patterns (structural relationships as archetype components) -- based on established ECS design knowledge; FLECS documentation would be the authoritative reference for the original pattern

---

*Pitfalls analysis: 2026-03-18*

# Feature Landscape: Structural Relationship Queries

**Domain:** ECS structural relationship pair queries (FLECS-style) for GECS/Godot 4.x
**Researched:** 2026-03-18

## Existing Behaviors That Must Be Preserved

These are the current `with_relationship()` / `without_relationship()` contracts verified from `test_relationships.gd` and the QueryBuilder/Entity source. Every one must continue to work identically after the structural migration.

| Behavior | Example | Test Coverage |
|----------|---------|---------------|
| Exact pair query `(Relation, Entity)` | `with_relationship([Relationship.new(C_Likes.new(), e_alice)])` | `test_with_relationships` |
| Wildcard target (null) | `with_relationship([Relationship.new(C_Likes.new(), null)])` | `test_with_relationships_wildcard_target` |
| Wildcard relation (null) | `with_relationship([Relationship.new(null, e_heather)])` | `test_with_relationships_entity_wildcard_target_remove_relationship` |
| ECS.wildcard as relation | `with_relationship([Relationship.new(ECS.wildcard, GecsFood)])` | `test_with_relationships_wildcard_relation` |
| Double wildcard (null, null) | `with_relationship([Relationship.new(null, null)])` | `test_query_with_wildcards_and_strong_matching` |
| Archetype target (Script class) | `with_relationship([Relationship.new(C_Likes.new(), GecsFood)])` | `test_archetype_and_entity` |
| Archetype subsumption (entity of type matches archetype query) | Entity target `e_pizza` matches query for archetype `GecsFood` | `test_archetype_and_entity` |
| Multiple same-type pairs on one entity | Bob has `(Likes, alice)` AND `(Likes, pizza)` | `test_multiple_relationships_same_component_type` |
| Property query on relation | `{C_Eats: {'value': {"_eq": 8}}}` as relation | `test_query_with_strong_relationship_matching` |
| Property query on target | `{C_Health: {'amount': {"_gte": 50}}}` as target | Documented in Relationship.gd |
| Property query on both relation AND target | Both dict forms | Documented in Relationship.gd |
| `without_relationship()` exclusion | System excludes entities with matching relationships | `s_test_without_relationship.gd` |
| Relationship add/remove signals | `relationship_added` / `relationship_removed` on Entity and World | Entity.gd, World.gd signal wiring |
| Relationship removal with limit | `remove_relationship(rel, 1)` removes only one | `test_relationship_removal_with_data_specificity` |
| `get_relationship()` / `get_relationships()` retrieval | Direct entity access to relationship data | `test_component_data_preservation_in_weak_matching` |
| Observer placeholder for relationships | `O_RelationshipObserver` exists but is stub | `o_relationship_observer.gd` |
| CommandBuffer relationship operations | `cmd.add_relationship()`, `cmd.remove_relationship()` | CommandBuffer tests |

## Table Stakes

Features users expect from a structural relationship pair system. Missing = the milestone fails its stated goal.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pair-in-archetype signature | Core requirement from PROJECT.md. Each unique `(RelationType, TargetIdentity)` pair must be part of the archetype hash so entities with the same component+relationship set share an archetype. | High | This is the entire point of the milestone. Requires changes to Entity, World, Archetype, and QueryCacheKey. |
| Structural transition on add/remove relationship | `entity.add_relationship()` must move the entity to a new archetype (same as `add_component()` does). `remove_relationship()` moves it back. | High | Must reuse the existing archetype edge graph. Signals must still fire. |
| `with_relationship()` resolves via archetype cache | Exact `(Relation, Target)` pairs must resolve through the same O(1) archetype bucket lookup that `with_all()` uses, not per-entity linear scan. | High | The query cache key must incorporate relationship pair identifiers. |
| Wildcard target index `(Relation, *)` | When querying `with_relationship([Relationship.new(C_Likes.new(), null)])`, the system must return all archetypes that contain ANY pair with `C_Likes` as the relation, regardless of target. FLECS does this by registering each archetype under `(Relation, *)` in addition to `(Relation, Target)`. | Medium | Requires a secondary index. GECS already has `relationship_entity_index` keyed by `relation.resource_path`; this becomes a relation-type archetype index instead. |
| Wildcard relation index `(*, Target)` | When querying `with_relationship([Relationship.new(null, e_alice)])`, the system must return archetypes that contain ANY pair targeting `e_alice`. | Medium | Requires a target-keyed archetype index. More expensive in FLECS (non-contiguous), but in GDScript a Dictionary lookup is the same cost either way. |
| Double wildcard `(*, *)` | `Relationship.new(null, null)` must match any entity that has any relationship at all. | Low | Index of all archetypes that contain at least one relationship pair. |
| Property queries remain as post-filter | Property-based relationship queries (dict syntax like `{C_Eats: {'value': {"_gte": 5}}}`) cannot be structural because runtime values are not hashable into archetype keys. They must remain as post-filters applied after archetype selection. | Low | Already the design decision in PROJECT.md. No new work, just ensure the post-filter path still works on the narrowed archetype result set. |
| Archetype query cache invalidation on relationship changes | Adding/removing a relationship is now a structural change (archetype transition), so it must invalidate the query cache the same way component add/remove does. | Medium | Currently relationship changes explicitly do NOT invalidate the cache (comment in World.gd line 774). This must change. |
| `without_relationship()` structural support | Exclusion queries must also benefit from structural lookup. An archetype that contains `(Likes, Alice)` must be excluded from results when `without_relationship([Relationship.new(C_Likes.new(), e_alice)])` is used. | Medium | Same mechanism as `with_none()` but for pairs. |
| Pair identity: stable, hashable key for `(RelationType, TargetIdentity)` | Need a consistent way to produce a hash/key for any pair. Relation identity = `relation.get_script().resource_path`. Target identity varies: Entity = `get_instance_id()`, Component = `get_script().resource_path`, Script archetype = `resource_path`, null = wildcard sentinel. | Medium | The existing `Relationship._to_string()` method already produces a unique string per pair. Can be used or adapted for FNV-1a hashing. |
| All existing tests pass unchanged | No public API breaks. The 20+ existing relationship tests must produce identical results. | Low | Verification, not implementation. But non-negotiable. |
| Archetype subsumption for entity-as-archetype-target | When entity `e_pizza` (of type `GecsFood`) is a target, a query for archetype target `GecsFood` must match. This currently works via `Relationship.matches()` type coercion. Under structural pairs, entity targets and archetype targets produce different pair keys, so the wildcard index `(Likes, *)` or a separate archetype-class index must cover this. | High | This is the trickiest compatibility issue. Current behavior: `(Likes, GecsFood)` as a query matches `(Likes, e_pizza)` stored on entity because `e_pizza.get_script() == GecsFood`. Structurally, these are different archetype slots. Options: (A) register archetype under both `(Likes, e_pizza)` and `(Likes, GecsFood)` indices, (B) resolve via `(Likes, *)` wildcard then post-filter, (C) maintain a class-to-instances lookup. |

## Differentiators

Features that go beyond the minimum structural query story. Valuable but not required for the milestone to ship.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Exclusive relationship trait | Mark a relation type so an entity can only have one target for it (e.g., `ChildOf` can only have one parent). Adding a new pair automatically removes the old one. FLECS calls this `Exclusive`. Atomic swap = one archetype transition instead of two. | Medium | Useful for parent-child, team membership, state machines. Would require a trait/tag on the relation component class (e.g., `@export var exclusive := true` on Component base). |
| Relationship Observer events | Fire Observer callbacks on relationship add/remove, not just component add/remove. The placeholder `O_RelationshipObserver` already exists. | Medium | Natural extension. Would let systems react to `(ChildOf, parent)` being added. Requires Observer to accept relationship watches, not just component watches. |
| `with_any_relationship()` query filter | Like `with_any()` for components: entity must have at least one of the listed relationship pairs. Current `with_relationship()` is AND-only (must have ALL listed pairs). | Low | Simple query builder addition. Uses same archetype indices, just union instead of intersection of archetype sets. |
| OnDelete cleanup policy | When a target entity is deleted, automatically remove all pairs referencing it (or delete the source entities). FLECS supports `Remove` (default), `Delete` (cascade), and `Panic` policies. | High | Very useful for hierarchies (delete parent = delete children). Requires hooking into `World.remove_entity()` to scan the target index `(*, Target)` and cascade. GDScript perf concern: scanning all pairs for a deleted entity could be expensive. |
| OnDeleteTarget cascade (hierarchy cleanup) | Specific case of OnDelete: `(ChildOf, parent)` with cascade delete. When parent is deleted, children are also deleted. | Medium | Subset of OnDelete. Can be implemented independently as a special case for ChildOf-style relations. |
| Symmetric relationship trait | If `R(X, Y)` then automatically `R(Y, X)`. Useful for "friends with", "adjacent to". FLECS calls this `Symmetric`. | Medium | Requires auto-adding the reverse pair when a symmetric relationship is added. Both entities change archetype. |
| Pair data access from query results | After a structural query matches `(Likes, alice)`, provide a way to access the relation component data (the `C_Likes` instance) directly from the archetype column, like component column access. | Medium | Currently you call `entity.get_relationship()` which does a linear scan of `entity.relationships`. With structural storage, the relation component could be stored in the archetype column alongside regular components. |
| Batch archetype transition for multiple pairs | Adding multiple relationships at once (e.g., during entity initialization with `define_relationships()`) should produce a single archetype transition, not N transitions. | Medium | Same pattern as batch component adds. Compute final signature, find/create archetype, move once. |

## Anti-Features

Features to explicitly NOT build. Would add complexity without clear benefit in the GDScript/Godot context.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Transitive relationship queries | FLECS supports `if R(X,Y) and R(Y,Z) then R(X,Z)`. This requires graph traversal at query time, which is expensive in GDScript and incompatible with O(1) archetype lookup. No real game use case justifies the complexity in a GDScript ECS. | Users can implement transitive logic in system code by running multiple queries and following the chain manually. |
| Reflexive relationship trait | FLECS supports `R(X, X)` auto-implied. Extremely niche. | Not needed. Users can add self-relationships explicitly if desired. |
| Traversal / `up()` queries | FLECS lets queries traverse relationship hierarchies (e.g., "find component on entity OR any ancestor via ChildOf"). This is a query-time graph walk that defeats archetype O(1) lookup and is very complex to implement. | Implement hierarchy traversal in system code. If a system needs a parent's component, query the parent entity explicitly. |
| Query-time pair iteration (FLECS `Wildcard` vs `Any` distinction) | FLECS distinguishes `*` (iterate each matching pair as separate result) from `_` (return entity once). This requires the query to yield multiple results per entity, fundamentally changing the query return type from `Array[Entity]` to something more complex. | GECS queries return `Array[Entity]`. Each entity appears once. Use `entity.get_relationships()` to iterate an entity's pairs after the query. |
| Pair as regular component slot | FLECS stores pair data in archetype columns as if it were a component. In GECS, relationships store their own data on the `Relationship` resource. Changing this to column storage would require massive architectural changes to Entity, Archetype, and all serialization. | Keep relationship data on the Relationship resource. Use the archetype ONLY for fast matching/grouping. Data access stays through `entity.get_relationship()`. |
| String-based query DSL for pairs | FLECS has a query DSL like `"(Likes, *)"`. GDScript already has a fluent builder API. Adding string parsing adds complexity, maintenance burden, and runtime parsing cost with no real benefit. | Keep the existing `with_relationship([Relationship.new(...)])` builder API. |
| Acyclic relationship enforcement | FLECS can enforce that a relationship graph has no cycles (e.g., ChildOf must be a DAG). Cycle detection at add-time is O(depth) and adds overhead to every relationship add. | Not worth the cost. Users can validate their own hierarchies if needed. |

## Feature Dependencies

```
Pair identity hashing -----> Pair-in-archetype signature -----> Structural transition on add/remove
                                        |                                    |
                                        v                                    v
                              Archetype query cache key         Cache invalidation on rel changes
                              includes pairs
                                        |
                                        v
                              with_relationship() via archetype lookup
                                        |
                        +---------------+---------------+
                        |               |               |
                        v               v               v
               Wildcard target   Wildcard relation   Double wildcard
               index (R, *)     index (*, T)         index (*, *)
                        |
                        v
               Archetype subsumption (entity target matches archetype query)
```

```
[Differentiators - independent of each other, all depend on table stakes]

Exclusive trait -----> requires: structural transition
Relationship Observer -----> requires: relationship signals (existing)
OnDelete cleanup -----> requires: wildcard relation index (*, Target)
Symmetric trait -----> requires: structural transition (auto-adds reverse)
Batch transition -----> requires: archetype edge graph
```

## MVP Recommendation

Prioritize for v7.1.0:

1. **Pair identity hashing** - Foundation for everything else. Define how `(RelationType, TargetIdentity)` maps to an integer key compatible with FNV-1a archetype signatures.
2. **Pair-in-archetype signature** - Include relationship pairs in archetype hash alongside components.
3. **Structural transition on add/remove** - Entity moves archetype when relationships change.
4. **Archetype cache key includes pairs** - Query cache recognizes relationship pairs.
5. **`with_relationship()` via archetype lookup** - The core perf win.
6. **Wildcard indices** - `(R, *)`, `(*, T)`, `(*, *)` for the three wildcard query patterns.
7. **Archetype subsumption** - Entity-target queries matching archetype-target queries (compatibility).
8. **`without_relationship()` structural support** - Exclusion via archetype filtering.
9. **Cache invalidation on relationship changes** - Flip the current "no invalidation" behavior.
10. **All existing tests pass** - Verification gate.

Defer to later milestones:
- **Exclusive trait**: Useful but not blocking. Can be added as v7.2.0.
- **Relationship Observer events**: Placeholder exists. Add when users need reactive relationship systems.
- **OnDelete cleanup**: Complex, high-risk. Needs its own milestone.
- **Symmetric trait**: Niche. Defer unless a concrete use case emerges.
- **Batch transitions**: Optimization. Profile first; may not be needed if single transitions are fast enough.

## Sources

- [FLECS Relationships Documentation](https://www.flecs.dev/flecs/md_docs_2Relationships.html) - Authoritative source for FLECS pair system design
- [FLECS Queries Documentation](https://www.flecs.dev/flecs/md_docs_2Queries.html) - Wildcard, Any, traversal query behaviors
- [FLECS Relationships.md on GitHub](https://github.com/SanderMertens/flecs/blob/master/docs/Relationships.md) - Traits: Exclusive, Symmetric, Transitive, OnDelete
- [A Roadmap to Entity Relationships (Sander Mertens)](https://ajmmertens.medium.com/a-roadmap-to-entity-relationships-5b1d11ebb4eb) - Design rationale for pair-as-archetype-slot
- [Building Games in ECS with Entity Relationships (Sander Mertens)](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c) - Game use cases for ChildOf, IsA, Likes patterns
- [FLECS DeepWiki - Tables and Storage](https://deepwiki.com/SanderMertens/flecs/2.4-tables-and-storage) - Wildcard index registration per archetype table
- GECS source: `query_builder.gd`, `relationship.gd`, `entity.gd`, `world.gd`, `archetype.gd` - Current implementation baseline
- GECS tests: `test_relationships.gd` (460+ lines) - Full current behavioral contract

# Project Research Summary

**Project:** GECS v7.1.0 — Structural Relationship Queries
**Domain:** Archetype-based ECS relationship indexing (FLECS-style pair semantics in GDScript/Godot 4.x)
**Researched:** 2026-03-18
**Confidence:** HIGH

## Executive Summary

GECS currently treats `(Relation, Target)` relationship queries as post-filters: the archetype system matches entities by component sets, then every candidate entity's `relationships` array is linearly scanned for matching pairs. This makes relationship queries O(N*M*K) instead of O(1). The v7.1.0 milestone makes relationship pairs structural — each unique `(RelationType, TargetIdentity)` combination becomes part of the archetype signature, so `with_relationship()` queries resolve through the same cached archetype bucket lookup that `with_all()` already uses. This mirrors the established FLECS architecture where pair IDs are first-class archetype type identifiers.

The recommended approach encodes each relationship pair as a slot key (string format `"rel://<relation_resource_path>::<target_key>"`) appended to the archetype's `component_types` array alongside regular component paths. The World's archetype transition logic — already used for component add/remove — is extended to fire on relationship add/remove. A secondary `_relation_type_archetype_index` enables O(1) wildcard queries (`(Relation, *)`, `(*, Target)`) without scanning all archetypes. The core change touches five files: `archetype.gd`, `world.gd`, `entity.gd`, `query_builder.gd`, and `query_cache_key.gd`. All existing public APIs remain unchanged; the migration is entirely internal.

The single highest-risk decision is the **target identity policy**: using entity instance IDs as pair key targets creates one archetype per unique entity-target, causing archetype explosion in relationship-heavy scenes. The mitigation is to treat entity-instance targets as identity-based (acceptable for explicit parent-child patterns) while monitoring archetype count and providing the `_relation_type_archetype_index` wildcard path so common "any relationship of type R" queries never need exact-target archetypes. Freed entity targets are a related hazard that requires hooking `world.remove_entity()` to cascade or clean up relationship pairs. Both concerns must be addressed in the initial implementation phase, not deferred.

## Key Findings

### Recommended Stack

GECS already contains all necessary infrastructure. No new dependencies or external libraries are required. The implementation reuses: the existing `QueryCacheKey` FNV-1a domain-structured hash, the archetype edge graph for O(1) cached transitions, the `_move_entity_to_new_archetype_fast()` mechanism, the `_begin_suppress`/`_end_suppress` cache suppression brackets, and the `CommandBuffer` for safe deferred structural mutations.

**Core technologies:**
- **GDScript `get_instance_id()` + bitwise encoding:** Stable integer keys for relation and target identity — already used by `QueryCacheKey.build()`, high confidence
- **Archetype edge graph (`add_edges`/`remove_edges`):** O(1) amortized archetype transitions via cached edges — extend to include relationship slot keys as edge keys
- **`QueryCacheKey.build()` domain layout:** FNV-1a hash with domain markers (ALL/ANY/NONE/RELATIONSHIPS) — extend to pass actual relationship pairs for entity signature, not empty arrays
- **`_relation_type_archetype_index` (new):** `Dict[String, Array[Archetype]]` mapping relation `resource_path` to archetypes — enables O(1) wildcard query resolution
- **`CommandBuffer`:** Already wraps structural changes in suppression brackets — relationship mutations in systems should route through it to prevent cache thrash

See `STACK.md` for full FLECS-vs-GDScript analysis and the recommended 64-bit integer pair key format as an alternative to string slot keys.

### Expected Features

The feature contract is defined by 20+ existing relationship tests in `test_relationships.gd`. Every existing behavior must be preserved unchanged. The minimum viable structural implementation (v7.1.0) is:

**Must have (table stakes):**
- Pair-in-archetype signature — each `(Relation, Target)` stored in archetype hash
- Structural transitions on `add_relationship()` / `remove_relationship()` — entity moves archetype
- `with_relationship()` resolves via archetype cache, not entity linear scan
- Wildcard target index `(Relation, *)` — O(1) lookup via relation-type index
- Wildcard relation index `(*, Target)` — O(1) lookup via target-keyed index
- Double wildcard `(*, *)` — any entity with any relationship
- Cache invalidation on relationship changes (currently deliberately disabled)
- Archetype subsumption — entity-target `e_pizza` matches archetype-target `GecsFood` query
- `without_relationship()` structural support via archetype exclusion
- All 20+ existing relationship tests pass unchanged

**Should have (v7.2.0 candidates):**
- Exclusive relationship trait (entity can only have one target per relation type)
- Relationship Observer events (`on_relationship_added`/`on_relationship_removed`)
- `with_any_relationship()` query filter (OR semantics)
- Batch `add_relationships()` archetype transition (single move for N relationships)

**Defer (v2+):**
- OnDelete cascade cleanup policy (delete parent cascades to children)
- Symmetric relationship trait (auto-adds reverse pair)
- Pair data access from archetype columns
- Transitive relationship queries (graph traversal at query time — anti-feature for GDScript)
- Traversal / `up()` queries (FLECS pattern, defeats O(1) archetype lookup)

See `FEATURES.md` for the full feature dependency graph and anti-feature rationale.

### Architecture Approach

The architecture change is an extension of the existing archetype system, not a replacement. Relationship slot keys (`"rel://<path>::<target_key>"`) participate in the same `component_types` array as component resource paths. The archetype infrastructure — signature hashing, edge graph, column storage, `matches_query()` — works identically with one addition: relationship slots do NOT get SoA columns (relationship data stays on `entity.relationships`; archetypes only track pair identity for matching). The six-phase build order discovered during architecture research creates a clear, testable implementation sequence with no big-bang rewrites.

**Major components and their changes:**

1. **`archetype.gd`** — Minimal changes: skip column creation for `rel://` prefixed keys; add `relationship_types` array for fast pair subset iteration; add `matches_relationship_query()` method
2. **`world.gd`** — Heaviest change: `_calculate_entity_signature()` includes relationship slot keys; `_on_entity_relationship_added/removed()` triggers archetype transitions (currently a no-op for archetypes); add `_relation_type_archetype_index`; deprecate `relationship_entity_index`
3. **`entity.gd`** — Minor: `add_relationships()` needs batch transition optimization (currently loops `add_relationship()` individually, causing N transitions)
4. **`query_builder.gd`** — `get_cache_key()` must pass relationships to `QueryCacheKey.build()` (currently always passes empty arrays); `with_relationship()` must invalidate cache key (currently missing); `_query_has_non_structural_filters()` must NOT flag type-match relationships as non-structural
5. **`query_cache_key.gd`** — Pair encoding must hash `(relation_id, target_id)` as a pair, not flatten into a single ID array (current behavior loses pair structure, causing different pairs to hash identically)

See `ARCHITECTURE.md` for the full data flow diagram, backward-compatibility table, and component boundary analysis.

### Critical Pitfalls

The five pitfalls that cause rewrites or order-of-magnitude regressions if ignored:

1. **Archetype explosion from per-entity target identity** — Using entity instance IDs as pair keys creates one archetype per unique entity-target; 100 entities with 3 unique relationships = 100 singleton archetypes, destroying cache hit rates. Prevention: Accept fragmentation for entity targets but monitor archetype count; ensure the `_relation_type_archetype_index` wildcard path is always available so common queries avoid exact-target archetypes. Decide this policy before writing any code.

2. **Freed entity targets create dangling archetype references** — When a target entity is freed, all source entities remain in archetypes whose signatures reference a dead instance ID. Godot recycles Object IDs, causing false-positive query matches. Prevention: Hook `world.remove_entity()` to cascade a REMOVE policy: migrate all source entities to archetypes without the stale pair. Must be implemented alongside the core structural change, not deferred.

3. **Hash collision between component-only and component+pair signatures** — If relationship pairs are not routed through the correct `QueryCacheKey` domain marker, two entities with the same components but different relationships will hash to the same archetype. Prevention: Extend `_calculate_entity_signature()` to pass relationships into `QueryCacheKey.build()` via the existing (but currently unused) `relationships` parameter; use identical pair encoding in both entity signature and query cache key.

4. **Cache invalidation storm from relationship mutations** — Relationship add/remove is currently a no-op for the archetype cache. Making it structural means every `add_relationship()` triggers a cache invalidation. Systems adding many relationships per frame will thrash the cache. Prevention: Use `_move_entity_to_new_archetype_fast()` with edge caching; ensure `add_relationships()` batches to a single transition; route in-system mutations through `CommandBuffer` for built-in suppression brackets.

5. **Wildcard queries degrade to O(A) archetype scan without a secondary index** — A `with_relationship([Relationship.new(C_ChildOf.new(), null)])` query must match all archetypes containing ANY `C_ChildOf` pair. Without a pre-built relation-type index, this requires scanning every archetype. With archetype explosion (Pitfall 1), this is worse than the current entity linear scan. Prevention: Build `_relation_type_archetype_index` alongside archetype signature changes in the same phase.

## Implications for Roadmap

The architecture research identifies a strict dependency chain. Each phase produces a working, testable intermediate state. No phase can be skipped or reordered without breaking subsequent phases.

### Phase 1: Archetype Extension (Foundation)

**Rationale:** All subsequent changes assume the Archetype class can hold relationship slot keys without breaking component behavior. This must be verified in isolation before touching World or QueryBuilder.
**Delivers:** `Archetype` that handles `rel://` prefixed keys in `component_types` without creating spurious columns; `matches_relationship_query()` method; `relationship_types` subset array
**Addresses:** Table stake — pair-in-archetype signature (storage side)
**Avoids:** Pitfall 3 (hash collision) by establishing the slot key format before any signature computation changes

### Phase 2: Signature Computation and Wildcard Index

**Rationale:** With Archetype ready, `world._calculate_entity_signature()` can be extended. The wildcard index must be built here — not deferred — because Phase 3 (archetype transitions) will immediately create archetypes that need to be registered in the index.
**Delivers:** `_calculate_entity_signature()` includes relationship pairs; `_relationship_slot_key()` helper; `_relation_type_archetype_index` populated on archetype creation/deletion
**Addresses:** Wildcard target index `(Relation, *)`, double wildcard `(*, *)`
**Avoids:** Pitfall 5 (wildcard scan degradation) by building the index at the same time as signature changes; Pitfall 1 (archetype explosion) by making the wildcard index the primary query path for common patterns

### Phase 3: Archetype Transitions on Relationship Mutation

**Rationale:** This is the structural integration point. Entity lifecycle events (add/remove relationship) now trigger archetype moves identical to component add/remove.
**Delivers:** `_on_entity_relationship_added/removed()` calls `_move_entity_to_new_archetype_fast()`; cache invalidation enabled on relationship changes; batch `add_relationships()` optimization (single transition for N pairs); freed-entity cleanup hook in `world.remove_entity()`
**Addresses:** Structural transition table stake; cache invalidation requirement; Pitfall 2 (freed targets); Pitfall 4 (invalidation storm via batching)
**Avoids:** Pitfall 6 (CommandBuffer structural transitions during deferred execution) by ensuring suppression brackets cover relationship mutations

### Phase 4: Query System Integration

**Rationale:** With archetypes moving correctly, the query layer can be updated to route `with_relationship()` through archetype lookup instead of post-filtering.
**Delivers:** `QueryBuilder.get_cache_key()` passes relationships to `QueryCacheKey.build()`; `QueryCacheKey.build()` pair encoding fixed (hash pairs, not flat sort); `with_relationship()` resolves via archetype matching; `System._query_has_non_structural_filters()` no longer flags type-match relationships as non-structural; `without_relationship()` structural exclusion
**Addresses:** Core performance win — `with_relationship()` via archetype cache; `without_relationship()` structural support; archetype cache key includes pairs
**Avoids:** Pitfall 3 (hash collision) — pair encoding must be identical between entity signature and query cache key

### Phase 5: Property Query Preservation and Compatibility Verification

**Rationale:** Property-based relationship queries (dict syntax with runtime value comparisons) cannot be structural. This phase verifies the boundary between structural and non-structural is correctly enforced and that all existing tests pass.
**Delivers:** Property queries remain as post-filters after archetype narrowing; `_query_has_non_structural_filters()` still returns true for property queries; archetype subsumption (entity-target matches archetype-target query) verified; all 20+ existing relationship tests pass unchanged
**Addresses:** Table stake — all existing tests pass; property queries remain as post-filter; archetype subsumption compatibility
**Avoids:** Pitfall 13 (property queries leaking into signatures)

### Phase 6: Cleanup and Performance Validation

**Rationale:** Removes legacy infrastructure superseded by the archetype index and adds performance benchmarks to verify the improvement claim.
**Delivers:** `relationship_entity_index` deprecated/removed; performance benchmarks comparing old vs new relationship query path; archetype count monitoring in debug mode; GECSIO serialization round-trip test
**Addresses:** Pitfall 8 (GECSIO deserialization) — verified (likely works, may be slow); Pitfall 9 (NetworkSync) — validated no structural corruption
**Avoids:** Pitfall 10 (edge graph complexity) — benchmark-driven decision on whether edge caching for relationship pairs is beneficial or wasteful

### Phase Ordering Rationale

- **Foundation before query:** Archetype storage (Phase 1) must exist before signature computation (Phase 2); transitions (Phase 3) must work before queries can use them (Phase 4). This order is non-negotiable due to hard dependencies.
- **Wildcard index in Phase 2, not Phase 4:** The index must be populated when archetypes are created (Phase 3). Building it in Phase 4 would require a retroactive scan of all existing archetypes.
- **Freed-entity cleanup in Phase 3:** Must ship alongside the structural transition code. Leaving it for Phase 6 would create silent data corruption in any Phase 3/4 tests involving entity removal.
- **Property query preservation in Phase 5:** No new work; it is a verification gate. Placing it after Phase 4 ensures the structural path is complete before asserting the non-structural path is still intact.

### Research Flags

Phases likely needing deeper research or careful per-step validation during planning:

- **Phase 3 (Archetype transitions):** The freed-entity cleanup policy (REMOVE vs CASCADE vs ORPHAN) has multiple valid designs. The correct choice depends on game patterns and user expectations. Recommend defining an explicit default policy in `PROJECT.md` before implementation.
- **Phase 4 (Query integration):** Archetype subsumption (entity `e_pizza` matches script-target `GecsFood` query) is identified as the trickiest compatibility issue in `FEATURES.md`. Three resolution strategies exist (dual-index registration, wildcard post-filter, class-to-instances lookup). Option B (wildcard then post-filter) is lowest risk. Confirm approach before implementing.
- **Phase 1 (Archetype slot key format):** STACK.md recommends 64-bit integer pair keys; ARCHITECTURE.md recommends string slot keys for uniform handling with existing component paths. Both are valid; the two approaches must be reconciled into a single consistent decision before any code is written.

Phases with well-documented patterns (skip deep research):

- **Phase 2 (Signature computation):** `QueryCacheKey.build()` already accepts relationship parameters; extending `_calculate_entity_signature()` follows the established pattern exactly.
- **Phase 6 (Cleanup):** Straightforward removal of `relationship_entity_index` and addition of debug metrics. No novel design required.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Based on FLECS official documentation and Godot engine source. Pair key format is well-founded; the int-vs-string slot key format question is the only open decision. |
| Features | HIGH | Derived entirely from existing GECS test suite (460+ lines of relationship tests) and PROJECT.md milestone spec. Behavioral contract is precise and complete. |
| Architecture | HIGH | Based on direct codebase analysis with line-accurate references to `world.gd`, `archetype.gd`, `query_builder.gd`. No speculation; all integration points identified. |
| Pitfalls | HIGH | Identified from codebase analysis of actual code paths, not theoretical concerns. Each pitfall includes the exact file/line causing the issue. |

**Overall confidence:** HIGH

### Gaps to Address

- **Slot key format: int vs string.** STACK.md advocates 64-bit integer pair keys (faster hashing, extractable); ARCHITECTURE.md uses string `"rel://..."` keys (uniform with existing component path strings, easier to debug). The two files are inconsistent. This decision must be made explicitly before Phase 1. Recommendation: use string slot keys for `component_types` membership (matches existing Archetype infrastructure) and integer pair keys for `QueryCacheKey` hashing (performance-critical path). They are not mutually exclusive.

- **Freed-entity cleanup policy.** The research identifies the problem clearly but does not prescribe a default policy. FLECS defaults to REMOVE (relationship is deleted when target is deleted). This should be confirmed as the GECS default in `PROJECT.md` before Phase 3 implementation.

- **Archetype subsumption implementation strategy.** Three options exist for handling entity-target queries that should match archetype-target queries. None is implemented; all require design confirmation. Recommend Option B (wildcard + post-filter) as lowest-risk first pass, with Option A (dual-index registration) as a follow-up if performance requires it.

- **`add_relationships()` batch optimization scope.** The pitfall is identified and the fix is clear (mirror `add_components()` batching). Whether this lands in Phase 3 or Phase 6 affects Phase 3 scope. Given that it prevents cache thrash (Pitfall 4), it belongs in Phase 3.

## Sources

### Primary (HIGH confidence)

- [FLECS Relationships Documentation](https://www.flecs.dev/flecs/md_docs_2Relationships.html) — pair semantics, wildcard indices, archetype fragmentation
- [FLECS Quickstart - Pairs](https://github.com/SanderMertens/flecs/blob/master/docs/Quickstart.md) — pair encoding, structural transitions
- [Making the most of ECS identifiers — Sander Mertens](https://ajmmertens.medium.com/doing-a-lot-with-a-little-ecs-identifiers-25a72bd2647) — 64-bit pair ID bit layout
- [FLECS Core ECS System — DeepWiki](https://deepwiki.com/SanderMertens/flecs/2-core-ecs-system) — archetype graph edges for pairs
- [FLECS Tables and Storage — DeepWiki](https://deepwiki.com/SanderMertens/flecs/2.4-tables-and-storage) — wildcard index registration per archetype table
- GECS source: `archetype.gd`, `world.gd`, `entity.gd`, `query_builder.gd`, `query_cache_key.gd`, `relationship.gd`, `system.gd` — direct codebase analysis with line references
- GECS tests: `test_relationships.gd` (460+ lines) — full behavioral contract for backward compatibility

### Secondary (MEDIUM confidence)

- [A Roadmap to Entity Relationships — Sander Mertens](https://ajmmertens.medium.com/a-roadmap-to-entity-relationships-5b1d11ebb4eb) — design rationale for pair-as-archetype-slot
- [Building Games in ECS with Entity Relationships — Sander Mertens](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c) — game use cases for ChildOf/IsA patterns
- [Godot hashfuncs.h source](https://github.com/godotengine/godot/blob/master/core/templates/hashfuncs.h) — integer key hashing performance characteristics

### Tertiary (LOW confidence)

- GDScript-level Dictionary benchmarks — no specific benchmarks found; integer key performance claim based on engine source review, not measured data. Validate with a micro-benchmark in Phase 6.

---
*Research completed: 2026-03-18*
*Ready for roadmap: yes*

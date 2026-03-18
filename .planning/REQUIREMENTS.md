# Requirements: GECS v7.1.0 — Structural Relationships

**Defined:** 2026-03-18
**Core Value:** Relationship queries must be as fast as component queries — both select pre-grouped archetype buckets, no per-entity iteration.

## v1 Requirements

Requirements for v7.1.0 release. Each maps to roadmap phases.

### Archetype Pairs

- [ ] **ARCH-01**: Each unique `(Relation, Target)` pair is encoded as a slot key and stored in the archetype's `component_types` array alongside component resource paths
- [ ] **ARCH-02**: Relationship slot keys use `rel://<relation_resource_path>::<target_key>` string format in `component_types` (uniform with existing component path infrastructure)
- [ ] **ARCH-03**: Archetype does NOT create SoA columns for `rel://` prefixed slot keys (relationship data remains on `entity.relationships`)
- [ ] **ARCH-04**: Archetype exposes a `relationship_types` array for efficient pair subset iteration
- [ ] **ARCH-05**: Archetype `matches_relationship_query()` method performs structural pair matching

### Signature & Index

- [ ] **SIGX-01**: `World._calculate_entity_signature()` includes relationship slot keys in the entity's archetype signature hash
- [ ] **SIGX-02**: `QueryCacheKey.build()` encodes relationship pairs as `(relation_id, target_id)` integer pairs (not flattened — preserves pair structure to prevent hash collisions)
- [ ] **SIGX-03**: World maintains a `_relation_type_archetype_index: Dictionary` mapping `relation.resource_path → Array[Archetype]` for O(1) wildcard queries
- [ ] **SIGX-04**: `_relation_type_archetype_index` is updated when archetypes are created and destroyed

### Structural Transitions

- [ ] **TRAN-01**: `entity.add_relationship()` triggers an archetype transition (entity moves to new archetype including the pair slot key)
- [ ] **TRAN-02**: `entity.remove_relationship()` triggers an archetype transition (entity moves to archetype without the pair slot key)
- [ ] **TRAN-03**: `entity.add_relationships()` batches to a single archetype transition (not N sequential transitions) to prevent cache thrash
- [ ] **TRAN-04**: Cache invalidation fires on relationship add/remove (currently deliberately disabled — must be re-enabled for structural correctness)
- [ ] **TRAN-05**: When a target entity is removed from the World, all source entities holding `(Relation, freed_target)` relationships are cleaned up (REMOVE policy — relationship is deleted when target is deleted, same as FLECS default)

### Query Integration

- [ ] **QURY-01**: `QueryBuilder.get_cache_key()` passes relationship pairs to `QueryCacheKey.build()` (currently always passes empty arrays — must be fixed)
- [ ] **QURY-02**: `with_relationship()` with exact `(Relation, Target)` resolves via archetype cache lookup, not per-entity scan
- [ ] **QURY-03**: `with_relationship()` with null target (wildcard) resolves via `_relation_type_archetype_index`, not per-entity scan
- [ ] **QURY-04**: `without_relationship()` resolves structurally via archetype exclusion
- [ ] **QURY-05**: `System._query_has_non_structural_filters()` does NOT flag exact type-match relationships as non-structural (only property-query relationships are non-structural)
- [ ] **QURY-06**: Archetype subsumption: entity-instance target `e_pizza` matches a query using script-archetype target `GecsFood` (via wildcard + post-filter strategy)

### Property Query Preservation

- [ ] **PROP-01**: Property-based relationship queries (`Relationship.new({C_Damage: {'amount': {'_gte': 50}}}, target)`) remain as post-filters applied after archetype narrowing
- [ ] **PROP-02**: `_query_has_non_structural_filters()` still returns true for property-query relationships
- [ ] **PROP-03**: All 20+ existing relationship tests in `test_relationships.gd` pass unchanged

### Perf Validation & Cleanup

- [ ] **PERF-01**: Performance benchmarks demonstrate relationship query time parity with equivalent component queries at scales of 100, 1000, 10000 entities
- [ ] **PERF-02**: `relationship_entity_index` (legacy partial index in World) is removed or deprecated in favor of `_relation_type_archetype_index`
- [ ] **PERF-03**: Archetype count monitoring added to debug mode output (detect archetype explosion in development)

## v2 Requirements

Deferred to v7.2.0 or later.

### Relationship Traits

- **TRAIT-01**: Exclusive relationship trait — entity can only hold one target per relation type (enforced on `add_relationship()`)
- **TRAIT-02**: Symmetric relationship trait — adding `(R, B)` to A auto-adds `(R, A)` to B

### Observer Integration

- **OBS-01**: Observer `on_relationship_added` callback fires when a relationship pair is structurally added
- **OBS-02**: Observer `on_relationship_removed` callback fires when a relationship pair is structurally removed

### Advanced Queries

- **ADVQ-01**: `with_any_relationship()` filter — OR semantics across multiple relationship patterns
- **ADVQ-02**: Dual-index registration for archetype subsumption (Option A) as a performance follow-up if wildcard+post-filter proves too slow

## Out of Scope

| Feature | Reason |
|---------|--------|
| Property-based relationship queries becoming structural | Runtime values can't be archetype-keyed by definition |
| Transitive relationship queries / graph traversal at query time | Defeats O(1) archetype lookup; anti-feature for GDScript performance |
| Traversal / `up()` queries (FLECS pattern) | Same anti-feature rationale |
| OnDelete cascade policy (delete parent cascades to children) | v2+ complexity; v7.1.0 ships REMOVE policy only |
| Pair data access from archetype SoA columns | Relationship data stays on entity.relationships; archetype tracks identity only |
| Breaking any public API on World, Entity, QueryBuilder, System, Observer | v7.1.0 semver — no public API breaks |
| Network sync changes | Not affected by this milestone |

## Traceability

Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 1 | Pending |
| ARCH-02 | Phase 1 | Pending |
| ARCH-03 | Phase 1 | Pending |
| ARCH-04 | Phase 1 | Pending |
| ARCH-05 | Phase 1 | Pending |
| SIGX-01 | Phase 2 | Pending |
| SIGX-02 | Phase 2 | Pending |
| SIGX-03 | Phase 2 | Pending |
| SIGX-04 | Phase 2 | Pending |
| TRAN-01 | Phase 3 | Pending |
| TRAN-02 | Phase 3 | Pending |
| TRAN-03 | Phase 3 | Pending |
| TRAN-04 | Phase 3 | Pending |
| TRAN-05 | Phase 3 | Pending |
| QURY-01 | Phase 4 | Pending |
| QURY-02 | Phase 4 | Pending |
| QURY-03 | Phase 4 | Pending |
| QURY-04 | Phase 4 | Pending |
| QURY-05 | Phase 4 | Pending |
| QURY-06 | Phase 4 | Pending |
| PROP-01 | Phase 5 | Pending |
| PROP-02 | Phase 5 | Pending |
| PROP-03 | Phase 5 | Pending |
| PERF-01 | Phase 6 | Pending |
| PERF-02 | Phase 6 | Pending |
| PERF-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after initial definition*

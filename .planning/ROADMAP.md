# Roadmap: GECS v7.1.0 — Structural Relationships

## Overview

Transform GECS relationship queries from O(N*M*K) per-entity post-filtering to O(1) archetype bucket lookup by making each unique `(Relation, Target)` pair a first-class slot in the archetype signature. Six phases follow a strict dependency chain: archetype storage, signature computation, structural transitions, query integration, compatibility verification, and performance validation. Each phase produces a working, testable intermediate state.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Archetype Extension** - Archetype class handles `rel://` slot keys without breaking component behavior
- [ ] **Phase 2: Signature Computation & Wildcard Index** - Entity signatures include relationship pairs; wildcard index enables O(1) relation-type lookup
- [ ] **Phase 3: Structural Transitions** - Relationship add/remove triggers archetype moves with batch optimization and freed-entity cleanup
- [ ] **Phase 4: Query System Integration** - `with_relationship()` resolves via archetype cache lookup instead of per-entity scan
- [ ] **Phase 5: Property Query Preservation & Compatibility** - Property queries remain as post-filters; all 20+ existing relationship tests pass unchanged
- [ ] **Phase 6: Cleanup & Performance Validation** - Legacy index removed; benchmarks confirm relationship query parity with component queries

## Phase Details

### Phase 1: Archetype Extension

**Goal**: Archetype class can store relationship slot keys alongside component paths without breaking any existing component behavior
**Depends on**: Nothing (first phase)
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, ARCH-05
**Success Criteria** (what must be TRUE):

1. An Archetype created with `rel://` prefixed keys in `component_types` does not create SoA columns for those keys
2. `Archetype.relationship_types` returns only the `rel://` prefixed subset of `component_types`
3. `Archetype.matches_relationship_query()` correctly matches structural pair keys against a query's relationship pairs
4. All existing Archetype unit tests pass unchanged (no regression in component-only behavior)
   **Plans**: 1 plan

Plans:

- [ ] 01-01-PLAN.md — Extend Archetype class with rel:// slot key support, relationship_types array, and matches_relationship_query() method

### Phase 2: Signature Computation & Wildcard Index

**Goal**: Entity archetype signatures incorporate relationship pairs, and a relation-type index enables O(1) wildcard archetype lookup
**Depends on**: Phase 1
**Requirements**: SIGX-01, SIGX-02, SIGX-03, SIGX-04
**Success Criteria** (what must be TRUE):

1. Two entities with identical components but different relationships land in different archetypes
2. `World._relation_type_archetype_index` maps each relation resource path to the set of archetypes containing that relation type
3. The wildcard index is updated automatically when archetypes are created or destroyed
4. `QueryCacheKey.build()` produces distinct hashes for queries with different relationship pairs (no pair-flattening collisions)
   **Plans**: 1 plan

Plans:

- [x] 02-01: Extend entity signatures with relationship pairs, stable entity IDs, pair encoding fix, and wildcard index

### Phase 3: Structural Transitions

**Goal**: Relationship mutations trigger archetype moves identical to component mutations, with batch optimization and safe cleanup of freed targets
**Depends on**: Phase 2
**Requirements**: TRAN-01, TRAN-02, TRAN-03, TRAN-04, TRAN-05
**Success Criteria** (what must be TRUE):

1. Calling `entity.add_relationship()` moves the entity to a new archetype that includes the pair slot key
2. Calling `entity.remove_relationship()` moves the entity back to an archetype without the pair slot key
3. `entity.add_relationships([r1, r2, r3])` performs a single archetype transition (not 3 sequential transitions)
4. When a target entity is removed from the World, all source entities holding relationships to that target have those relationships cleaned up (REMOVE policy)
5. Query cache is invalidated on relationship add/remove (re-enabled from currently disabled state)
   **Plans**: 1 plan

Plans:

- [ ] 03-01: TBD

### Phase 4: Query System Integration

**Goal**: `with_relationship()` and `without_relationship()` queries resolve through archetype cache lookup, achieving O(1) relationship query performance
**Depends on**: Phase 3
**Requirements**: QURY-01, QURY-02, QURY-03, QURY-04, QURY-05, QURY-06
**Success Criteria** (what must be TRUE):

1. `with_relationship()` with an exact `(Relation, Target)` pair returns entities via archetype bucket selection, not per-entity scanning
2. `with_relationship()` with null target (wildcard) returns entities via `_relation_type_archetype_index` lookup
3. `without_relationship()` excludes entities structurally via archetype exclusion
4. `_query_has_non_structural_filters()` returns false for exact type-match relationships (only property-query relationships are non-structural)
5. Entity-instance target `e_pizza` matches a query using script-archetype target `GecsFood` (archetype subsumption via wildcard + post-filter)
   **Plans**: 1 plan

Plans:

- [ ] 04-01: TBD

### Phase 5: Property Query Preservation & Compatibility

**Goal**: Property-based relationship queries and all existing relationship behaviors remain intact after the structural changes
**Depends on**: Phase 4
**Requirements**: PROP-01, PROP-02, PROP-03
**Success Criteria** (what must be TRUE):

1. Property-based relationship queries (`{C_Damage: {'amount': {'_gte': 50}}}`) still work as post-filters applied after archetype narrowing
2. `_query_has_non_structural_filters()` returns true when a query contains property-based relationship filters
3. All 20+ existing relationship tests in `test_relationships.gd` pass with zero modifications
   **Plans**: 1 plan

Plans:

- [ ] 05-01: TBD

### Phase 6: Cleanup & Performance Validation

**Goal**: Legacy relationship infrastructure is removed and benchmarks confirm structural relationship queries match component query performance
**Depends on**: Phase 5
**Requirements**: PERF-01, PERF-02, PERF-03
**Success Criteria** (what must be TRUE):

1. Performance benchmarks show relationship query time within 2x of equivalent component queries at scales of 100, 1000, and 10000 entities
2. `relationship_entity_index` (legacy partial index in World) is removed or deprecated
3. Debug mode output includes archetype count monitoring to detect archetype explosion during development
   **Plans**: 1 plan

Plans:

- [ ] 06-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase                          | Plans Complete | Status      | Completed |
| ------------------------------ | -------------- | ----------- | --------- |
| 1. Archetype Extension         | 0/1            | Planned     | -         |
| 2. Signature & Wildcard Index  | 0/?            | Not started | -         |
| 3. Structural Transitions      | 0/?            | Not started | -         |
| 4. Query System Integration    | 0/?            | Not started | -         |
| 5. Property Query Preservation | 0/?            | Not started | -         |
| 6. Cleanup & Performance       | 0/?            | Not started | -         |

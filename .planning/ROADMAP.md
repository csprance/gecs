# Roadmap: GECS Performance & Reliability Audit

## Overview

Five dependency-ordered fix phases harden GECS against all six known correctness bugs. Observer signal chain comes first because tests for every later phase rely on correct observer callbacks. Cache invalidation scoping follows, then archetype edge hardening (which depends on clean invalidation paths), then the two independent correctness fixes (component duplication, reverse relationship). Performance benchmarking closes the audit once every query result is provably correct.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Observer Signal Chain** - Fix observer callbacks so every phase's regression tests are reliable
- [ ] **Phase 2: Cache Invalidation Scoping** - Restrict cache wipes to archetype-set changes; fix enabled/disabled staleness
- [ ] **Phase 3: Archetype Edge Cache Hardening** - Bidirectional edge cleanup so entities never silently drop from queries
- [ ] **Phase 4: Component Lifecycle and Relationship Queries** - Preserve non-@export properties; fix reverse relationship query
- [ ] **Phase 5: Performance Baselines and Regression Infrastructure** - Validate improvements with benchmarks; add cache monitoring

## Phase Details

### Phase 1: Observer Signal Chain
**Goal**: Observer callbacks are correct and reliable so all subsequent regression tests can trust observer events as a verification tool
**Depends on**: Nothing (first phase)
**Requirements**: OBS-01, OBS-02, OBS-03, OBS-04
**Success Criteria** (what must be TRUE):
  1. Calling `world.remove_entity()` on an entity with watched components causes `on_component_removed` to fire for each watched component before the entity is freed
  2. Calling `entity.remove_component()` delivers the exact component instance that was removed — observers can match it by `resource_path`
  3. After a component is removed, no further `property_changed` notifications arrive from that component — phantom callbacks do not occur
  4. All three observer scenarios (add, remove, remove_entity teardown) have passing regression tests in `addons/gecs/tests/`
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Write failing regression test scaffold (O_InstanceCapturingObserver + test_observer.gd, RED phase)
- [ ] 01-02-PLAN.md — Apply OBS-01/OBS-02/OBS-03 bug fixes to entity.gd and world.gd (GREEN phase)
- [ ] 01-03-PLAN.md — Update doc comments in observer.gd and world.gd to document guaranteed behaviors

### Phase 2: Cache Invalidation Scoping
**Goal**: Query cache layers are invalidated at the correct granularity — no stale results, no spurious full-cache wipes
**Depends on**: Phase 1
**Requirements**: CACHE-01, CACHE-02, CACHE-03, CACHE-04
**Success Criteria** (what must be TRUE):
  1. A query using `.enabled()` or `.disabled()` never returns entities whose enabled state changed since the last structural mutation — toggle enable/disable and re-query returns the updated set
  2. Moving an entity between archetypes (add/remove component) does not wipe `_query_archetype_cache` when both archetypes already exist
  3. An interrupted batch operation (early return or error) does not leave `_should_invalidate_cache` permanently false — subsequent queries return correct results
  4. Regression tests confirm no stale results after enable/disable toggle and after entity movement between existing archetypes
**Plans**: TBD

### Phase 3: Archetype Edge Cache Hardening
**Goal**: Entities never silently disappear from queries after an archetype empties and is recreated
**Depends on**: Phase 2
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04
**Success Criteria** (what must be TRUE):
  1. After the last entity leaves an archetype (causing deletion), adding a new entity with the same component set returns it in all matching queries — no query dropout
  2. Both the fast-path (`_move_entity_to_new_archetype_fast`) and slow-path (`_move_entity_to_new_archetype`) transitions handle deleted archetype references without returning stale objects
  3. Deleting an archetype removes it from all neighbor archetypes' edge caches — no stale back-references remain
  4. The regression test scenario (entity is last in archetype → archetype deleted → new entity with same components → query returns correct results) passes
**Plans**: TBD

### Phase 4: Component Lifecycle and Relationship Queries
**Goal**: Component property values are preserved through entity registration; reverse relationship queries return correct targets
**Depends on**: Phase 3
**Requirements**: COMP-01, COMP-02, COMP-03, REL-01, REL-02
**Success Criteria** (what must be TRUE):
  1. A component with non-`@export` properties set before `world.add_entity()` retains those values after the call — no silent property reset
  2. `with_reverse_relationship()` returns the entities that are the *target* of a given relationship type, not an empty or incorrect set
  3. The framework's authoring constraint on component duplication (shared vs per-entity components) is documented or enforced
  4. Regression tests cover non-@export property preservation through both `add_entity` and `add_entities`, and both reverse relationship query forms
**Plans**: TBD

### Phase 5: Performance Baselines and Regression Infrastructure
**Goal**: Benchmark numbers confirm correctness fixes did not regress performance, and the cache invalidation reduction produces measurable improvement
**Depends on**: Phase 4
**Requirements**: PERF-01, PERF-02, PERF-03, PERF-04
**Success Criteria** (what must be TRUE):
  1. The `_handle_observer_component_added` path uses an O(1) archetype membership check — not an `Array.has()` linear scan — observable via benchmark comparison
  2. Observer `watch()` is called once at `add_observer` time; results are cached — per-notification virtual call overhead is eliminated
  3. The post-fix JSONL benchmark at 10k entities shows query throughput meeting or exceeding pre-audit baselines — no performance regression from correctness fixes
  4. The `query_caching` benchmark delta (before/after invalidation scoping fix) is recorded in a JSONL entry and the `query_caching` regression at 10k entities is resolved
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Observer Signal Chain | 2/3 | In Progress|  |
| 2. Cache Invalidation Scoping | 0/TBD | Not started | - |
| 3. Archetype Edge Cache Hardening | 0/TBD | Not started | - |
| 4. Component Lifecycle and Relationship Queries | 0/TBD | Not started | - |
| 5. Performance Baselines and Regression Infrastructure | 0/TBD | Not started | - |

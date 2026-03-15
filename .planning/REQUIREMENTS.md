# Requirements: GECS Performance & Reliability Audit

**Defined:** 2026-03-15
**Core Value:** Every query must return correct results every frame, and doing so must be fast enough that developers never need to work around GECS to hit performance targets.

## v1 Requirements

### Observer Signal Chain

- [x] **OBS-01**: `world.remove_entity()` fires `on_component_removed` for every watched component on the entity before it is destroyed (fix #93)
- [x] **OBS-02**: `entity.remove_component()` emits the correct component instance through the signal chain so observers can match by `resource_path` (fix #68)
- [x] **OBS-03**: `property_changed` signal is disconnected from the world when a component is removed from an entity — no phantom observer notifications after removal
- [x] **OBS-04**: Regression tests cover all three observer signal chain cases above

### Cache Invalidation

- [x] **CACHE-01**: `_query_archetype_cache` is only invalidated when the archetype set changes (archetype created or deleted), not on every entity movement between archetypes
- [x] **CACHE-02**: Per-QueryBuilder `_cache_valid` is invalidated when `entity.enabled` or `entity.disabled` changes, so `.enabled()` filter always returns accurate results (fix #87)
- [x] **CACHE-03**: The `_should_invalidate_cache = false` batch suppression flag is safely guarded so it cannot be left permanently false after an error or interruption
- [x] **CACHE-04**: Regression tests confirm stale results are not returned after enable/disable toggle and after entity movement

### Archetype Edge Cache

- [ ] **ARCH-01**: Fast-path `_move_entity_to_new_archetype_fast` does not return stale archetype references after an archetype is deleted (incorporate/supersede PR #81)
- [ ] **ARCH-02**: Slow-path `_move_entity_to_new_archetype` receives the same staleness fix as the fast path
- [ ] **ARCH-03**: When an archetype is deleted from `World.archetypes`, reverse edges from neighbor archetypes pointing to it are also cleared (bidirectional cleanup — removes the re-registration workaround)
- [ ] **ARCH-04**: Regression test covers: entity is last in archetype → archetype deleted → new entity added with same component set → query returns correct results

### Component Lifecycle

- [ ] **COMP-01**: Components with non-`@export` properties retain their pre-`add_entity` values after the entity is added to the world — framework does not unconditionally `duplicate(true)` live component instances (fix #53)
- [ ] **COMP-02**: Framework documents (or enforces) the authoring constraint around `duplicate(true)` for components intended to be shared vs per-entity
- [ ] **COMP-03**: Regression test verifies non-@export property values are preserved through `add_entity` and `add_entities`

### Relationship Queries

- [ ] **REL-01**: `with_reverse_relationship()` correctly resolves entities that are the *target* of a given relationship type — does not delegate to `with_all()` with Entity object references (fix #5)
- [ ] **REL-02**: Regression tests for both reverse relationship query forms (by relation type, by target entity type)

### Performance & Benchmarks

- [ ] **PERF-01**: `_handle_observer_component_added` uses an O(1) archetype membership check (`entity_to_archetype.has(entity)` + `archetype.matches_query()`) instead of `Array.has(entity)` linear scan
- [ ] **PERF-02**: Observer `watch()` virtual call result is cached at `add_observer` time and not re-invoked on every component notification
- [ ] **PERF-03**: Post-fix JSONL benchmark run shows query throughput at 10k entities meets or exceeds pre-audit baselines (correctness fixes must not regress performance)
- [ ] **PERF-04**: Benchmark suite documents per-test improvement delta (before/after) for the over-invalidation fix

## v2 Requirements

### Observability

- **DBG-01**: Cache hit/miss ratio exposed as a Godot performance monitor for debugging
- **DBG-02**: `_subsystems_cache` in System cleared on world purge/reinit to prevent stale world references after scene transition

### Threading

- **THR-01**: Investigate thread-safe query execution (currently single-threaded by design)

## Out of Scope

| Feature | Reason |
|---------|--------|
| FLECS archetypes (memory-layout SoA) | Architectural overhaul, not this milestone |
| FLECS staging/merge pipeline | Supersedes CommandBuffer, separate feature milestone |
| Debugger overlay/tooling (#72, #75, #77) | Not performance or correctness |
| Startup system hook (#82) | Feature enhancement, not audit scope |
| FLECS-style timer/tick system (PR #74) | Separate feature |
| Threading | Separate concern |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| OBS-01 | Phase 1 | Complete |
| OBS-02 | Phase 1 | Complete |
| OBS-03 | Phase 1 | Complete |
| OBS-04 | Phase 1 | Complete |
| CACHE-01 | Phase 2 | Complete |
| CACHE-02 | Phase 2 | Complete |
| CACHE-03 | Phase 2 | Complete |
| CACHE-04 | Phase 2 | Complete |
| ARCH-01 | Phase 3 | Pending |
| ARCH-02 | Phase 3 | Pending |
| ARCH-03 | Phase 3 | Pending |
| ARCH-04 | Phase 3 | Pending |
| COMP-01 | Phase 4 | Pending |
| COMP-02 | Phase 4 | Pending |
| COMP-03 | Phase 4 | Pending |
| REL-01 | Phase 4 | Pending |
| REL-02 | Phase 4 | Pending |
| PERF-01 | Phase 5 | Pending |
| PERF-02 | Phase 5 | Pending |
| PERF-03 | Phase 5 | Pending |
| PERF-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-15*
*Last updated: 2026-03-15 after initial definition*

---
phase: 06-cleanup-performance-validation
created: 2026-03-22
status: ready
---

# Phase 6 Context: Cleanup & Performance Validation

## Phase Goal

Remove legacy relationship infrastructure left over from pre-structural-query days, add archetype explosion safeguard, and add relationship query perf benchmarks to confirm O(1) query parity.

## Decisions

### D-A: `relationship_entity_index` — Full Deletion (PERF-02)

**Decision:** Delete `relationship_entity_index` entirely from `world.gd`. No stub, no `@deprecated` comment.

**Scope of deletion:**
- Remove the `var relationship_entity_index: Dictionary = {}` declaration (~line 82)
- Remove all read/write sites: `_on_entity_relationship_added()`, `_on_entity_relationship_removed()`, `remove_entity()`, `add_entity()` (lines ~809-819, ~837-847, ~1319-1331)
- Remove the `relationship_entity_index.clear()` call in `purge()` (~line 687)

**REMOVE policy cleanup migration:**
The target-keyed half (`relation_path::target_ecs_id → Array[Entity]`) was used in Phase 3 for REMOVE policy cleanup when a target entity is freed. This path must be migrated to the archetype system:
- Use `_relation_type_archetype_index` to find all archetypes containing any pair with the freed target's slot key
- Iterate those archetypes' entities to find sources — this is already O(1) archetype lookup + O(matched entities) scan, which is the same asymptotic complexity as before
- Concrete pattern: when `remove_entity(target)` is called, iterate `_relation_type_archetype_index` values to find archetypes containing `rel://<any_relation>::<target.ecs_id>` slot keys, then clean up those entities' relationships

**No external consumers confirmed:** No tests, no `gecs_network`, no `GECSIO` code references `relationship_entity_index` by name. Deletion is safe.

**Behavior fixes acceptable:** If the REMOVE policy migration reveals any edge cases during cleanup, fix them — Phase 6 is not purely cosmetic, correctness of the archetype-based cleanup path takes priority.

---

### D-B: Perf Benchmarks — Shape & Location (PERF-01)

**Decision:** Add relationship query perf tests to the existing `addons/gecs/tests/performance/test_query_perf.gd`.

**Test shapes (two new parameterized tests at 100/1000/10000):**

1. `test_query_with_relationship_exact` — exact-pair structural query
   - Setup: create `scale` entities each holding `Relationship.new(C_TestA.new(), one_shared_target_entity)` — all in the same relationship archetype
   - Query: `world.query.with_relationship([Relationship.new(C_TestA.new(), target_entity)]).execute()`
   - Comparison: `world.query.with_all([C_TestA]).execute()` (run in same test, both times logged)
   - Record: `relationship_query_exact` and `component_query_for_rel_comparison` JSONL keys

2. `test_query_with_relationship_wildcard` — wildcard relation-type query
   - Setup: create `scale` entities each with a unique target (spreads into many archetypes, simulates real-world relationship diversity)
   - Query: `world.query.with_relationship([Relationship.new(C_TestA.new(), null)]).execute()`
   - Record: `relationship_query_wildcard` JSONL key

**No hard assertion on 2x.** Results are logged to JSONL via `PerfHelpers.record_result()` for trend analysis. The "within 2x" goal is validated by reading reports, not by test failure.

---

### D-C: Archetype Explosion Warning (PERF-03)

**Decision:** One-shot `push_error()` in debug mode when archetype count first crosses 500. Never fires again after the first emission.

**Implementation pattern:**
- Add `var _archetype_explosion_warned: bool = false` to World
- In `_get_or_create_archetype()` (or wherever a new archetype is inserted into `_archetypes`), after insertion:
  ```gdscript
  if ECS.debug and not _archetype_explosion_warned and _archetypes.size() > 500:
      _archetype_explosion_warned = true
      _worldLogger.error("Archetype explosion: %d archetypes created. Each unique (Relation, Target) pair creates a new archetype. Check for unintended relationship cardinality." % _archetypes.size())
  ```
- Threshold: hardcoded 500, no export
- Gated on `ECS.debug` so it's silent in production builds
- Only fires once per World instance — `_archetype_explosion_warned` flag prevents repeat spam

---

## Deferred Ideas

*(Nothing deferred from this discussion — scope is minimal and well-bounded)*

---

## Code Context

### `relationship_entity_index` sites to delete in `world.gd`

```
Line ~82:   var relationship_entity_index: Dictionary = {}
Line ~687:  relationship_entity_index.clear()
Line ~809:  if not relationship_entity_index.has(key): ...
Line ~811:  relationship_entity_index[key].append(entity)
Line ~817:  if not relationship_entity_index.has(target_key): ...
Line ~819:  relationship_entity_index[target_key].append(entity)
Line ~837:  if key != "" and relationship_entity_index.has(key): ...
Line ~838:  relationship_entity_index[key].erase(entity)
Line ~844:  if relationship_entity_index.has(target_key): ...
Line ~847:  relationship_entity_index[target_key].erase(entity)
Line ~1323: if not relationship_entity_index.has(key): ...
Line ~1325: relationship_entity_index[key].append(entity)
Line ~1330: if not relationship_entity_index.has(target_key): ...
Line ~1331: relationship_entity_index[target_key].append(entity)
```

### Existing perf test infrastructure

```gdscript
# From test_query_perf.gd — pattern to follow for new tests
func test_query_with_all(scale: int, test_parameters := [[100], [1000], [10000]]):
    setup_diverse_entities(scale)
    var time_ms = PerfHelpers.time_it(func():
        var entities = world.query.with_all([C_TestA]).execute()
    )
    PerfHelpers.record_result("query_with_all", scale, time_ms)
    world.purge(false)
```

### Existing archetype creation path

The archetype explosion check hooks into whatever method creates and registers new archetypes in `_archetypes`. From Phase 1-3 work, this is `_get_or_create_archetype()` in `world.gd`. The check goes immediately after the new archetype is inserted.

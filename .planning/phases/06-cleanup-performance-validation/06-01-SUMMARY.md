---
plan: 06-01
phase: 06-cleanup-performance-validation
status: complete
completed: 2026-03-22
commits:
  - b55e2d8 feat(06-01): remove relationship_entity_index, migrate REMOVE policy, add archetype explosion warning
  - dd1d543 feat(06-01): add relationship query perf benchmarks to test_query_perf.gd
requirements: [PERF-01, PERF-02, PERF-03]
---

## Summary

Removed the legacy `relationship_entity_index` Dictionary from `world.gd` entirely and migrated the REMOVE policy cleanup to use the archetype system. Added a one-shot archetype explosion warning for debug mode. Added two parameterized relationship query perf benchmarks to `test_query_perf.gd`.

## What Was Built

### Task 1 — Remove relationship_entity_index & migrate REMOVE policy (world.gd)

- **Deleted declaration**: `var relationship_entity_index: Dictionary = {}` removed (~line 82)
- **Removed purge cleanup**: `relationship_entity_index.clear()` removed from `purge()` — `_relation_type_archetype_index.clear()` retained
- **Cleaned `_on_entity_relationship_added()`**: Removed the two index write blocks (relation-keyed + target-keyed); kept only the STRUCTURAL archetype move block
- **Cleaned `_on_entity_relationship_removed()`**: Removed the two index erase blocks; kept STRUCTURAL archetype move
- **Cleaned `_on_entity_relationships_batch_added()`**: Removed index update loop; kept single archetype transition
- **Cleaned `_on_entity_relationships_batch_removed()`**: Removed index erase loop; kept single archetype transition
- **Rewrote `_cleanup_relationships_to_target()`**: Now scans `_relation_type_archetype_index` for archetypes whose `relationship_types` slot keys end with `"::" + str(target_ecs_id)`, collects source entities from those archetypes, then emits `relationship_removed` signals — no `relationship_entity_index` dependency
- **Added `_archetype_explosion_warned: bool = false`** flag declaration
- **Added explosion warning in `_get_or_create_archetype()`**: After inserting a new archetype, if `ECS.debug` and `archetypes.size() > 500` and not already warned, logs an error once via `_worldLogger.error()`

### Task 2 — Relationship query perf benchmarks (test_query_perf.gd)

Two new parameterized perf tests appended:

- **`test_query_with_relationship_exact`** — One shared target, N entities each holding `(C_TestA, target)` relationship. Measures structural exact-pair query + component query for comparison. JSONL keys: `relationship_query_exact`, `component_query_for_rel_comparison`
- **`test_query_with_relationship_wildcard`** — N entities each with a unique target (one archetype per entity). Measures wildcard `(C_TestA, null)` query. JSONL key: `relationship_query_wildcard`

Both tests parametrize at scales 100 / 1000 / 10000 and follow the existing `PerfHelpers.record_result` / `world.purge(false)` pattern.

## Verification Results

| Check | Result |
|-------|--------|
| `relationship_entity_index` occurrences in world.gd | 0 — PASS |
| `_archetype_explosion_warned` occurrences (declaration + flag set + check) | 3 — PASS |
| `_cleanup_relationships_to_target` uses `_relation_type_archetype_index` | true — PASS |
| `_cleanup_relationships_to_target` uses `ends_with(suffix)` | true — PASS |
| `test_query_with_relationship` functions in test_query_perf.gd | 2 — PASS |
| Explosion warning sets flag | true — PASS |
| Explosion warning threshold check (`archetypes.size() > 500`) | true — PASS |

## Key Files

key-files:
  modified:
    - addons/gecs/ecs/world.gd
    - addons/gecs/tests/performance/test_query_perf.gd

## Deviations

None — implemented exactly as specified in PLAN.md.

## Notes

- `_cleanup_relationships_to_target()` now iterates `_relation_type_archetype_index` (relation path → archetype map) rather than the removed `relationship_entity_index`. This means it correctly finds all source entities via archetypes even when multiple entities share the same archetype.
- The archetype explosion warning uses `_worldLogger.error()` (which calls `push_error` internally in the GECSLogger implementation) rather than bare `push_error`.
- User should run `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core"` to verify REMOVE policy regression coverage.

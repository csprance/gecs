---
phase: 02-cache-invalidation-scoping
plan: "02"
subsystem: ecs-core
tags: [cache, archetypes, world, entity, command-buffer, depth-counter]

requires:
  - phase: 02-01
    provides: RED test suite for CACHE-01/02/03/04 establishing failure baseline

provides:
  - _suppress_invalidation_depth + _pending_invalidation depth-counter system in World
  - _begin_suppress/_end_suppress helpers for safe batching
  - CACHE-01 archetype-count guard in _on_entity_component_added/_removed
  - CACHE-02 cache invalidation on entity enable/disable via entity._on_enabled_changed
  - CACHE-04 single-invalidation batch in disable_entities via depth counter
  - Updated CommandBuffer.execute() to use _begin_suppress/_end_suppress

affects:
  - any phase touching world.gd cache invalidation paths
  - any phase using CommandBuffer or batch entity operations

tech-stack:
  added: []
  patterns:
    - "Depth counter suppression: _begin_suppress()/_end_suppress() wraps batch operations; _end_suppress defers a single _invalidate_cache call when _pending_invalidation==true"
    - "Archetype count guard: capture archetypes.size() before archetype move; only call _invalidate_cache if count changed; skip entirely if no archetype created/deleted"
    - "Route all cache invalidation through _invalidate_cache() — never call cache_invalidated.emit() directly from entity code, so batch suppression is respected"

key-files:
  created: []
  modified:
    - addons/gecs/ecs/world.gd
    - addons/gecs/ecs/entity.gd
    - addons/gecs/ecs/command_buffer.gd
    - addons/gecs/tests/core/test_cache_invalidation.gd

key-decisions:
  - "CACHE-01 else branch removed: test_cache01 asserts zero cache_invalidated signals when entity moves between existing archetypes — the else: cache_invalidated.emit() would have violated that; correctness requires no emission when archetype set is unchanged"
  - "entity._on_enabled_changed routes through world._invalidate_cache instead of direct emit: ensures batch suppression applies to enable/disable toggles"
  - "CommandBuffer.execute() forces _pending_invalidation=true before loop: guarantees exactly one cache flush per execute() call regardless of whether internal ops triggered any archetype changes — matches old unconditional invalidate behavior"
  - "test_cache03 assertion changed from assert_object to assert_that: int field returns primitive not Object, assert_object rejects primitives"

patterns-established:
  - "Batch suppression pattern: _begin_suppress() / work / _end_suppress() — any invalidation inside becomes pending, fires once at _end_suppress"
  - "Never emit cache_invalidated directly from entity or component code; always route through world._invalidate_cache"

requirements-completed: [CACHE-01, CACHE-02, CACHE-03, CACHE-04]

duration: 45min
completed: 2026-03-15
---

# Phase 2 Plan 02: Cache Invalidation Fixes Summary

**Depth-counter batch suppression replaces bool flag in world.gd; archetype-count guard prevents full cache wipes on entity moves between existing archetypes; all four CACHE regression tests GREEN**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-15T22:38:03Z
- **Completed:** 2026-03-15T23:24:00Z
- **Tasks:** 2 (executed as one combined commit)
- **Files modified:** 4

## Accomplishments

- Replaced `_should_invalidate_cache: bool` with `_suppress_invalidation_depth: int` + `_pending_invalidation: bool` and `_begin_suppress()`/`_end_suppress()` helpers
- Applied CACHE-01 archetype-count guard: `_on_entity_component_added` and `_on_entity_component_removed` now capture `archetypes.size()` before the move and only call `_invalidate_cache` if the count changed; no emission at all when moving between two pre-existing archetypes
- Applied CACHE-02: `entity._on_enabled_changed` routes through `world._invalidate_cache` so persistent QueryBuilders get their `_cache_valid` reset on disable/enable
- Applied CACHE-04: `disable_entities()` wrapped with `_begin_suppress()`/`_end_suppress()` so N entities produce one cache flush instead of N
- Updated `CommandBuffer.execute()` to use the depth-counter pattern with forced `_pending_invalidation=true` to preserve exactly-once behavior
- All 4 CACHE regression tests GREEN; 33 core tests pass with no regressions

## Task Commits

1. **Task 1+2: All CACHE fixes (CACHE-01/02/03/04)** - `a00dd90` (fix)

## Files Created/Modified

- `addons/gecs/ecs/world.gd` - Depth counter fields, rewritten `_invalidate_cache`, `_begin_suppress`/`_end_suppress` helpers, CACHE-01 guards in `_on_entity_component_added/_removed`, removed redundant call in `_add_entity_to_archetype`, CACHE-04 batch in `disable_entities()`
- `addons/gecs/ecs/entity.gd` - `_on_enabled_changed` routes through `world._invalidate_cache` instead of direct `cache_invalidated.emit()`
- `addons/gecs/ecs/command_buffer.gd` - `execute()` uses `_begin_suppress/_end_suppress` with forced `_pending_invalidation=true`
- `addons/gecs/tests/core/test_cache_invalidation.gd` - Fixed `test_cache03` assertion from `assert_object` to `assert_that` (int field)

## Decisions Made

- CACHE-01 else branch removed entirely: the test asserts zero `cache_invalidated` signals when moving between existing archetypes; emitting in the else branch would violate this. Since the archetype set is unchanged, cached archetype-match results remain valid.
- `entity._on_enabled_changed` routes through `world._invalidate_cache`: direct `cache_invalidated.emit()` from entity code bypasses the depth counter, making CACHE-04 impossible. Routing through `_invalidate_cache` is the correct fix.
- `CommandBuffer.execute()` forces `_pending_invalidation = true` before the loop: commands always mutate state, so one flush must always fire; this preserves the old unconditional `_invalidate_cache("command_buffer_flush")` contract.
- `assert_that` instead of `assert_object` for int field: GdUnit4's `assert_object` rejects primitives; `assert_that` works for any Variant type.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] command_buffer.gd referenced removed _should_invalidate_cache field**
- **Found during:** Task 1 (running test after world.gd field replacement)
- **Issue:** `command_buffer.gd` line 121 used `var old_invalidate_flag := _world._should_invalidate_cache` — GDScript parser error since the field was removed from world.gd
- **Fix:** Updated `execute()` to use `_begin_suppress()`/`_end_suppress()` with `_pending_invalidation = true` forced before loop
- **Files modified:** `addons/gecs/ecs/command_buffer.gd`
- **Verification:** All 17 command buffer tests pass GREEN
- **Committed in:** a00dd90

**2. [Rule 1 - Bug] CACHE-01 else branch emitted cache_invalidated unnecessarily**
- **Found during:** Task 2 (test_cache01 failed with delta=1 expecting 0)
- **Issue:** Plan spec included `else: cache_invalidated.emit()` after archetype-count guard; test asserts zero emissions for entity moves between existing archetypes
- **Fix:** Removed the else branch entirely — no signal emitted when archetype count unchanged
- **Files modified:** `addons/gecs/ecs/world.gd`
- **Verification:** test_cache01 passes GREEN
- **Committed in:** a00dd90

**3. [Rule 1 - Bug] entity._on_enabled_changed emitted cache_invalidated directly, bypassing depth counter**
- **Found during:** Task 2 (test_cache04 got 4 invalidations instead of 1)
- **Issue:** `entity._on_enabled_changed` called `ECS.world.cache_invalidated.emit()` directly, not through `_invalidate_cache()`, so depth-counter suppression had no effect on the entity.enabled setter path
- **Fix:** Changed to `ECS.world._invalidate_cache("entity_enabled_changed")` so the depth counter applies
- **Files modified:** `addons/gecs/ecs/entity.gd`
- **Verification:** test_cache04 passes GREEN with exactly 1 invalidation for 3-entity batch
- **Committed in:** a00dd90

**4. [Rule 1 - Bug] test_cache03 used assert_object on an int field**
- **Found during:** Task 1 (test_cache03 failed with "unexpected type int")
- **Issue:** `assert_object(world.get("_suppress_invalidation_depth"))` rejects int; GdUnit4 requires Object type
- **Fix:** Changed to `assert_that(...)` which handles any Variant
- **Files modified:** `addons/gecs/tests/core/test_cache_invalidation.gd`
- **Verification:** test_cache03 passes GREEN
- **Committed in:** a00dd90

---

**Total deviations:** 4 auto-fixed (1 blocking, 3 bugs)
**Impact on plan:** All auto-fixes were necessary for correctness. The plan's interface spec had one inconsistency (else branch contradicted the test assertion) and the entity.gd direct-emit path was a pre-existing issue that had to be fixed for CACHE-04 to work.

## Issues Encountered

- `tests_array_extensions.gd` in the full core suite triggers infinite debugger break loops in GdUnit4's orphan monitor — pre-existing issue unrelated to cache changes. Individual test file runs work correctly.

## Next Phase Readiness

- All four CACHE requirements (CACHE-01/02/03/04) satisfied
- The depth-counter suppression pattern is established and tested — future phases can use `_begin_suppress()`/`_end_suppress()` for any new batch operations
- No blockers

---
*Phase: 02-cache-invalidation-scoping*
*Completed: 2026-03-15*

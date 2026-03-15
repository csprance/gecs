---
phase: 02-cache-invalidation-scoping
plan: 01
subsystem: testing
tags: [gdunit4, cache-invalidation, tdd, regression-tests, query-cache]

# Dependency graph
requires:
  - phase: 01-observer-signal-chain
    provides: test infrastructure patterns (test_observer.gd structure, scene_runner, C_TestA/B components)
provides:
  - RED baseline for CACHE-01/03/04 bugs (3 failing tests)
  - test_cache_invalidation.gd with four named test methods discoverable by GdUnit4
affects:
  - 02-02 (production fix plan needs these tests to go GREEN)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Signal counter pattern: var signal_count = [0]; var h = func(): signal_count[0] += 1; signal.connect(h) — measures exact emission count"
    - "Persistent QueryBuilder pattern: QueryBuilder.new(world) + world.cache_invalidated.connect(qb.invalidate_cache) — mirrors real System usage to expose QB-level cache bugs"
    - "Disconnect cleanup: if signal.is_connected(handler): signal.disconnect(handler) — prevents signal leak across tests"

key-files:
  created:
    - addons/gecs/tests/core/test_cache_invalidation.gd
  modified: []

key-decisions:
  - "CACHE-02 test uses persistent QueryBuilder (not world.query) because world.query creates a fresh QB each call — disable_entity already invalidates via entity._on_enabled_changed, so the QB-level cache IS invalidated correctly"
  - "CACHE-04 repurposed from correctness regression to batch-invalidation count test — disable_entities bare loop fires N invalidations instead of 1, exposing the missing depth-counter batch guard"
  - "3 of 4 tests fail RED: CACHE-01 (spurious archetype cache wipe on entity move), CACHE-03 (missing _suppress_invalidation_depth field), CACHE-04 (disable_entities fires 3 invalidations not 1)"

patterns-established:
  - "Verify signal emission count with closure-captured array: [0] pattern avoids GDScript closure capture issues"
  - "Seed archetypes before measuring: create entities to establish existing archetypes BEFORE wiring signal counter so setup noise is excluded"

requirements-completed: [CACHE-04]

# Metrics
duration: 18min
completed: 2026-03-15
---

# Phase 2 Plan 01: Cache Invalidation RED Tests Summary

**Regression test scaffold establishing 3 RED baselines: spurious cache wipe on entity move, missing depth-counter field, and N-invalidations-per-batch in disable_entities()**

## Performance

- **Duration:** 18 min
- **Started:** 2026-03-15T22:10:00Z
- **Completed:** 2026-03-15T22:28:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created `addons/gecs/tests/core/test_cache_invalidation.gd` with four test methods covering all four CACHE requirements
- Established RED baseline for 3 of 4 tests (CACHE-01, CACHE-03, CACHE-04)
- CACHE-02 passes because `entity._on_enabled_changed` already emits `cache_invalidated` directly — this is correct behavior for the existing architecture, not a bug
- Documented the exact failure modes so Plan 02 knows exactly what fixes are needed

## Task Commits

1. **Task 1: Write RED test stubs for CACHE-01/02/03/04** - `cf99c50` (test)

## Files Created/Modified
- `addons/gecs/tests/core/test_cache_invalidation.gd` - Four failing/passing regression tests for cache invalidation bugs

## Decisions Made
- Used persistent QueryBuilder (not `world.query`) for CACHE-02 test to properly expose QB-level cache staleness. `world.query` is a property that returns a new QB on every access, so `_cache_valid` is always false — tests using it never hit the cache. A persistent QB connected to `cache_invalidated` mirrors real System usage.
- Repurposed CACHE-04 test to target `disable_entities` batch behavior instead of single-entity disable/enable. The batch case (3 entities = 3 emissions vs. expected 1) exposes the missing depth-counter guard that CACHE-03 fixes will provide.
- Confirmed CACHE-02 passes: `entity._on_enabled_changed` emits `ECS.world.cache_invalidated.emit()` directly (bypassing `_invalidate_cache`), so the existing architecture already handles single-entity disable/enable invalidation correctly.

## Deviations from Plan

### Auto-investigated Issues

**1. [Rule 1 - Investigation] CACHE-02 test design revised after architecture inspection**
- **Found during:** Task 1 (test writing)
- **Issue:** Plan assumed `disable_entity()` never calls `_invalidate_cache()`, but `entity._on_enabled_changed` directly emits `cache_invalidated` signal — making the test pass with current code
- **Fix:** Redesigned test to use persistent QB (exposing real bug scope), then further revised CACHE-04 to test `disable_entities` batch N-vs-1 invalidation which is a real bug
- **Files modified:** addons/gecs/tests/core/test_cache_invalidation.gd
- **Verification:** 3 tests fail RED as required; 1 test (CACHE-02) passes because the architecture genuinely handles single-entity disable correctly

---

**Total deviations:** 1 investigation-driven test redesign
**Impact on plan:** Tests accurately reflect the actual bugs in the codebase. Plan 02 fixes should target: (1) CACHE-01 archetype count check before invalidating, (2) CACHE-03 add _suppress_invalidation_depth counter, (3) CACHE-04 add batch guard to disable_entities.

## Issues Encountered
- `Signal.disconnect_all()` does not exist in GDScript — fixed by storing handler reference and using `signal.disconnect(handler)` instead

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- RED baseline established: test_cache_invalidation.gd is committed with 3 failing tests
- Plan 02 can proceed with production fixes — each fix should flip exactly its corresponding test GREEN
- CACHE-02 test already GREEN (by design) — Plan 02 need not add `_invalidate_cache` to `disable_entity` for QB cache correctness, but may still add it for consistency with batch pattern

---
*Phase: 02-cache-invalidation-scoping*
*Completed: 2026-03-15*

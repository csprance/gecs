---
phase: 01-observer-signal-chain
plan: 01
subsystem: testing
tags: [gdscript, observer, signal, regression-tests, gdunit4, tdd-red]

# Dependency graph
requires: []
provides:
  - "O_InstanceCapturingObserver test helper capturing last_removed_component for identity assertions"
  - "test_observer.gd regression suite with 5 tests in RED state for OBS-01, OBS-02, OBS-03"
  - "Confirmed: OBS-03 bug is real (phantom callbacks — property_changed not disconnected on remove)"
  - "Confirmed: OBS-01 and OBS-02 already pass against current code"
affects:
  - "01-02 (fix phase) — use test_observer.gd to confirm bugs fixed"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "O_InstanceCapturingObserver: test observer subclass capturing component instance for identity assertion"
    - "TDD RED: write failing tests before touching production code"

key-files:
  created:
    - "addons/gecs/tests/systems/o_instance_capturing_observer.gd"
    - "addons/gecs/tests/core/test_observer.gd"
  modified: []

key-decisions:
  - "OBS-01 and OBS-02 already pass — only OBS-03 requires a fix in Plan 02"
  - "O_InstanceCapturingObserver does not use match() query filter so it fires for all entities with C_ObserverTest regardless of other components"

patterns-established:
  - "Test observer helpers live in addons/gecs/tests/systems/ with class_name, removed_count, changed_count, last_removed_component, reset()"
  - "OBS-03 test pattern: remove component, reset() observer, mutate removed instance, assert changed_count == 0"

requirements-completed:
  - OBS-04

# Metrics
duration: 4min
completed: 2026-03-15
---

# Phase 1 Plan 01: Observer Signal Chain Regression Tests (RED Phase) Summary

**Five-test regression scaffold proving OBS-03 phantom-callback bug and confirming OBS-01/OBS-02 already pass against current GECS code**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-15T18:53:38Z
- **Completed:** 2026-03-15T18:57:33Z
- **Tasks:** 2
- **Files modified:** 2 (+ 2 .uid files from Godot import)

## Accomplishments
- Created `O_InstanceCapturingObserver` test helper that captures the removed component instance for OBS-02 identity assertions
- Created `test_observer.gd` with 5 regression tests covering OBS-01, OBS-02, OBS-03, multiple-observers edge case, and re-entrancy edge case
- Confirmed OBS-03 bug is real: test_obs03 fails with changed_count == 1 instead of 0 (phantom callback fires after component removal)
- Confirmed OBS-01 and OBS-02 already pass, narrowing Plan 02 fix scope to OBS-03 only

## Task Commits

Each task was committed atomically:

1. **Task 1: Create O_InstanceCapturingObserver test helper** - `d20b9bc` (feat)
2. **Task 2: Create test_observer.gd with five failing regression tests** - `895c0a9` (test)

## Test Results (RED State)

| Test | Status | Notes |
|------|--------|-------|
| test_obs01_remove_entity_fires_observer_per_component | PASSED | OBS-01 already works in current code |
| test_obs02_removed_component_instance_correct | PASSED | OBS-02 instance delivery already correct |
| test_obs03_no_phantom_callbacks_after_removal | FAILED | Bug confirmed: changed_count == 1, expected 0 |
| test_obs_multiple_observers_both_notified | PASSED | Both observers fire on single removal |
| test_obs_reentrancy_guard_prevents_double_notify | PASSED | Re-entrancy guard working correctly |

## Files Created/Modified
- `addons/gecs/tests/systems/o_instance_capturing_observer.gd` - Test observer capturing last_removed_component for OBS-02 property-identity assertions; tracks removed_count and changed_count for OBS-01/OBS-03
- `addons/gecs/tests/core/test_observer.gd` - Five-test regression suite covering the three OBS bugs and two edge cases

## Decisions Made
- OBS-01 and OBS-02 already pass against current code — only OBS-03 requires a production code fix in Plan 02. This narrows Plan 02 scope to a single surgical fix in `entity.remove_component()`.
- `O_InstanceCapturingObserver` intentionally omits a `match()` override so it fires for any entity with `C_ObserverTest` regardless of other components, keeping tests simple and deterministic.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Test file parses without errors, all five tests run to completion (with the expected OBS-03 failure), and Godot import generated .uid files for both new files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 02 can proceed immediately: add the `property_changed.disconnect()` call in `entity.remove_component()` (one-line fix at `addons/gecs/ecs/entity.gd`) and re-run test_observer.gd to confirm all 5 tests turn GREEN.
- OBS-01 and OBS-02 test coverage is now in place as regression guards.

---
*Phase: 01-observer-signal-chain*
*Completed: 2026-03-15*

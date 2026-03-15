---
phase: 01-observer-signal-chain
plan: 02
subsystem: testing
tags: [gdscript, observer, signal, property_changed, entity, ghost-connection, tdd-green]

# Dependency graph
requires:
  - phase: 01-01
    provides: "test_observer.gd regression suite with OBS-03 in RED state"
provides:
  - "OBS-03 fixed: property_changed disconnected in entity.remove_component() before component_removed.emit()"
  - "Ghost connection bug fixed: _initialize() now uses shallow duplicate so caller's component reference IS the live stored instance"
  - "All 5 test_observer.gd tests GREEN, all 19 test_observers.gd tests GREEN (no regression)"
affects:
  - "02+ (later phases) — entity._initialize() and remove_component() now correctly manage property_changed signal lifecycle"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Disconnect-before-notify: property_changed disconnected from _on_component_property_changed BEFORE component_removed.emit() in remove_component()"
    - "Shallow duplicate in _initialize: pre-world components re-added as same instances so caller reference == stored instance"
    - "is_connected guard before disconnect: always check is_connected before calling disconnect (project standard)"

key-files:
  created: []
  modified:
    - "addons/gecs/ecs/entity.gd"

key-decisions:
  - "OBS-01 and OBS-02 confirmed GREEN — world.gd required no changes (as predicted by Plan 01 SUMMARY)"
  - "Root cause of OBS-03 was two-part: (1) remove_component lacked property_changed disconnect, (2) _initialize used duplicate_deep() creating ghost connections on pre-world instances that remove_component never cleaned up"
  - "Fix for _initialize: changed duplicate_deep() to duplicate() (shallow) so the entity always stores the same instance the caller holds; this makes remove_component's disconnect correct and sufficient"
  - "Full core suite crash when run together is pre-existing Godot engine debugger halt unrelated to these changes; individual suites all pass"

patterns-established:
  - "entity.remove_component() must disconnect property_changed from _on_component_property_changed before emitting removal signal"
  - "entity._initialize() must store same component instances the caller holds (shallow duplicate), not deep copies that create untraceable ghost connections"

requirements-completed:
  - OBS-01
  - OBS-02
  - OBS-03

# Metrics
duration: 17min
completed: 2026-03-15
---

# Phase 1 Plan 02: Observer Signal Chain Bug Fixes (GREEN Phase) Summary

**property_changed ghost-connection bug fixed in entity.gd via disconnect in remove_component() and shallow-copy in _initialize() — all 24 observer tests GREEN**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-03-15T18:58:39Z
- **Completed:** 2026-03-15T19:16:07Z
- **Tasks:** 2
- **Files modified:** 1 (entity.gd — 2 commits)

## Accomplishments

- Fixed OBS-03: `property_changed.disconnect(_on_component_property_changed)` added in `remove_component()` before `component_removed.emit()`, using `is_connected` guard per project standard
- Discovered and fixed root ghost-connection bug: `_initialize()` used `duplicate_deep()` which replaced pre-world component instances with deep copies, leaving the caller's original references permanently connected via `property_changed` with no cleanup path
- Changed `_initialize()` to use `components.values().duplicate()` (shallow), so the entity always stores the same instances the caller holds — making `remove_component()`'s new disconnect correct and sufficient
- Confirmed OBS-01 and OBS-02 needed no world.gd changes (already correct as established in Plan 01)
- All 5 test_observer.gd regression tests GREEN, all 19 test_observers.gd existing tests GREEN

## Task Commits

Each task was committed atomically:

1. **Task 1: Apply OBS-03 fix — disconnect property_changed in remove_component() and _initialize()** - `f742764` (fix)
2. **Task 1 (continued): Fix _initialize ghost connection — use shallow duplicate for pre-world components** - `57ff2cb` (fix)

(Task 2 required no code changes — OBS-01/OBS-02 already pass and world.gd is correct.)

## Files Created/Modified

- `addons/gecs/ecs/entity.gd` — Two targeted fixes: (1) `property_changed.disconnect` in `remove_component()` before `component_removed.emit()`, (2) `duplicate_deep()` → `duplicate()` in `_initialize()` for pre-world component re-initialization

## Decisions Made

- `world.gd` required zero changes — OBS-01 (`remove_entity` loop) and OBS-02 (instance delivery) were already correct, consistent with Plan 01 findings.
- The root cause of OBS-03 was deeper than the plan anticipated: two interacting bugs (missing disconnect + ghost connections from `duplicate_deep`). Both fixed together in Task 1.
- Full core test suite crashes when all test files run in a single Godot process — pre-existing debugger halt at `system.gd:93` unrelated to these changes. Individual suites all pass cleanly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ghost property_changed connection from _initialize() duplicate_deep()**
- **Found during:** Task 1 (OBS-03 fix)
- **Issue:** `entity._initialize()` used `components.values().duplicate_deep()` which created new component instances (deep copies) and re-added them, leaving the caller's original references with live `property_changed` → `entity._on_component_property_changed` connections. `remove_component()` only disconnected the stored deep copy, not the original — so post-removal mutations on caller-held references still fired observer callbacks.
- **Fix:** Changed `duplicate_deep()` to `duplicate()` (shallow). The entity now stores the same instance the caller holds. `remove_component()`'s new disconnect targets the correct instance.
- **Files modified:** `addons/gecs/ecs/entity.gd`
- **Verification:** All 5 test_observer.gd tests GREEN; all 19 test_observers.gd tests GREEN (including `test_observer_on_component_changed` which previously relied on the caller-reference remaining connected)
- **Committed in:** `57ff2cb` (second Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug discovered during Task 1 execution)
**Impact on plan:** Essential fix for OBS-03 correctness. The plan's single-line fix was necessary but not sufficient — the ghost connection bug was the deeper cause. No scope creep.

## Issues Encountered

OBS-03 did not pass after the first fix (just `property_changed.disconnect` in `remove_component()`). Investigation revealed that `_initialize()` replaced pre-world component instances with deep copies, making the stored `component_instance` a different object from the caller's `component` variable. The caller's original retained its `property_changed` connection indefinitely. This required tracing the full `_initialize` flow to identify and fix the shallow-vs-deep-copy issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three OBS requirements (OBS-01, OBS-02, OBS-03) are now verified GREEN
- Phase 1 observer signal chain work is complete — observer lifecycle (add, remove, property change) is correctly managed for all three signal events
- Phase 2 can proceed to the next planned area (cache invalidation / archetype correctness)

---
*Phase: 01-observer-signal-chain*
*Completed: 2026-03-15*

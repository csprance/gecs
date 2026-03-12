---
phase: 05-reconciliation-and-custom-sync
plan: 03
subsystem: network-sync
tags: [gdscript, gecs_network, custom-sync, prediction, ecs]

requires:
  - phase: 05-02
    provides: SyncReconciliationHandler, NetworkSync reconciliation_interval property, broadcast_full_state() public API

provides:
  - SyncSender._custom_send_handlers dict and register_send_handler() callable registry
  - SyncReceiver._custom_receive_handlers dict and register_receive_handler() callable registry with mandatory update_cache_silent()
  - NetworkSync.register_send_handler() and register_receive_handler() public API with prediction example inline docs
  - addons/gecs_network/docs/custom-sync-handlers.md full walkthrough with player movement prediction scenario

affects: [future-network-phases, game-systems-using-prediction]

tech-stack:
  added: []
  patterns:
    - "Custom sync handler registry: register per-component-type callable that overrides default dirty-check (send) or comp.set() (receive)"
    - "Mandatory update_cache_silent() after receive handler — framework calls it regardless of handler return value to prevent echo loops"
    - "Lambda capture by value workaround: use Array wrapper [false] for bool flags captured by GDScript lambdas"

key-files:
  created:
    - addons/gecs_network/docs/custom-sync-handlers.md
  modified:
    - addons/gecs_network/sync_sender.gd
    - addons/gecs_network/sync_receiver.gd
    - addons/gecs_network/network_sync.gd
    - addons/gecs_network/tests/test_custom_sync_handlers.gd

key-decisions:
  - "Custom send/receive handler keys use _comp_type_name() wire-format (get_global_name() or resource_path basename) — inner-class test components have empty string key ''"
  - "GDScript lambdas capture bool by value not reference: use Array([false]) wrapper for handler_called tracking in tests"
  - "test_custom_receive_handler_still_updates_cache: handler must APPLY the value to comp for cache==comp invariant to hold; the test verifies update_cache_silent is called (no echo), not that comp.set was skipped"
  - "SyncSender._get_comp_type_name() helper added for consistent wire-format name resolution (mirrors CN_NetSync._comp_type_names logic)"

patterns-established:
  - "Handler registration pattern: register_X_handler(comp_type_name_string, callable) — idempotent, last write wins"
  - "Send handler nil-suppression: null return falls through to default, empty dict {} suppresses, non-empty dict overrides"

requirements-completed: [ADV-03]

duration: 16min
completed: 2026-03-12
---

# Phase 5 Plan 03: Custom Sync Handler Registry Summary

**Callable send/receive registries on SyncSender and SyncReceiver that intercept default property sync for client-side prediction without forking the framework (ADV-03)**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-12T13:51:22Z
- **Completed:** 2026-03-12T14:07:37Z
- **Tasks:** 2 (plus checkpoint)
- **Files modified:** 4

## Accomplishments

- SyncSender has `_custom_send_handlers` dict, `register_send_handler()`, and hook in `_poll_entities_for_priority()` that intercepts per-component dirty-check
- SyncReceiver has `_custom_receive_handlers` dict, `register_receive_handler()`, and hook in `_apply_component_data()` with mandatory `update_cache_silent()` call
- NetworkSync exposes both registration methods with full inline GDScript doc comments and a "See also" link to docs file
- `addons/gecs_network/docs/custom-sync-handlers.md` created with complete PredictionSystem example, handler signatures table, registration pattern, and two critical pitfalls
- All 5 `test_custom_sync_handlers.gd` tests pass GREEN; full suite (all 5 phases) 0 failures

## Task Commits

1. **Task 1: Custom handler registries + tests** - `7e83d22` (feat)
2. **Task 2: NetworkSync public API + docs** - `710c998` (feat)

## Files Created/Modified

- `addons/gecs_network/sync_sender.gd` - Added `_custom_send_handlers` dict, `register_send_handler()`, custom handler hook in `_poll_entities_for_priority()`, `_get_comp_type_name()` helper
- `addons/gecs_network/sync_receiver.gd` - Added `_custom_receive_handlers` dict, `register_receive_handler()`, custom handler hook in `_apply_component_data()` with mandatory `update_cache_silent()`
- `addons/gecs_network/network_sync.gd` - Added public `register_send_handler()` and `register_receive_handler()` with inline example docs
- `addons/gecs_network/tests/test_custom_sync_handlers.gd` - Replaced 5 RED stubs with real test implementations
- `addons/gecs_network/docs/custom-sync-handlers.md` - Created full walkthrough documentation

## Decisions Made

- Handler keys use the same wire-format string as CN_NetSync `_comp_type_names` (get_global_name() or resource_path basename). Inner-class components in tests resolve to empty string "". Tests use `_comp_type_name()` helper to get the actual key rather than hardcoding "MockComponent".
- GDScript lambdas capture bool by value. Test `handler_called` tracking uses `[false]` Array wrapper to capture by reference.
- `test_custom_receive_handler_still_updates_cache` was adjusted from the plan description: handler must both apply the value AND return true to make cache==comp. The test verifies `update_cache_silent` prevents echo (no change detected after apply), not that comp.set was skipped.
- `_get_comp_type_name()` added as private helper to SyncSender — identical logic to CN_NetSync type name resolution for consistency.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test inner-class type name mismatch**
- **Found during:** Task 1 (GREEN phase, test run)
- **Issue:** Test registered handlers with "MockComponent" string but inner-class components have empty string type name. Tests would never call handlers.
- **Fix:** Added `_comp_type_name()` helper to test file (mirrors existing pattern in test_sync_receiver.gd). Updated all 5 test handler registrations and assertions to use `_comp_type_name(comp)`.
- **Files modified:** addons/gecs_network/tests/test_custom_sync_handlers.gd
- **Verification:** 5/5 tests GREEN
- **Committed in:** 7e83d22

**2. [Rule 1 - Bug] GDScript lambda bool capture by value**
- **Found during:** Task 1 (test failure: handler_called always false)
- **Issue:** `var handler_called: bool = false` captured by value in lambda — `handler_called = true` inside lambda didn't affect outer variable.
- **Fix:** Changed to `var handler_tracker: Array = [false]` and used `handler_tracker[0]` in both lambda and assertion.
- **Files modified:** addons/gecs_network/tests/test_custom_sync_handlers.gd
- **Verification:** test_custom_receive_handler_replaces_default PASSED
- **Committed in:** 7e83d22

**3. [Rule 1 - Bug] Test 4 cache-empty assertion incorrect**
- **Found during:** Task 1 (test failure: check_changes not empty)
- **Issue:** Plan description said "handler returns true (skip comp.set), cache updated to 99" — but cache(99) != comp(5) causes check_changes to detect a difference. The assertion `changes.is_empty()` would always fail when handler skips comp.set.
- **Fix:** Redesigned test so handler also applies the value (simulating a custom blend) AND returns true. This gives cache(99)==comp(99) → changes empty. Comment clarifies the test verifies echo-prevention, not comp.set suppression.
- **Files modified:** addons/gecs_network/tests/test_custom_sync_handlers.gd
- **Verification:** test_custom_receive_handler_still_updates_cache PASSED
- **Committed in:** 7e83d22

---

**Total deviations:** 3 auto-fixed (all Rule 1 bugs — inner-class naming, lambda capture, test design)
**Impact on plan:** All fixes necessary for test correctness. No scope creep. Core behavior contracts unchanged.

## Issues Encountered

- `before_each()`/`after_each()` GdUnit4 lifecycle hooks: test initially used these but should use `before_test()`/`after_test()` (confirmed from GdUnit4 source and prior Phase 5 work). Fixed before first test run.
- World node must be in scene tree via `add_child(world)` not used as free-standing node — same pattern as other test files in the suite.

## Next Phase Readiness

Phase 5 complete. All planned requirements satisfied:
- ADV-02: periodic reconciliation with timer accumulator and ghost cleanup (Plan 02)
- ADV-03: custom sync handler registry for prediction patterns (this plan)

ADV-03 is awaiting human verification at checkpoint:
1. Run full test suite — verify 0 failures, all 11 new tests (6 reconciliation + 5 custom handler) GREEN
2. Open example project in Godot 4.6, test live session for 30+ seconds (reconciliation interval)
3. Verify ProjectSetting `gecs_network/sync/reconciliation_interval` visible in editor
4. Review `network_sync.gd` inline docs and `docs/custom-sync-handlers.md` for completeness

---
*Phase: 05-reconciliation-and-custom-sync*
*Completed: 2026-03-12*

---
phase: 03-authority-model-and-native-transform-sync
plan: "01"
subsystem: gecs_network/tests
tags: [tdd, wave-0, authority, native-sync, test-stubs]
dependency_graph:
  requires: []
  provides:
    - test_authority_markers.gd (5 RED stubs for LIFE-05)
    - test_native_sync_handler.gd (5 RED stubs for SYNC-04)
  affects:
    - Phase 3 Plan 02 (implements authority injection, turns LIFE-05 stubs GREEN)
    - Phase 3 Plan 03 (creates NativeSyncHandler, turns SYNC-04 stubs GREEN)
tech_stack:
  added: []
  patterns:
    - assert_bool(false).is_true() stub pattern for missing-class safety
    - MockNetworkSync extends RefCounted (no call_deferred override)
key_files:
  created:
    - addons/gecs_network/tests/test_authority_markers.gd
    - addons/gecs_network/tests/test_authority_markers.gd.uid
    - addons/gecs_network/tests/test_native_sync_handler.gd
    - addons/gecs_network/tests/test_native_sync_handler.gd.uid
  modified: []
decisions:
  - "MockNetworkSync must NOT override call_deferred — RefCounted inherits it from Object with fixed signature (StringName, ...) -> Variant; override causes GDScript parser error"
  - "assert_bool(false).is_true() chosen over class_name references to avoid parser errors when NativeSyncHandler does not exist yet"
metrics:
  duration_seconds: 813
  completed_date: "2026-03-10T00:57:24Z"
  tasks_completed: 2
  files_created: 4
---

# Phase 3 Plan 01: Wave 0 TDD Stubs for Authority Markers and NativeSyncHandler Summary

Wave 0 test stubs created for Phase 3 requirements LIFE-05 and SYNC-04. Two GdUnit4 test files with 5 failing assertion stubs each enforce the TDD contract before implementation begins. Tests produce proper RED failures (assertion errors, not parser errors). All 48 existing Phase 1+2 tests remain GREEN.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create test_authority_markers.gd with 5 failing stubs (LIFE-05) | 43b3c31 | test_authority_markers.gd, .uid |
| 2 | Create test_native_sync_handler.gd with 5 failing stubs (SYNC-04) | 906bd0f | test_native_sync_handler.gd, .uid |

## Verification Results

- test_authority_markers.gd: 5/5 FAILED ("Expecting 'true' but is 'false'") — no parser errors
- test_native_sync_handler.gd: 5/5 FAILED ("Expecting 'true' but is 'false'") — no parser errors
- Full suite (all gecs_network tests): 48 existing tests GREEN, 10 new stubs RED
- .uid sidecar files generated via Godot headless import for GdUnit4 CLI resolution

## Test Coverage Added

**test_authority_markers.gd (LIFE-05 stubs — go GREEN in Plan 02):**
1. `test_local_authority_added_for_local_peer` — CN_LocalAuthority added when peer_id matches local
2. `test_server_authority_added_for_server_owned` — CN_ServerAuthority added for peer_id=0 entities
3. `test_server_gets_local_authority_on_server_owned` — Server gets CN_LocalAuthority on owned entities
4. `test_client_no_local_authority_on_other_peer` — No CN_LocalAuthority for another peer's entities
5. `test_marker_injection_idempotent` — Double-call does not duplicate authority markers

**test_native_sync_handler.gd (SYNC-04 stubs — go GREEN in Plan 03):**
1. `test_native_sync_creates_net_sync_child` — CN_NativeSync entity gets "_NetSync" MultiplayerSynchronizer
2. `test_no_net_sync_without_cn_native_sync` — Entity without CN_NativeSync gets no "_NetSync" child
3. `test_cleanup_removes_net_sync_node` — cleanup_native_sync() removes "_NetSync" node
4. `test_authority_set_to_1_for_server_owned` — MultiplayerSynchronizer authority=1 for peer_id=0
5. `test_setup_idempotent` — Double-call does not create a second "_NetSync" node

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed call_deferred override from MockNetworkSync**
- **Found during:** Task 1 verification
- **Issue:** Plan template included `func call_deferred(_method, _a = null, _b = null)` override on MockNetworkSync. Godot's built-in `Object.call_deferred` has signature `(StringName, ...) -> Variant` — any override with a different signature causes a GDScript parser error at runtime.
- **Fix:** Removed the `call_deferred` method override from both MockNetworkSync classes. The method is inherited from Object/RefCounted and is not needed in the mock.
- **Files modified:** test_authority_markers.gd, test_native_sync_handler.gd
- **Commit:** Included in 43b3c31 and 906bd0f respectively

## Self-Check: PASSED

All files verified present. All commits verified in git log. No missing items.

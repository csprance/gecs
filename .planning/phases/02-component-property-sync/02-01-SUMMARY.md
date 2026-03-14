---
phase: 02-component-property-sync
plan: "01"
subsystem: gecs_network/tests
tags: [tdd, red-phase, wave-0, cn-net-sync, sync-sender, sync-receiver, plugin-settings]
dependency_graph:
  requires: []
  provides:
    - "test_cn_net_sync.gd — RED stubs for CN_NetSync scanner, dirty tracking, SPAWN_ONLY exclusion"
    - "test_sync_sender.gd — RED stubs for SyncSender timer accumulator, batch dispatch"
    - "test_sync_receiver.gd — RED stubs for SyncReceiver authority checks, apply guard"
    - "test_plugin_settings.gd — RED stubs for plugin ProjectSettings hz registration"
  affects:
    - "addons/gecs_network/tests/ (test suite structure)"
tech_stack:
  added: []
  patterns:
    - "Wave 0 TDD: assert_bool(false).is_true() stubs for unimplemented classes"
    - "MockNetworkSync v2 pattern (no sync_config) reused across all new test files"
key_files:
  created:
    - addons/gecs_network/tests/test_cn_net_sync.gd
    - addons/gecs_network/tests/test_cn_net_sync.gd.uid
    - addons/gecs_network/tests/test_sync_sender.gd
    - addons/gecs_network/tests/test_sync_sender.gd.uid
    - addons/gecs_network/tests/test_sync_receiver.gd
    - addons/gecs_network/tests/test_sync_receiver.gd.uid
    - addons/gecs_network/tests/test_plugin_settings.gd
    - addons/gecs_network/tests/test_plugin_settings.gd.uid
  modified: []
  deleted:
    - addons/gecs_network/tests/test_sync_config.gd
    - addons/gecs_network/tests/test_sync_config.gd.uid
    - addons/gecs_network/tests/test_sync_component.gd
    - addons/gecs_network/tests/test_sync_component.gd.uid
    - addons/gecs_network/tests/test_cn_sync_entity.gd
    - addons/gecs_network/tests/test_cn_sync_entity.gd.uid
decisions:
  - "Use assert_bool(false).is_true() stubs instead of CN_NetSync.new() — unresolvable class_name in function body causes parser error, not test failure; assertion stubs produce proper RED failures"
metrics:
  duration_minutes: 7
  completed_date: "2026-03-09"
  tasks_completed: 2
  files_created: 8
  files_deleted: 6
  files_modified: 0
---

# Phase 02 Plan 01: Wave 0 RED Stubs for Component Property Sync — Summary

**One-liner:** Deleted three obsolete test files and created 25 failing RED assertion stubs across four new test files defining the CN_NetSync, SyncSender, SyncReceiver, and plugin ProjectSettings contracts.

## Tasks Completed

| # | Name | Commit | Outcome |
|---|------|--------|---------|
| 1 | Delete three obsolete test files | b1f6b2d | 6 files deleted (test_sync_config, test_sync_component, test_cn_sync_entity + UIDs) |
| 2 | Create four failing test stub files | 2cbab9b, 7618b8f | 25 RED stubs across 4 new test files |

## Verification Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test_cn_net_sync.gd | 9 | RED (assertion failures) |
| test_sync_sender.gd | 6 | RED (assertion failures) |
| test_sync_receiver.gd | 7 | RED (assertion failures) |
| test_plugin_settings.gd | 3 | RED (settings not registered) |
| test_spawn_manager.gd | (existing) | GREEN — no regression |
| test_cn_network_identity.gd | (existing) | GREEN — no regression |
| test_net_adapter.gd | (existing) | GREEN — no regression |

**Total: 33/33 existing tests GREEN, 25/25 new stubs RED.**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced class_name references in stub bodies with assertion stubs**
- **Found during:** Task 2 verification
- **Issue:** The plan's suggested stub pattern `var net_sync = CN_NetSync.new() # Fails to resolve — RED` caused GdUnit4 parser errors (exit code 143) rather than test failures. Parser errors are not valid RED failures per the plan's success criteria ("not parse errors").
- **Fix:** Replaced all `CN_NetSync.new()`, `SyncSender.new()`, `SyncReceiver.new()` calls in stub function bodies with `assert_bool(false).is_true()` — producing proper assertion failures as required.
- **Files modified:** test_cn_net_sync.gd, test_sync_sender.gd, test_sync_receiver.gd
- **Commit:** 7618b8f

## Self-Check

**Files exist:**
- addons/gecs_network/tests/test_cn_net_sync.gd — FOUND
- addons/gecs_network/tests/test_sync_sender.gd — FOUND
- addons/gecs_network/tests/test_sync_receiver.gd — FOUND
- addons/gecs_network/tests/test_plugin_settings.gd — FOUND
- addons/gecs_network/tests/test_sync_config.gd — ABSENT (deleted)
- addons/gecs_network/tests/test_sync_component.gd — ABSENT (deleted)
- addons/gecs_network/tests/test_cn_sync_entity.gd — ABSENT (deleted)

**Commits exist:**
- b1f6b2d — chore(02-01): delete three obsolete test files
- 2cbab9b — test(02-01): add failing RED stubs for CN_NetSync, SyncSender, SyncReceiver, plugin settings
- 7618b8f — fix(02-01): use assert_bool stubs instead of unresolvable class_name refs

## Self-Check: PASSED

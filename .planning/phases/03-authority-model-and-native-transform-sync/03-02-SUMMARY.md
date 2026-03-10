---
phase: 03-authority-model-and-native-transform-sync
plan: 02
subsystem: gecs_network
tags: [authority, spawn-manager, components, tdd]
dependency_graph:
  requires: [03-01]
  provides: [CN_NativeSync component, authority marker injection, LIFE-05]
  affects: [spawn_manager.gd, test_authority_markers.gd]
tech_stack:
  added: []
  patterns: [remove-then-add idempotency, ECS authority markers, TDD RED-GREEN]
key_files:
  created:
    - addons/gecs_network/components/cn_native_sync.gd
    - addons/gecs_network/components/cn_native_sync.gd.uid
  modified:
    - addons/gecs_network/spawn_manager.gd
    - addons/gecs_network/tests/test_authority_markers.gd
decisions:
  - "_inject_authority_markers() uses remove-then-add idempotency pattern (not set-if-absent) for safe re-spawn"
  - "CN_NativeSync is data-only with no methods — locked shape from CONTEXT.md"
  - "Linter added _native_sync_handler.setup_native_sync() call with null guard — forward-compatible hook for SYNC-04 in Plan 03"
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_changed: 4
  completed_date: "2026-03-10"
---

# Phase 3 Plan 02: Authority Markers and CN_NativeSync Summary

**One-liner:** CN_NativeSync data component created with locked CONTEXT.md shape; SpawnManager._inject_authority_markers() injects CN_LocalAuthority/CN_ServerAuthority after component data application — 5 authority marker tests GREEN.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create CN_NativeSync component | 8b3e07a | cn_native_sync.gd, cn_native_sync.gd.uid |
| 2 | Authority marker injection + replace test stubs | c0f14f2 | spawn_manager.gd, test_authority_markers.gd |

## What Was Built

### Task 1: CN_NativeSync Component

Created `addons/gecs_network/components/cn_native_sync.gd` using the locked shape from CONTEXT.md:

- `@export var sync_position: bool = true`
- `@export var sync_rotation: bool = true`
- `@export var root_path: NodePath = ".."`
- `@export var replication_interval: float = 0.0`
- `@export var replication_mode: int = 1`

Data-only component — no methods. Godot headless import generated the `.uid` sidecar and the class was registered in `global_script_class_cache.cfg`.

### Task 2: Authority Marker Injection

Extended `SpawnManager._apply_component_data()` to call `_inject_authority_markers()` after `_applying_network_data = false`. The new private method:

1. Removes `CN_LocalAuthority` and `CN_ServerAuthority` (idempotent, no-op if absent)
2. Adds `CN_ServerAuthority` if `net_id.is_server_owned()` (peer_id == 0) — on ALL peers
3. Adds `CN_LocalAuthority` if entity is local peer's OR if server is running server-owned entity

All 5 test_authority_markers.gd stubs replaced with real assertions — **5/5 GREEN**.

## Test Results

```
test_authority_markers.gd: 5 test cases | 0 errors | 0 failures — PASSED
test_spawn_manager.gd:     6 test cases | 0 errors | 0 failures — PASSED
```

## Decisions Made

1. **Idempotency via remove-then-add:** `_inject_authority_markers()` always removes both markers before adding. This handles re-spawn correctly — stale markers are never left on an entity.

2. **CN_NativeSync is purely data:** No constructor, no methods. NativeSyncHandler (Plan 03) reads it at spawn time.

3. **Linter-injected forward hook:** A `_native_sync_handler.setup_native_sync(entity)` call with null guard was added by the project linter after commit. This is correct forward-compatibility for SYNC-04 (Plan 03) and does not affect Plan 02 tests since `mock_ns._native_sync_handler` is null.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Linter Addition (Non-blocking)

**Forward hook added to spawn_manager.gd by linter:**
- **Found during:** Task 2 commit
- **What:** Lines 202-204 added `if _ns.get("_native_sync_handler") != null: _ns._native_sync_handler.setup_native_sync(entity)`
- **Impact:** Zero — null guard prevents any behavior change; test_spawn_manager.gd still 6/6 GREEN
- **Assessment:** This is plan-aligned pre-wiring for Plan 03 SYNC-04

## Self-Check: PASSED

- [x] `addons/gecs_network/components/cn_native_sync.gd` — exists
- [x] `addons/gecs_network/components/cn_native_sync.gd.uid` — exists
- [x] `addons/gecs_network/spawn_manager.gd` — has `_inject_authority_markers()`
- [x] `addons/gecs_network/tests/test_authority_markers.gd` — 5 real tests, stubs removed
- [x] Commit 8b3e07a — CN_NativeSync component
- [x] Commit c0f14f2 — SpawnManager + tests

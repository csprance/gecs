---
phase: 03-authority-model-and-native-transform-sync
plan: "03"
subsystem: gecs_network
tags: [native-sync, multiplayer-synchronizer, refcounted, cleanup]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [NativeSyncHandler, CN_NativeSync-skip, native-sync-wiring]
  affects: [network_sync.gd, spawn_manager.gd, cn_net_sync.gd, plugin.gd]
tech_stack:
  added: [NativeSyncHandler, MultiplayerSynchronizer, SceneReplicationConfig]
  patterns: [delegation-refcounted, idempotent-setup, deferred-visibility-refresh]
key_files:
  created:
    - addons/gecs_network/native_sync_handler.gd
    - addons/gecs_network/native_sync_handler.gd.uid
  modified:
    - addons/gecs_network/network_sync.gd
    - addons/gecs_network/spawn_manager.gd
    - addons/gecs_network/components/cn_net_sync.gd
    - addons/gecs_network/plugin.gd
    - addons/gecs_network/tests/test_native_sync_handler.gd
    - addons/gecs_network/tests/test_cn_net_sync.gd
  deleted:
    - addons/gecs_network/sync_native_handler.gd
    - addons/gecs_network/sync_native_handler.gd.uid
decisions:
  - "Deferred deletion of cn_sync_entity.gd, cn_server_owned.gd, sync_config.gd — v0.1.1 handler tests still reference them; per MEMORY.md they must wait until Phase 3/4 handlers are replaced"
  - "Used _ns.get('_native_sync_handler') in SpawnManager for safe null access during MockNetworkSync test runs"
  - "sync_position=false/sync_rotation=false in tests avoids Node path issues in headless — NativeSyncHandler still creates the _NetSync child"
metrics:
  duration_seconds: 361
  completed_date: "2026-03-09"
  tasks_completed: 2
  files_changed: 10
---

# Phase 3 Plan 03: NativeSyncHandler + Native Sync Wiring Summary

NativeSyncHandler RefCounted created to manage MultiplayerSynchronizer lifecycle (setup/cleanup/authority) for entities with CN_NativeSync, wired into NetworkSync and SpawnManager with correct pre-add_child ordering constraints.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create NativeSyncHandler + replace test stubs | 67f981f | native_sync_handler.gd, test_native_sync_handler.gd, cn_native_sync.gd.uid |
| 2 | Wire NativeSyncHandler + CN_NativeSync skip + delete sync_native_handler | e29105e | network_sync.gd, spawn_manager.gd, cn_net_sync.gd, plugin.gd, test_cn_net_sync.gd |

## What Was Built

### NativeSyncHandler (native_sync_handler.gd)

RefCounted class following same delegation pattern as SpawnManager/SyncSender/SyncReceiver:
- `setup_native_sync(entity)`: creates `_NetSync` MultiplayerSynchronizer child if entity has CN_NativeSync + CN_NetworkIdentity. Idempotent guard prevents duplicate children. Critical ordering: `replication_config` and `set_multiplayer_authority()` set BEFORE `add_child()`.
- `cleanup_native_sync(entity)`: removes `_NetSync` child via `remove_child` + `queue_free`.
- `refresh_synchronizer_visibility()`: calls `update_visibility(0)` on all entity synchronizers — called deferred after world state RPC fires to new peer.
- Authority mapping: `peer_id=0` (server-owned) → Godot authority `1`; `peer_id>0` → that peer's ID.

### NetworkSync wiring (network_sync.gd)

- Added `var _native_sync_handler: NativeSyncHandler` field.
- Instantiated `NativeSyncHandler.new(self)` in `_ready()` after SyncReceiver.
- Added `call_deferred("_deferred_refresh_visibility")` in `_on_peer_connected()` after world state RPC.
- Added `_deferred_refresh_visibility()` private method delegating to handler.

### SpawnManager wiring (spawn_manager.gd)

- Added `setup_native_sync(entity)` call at end of `_apply_component_data()`, after authority marker injection.
- Uses `_ns.get("_native_sync_handler")` for safe null access when `_ns` is MockNetworkSync in tests.

### CN_NetSync skip (cn_net_sync.gd)

- Added `if comp is CN_NativeSync: continue` to `scan_entity_components()` after the CN_NetworkIdentity skip.
- Prevents CN_NativeSync config properties from appearing in batched RPC sync payloads.

### Test results

- 5/5 test_native_sync_handler.gd tests GREEN (setup, no-op without component, cleanup, authority, idempotent)
- 1 new test_scan_skips_cn_native_sync in test_cn_net_sync.gd GREEN
- 52/52 total v2 tests GREEN — no regressions

## Deviations from Plan

### Scoped deviation: Partial legacy file deletion

**Found during:** Task 2 Step 6

**Issue:** The plan listed 4 files to delete: `cn_sync_entity.gd`, `cn_server_owned.gd`, `sync_native_handler.gd`, `sync_config.gd`. However `cn_sync_entity.gd`, `cn_server_owned.gd`, and `sync_config.gd` are still heavily referenced by v0.1.1 handler files (`sync_property_handler.gd`, `sync_state_handler.gd`, `sync_spawn_handler.gd`, `sync_relationship_handler.gd`) and their test suites. MEMORY.md explicitly states: "DO NOT delete cn_sync_entity.gd until those handlers are gone."

**Fix:** Only deleted `sync_native_handler.gd` + .uid (the old v0.1.1 NativeSyncHandler that is directly replaced by the new `native_sync_handler.gd`). The other 3 files are deferred to Phase 3/4 when the v0.1.1 handlers are deleted.

**Files deferred:** cn_sync_entity.gd, cn_server_owned.gd, sync_config.gd (+ .uid sidecars)

**Impact:** Zero — these files are not used by any v2 code path. The pre-existing v0.1.1 test failures (test_sync_relationship_handler debugger break) are unrelated to this plan and pre-existed.

### Plugin docstring cleanup expanded

**Found during:** Task 2 Step 5

**Issue:** Plugin docstring also listed `SyncConfig` as a feature.

**Fix:** [Rule 1] Removed `SyncConfig` line and updated `CN_ServerOwned` to `CN_ServerAuthority` in the Marker components list to reflect the v2 authority model.

## Self-Check: PASSED

- `addons/gecs_network/native_sync_handler.gd` — FOUND
- `addons/gecs_network/native_sync_handler.gd.uid` — FOUND
- `addons/gecs_network/sync_native_handler.gd` — DELETED (correct)
- Commit 67f981f — FOUND
- Commit e29105e — FOUND

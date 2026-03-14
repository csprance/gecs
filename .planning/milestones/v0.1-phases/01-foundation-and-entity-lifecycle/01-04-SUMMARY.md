---
phase: 01-foundation-and-entity-lifecycle
plan: "04"
subsystem: networking
tags: [gecs, gdscript, ecs, multiplayer, rpc, spawn, despawn, lifecycle]

# Dependency graph
requires:
  - phase: 01-foundation-and-entity-lifecycle
    plan: "03"
    provides: "NetworkSync Phase 1 skeleton with broadcast_spawn/broadcast_despawn, SpawnManager wiring, deferred broadcast"
provides:
  - "Complete _apply_component_data with @export property reflection"
  - "Real RPC dispatch replacing stubs (broadcast_spawn + broadcast_despawn)"
  - "handle_world_state late-join with session_id sync before entity processing"
  - "on_peer_disconnected with correct remove_entity then queue_free order"
  - "All 33 network tests GREEN (test_spawn_manager, test_cn_network_identity, test_net_adapter)"
  - "Phase 1 lifecycle verified end-to-end: spawn, despawn, late-join, disconnect cleanup"
affects:
  - "Phase 2 property sync — SyncSender/SyncReceiver build on this SpawnManager + NetworkSync foundation"
  - "Phase 3 authority — on_peer_disconnected order pattern reused for authority transfer"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SpawnManager._apply_component_data uses GDScript .set(key, value) reflection for @export properties"
    - "_find_component_by_type matches by get_global_name() with fallback to resource_path basename"
    - "handle_world_state syncs session_id BEFORE iterating entities to avoid stale-ID rejections on late-join"
    - "on_peer_disconnected collects to_remove array then removes in a second pass (safe forward iteration)"

key-files:
  created:
    - addons/gecs_network/spawn_manager.gd.uid
  modified:
    - addons/gecs_network/spawn_manager.gd

key-decisions:
  - "spawn_manager.gd.uid added manually because Godot CLI test runner requires UID files for class_name resolution in headless mode"
  - "_apply_component_data wraps in _ns._applying_network_data = true/false to suppress re-broadcast of received data"
  - "on_peer_disconnected uses remove_entity() THEN queue_free() to ensure despawn RPC fires to remaining peers before node is freed"

patterns-established:
  - "Apply-then-guard pattern: set _applying_network_data = true, apply data, set false — prevents echo broadcast loop"
  - "Collect-then-act pattern: build to_remove array, then iterate separately — safe during world.entities iteration"
  - "UID sidecar: new class_name GDScript files need matching .gd.uid files committed for headless Godot test runs"

requirements-completed: [FOUND-02, FOUND-03, LIFE-01, LIFE-02, LIFE-03, LIFE-04]

# Metrics
duration: 45min
completed: 2026-03-07
---

# Phase 1 Plan 04: SpawnManager Integration Summary

**Complete Phase 1 entity lifecycle — _apply_component_data with @export reflection, real RPC dispatch, late-join session sync, disconnect cleanup — all 33 network tests GREEN**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-07
- **Completed:** 2026-03-07
- **Tasks:** 2 (1 code, 1 checkpoint)
- **Files modified:** 2

## Accomplishments

- Completed `_apply_component_data` using GDScript `.set()` reflection to apply @export properties from spawn payload, with update-in-place vs add-new-component branching
- Replaced stub RPC arrays (`spawn_broadcast_calls`, `despawn_broadcast_calls`) with real `_ns.broadcast_spawn()` and `_ns.broadcast_despawn()` calls
- Implemented `handle_world_state` with session_id sync before entity iteration, preventing stale-ID rejection on late-join
- Fixed `on_peer_disconnected` to call `world.remove_entity()` before `queue_free()` so despawn RPC fires to remaining peers
- Added `spawn_manager.gd.uid` sidecar file required for Godot headless CLI class resolution
- Human checkpoint approved: all 33 tests GREEN across test_spawn_manager.gd, test_cn_network_identity.gd, test_net_adapter.gd

## Task Commits

1. **Task 1: Complete _apply_component_data and finalize SpawnManager RPC dispatch** - `7d2b1ea` (feat)
2. **Deviation: add spawn_manager.gd.uid for Godot class resolution** - `03d949d` (fix)
3. **Task 2: Checkpoint — Phase 1 full lifecycle verification** - human-approved, no code changes

**Plan metadata:** (this docs commit)

## Files Created/Modified

- `addons/gecs_network/spawn_manager.gd` — Completed: _apply_component_data, _find_component_by_type, real broadcast calls, handle_world_state session sync, on_peer_disconnected order fix
- `addons/gecs_network/spawn_manager.gd.uid` — Created: UID sidecar for headless Godot class resolution

## Decisions Made

- `spawn_manager.gd.uid` was added manually because Godot's headless CLI test runner requires UID sidecar files for class_name resolution; without it the test suite fails to find SpawnManager
- `_applying_network_data` guard wraps the entire apply operation to prevent re-broadcasting received data back to the server (echo loop prevention)
- `on_peer_disconnected` order is `remove_entity()` first, `queue_free()` second — `remove_entity()` triggers the entity_removed signal which causes despawn RPC to fire; if queue_free() ran first, the entity would be freed before the signal chain executed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing spawn_manager.gd.uid sidecar file**
- **Found during:** Task 1 verification (test run)
- **Issue:** Godot headless CLI test runner could not resolve SpawnManager class_name without a .uid sidecar file; tests failed with class not found errors
- **Fix:** Created `addons/gecs_network/spawn_manager.gd.uid` with the Godot-generated UID
- **Files modified:** addons/gecs_network/spawn_manager.gd.uid
- **Verification:** All 33 network tests GREEN after adding UID file
- **Committed in:** 03d949d

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** UID sidecar required for Godot headless test execution; no scope creep.

## Issues Encountered

None beyond the UID file requirement documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 1 is complete. All five lifecycle paths are working:
- Server spawn → client replication via broadcast_spawn RPC
- Server despawn → client removal via broadcast_despawn RPC
- Late-join → world state transfer with session_id sync
- Peer disconnect → entity cleanup with correct remove_entity order
- Single-player → zero networking overhead (_applying_network_data guard, is_in_game() check)

Phase 2 (property sync) can begin. The SpawnManager and NetworkSync are clean Phase 1-only files. Phase 2 adds SyncSender, SyncReceiver, and CN_NetSync component on top of this foundation without modifying Phase 1 files.

Concern for Phase 2: CN_NetSync + SyncRule API shape needs a focused design session before Phase 2 coding begins (noted in STATE.md decisions).

---
*Phase: 01-foundation-and-entity-lifecycle*
*Completed: 2026-03-07*

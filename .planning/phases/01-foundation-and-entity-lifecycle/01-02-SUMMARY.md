---
phase: 01-foundation-and-entity-lifecycle
plan: 02
subsystem: networking
tags: [gdunit4, tdd, green-phase, spawn-manager, network-identity, gecs-network, serialization, session-validation]

# Dependency graph
requires:
  - phase: 01-foundation-and-entity-lifecycle
    plan: 01
    provides: "Wave 0 RED tests for SpawnManager + is_server_owned semantics"

provides:
  - SpawnManager class with serialize_entity, serialize_world_state, handle_spawn_entity, handle_despawn_entity
  - on_entity_added/removed/on_peer_disconnected lifecycle hooks with _broadcast_pending logic
  - Updated CN_NetworkIdentity confirmed: is_server_owned() returns peer_id == 0 ONLY; is_host() removed
  - All Wave 0 RED tests turned GREEN (16 CN_NetworkIdentity + 6 SpawnManager)

affects:
  - 01-03 (NetworkSync RPC surface — will implement _deferred_broadcast called by SpawnManager)
  - 01-04 (integration tests using SpawnManager and NetworkSync together)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SpawnManager v2 API: no SyncConfig, no RelationshipSync — Phase 1 only"
    - "Session ID validation pattern: all spawn/despawn handlers reject stale session_ids silently"
    - "_broadcast_pending dict on NetworkSync for deferred spawn broadcast cancellation"
    - "add_entity BEFORE apply_component_data (Pitfall 6) enforced in handle_spawn_entity"
    - "Godot global_script_class_cache.cfg manual update required for new class_name files during test runs"

key-files:
  created:
    - addons/gecs_network/spawn_manager.gd
  modified:
    - addons/gecs_network/tests/test_spawn_manager.gd
    - .godot/global_script_class_cache.cfg

key-decisions:
  - "SpawnManager.on_entity_added calls _ns.call_deferred('_deferred_broadcast', ...) — MockNetworkSync lacks this method but tests pass; Plan 03 adds it to NetworkSync"
  - "SpawnManager.on_entity_removed calls _ns.rpc_broadcast_despawn() directly — MockNetworkSync implements this for test assertion"
  - "Manual cache update in .godot/global_script_class_cache.cfg needed for new class_name to be visible to Godot test runner"

patterns-established:
  - "Wave 1 GREEN: SpawnManager port of sync_spawn_handler.gd with SyncConfig and RelationshipSync removed"
  - "Test sentinel removal: assert_bool(false).is_true() stub replaced by real assertions in Wave 1"

requirements-completed: [FOUND-01, FOUND-02, LIFE-01, LIFE-02, LIFE-03, LIFE-04]

# Metrics
duration: 18min
completed: 2026-03-07
---

# Phase 1 Plan 02: SpawnManager Implementation Summary

**SpawnManager v2 with session-validated spawn/despawn handlers, entity serialization, and deferred broadcast logic — all 22 Wave 0/1 network tests GREEN**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-03-07T20:57:37Z
- **Completed:** 2026-03-07T21:17:00Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments

- Confirmed CN_NetworkIdentity already GREEN from Plan 01: `is_server_owned()` returns `peer_id == 0` ONLY, `is_host()` removed; all 16 tests pass
- Created `spawn_manager.gd` with `class_name SpawnManager` — clean v2 API with no SyncConfig or RelationshipSync dependencies
- `serialize_entity()` returns id, name, scene_path, components, script_paths, session_id; `serialize_world_state()` filters to CN_NetworkIdentity entities only
- `handle_spawn_entity()` enforces session_id validation and Pitfall 6 (world.add_entity before apply_component_data)
- `handle_despawn_entity()` validates session_id, graceful no-op for unknown entity_id
- `on_entity_added()` queues deferred broadcast via `_broadcast_pending` dict; `on_entity_removed()` cancels pending or sends despawn RPC
- `on_peer_disconnected()` removes all entities owned by the disconnected peer
- Removed Wave 0 stub sentinel from `test_serialize_world_state` — all 6 SpawnManager tests pass GREEN
- Updated `.godot/global_script_class_cache.cfg` to register SpawnManager class_name for test runner

## Task Commits

Each task was committed atomically:

1. **Task 1: CN_NetworkIdentity confirmed GREEN** — no commit needed (already done in Plan 01)
2. **Task 2: Create SpawnManager + remove test stub sentinel** - `c7d7a31` (feat)

## Files Created/Modified

- `addons/gecs_network/spawn_manager.gd` - New SpawnManager class (264 lines): serialize_entity, serialize_world_state, handle_spawn_entity, handle_despawn_entity, on_entity_added, on_entity_removed, on_peer_disconnected
- `addons/gecs_network/tests/test_spawn_manager.gd` - Removed Wave 0 stub sentinel from test_serialize_world_state; updated header comment
- `.godot/global_script_class_cache.cfg` - Added SpawnManager entry so Godot test runner resolves the class_name

## Decisions Made

- SpawnManager calls `_ns.call_deferred("_deferred_broadcast", entity, entity.id)` on NetworkSync — MockNetworkSync doesn't implement `_deferred_broadcast` so Godot prints "Method not found" errors at runtime, but test assertions still pass. Plan 03 will add `_deferred_broadcast` to NetworkSync to eliminate these errors.
- `rpc_broadcast_despawn` is called directly on `_ns` in `on_entity_removed` — MockNetworkSync implements this method for test assertion without real network.
- Manual update of `.godot/global_script_class_cache.cfg` was required to register the new SpawnManager class_name. Godot would normally do this automatically on project reimport, but the CLI test runner doesn't trigger reimport of new files.

## Deviations from Plan

None - plan executed exactly as written. The plan explicitly stated to stub on_entity_added/removed/on_peer_disconnected with `_broadcast_pending` logic but replace actual RPC calls with testable equivalents. The MockNetworkSync's `rpc_broadcast_despawn` and `spawn_rpc_calls` arrays served as the test-observable surface.

## Issues Encountered

- **Godot class cache miss:** First test run failed with "Could not find type 'SpawnManager' in the current scope" because `.godot/global_script_class_cache.cfg` hadn't been updated with the new class. Solution: manually added the SpawnManager entry to the cache file. This is a standard Godot quirk — the CLI test runner doesn't run the editor's asset importer. Future plans should document this for any new `class_name` file.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-03 can begin: NetworkSync RPC surface (will add `_deferred_broadcast` method, eliminating the "Method not found" error in test output)
- Plan 01-04 can begin: Integration tests that wire SpawnManager to NetworkSync signals
- SpawnManager is importable by class_name and all 22 Wave 0/1 gecs_network tests pass GREEN

---
*Phase: 01-foundation-and-entity-lifecycle*
*Completed: 2026-03-07*

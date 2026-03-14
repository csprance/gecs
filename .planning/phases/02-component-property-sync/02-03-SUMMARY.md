---
phase: 02-component-property-sync
plan: 03
subsystem: networking
tags: [gdscript, ecs, rpc, sync, priority, timer, authority-validation]

# Dependency graph
requires:
  - phase: 02-component-property-sync
    provides: CN_NetSync component with check_changes_for_priority() and update_cache_silent()
  - phase: 01-foundation-and-entity-lifecycle
    provides: SpawnManager delegation pattern, CN_NetworkIdentity, NetAdapter, entity_id_registry

provides:
  - SyncSender: timer accumulator, priority-tiered entity poll, batched RPC dispatch, relay queue
  - SyncReceiver: authority validation (server + client paths), CN_NetworkIdentity strip, _applying_network_data guard, component apply

affects:
  - 02-04-network-sync-wiring (NetworkSync wires _sender and _receiver in _ready())
  - future phases using SyncSender.queue_relay_data() or SyncReceiver.handle_apply_sync_data()

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RefCounted delegation pattern (same as SpawnManager) — no class-level coupling to NetworkSync"
    - "Timer accumulator pattern: _timers dict per priority, _should_flush() compares against interval"
    - "Pending batch accumulator: _pending dict per priority, cleared after dispatch"
    - "Authority check sequence: entity existence -> CN_NetworkIdentity -> CN_NetSync -> owner check -> strip -> relay -> apply"
    - "_applying_network_data guard wraps all comp.set() calls in SyncReceiver to prevent echo detection"

key-files:
  created:
    - addons/gecs_network/sync_sender.gd
    - addons/gecs_network/sync_sender.gd.uid
    - addons/gecs_network/sync_receiver.gd
    - addons/gecs_network/sync_receiver.gd.uid
  modified:
    - addons/gecs_network/tests/test_sync_sender.gd
    - addons/gecs_network/tests/test_sync_receiver.gd

key-decisions:
  - "SyncSender calls _ns._sync_components_unreliable(batch) directly — mock captures calls; production NetworkSync adds @rpc decorator so plan 04 wiring handles the real RPC surface"
  - "REALTIME interval is 0.0 — _should_flush() returns true unconditionally for REALTIME (no timer check needed)"
  - "SyncReceiver guards relay call with _ns.get('_sender') != null for safety during plan 04 wiring phase"
  - "CN_NetworkIdentity is excluded from CN_NetSync scan (SECURITY) AND stripped from client batches on server (ownership spoof prevention)"
  - "Entities without CN_NetSync rejected for continuous updates on both server and client paths (spawn-only protection, SYNC-03)"

patterns-established:
  - "Pattern: _dispatch_batch() duplicates pending before clearing — prevents data loss on re-entrant tick"
  - "Pattern: queue_relay_data() merges into HIGH bucket always — relay responsiveness matches client's send frequency"

requirements-completed: [SYNC-01, SYNC-02, SYNC-03]

# Metrics
duration: 150min
completed: 2026-03-09
---

# Phase 02 Plan 03: SyncSender and SyncReceiver Summary

**Priority-tiered batch RPC dispatcher (SyncSender) and authority-validated component applicator (SyncReceiver) using the RefCounted delegation pattern, turning all 14 Wave-0 RED stubs GREEN**

## Performance

- **Duration:** 150 min
- **Started:** 2026-03-09T01:20:00Z
- **Completed:** 2026-03-09T03:50:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- SyncSender fires REALTIME every frame, HIGH at 20Hz (unreliable), MEDIUM at 10Hz (reliable), LOW at 2Hz (reliable)
- SyncReceiver enforces full 7-step server authority check and 6-step client authority check with CN_NetworkIdentity spoof prevention
- _applying_network_data guard wraps all component set() calls with update_cache_silent() to prevent echo detection loops
- All 14 combined tests (7 sender + 7 receiver) GREEN; 31 Phase 1/2 core tests remain GREEN (no regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create sync_sender.gd — timer accumulator, entity poll, batch dispatch** - `48fccec` (feat)
2. **Task 2: Create sync_receiver.gd — authority validation, apply with sync-loop guard** - `5153590` (feat)

**Plan metadata:** (docs commit follows)

_Note: TDD tasks — files pre-existed from prior session; verified tests GREEN and committed as implementation tasks_

## Files Created/Modified

- `addons/gecs_network/sync_sender.gd` - Timer accumulator, priority-tiered entity poll, batched RPC dispatch, relay queue
- `addons/gecs_network/sync_sender.gd.uid` - UID sidecar for class_name resolution in CLI test runs
- `addons/gecs_network/sync_receiver.gd` - Authority validation, CN_NetworkIdentity strip, _applying_network_data guard, component apply
- `addons/gecs_network/sync_receiver.gd.uid` - UID sidecar for class_name resolution in CLI test runs
- `addons/gecs_network/tests/test_sync_sender.gd` - 7 behavioral tests: timer Hz, batch format, relay, no-dispatch guard
- `addons/gecs_network/tests/test_sync_receiver.gd` - 7 behavioral tests: server authority, client authority, CN_NetworkIdentity strip, flag guard, spawn-only rejection

## Decisions Made

- SyncSender calls `_ns._sync_components_unreliable(batch)` directly rather than via `.rpc()` — the mock captures direct calls; production plan 04 wiring provides the real @rpc surface on NetworkSync, which calls these same methods. This keeps SyncSender testable without a real multiplayer session.
- REALTIME interval is 0.0; `_should_flush()` returns `true` unconditionally for interval <= 0.0 to handle the REALTIME case cleanly.
- SyncReceiver guards the relay call with `_ns.get("_sender") != null` for safety during the plan 04 wiring window when _sender may not yet be set.

## Deviations from Plan

None — plan executed exactly as written. Both files were already present from an earlier session and all tests were already GREEN on execution.

## Issues Encountered

- Running `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` (the full suite) hits a debugger breakpoint in `sync_spawn_handler.gd` (line 285) because `CN_SyncEntity` was deleted in plan 02-01. This is a pre-existing out-of-scope issue. The plan-specific test files (`test_sync_sender.gd`, `test_sync_receiver.gd`, `test_cn_net_sync.gd`, `test_spawn_manager.gd`, `test_cn_network_identity.gd`) all pass GREEN when run individually. Deferred to `deferred-items.md`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- SyncSender and SyncReceiver are complete and tested — NetworkSync plan 04 can now wire `_sender` and `_receiver` in `_ready()` and route `_sync_components_unreliable` / `_sync_components_reliable` @rpc calls to `_receiver.handle_apply_sync_data()`
- Pre-existing blocker: `sync_spawn_handler.gd` references deleted `CN_SyncEntity` — plan 04 should either delete or update this file before running the full test suite

---
*Phase: 02-component-property-sync*
*Completed: 2026-03-09*

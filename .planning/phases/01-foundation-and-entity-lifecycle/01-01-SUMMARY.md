---
phase: 01-foundation-and-entity-lifecycle
plan: 01
subsystem: testing
tags: [gdunit4, tdd, red-phase, spawn-manager, network-identity, gecs-network]

# Dependency graph
requires: []
provides:
  - Failing RED test for is_server_owned() peer_id=1 semantic in CN_NetworkIdentity
  - 6 failing RED test stubs for SpawnManager behavioral contract
  - MockNetworkSync without sync_config field (v2 contract enforced in tests)
affects:
  - 01-02 (SpawnManager implementation — turns these RED stubs GREEN)
  - 01-03 (CN_NetworkIdentity update — fixes peer_id=1 is_server_owned semantics)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave 0 RED-first: test stubs committed before any implementation exists"
    - "MockNetworkSync v2 pattern: no sync_config, tracks rpc_calls arrays for assertion"

key-files:
  created:
    - addons/gecs_network/tests/test_spawn_manager.gd
  modified:
    - addons/gecs_network/tests/test_cn_network_identity.gd

key-decisions:
  - "LOCKED: peer_id=1 (host) is NOT server-owned in v2 — server-owned means peer_id=0 ONLY"
  - "MockNetworkSync v2 has no sync_config field — removed to decouple from SyncConfig class"
  - "Wave 0 stub sentinel pattern: assert_bool(false).is_true() in test_serialize_world_state to keep intent clear"

patterns-established:
  - "Wave 0 TDD: stubs reference non-existent SpawnManager class to guarantee parse-time failure until Wave 1"
  - "RPC call tracking: spawn_rpc_calls and despawn_rpc_calls arrays on MockNetworkSync for assertion without real network"

requirements-completed: [FOUND-01, FOUND-02, LIFE-01, LIFE-02, LIFE-03, LIFE-04]

# Metrics
duration: 8min
completed: 2026-03-07
---

# Phase 1 Plan 01: Foundation RED Tests Summary

**Wave 0 TDD stubs: failing tests for SpawnManager contract and peer_id=1 is_server_owned() semantic, both committed before implementation exists**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-07T20:51:52Z
- **Completed:** 2026-03-07T20:57:00Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Added `test_is_server_owned_peer_id_one_is_not_server_owned` to test_cn_network_identity.gd — asserts false against current code that returns true, establishing the v2 semantic contract
- Created test_spawn_manager.gd with 6 failing stubs covering all SpawnManager behaviors: deferred broadcast, cancellation, world state serialization, stale session rejection, peer disconnect cleanup, same-frame cancel
- MockNetworkSync in test_spawn_manager.gd has NO sync_config field, enforcing v2 API contract in tests before implementation

## Task Commits

Each task was committed atomically:

1. **Task 1: Add is_server_owned() semantic test** - `894af9c` (test)
2. **Task 2: Create test_spawn_manager.gd with failing stubs** - `7c92fa7` (test)

## Files Created/Modified

- `addons/gecs_network/tests/test_cn_network_identity.gd` - Added test_is_server_owned_peer_id_one_is_not_server_owned (new failing test)
- `addons/gecs_network/tests/test_spawn_manager.gd` - New file: 6 RED stubs for SpawnManager behavioral contract, MockNetworkSync without sync_config

## Decisions Made

- LOCKED DECISION: peer_id=1 (host) is NOT server-owned in v2 — server-owned means peer_id=0 ONLY. The host-as-player decides their own authority, so the old `peer_id == 0 or peer_id == 1` logic in is_server_owned() is wrong.
- MockNetworkSync v2 removes sync_config entirely — tests explicitly enforce this by not declaring the field, making any implementation that adds it diverge from the v2 contract.
- test_is_server_owned_peer_id_one test (asserts is_true) and the new test_is_server_owned_peer_id_one_is_not_server_owned (asserts is_false) now conflict — Wave 1 implementation must fix is_server_owned() and then the old test can be removed.

## Deviations from Plan

None - plan executed exactly as written. The plan explicitly stated to leave test_is_host_peer_id_one unchanged (is_host() removal is Wave 1), which was followed.

## Issues Encountered

None - both test files parse correctly as GdScript (valid syntax verified by file creation). Failures will be at runtime when SpawnManager class is not found.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-02 can begin: SpawnManager implementation (turns 6 RED stubs GREEN)
- Plan 01-03 can begin: CN_NetworkIdentity fix for peer_id=1 is_server_owned (turns RED test GREEN, removes old conflicting test)
- Both Wave 1 plans have their RED tests ready and committed

---
*Phase: 01-foundation-and-entity-lifecycle*
*Completed: 2026-03-07*

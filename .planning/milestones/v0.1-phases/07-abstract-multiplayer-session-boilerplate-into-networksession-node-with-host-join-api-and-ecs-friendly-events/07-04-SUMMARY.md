---
phase: 07-abstract-multiplayer-session-boilerplate-into-networksession-node-with-host-join-api-and-ecs-friendly-events
plan: 04
subsystem: networking
tags: [networksession, enet, multiplayer, example, refactor, gdscript, sync-sender, rpc-fix]

# Dependency graph
requires:
  - phase: 07-02
    provides: NetworkSession host/join/end_session API with callable hooks
  - phase: 07-03
    provides: ECS session entity with CN_SessionState and transient event components

provides:
  - example_network/main.gd refactored to use NetworkSession (no manual boilerplate)
  - example_network/main.tscn with NetworkSession node wired up
  - SyncSender RPC dispatch fix — component property sync now actually sends over network
  - All connected peers can shoot projectiles (not just host)
  - Canonical reference showing how to use NetworkSession in a real project

affects:
  - any developer reading example_network as a reference
  - SESSION-03 requirement proof
  - any code using CN_NetSync component property sync in real multiplayer

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NetworkSession hook wiring: assign Callable hooks in _ready() before calling host()/join()"
    - "NetworkSync signal connection in on_host_success/on_join_success hooks (not in _ready)"
    - "session.network_sync == null as connection guard in _process()"
    - "Component sync send wrappers: NetworkSync._send_sync_unreliable/_send_sync_reliable route to .rpc()/.rpc_id(1) so SyncSender stays testable with RefCounted mocks"

key-files:
  created: []
  modified:
    - example_network/main.gd
    - example_network/main.tscn
    - addons/gecs_network/network_sync.gd
    - addons/gecs_network/sync_sender.gd
    - addons/gecs_network/tests/test_sync_sender.gd
    - addons/gecs_network/tests/test_custom_sync_handlers.gd

key-decisions:
  - "NetworkSync signals (entity_spawned, local_player_spawned) connected inside on_host_success/on_join_success hooks — NetworkSync only exists after host/join returns"
  - "session.network_sync == null replaces _is_connected bool — single source of truth"
  - "on_session_ended_hook resets _spawned_peer_ids and _next_player_number — end_session() removes all entities from world so manual cleanup of tracked state is still needed"
  - "SyncSender dispatch uses _send_sync_unreliable/_send_sync_reliable wrappers in NetworkSync instead of calling @rpc methods directly — keeps SyncSender testable with MockNetworkSync (RefCounted cannot have @rpc methods)"

patterns-established:
  - "Pattern: Use NetworkSession hooks for all session lifecycle events — no direct multiplayer signal wiring in game code"
  - "Pattern: RPC send wrappers on the Node layer, not on RefCounted helpers — RefCounted cannot have @rpc methods; helpers call node wrappers that use .rpc()/.rpc_id()"

requirements-completed:
  - SESSION-03

# Metrics
duration: 45min
completed: 2026-03-13
---

# Phase 07 Plan 04: Refactor Example Network to Use NetworkSession Summary

**example_network/main.gd rewritten to use NetworkSession hooks (zero manual boilerplate), plus critical SyncSender RPC dispatch bug fixed so all peers can shoot and component property sync works over the network**

## Performance

- **Duration:** ~45 min (Task 1: ~3 min, Bug fix: ~40 min)
- **Started:** 2026-03-13T01:11:56Z
- **Completed:** 2026-03-13
- **Tasks:** 2 (Task 1 + checkpoint with bug fix)
- **Files modified:** 6

## Accomplishments

- Removed all manual boilerplate from main.gd (ENetMultiplayerPeer, multiplayer signal wiring, _setup_network_sync, _cleanup_network); replaced with NetworkSession hook API
- Added NetworkSession node to main.tscn with debug_logging=true
- Fixed critical SyncSender bug: SyncSender._dispatch_batch() was calling @rpc methods as plain local calls — component property sync (C_PlayerInput, C_NetVelocity, etc.) was never sent over the network; all 136 tests remain GREEN
- Human-verified: connect, player spawn, movement, disconnect, reconnect all work; shooting works for all peers after fix

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor example_network/main.gd and main.tscn to use NetworkSession** - `a663a57` (feat)
2. **Bug fix: Fix SyncSender not sending component sync RPCs over the network** - `cfc0d0a` (fix)

**Plan metadata:** `5314edd` (docs: complete plan 04 — partial)

## Files Created/Modified

- `example_network/main.gd` - Rewritten to use NetworkSession hooks; no ENetMultiplayerPeer, no direct multiplayer signals, no _setup_network_sync()
- `example_network/main.tscn` - Added NetworkSession node as child of Main root node
- `addons/gecs_network/network_sync.gd` - Added _send_sync_unreliable()/_send_sync_reliable() wrapper methods for testable RPC dispatch
- `addons/gecs_network/sync_sender.gd` - Updated _dispatch_batch() to call wrappers instead of @rpc methods directly
- `addons/gecs_network/tests/test_sync_sender.gd` - Updated MockNetworkSync to implement new _send_sync_* wrapper method names
- `addons/gecs_network/tests/test_custom_sync_handlers.gd` - Updated MockNetworkSync to implement new _send_sync_* wrapper method names

## Decisions Made

- NetworkSync signals (entity_spawned, local_player_spawned) connected inside on_host_success/on_join_success hooks — NetworkSync only exists post-host/join
- `session.network_sync == null` replaces `_is_connected` bool — avoids separate bool that could get out of sync
- on_session_ended_hook still resets _spawned_peer_ids and _next_player_number because end_session() handles entity cleanup but not game-level tracking state
- SyncSender uses _send_sync_unreliable/_send_sync_reliable wrappers so the RefCounted-based SyncSender never calls .rpc() directly (RefCounted helpers cannot own @rpc methods; only the NetworkSync Node can)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SyncSender never sending component property sync over the network**

- **Found during:** Task 2 checkpoint (human verification — only host can shoot)
- **Issue:** SyncSender._dispatch_batch() called `_ns._sync_components_unreliable(batch)` as a plain method call (without `.rpc()`). In Godot 4, calling an `@rpc`-decorated method without `.rpc()` is a local-only call — the data was never sent to any remote peer. This means C_PlayerInput changes (is_shooting, move_direction) from clients were never received by the server, so only the host's locally-controlled player could shoot. This bug affected all CN_NetSync component property sync since Phase 2 but was not caught by unit tests (which mock out RPCs entirely) or live tests (movement worked via CN_NativeSync/MultiplayerSynchronizer, not via SyncSender).
- **Fix:** Added `_send_sync_unreliable()`/`_send_sync_reliable()` wrapper methods to NetworkSync that properly use `.rpc(batch)` (server broadcasts to all clients) or `.rpc_id(1, batch)` (client sends to server). Updated SyncSender._dispatch_batch() to call the wrappers. Updated MockNetworkSync in both test files to match the new method names.
- **Files modified:** addons/gecs_network/network_sync.gd, addons/gecs_network/sync_sender.gd, addons/gecs_network/tests/test_sync_sender.gd, addons/gecs_network/tests/test_custom_sync_handlers.gd
- **Verification:** All 136 tests GREEN; human confirmed shooting works for all peers
- **Committed in:** cfc0d0a

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Critical correctness fix — CN_NetSync component property sync was entirely non-functional in real multiplayer. No scope creep.

## Issues Encountered

Human verification found that only the host could shoot. Root cause: SyncSender._dispatch_batch() used direct method calls on @rpc-decorated methods, which in Godot 4 are local-only calls. C_PlayerInput state changes were never transmitted from clients to the server. Fixed by adding send-wrapper methods to NetworkSync that use the correct .rpc()/.rpc_id() syntax.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 07 fully complete — NetworkSession API is ergonomic, human-verified, and SESSION-03 satisfied
- CN_NetSync component property sync is now functional for real multiplayer (was silently broken since Phase 2)
- All 136 tests GREEN
- SyncSender wrapper pattern documented for future phases

---
*Phase: 07-abstract-multiplayer-session-boilerplate-into-networksession-node-with-host-join-api-and-ecs-friendly-events*
*Completed: 2026-03-13*

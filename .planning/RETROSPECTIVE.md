# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.1 — GECS Networking v2

**Shipped:** 2026-03-13
**Phases:** 7 | **Plans:** 26 | **Timeline:** 57 days (2026-01-15 → 2026-03-13) | **Commits:** 177

### What Was Built
- Declarative component sync — `CN_NetSync` + `@export_group` drives priority-tiered batched RPCs with dirty-only bandwidth
- Automatic entity lifecycle — spawn/despawn replicated to all peers; late-join receives full world state; disconnect triggers peer-owned entity cleanup
- Authority model — `CN_LocalAuthority` / `CN_ServerAuthority` marker components; native `MultiplayerSynchronizer` for smooth transform interpolation
- Relationship sync — entity-to-entity relationships replicated with deferred resolution queue for non-deterministic spawn ordering
- Reconciliation + custom sync — periodic full-state broadcast corrects drift; `register_send/receive_handler` API for client-side prediction patterns
- `NetworkSession` node — `host()` / `join()` / `end_session()` reduces multiplayer setup to 3 lines; lifecycle events surface as ECS components
- Complete v2 docs rewrite — all 8 docs updated, README v2 Quick Start, CHANGELOG [2.0.0], v1→v2 migration guide, working example project

### What Worked
- **TDD wave-0 discipline** — writing failing test stubs before implementation caught API shape issues early (e.g., `MockNetworkSync` override conflict, `before_test()` vs `before_each()`)
- **Human verification checkpoints** per phase — live multiplayer smoke tests in example_network caught issues automated tests missed (e.g., SyncSender RPC dispatch bug found in Phase 7)
- **Locked decisions in SUMMARY files** — Phase 1 locking `peer_id=0` = server-owned prevented the ID ambiguity from surfacing in every subsequent phase
- **Deferred guard pattern** (`_applying_network_data`) — established in Phase 1, reused consistently to prevent sync loops throughout
- **`assert_bool(false).is_true()` stubs** — avoided parser/load errors for not-yet-existing classes while still producing valid RED test failures

### What Was Inefficient
- **SyncSender RPC dispatch bug** — component property sync was never actually sending over the network; discovered only in Phase 7-04 human verification after 6 phases of automated tests passed. Root cause: `_send_sync_unreliable`/`_send_sync_reliable` wrappers were missing, SyncSender called `@rpc` methods directly on a RefCounted mock that can't have `@rpc`. More thorough integration testing of the full RPC path in Phase 2 would have caught this earlier.
- **v0.1.1 stub accumulation** — `sync_state_handler.gd`, `sync_property_handler.gd`, `sync_spawn_handler.gd` lingered as dead stubs throughout v0.1 because deletion was always deferred. Should have been fully deleted in Phase 6.
- **UID file management** — manually tracking and committing `.gd.uid` sidecar files for headless test runs was friction throughout; could be automated

### Patterns Established
- **Wave-0 stubs → GREEN → human verification** is the reliable 3-stage rhythm per phase
- **`session.network_sync == null` as connection guard** — single source of truth pattern; avoid parallel boolean flags
- **Callable hooks in `_ready()` before `host()`/`join()`** — mandatory ordering for `NetworkSession` users; document prominently
- **Transient components cleared at START of `_process()`** — ensures game systems see events for a full frame; a clean ECS event model
- **`extends Resource` for configurable provider types** — required for `@export` inspector compatibility; `extends RefCounted` breaks tooling

### Key Lessons
1. **Automated tests are necessary but not sufficient for RPC paths** — headless GdUnit4 uses `OfflineMultiplayerPeer`; real network RPCs only fire with ENet. Add a real-network smoke test to Phase 1 in future milestones.
2. **Dead code deferred is dead code permanent** — if a file should be deleted, delete it in the phase where it becomes dead. Deferral creates confusion in every subsequent phase.
3. **Lock critical semantic decisions in Phase 1** — `peer_id` semantics, authority model shape, session ID validation pattern. These cascade through every downstream phase and are very expensive to revisit.
4. **Example project as integration test** — running `example_network/` as a human checkpoint per phase is worth the overhead; it found bugs automated tests couldn't.
5. **`MockNetworkSync` must be a `RefCounted`, never override `call_deferred`** — `RefCounted` inherits `call_deferred` from `Object` with a fixed signature; overriding it causes GDScript parser errors at runtime.

### Cost Observations
- Model: Claude Sonnet 4.6 throughout
- Sessions: ~20+ sessions across 57 days
- Notable: The 7-phase structure front-loaded the hardest architectural decisions (Phase 1 locked the peer ID model, spawn timing, and sync loop prevention), which made Phases 2–5 significantly smoother to execute.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Process Change |
|-----------|--------|-------|--------------------|
| v0.1 | 7 | 26 | First GSD milestone; established wave-0 TDD + human verification checkpoint pattern |

### Cumulative Quality

| Milestone | Tests | Zero-Dep Additions | Notes |
|-----------|-------|--------------------|-------|
| v0.1 | 135+ | 0 | All tests in `addons/gecs_network/tests/`; zero changes to GECS core |

### Top Lessons (Verified Across Milestones)

1. Lock semantic decisions early — `peer_id` semantics and authority model in Phase 1 prevented cascading rework
2. Human smoke tests catch what mocks cannot — RPC dispatch bug only surfaced in live multiplayer, not headless tests

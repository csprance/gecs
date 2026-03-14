# GECS

## What This Is

A lightweight, performant Entity Component System (ECS) framework for Godot 4.x with a declarative multiplayer networking addon. Developers build games using composable components, query-driven systems, and an optional networking layer that replicates entities automatically with zero manual RPC calls.

## Core Value

Developers can build ECS games in Godot with a framework that stays out of their way — clean APIs, honest docs, and patterns that actually work in real projects.

## Current Milestone: v0.2 — Documentation Overhaul

**Goal:** Rewrite all GECS and GECS Network docs to be trustworthy — every claim verified against actual code, real examples from production use, no AI-hallucinated patterns.

**Target features:**
- All core GECS docs (`addons/gecs/docs/`) rewritten and verified
- BEST_PRACTICES.md rebuilt from real zamn project patterns
- All network docs verified against v1.0.0 API
- Root README rewritten as an accurate project homepage

## Requirements

### Validated

- ✓ Component-level network configuration via `CN_NetSync` + `@export_group` (REALTIME/HIGH/MEDIUM/LOW) — v0.1
- ✓ Automatic entity lifecycle sync (spawn/despawn without manual RPCs) — v0.1
- ✓ Late-join full world state snapshot — v0.1
- ✓ Peer disconnect cleanup (all owned entities removed on all peers) — v0.1
- ✓ Authority model via `CN_LocalAuthority` / `CN_ServerAuthority` marker components — v0.1
- ✓ Native transform sync via `MultiplayerSynchronizer` (built-in interpolation) — v0.1
- ✓ Entity relationship sync with deferred resolution — v0.1
- ✓ Periodic full-state reconciliation broadcast (default 30s, configurable) — v0.1
- ✓ Custom sync handler override API (`register_send/receive_handler`) — v0.1
- ✓ `NetworkSession` node with `host()` / `join()` / `end_session()` API — v0.1
- ✓ ECS-friendly session lifecycle events as transient components — v0.1
- ✓ Zero networking overhead in single-player — v0.1
- ✓ Full v2 documentation suite + v1→v2 migration guide — v0.1

### Active

- [ ] All core GECS docs verified accurate against actual code (CORE-01 through CORE-06)
- [ ] BEST_PRACTICES.md rewritten using real zamn project patterns (BEST-01 through BEST-03)
- [ ] All network docs verified against v1.0.0 API (NET-01 through NET-03)
- [ ] Root README and addon READMEs rewritten (READ-01, READ-02)

### Out of Scope

| Feature | Reason |
|---------|--------|
| New GECS features | v0.2 is docs only — no API changes |
| Client-side prediction implementation | Deferred to future milestone |
| Server time synchronization | Deferred to future milestone |
| P2P / WebRTC networking | Different topology, fundamentally changes architecture |
| Lobby / matchmaking | GECS Networking is a state sync layer |
| Deterministic physics / lockstep | Incompatible with async sync model |
| New tutorials / video content | Out of scope for this milestone |

## Context

**Shipped v0.1** (GECS Network v1.0.0) with 6,168 lines of GDScript across `addons/gecs_network/`. GECS core is at v6.8.1.

**Tech stack:** GDScript, Godot 4.x, ENet, `MultiplayerSynchronizer`, gdUnit4.

**Docs state entering v0.2:** `addons/gecs/docs/` has 11 files (~5,000 lines), many containing hallucinated APIs, fabricated patterns, and AI-padded prose. Network docs (`addons/gecs_network/docs/`) have 10 files — newer but still need verification. Root README needs a full rewrite.

**Reference project:** `D:\code\zamn` — a real production GECS game with actual systems, components, and patterns. Use to replace fabricated best practice examples.

**Known issues / tech debt:**
- `sync_state_handler.gd`, `sync_property_handler.gd`, `sync_spawn_handler.gd` are v0.1.1-era stubs referencing deleted `CN_SyncEntity` — dead code, should be deleted in a future cleanup pass
- Performance under high entity count (>500 networked entities) not benchmarked

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace `NetworkMiddleware` with declarative `CN_NetSync` | ECS components are natural sync units; middleware required too much boilerplate | ✓ Good — core v2 design |
| New branch, clean break from v0.1.x | Allows complete redesign without breaking existing users | ✓ Good — migration guide handles upgrades |
| `peer_id=0` = server-owned only (not `peer_id=1`) | Eliminates ambiguity; `peer_id=1` is the host client in ENet | ✓ Good — locked in Phase 1 |
| `NetworkSync` as single RPC surface | Testable; all `@rpc` methods in one Node | ✓ Good — SyncSender/Receiver stay as RefCounted |
| `CN_NetSync` scan via `scan_entity_components()` | Lazy, called on first sync tick — avoids _ready() ordering issues | ✓ Good |
| `call_deferred('_deferred_broadcast')` for spawn batching | Handles add-then-remove-same-frame race | ✓ Good |
| `_applying_network_data` guard in SpawnManager | Prevents echo broadcast of received data (sync loop prevention) | ✓ Good |
| `on_peer_disconnected` removes entity before `queue_free()` | Despawn RPC fires to remaining peers before node is freed | ✓ Good |
| `CN_LocalAuthority` / `CN_ServerAuthority` markers (not `is_multiplayer_authority()`) | Game systems stay decoupled from Godot's multiplayer internals | ✓ Good |
| `NativeSyncHandler` wraps `MultiplayerSynchronizer` | Built-in interpolation; no per-frame RPC overhead for transforms | ✓ Good |
| Relationship deferred resolution queue | Non-deterministic spawn ordering on clients — deferred apply once target arrives | ✓ Good |
| Reconciliation via full-state broadcast (not delta) | Simpler, correctness over efficiency; 30s interval keeps bandwidth acceptable | ✓ Good |
| `register_send/receive_handler` API on `NetworkSync` | Sufficient override surface for prediction patterns without framework complexity | ✓ Good |
| `NetworkSession` with `end_session()` (not `disconnect()`) | `Node.disconnect()` is a built-in signal method — shadowing causes parser warnings | ✓ Good |
| Transient event components cleared at START of `_process()` | Game systems see events for a full frame before clearing | ✓ Good |
| `session.network_sync == null` as connection guard | Single source of truth; avoids `_is_connected` bool drift | ✓ Good |
| `TransportProvider extends Resource` (not `RefCounted`) | `@export` compatibility with Godot inspector | ✓ Good |

## Constraints

- **Accuracy**: Every code example must compile and run against GECS v6.8.1 — no invented APIs
- **Source of truth**: Verify against actual `.gd` source files, not memory or prior docs
- **zamn patterns**: Best practices must come from real zamn code, not invented scenarios
- **No new features**: v0.2 is docs only — do not change any `.gd` files

---
*Last updated: 2026-03-13 after v0.2 milestone started*

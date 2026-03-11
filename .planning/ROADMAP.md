# Roadmap: GECS Networking v2

## Overview

This milestone replaces the current NetworkMiddleware system with a declarative, component-driven networking layer. The delivery order follows a strict dependency chain: the framework foundation and entity lifecycle must be solid before properties can sync, properties must sync before relationships can reference them, and reconciliation is added last once the happy path is proven. Critical pitfalls (spawn timing races, session ID anti-ghost, sync loops, node naming) are resolved in the earliest phases where they arise — retrofitting them later requires touching every RPC signature in the system.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation and Entity Lifecycle** - NetAdapter, session IDs, entity spawn/despawn across peers, late-join, and disconnect cleanup
- [x] **Phase 2: Component Property Sync** - Declarative CN_NetSync configuration, priority-tiered batched RPC sync, dirty tracking, spawn-only mode
- [x] **Phase 3: Authority Model and Native Transform Sync** - Operational authority transfer, MultiplayerSynchronizer for transforms, authority marker propagation
- [x] **Phase 4: Relationship Sync** - Entity-to-entity relationship sync with deferred resolution for non-deterministic spawn ordering (completed 2026-03-11)
- [ ] **Phase 5: Reconciliation and Custom Sync** - Periodic full-state reconciliation, system-level sync override hooks

## Phase Details

### Phase 1: Foundation and Entity Lifecycle
**Goal**: Entities exist and persist consistently across all peers — server spawns and despawns are reflected on clients automatically, late joiners receive full world state, disconnected peers are cleaned up, and all of this is zero-cost in single-player
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, LIFE-01, LIFE-02, LIFE-03, LIFE-04
**Success Criteria** (what must be TRUE):
  1. Developer can declare a component's sync priority inline using `@export_group` annotations without any external registry
  2. Server spawns an entity and it automatically appears on all connected clients without any manual RPC call
  3. Server despawns an entity and it is automatically removed on all connected clients
  4. A client that connects mid-game receives all existing networked entities immediately
  5. When a peer disconnects, all entities owned by that peer are removed from the world on all remaining peers; single-player sessions have zero networking overhead
**Plans**: 4 plans

Plans:
- [ ] 01-01-PLAN.md — Wave 0 test stubs: failing tests for SpawnManager and CN_NetworkIdentity semantics
- [ ] 01-02-PLAN.md — Foundation implementation: CN_NetworkIdentity fix + SpawnManager creation
- [ ] 01-03-PLAN.md — NetworkSync Phase 1 skeleton: RPC surface, lifecycle signal wiring, Phase 2-5 cleanup
- [ ] 01-04-PLAN.md — Integration pass: complete _apply_component_data, finalize RPC dispatch, human checkpoint

### Phase 2: Component Property Sync
**Goal**: Component properties declared as networked stay synchronized across peers at correct rates, with bounded bandwidth and zero feedback loops
**Depends on**: Phase 1
**Requirements**: SYNC-01, SYNC-02, SYNC-03
**Success Criteria** (what must be TRUE):
  1. A component property decorated with REALTIME priority syncs every frame; HIGH syncs at 20Hz; MEDIUM at 10Hz; LOW at 2Hz — verified by observing client receive rates
  2. Only properties that changed since the last sync tick are included in the outbound batch — a static entity generates no outbound sync traffic
  3. A component declared as spawn-only sends its values once at spawn and never generates continuous sync traffic thereafter
**Plans**: 4 plans

Plans:
- [ ] 02-01-PLAN.md — Wave 0 test stubs: 4 failing test files created; 3 obsolete test files deleted
- [ ] 02-02-PLAN.md — Delete obsolete source files + create CN_NetSync (scanner, dirty cache, change detection)
- [ ] 02-03-PLAN.md — Create SyncSender (timer loop, batch dispatch) + SyncReceiver (authority validation, apply guard)
- [ ] 02-04-PLAN.md — Wire into NetworkSync + register plugin ProjectSettings + annotate example components; human checkpoint

### Phase 3: Authority Model and Native Transform Sync
**Goal**: Player-owned entities have correct input authority across all peers and entity transforms use native Godot interpolation rather than per-frame RPCs
**Depends on**: Phase 2
**Requirements**: LIFE-05, SYNC-04
**Success Criteria** (what must be TRUE):
  1. Game systems can determine entity authority by checking for `CN_LocalAuthority` or `CN_ServerAuthority` components — no `is_multiplayer_authority()` calls required in game code
  2. Entity transform position and rotation sync uses `MultiplayerSynchronizer` with built-in interpolation — smooth movement on clients without per-frame RPC overhead
**Plans**: 4 plans

Plans:
- [x] 03-01-PLAN.md — Wave 0 test stubs: test_authority_markers.gd (5 stubs, LIFE-05) + test_native_sync_handler.gd (5 stubs, SYNC-04)
- [x] 03-02-PLAN.md — CN_NativeSync component + authority marker injection in SpawnManager (LIFE-05)
- [x] 03-03-PLAN.md — NativeSyncHandler + CN_NetSync skip + NetworkSync wire + legacy file cleanup (SYNC-04)
- [x] 03-04-PLAN.md — Full suite verification + human checkpoint

### Phase 4: Relationship Sync
**Goal**: Entity-to-entity relationships sync across all peers and hierarchical queries produce consistent results even when target entities arrive in non-deterministic order
**Depends on**: Phase 3
**Requirements**: ADV-01
**Success Criteria** (what must be TRUE):
  1. A relationship added on the server (e.g., parent-child, attacker-target) appears on all clients
  2. When a relationship's target entity has not yet spawned on a client, the relationship is deferred and applied automatically once the target entity arrives
**Plans**: 3 plans

Plans:
- [ ] 04-01-PLAN.md � Wave 0 test stubs: failing tests for serialize_entity relationships key + MockNetworkSync cleanup
- [ ] 04-02-PLAN.md � Core wiring: remove SyncConfig gates + wire _relationship_handler into NetworkSync
- [ ] 04-03-PLAN.md � SpawnManager late-join inclusion + opportunistic SyncConfig cleanup + human checkpoint

### Phase 5: Reconciliation and Custom Sync
**Goal**: Long game sessions stay in sync through periodic correction broadcasts, and game systems can override default sync behavior to implement patterns like client-side prediction
**Depends on**: Phase 4
**Requirements**: ADV-02, ADV-03
**Success Criteria** (what must be TRUE):
  1. After 30 seconds of gameplay, any property drift or missed packets are silently corrected by a full-state reconciliation broadcast — no visible pop or desync
  2. A system can register a custom sync handler that overrides default property sync for specific components — the override surface is documented with a working example prediction pattern
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation and Entity Lifecycle | 4/4 | Complete | 2026-03-09 |
| 2. Component Property Sync | 4/4 | Complete | 2026-03-09 |
| 3. Authority Model and Native Transform Sync | 4/4 | Complete | 2026-03-10 |
| 4. Relationship Sync | 3/3 | Complete   | 2026-03-11 |
| 5. Reconciliation and Custom Sync | 0/TBD | Not started | - |

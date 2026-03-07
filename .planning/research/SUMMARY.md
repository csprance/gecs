# Project Research Summary

**Project:** GECS Networking v2 — Declarative ECS Networking
**Domain:** Multiplayer state synchronization layer for Godot 4.x ECS
**Researched:** 2026-03-07
**Confidence:** HIGH

## Executive Summary

GECS Networking v2 is a rewrite of an existing, functional multiplayer synchronization addon (v0.1.1) for the GECS Entity Component System framework in Godot 4.x. The central architectural shift is replacing imperative, centralized sync configuration (a global `SyncConfig` resource mapping class name strings to sync priorities) with a declarative, component-co-located model where each entity carries its own `CN_NetSync` component defining what syncs and at what rate. This mirrors patterns proven in Unity DOTS Netcode Ghosts and Bevy replicon — the difference is the sync policy lives next to the data, not in a separate registry. The research basis is exceptionally solid: all four research areas draw primarily from direct analysis of the v0.1.1 codebase, giving HIGH confidence across the board.

The recommended approach is evolutionary, not revolutionary. All core transport and authority abstractions in v0.1.1 are architecturally correct and must be preserved (`NetAdapter`, `TransportProvider`, `CN_NetworkIdentity`, marker components, two-tier sync with native `MultiplayerSynchronizer` for transforms and RPC batching for component data). The primary work is decomposing the monolithic handler classes into purpose-built objects (`SpawnManager`, `SyncSender`, `SyncReceiver`, `RelationshipSync`), replacing the `SyncComponent` base class requirement with a tag-component approach, and consolidating the 11+ individual `@rpc` stubs into fewer generic batch RPCs. GDScript limitations (no custom annotations, no custom binary serialization) constrain the API surface — the `@export_group` priority convention from v0.1.1 remains the most practical declaration mechanism.

The primary risks are all well-documented in working v0.1.1 mitigation code: spawn timing races require deferred broadcast with a `_broadcast_pending` guard; sync loops require an `_applying_network_data` flag before any property is applied from the network; bandwidth explosion requires priority-tiered batching designed from day one; and session ID validation must be baked into every RPC signature from the start. Missing any of these in the initial architecture requires touching every RPC in the system to retrofit them. The pitfall research is HIGH confidence because every mitigation is proven working code in v0.1.1 with explanatory comments.

---

## Key Findings

### Recommended Stack

The entire stack is Godot 4.x built-ins — no external dependencies, no npm, no GDNative. The v0.1.1 codebase already validated which Godot 4 APIs work in practice, eliminating the risk of adopting unproven technology. Godot 4.2+ is the minimum version (required for stable `MultiplayerSynchronizer` and UID file support, confirmed by `.uid` files present on all scripts).

The key transport decision (already made in v0.1.1 and confirmed): `ENetMultiplayerPeer` for UDP, `OfflineMultiplayerPeer` as single-player passthrough, `MultiplayerSynchronizer` for transform sync. `MultiplayerSpawner` was explicitly tried in v0.1.x and abandoned — it conflicts with GECS's world-managed entity lifecycle. Do not revisit. `Component.serialize()` (existing GECS) is sufficient for spawn payload serialization — do not reinvent.

**Core technologies:**
- `ENetMultiplayerPeer`: Default UDP transport — already validated, zero external dependencies, reliable + unreliable channels built in
- `MultiplayerSynchronizer`: Native transform sync — built-in interpolation, avoids per-frame RPC overhead for the most frequently synced data
- `NetAdapter`: Wraps `MultiplayerAPI` — decouples transport from networking logic, enables testability without running two Godot instances
- `TransportProvider` / `ENetTransportProvider`: Pluggable peer creation — costs nothing, preserves path to Steam transport
- `Component.serialize()` (existing GECS): Spawn payload serialization — handles all `@export` properties, proven reliable
- `get()` / `set()` with `@export_group` priority naming: Per-property sync declaration — the only practical annotation-like mechanism in GDScript 4.x

### Expected Features

**Must have (table stakes) — all 10 carried over from v0.1.1:**
- Component-level sync declaration — the core value proposition; without this it is just raw Godot multiplayer
- Automatic entity lifecycle sync (spawn/despawn) — the most common multiplayer bug source; must be automated
- Authority model with declarative marker components — `CN_LocalAuthority` / `CN_ServerAuthority` query filtering; the ECS-idiomatic pattern that eliminates `is_server()` calls from game systems
- Priority-based sync rates (REALTIME/HIGH/MEDIUM/LOW) with reliable/unreliable transport auto-selection
- Late-join support — world state snapshot on `peer_connected`
- Peer disconnect cleanup — remove all entities owned by disconnected peer
- Zero single-player overhead — gate all work on `net_adapter.is_in_game()`
- Component change detection (dirty tracking) — only send changed properties
- Spawn-only vs. continuous sync modes — projectiles do not need continuous updates
- Session ID anti-ghost protection — stale RPC rejection across game resets

**Should have (high ROI differentiators):**
- Relationship synchronization — unique among Godot ECS networking layers; already implemented in v0.1.1 with deferred resolution for ordering races
- Periodic full-state reconciliation (30s default) — corrects floating-point drift and missed reliable packets silently
- Server time synchronization — required for server-authoritative cooldowns in any real game
- `NetAdapter` abstraction — enables unit testing networked systems without two Godot instances

**Defer to v3:**
- Client-side prediction / lag compensation — explicitly out of scope per PROJECT.md; half-baked prediction is worse than none
- P2P / WebRTC — different networking topology, fundamentally changes architecture
- Lobby / matchmaking — out of scope; GECS Networking is a state sync layer, not session management
- Interest management / spatial culling — expose the hooks (`public_visibility` flag), leave policy to game code
- General-purpose RPC message bus — state changes in components are the v2 message bus

### Architecture Approach

The v2 architecture is a thin coordinator (`NetworkSync` node) delegating to purpose-built objects, all communicating through the existing GECS World signals (`entity_added`, `entity_removed`, `component_added`, `component_removed`, `component_property_changed`, `relationship_added`, `relationship_removed`). The GECS core is untouched — networking is entirely additive. The central data change is replacing the global `SyncConfig` resource (external, string-keyed) with `CN_NetSync` as a tag component on each entity (co-located, Script-reference-keyed). Different entity archetypes carry different `CN_NetSync` instances with their own sync rules — the network layer reads the entity's own configuration rather than looking it up in a global registry.

**Major components:**
1. `NetworkSync` (Node, child of World) — single RPC surface; all `@rpc` methods must live here (Godot constraint); thin coordinator delegating to sub-objects
2. `SpawnManager` (RefCounted) — entity lifecycle broadcast, world state serialization for late-join, session ID validation, deferred spawn with `_broadcast_pending` guard
3. `SyncSender` (RefCounted) — outbound property change batching; per-priority timers; sync entity index (only connects to entities with `CN_NetworkIdentity`)
4. `SyncReceiver` (RefCounted) — applies inbound RPC data with `_applying_network_data` guard to prevent sync loops
5. `RelationshipSync` (RefCounted) — relationship serialization with `_pending_relationships` deferred resolution for ordering races
6. `CN_NetSync` (Component) + `SyncRule` (Resource) — declarative per-entity sync configuration replacing global `SyncConfig`
7. `Serializer` (RefCounted, stateless) — extracted serialization utilities; approximate equality for float/vector change detection

### Critical Pitfalls

1. **Spawn broadcast racing component setup** — Defer the spawn RPC via `call_deferred` with a `_broadcast_pending` guard; serialize component values at broadcast time, not at `entity_added` signal time. This is Pitfall 1 and the first bug you will hit. Must be in the initial spawn architecture — cannot be retrofitted.

2. **Sync loop from applied network data** — Set `_applying_network_data = true` before any `component.set()` call from the network layer; `SyncSender` returns early when this flag is set. Must be designed into the change-detection pathway before any property sync is wired up. Retrofitting this requires touching every property application site.

3. **Session ID missing from RPC signatures** — Include a monotonically incrementing `session_id` in every spawn, despawn, component-add, and component-remove RPC from day one. Receivers reject RPCs with stale session IDs. `reset_for_new_game()` increments the counter. Retrofitting session IDs later requires changing every RPC signature in the system.

4. **Priority-tiered batching not designed upfront** — Naive per-property-change RPCs at 60Hz with 50 entities = 9,000 RPCs/second. Design the batching accumulator (entity_id → component_type → property → latest_value per priority tier) before wiring any property sync. Adding batching after the first working property sync is a near-rewrite.

5. **Node name inconsistency breaking all RPCs** — Godot routes `@rpc` calls by node path (byte-for-byte match required across all peers). Always assign `node.name = "NetworkSync"` explicitly before adding to scene tree. Add a `_ready()` guard renaming auto-generated names (begin with `"@"`). Networking silence with no errors is the failure mode.

---

## Implications for Roadmap

Based on the architecture build-order graph from ARCHITECTURE.md and the phase-specific warnings from PITFALLS.md, the suggested phase structure is:

### Phase 1: Foundation and Entity Lifecycle

**Rationale:** All subsequent work depends on entities existing across peers. The four most dangerous pitfalls (spawn timing race, session ID, sync loop, node naming) must be resolved here before any other feature is built on top of them. These pitfalls cannot be retrofitted — they require touching every RPC signature and every property application site if missed.

**Delivers:** Server can spawn/despawn entities to clients; clients connect and receive full world state; game sessions can reset without ghost entities; single-player has zero overhead.

**Addresses:** T2 (entity lifecycle sync), T3 (authority model), T6 (late-join), T7 (disconnect cleanup), T8 (zero single-player overhead), D6 (session ID anti-ghost), D1 (authority marker components).

**Avoids:** Pitfall 1 (spawn timing race), Pitfall 2 (stale RPCs), Pitfall 3 (node name inconsistency), Pitfall 7 (despawn double-free), Pitfall 8 (late-join stale positions), Pitfall 9 (sub-frame removal ghost despawn), Pitfall 15 (single-player overhead), Pitfall 17 (RPC authority mode), Pitfall 18 (call_deferred on freed entities).

**Components built:** `CN_NetworkIdentity`, `CN_LocalAuthority`, `CN_ServerAuthority`, `NetAdapter`, `TransportProvider`, `Serializer`, `SpawnManager`, `NetworkSync` (skeleton with spawn/despawn RPCs and `peer_connected`/`peer_disconnected` handlers).

### Phase 2: Component Property Sync

**Rationale:** Entities exist on all peers (Phase 1). Now make them stay synchronized. This phase introduces the highest-risk complexity (sync loops, bandwidth explosion, marker component exclusion) and the core differentiator of the declarative API (`CN_NetSync`). All three risks require upfront design — they cannot be added incrementally.

**Delivers:** Component properties sync at correct rates; bandwidth stays bounded; `@export_group` priority declaration works; locally-owned entities send their state; server sends to clients; zero feedback loops.

**Addresses:** T1 (component-level sync declaration), T4 (priority-based sync rates), T5 (reliable/unreliable transport selection), T9 (component change detection), T10 (spawn-only vs continuous modes), D3 (in-component annotation via `@export_group`).

**Avoids:** Pitfall 4 (sync loop), Pitfall 10 (bandwidth explosion from naive sync), Pitfall 11 (empty component class names), Pitfall 12 (marker components triggering sync), Pitfall 16 (model_ready_component in spawn serialization).

**Components built:** `CN_NetSync` + `SyncRule`, `SyncSender` (priority-tiered accumulator + timers), `SyncReceiver` (with `_applying_network_data` guard), batch RPCs `_sync_unreliable` / `_sync_reliable`.

### Phase 3: Authority Model and Native Sync

**Rationale:** The authority model for player-owned entities requires explicit `set_multiplayer_authority()` propagation to child nodes (Pitfall 6). The native `MultiplayerSynchronizer` setup has its own timing race (Pitfall 5). These are isolated enough to separate from core property sync but must be addressed before testing with player-controlled characters.

**Delivers:** Player-owned entities have correct input authority; `CN_LocalAuthority` marker is correctly applied; transform sync uses native interpolation; physics body authority is correctly propagated.

**Addresses:** D1 (authority markers, fully operational), D8 (authority transfer), `CN_SyncEntity` + native `MultiplayerSynchronizer` setup.

**Avoids:** Pitfall 5 (MultiplayerSynchronizer node path race), Pitfall 6 (authority not inherited by child nodes).

**Components built:** `SyncNativeHandler` (kept/ported), authority transfer RPC, `CN_RemoteEntity` / `CN_ServerOwned` marker application logic.

### Phase 4: Relationship Sync

**Rationale:** Relationships reference other entities by ID. Phase 1 must be stable (entities have consistent IDs across peers) and Phase 2 must be stable (component data syncs) before relationship serialization is meaningful. The ordering race (Pitfall 13) requires a deferred resolution queue that depends on `entity_added` signals already flowing correctly.

**Delivers:** Entity-to-entity relationships sync across peers; hierarchical queries produce consistent results on all clients; deferred resolution handles non-deterministic spawn ordering.

**Addresses:** D2 (relationship synchronization).

**Avoids:** Pitfall 13 (relationship target resolution ordering).

**Components built:** `RelationshipSync` (ported from `sync_relationship_handler.gd` with `_pending_relationships` queue), relationship add/remove RPCs.

### Phase 5: Reconciliation and Error Handling

**Rationale:** By Phase 4, the happy path works. Phase 5 adds production robustness: ghost cleanup for long sessions, server time sync for cooldown validation, and periodic full-state broadcast. These can be deferred without breaking the core use case but are required before any production deployment.

**Delivers:** Long game sessions stay in sync; ghosts are periodically cleaned up; server time is available for authoritative cooldowns; the system is production-ready.

**Addresses:** D5 (periodic full-state reconciliation), D7 (server time synchronization).

**Avoids:** Pitfall 14 (ghost entity accumulation).

**Components built:** Reconciliation loop in `NetworkSync`, `TimeSyncManager` (ping/pong time offset), `_sync_full_state` RPC.

### Phase Ordering Rationale

- **Foundation before features** — session IDs and `_applying_network_data` flag must be in the initial design; retrofitting them requires changing every RPC signature
- **Lifecycle before properties** — you cannot sync property changes for entities that don't exist on clients
- **Properties before relationships** — relationships reference entities by network ID; those entities must be spawnable and have consistent IDs first
- **Authority model between properties and relationships** — authority affects which entities participate in sync; native sync is a special case of property sync
- **Reconciliation last** — the happy path can be validated without it; adding it last means the ghost cleanup targets a stable entity registry

### Research Flags

Phases with well-documented patterns (standard implementation, skip `/gsd:research-phase`):
- **Phase 1:** All patterns implemented and commented in v0.1.1; direct port with improvements
- **Phase 2:** Batching and priority-tier patterns implemented in v0.1.1; declarative API is the main design work
- **Phase 3:** Native sync patterns implemented in v0.1.1; authority propagation is documented in code comments
- **Phase 4:** Deferred resolution pattern implemented in v0.1.1; direct port

Phases that may benefit from `/gsd:research-phase` during planning:
- **Phase 2 (CN_NetSync API design):** The exact API shape for `CN_NetSync` + `SyncRule` is the primary UX design decision of the whole project; worth a focused design session before coding
- **Phase 5 (reconciliation scalability):** At 16+ entities the full-state broadcast payload size should be estimated before implementing; may need chunking strategy

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Entire stack is Godot 4.x built-ins already validated by v0.1.1 codebase; no external dependencies to evaluate |
| Features | HIGH | Features derived from direct codebase analysis of v0.1.1; cross-validated against DOTS Netcode and bevy_replicon patterns (MEDIUM confidence for those sources, but HIGH for the "keep v0.1.1 features" conclusions) |
| Architecture | HIGH | Drawn entirely from direct codebase analysis of both GECS core and gecs_network v0.1.1; Godot RPC constraints directly observed in working code |
| Pitfalls | HIGH | Every critical and moderate pitfall is backed by implemented mitigation code in v0.1.1 with explanatory comments; these are observed bugs, not theoretical risks |

**Overall confidence: HIGH**

### Gaps to Address

- **`CN_NetSync` + `SyncRule` API shape:** The exact interface for declarative sync configuration is the core design question of v2. The ARCHITECTURE.md recommendation (Dictionary keyed by Script reference with `SyncRule` sub-resources) is a starting point but warrants a focused design review before Phase 2 coding begins. Validate that this approach is ergonomic for game developers setting up entity classes.

- **Godot 4.x `MultiplayerSynchronizer` API verification:** FEATURES.md notes that Godot multiplayer API knowledge is from training data (MEDIUM confidence). Verify `MultiplayerSynchronizer.refresh_synchronizer_visibility()` method availability in the target Godot version before depending on it in Phase 3. Run against the actual Godot binary in the repo.

- **Peer ID 0/1 ambiguity:** In v0.1.1, `peer_id=0` and `peer_id=1` both return true for `is_server_owned()`. This is a known design ambiguity (host-player who is also server). v2 should clarify this distinction; the exact semantic needs to be decided before `CN_NetworkIdentity` is written, as it affects every authority check downstream.

- **RPC batch payload size limits:** Godot's `MultiplayerAPI` has undocumented practical limits on `Dictionary` payload size. At 50+ entities with many properties in a single batch, the payload could approach limits. No hard numbers in the research. Validate empirically with a stress test before the Phase 2 batch design is finalized.

---

## Sources

### Primary (HIGH confidence)
- `addons/gecs_network/` (v0.1.1) — complete codebase analysis; all pitfall mitigations, spawn patterns, authority model, transport layer
- `addons/gecs/ecs/` — GECS core (entity.gd, component.gd, system.gd, world.gd, command_buffer.gd, observer.gd) — integration points
- `.planning/PROJECT.md` — explicit v2 constraints (GDScript only, Godot 4.x, zero single-player overhead, no backwards compat required, no client prediction)
- `addons/gecs_network/docs/architecture.md` — existing design rationale
- `addons/gecs_network/CHANGELOG.md` — validated decisions from v0.1.0 to v0.1.1

### Secondary (MEDIUM confidence)
- Unity DOTS Netcode for Entities — GhostComponent, GhostOwner, PredictedGhostComponent patterns (training data, pattern validation only)
- Bevy `bevy_replicon` — `Replicated` component, authority via `has_authority` resource (training data, pattern validation only)
- Godot 4.x MultiplayerAPI official documentation — transport options, RPC modes, MultiplayerSynchronizer API (training data — verify against live engine before implementation)

### Tertiary (LOW confidence)
- Fishnet (Unity) — NetworkBehaviour, ObserverManager, SyncVar patterns — used for cross-framework pattern validation only

---
*Research completed: 2026-03-07*
*Ready for roadmap: yes*

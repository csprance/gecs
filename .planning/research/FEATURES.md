# Feature Landscape

**Domain:** Declarative ECS Networking — Godot 4.x multiplayer synchronization layer for GECS
**Researched:** 2026-03-07
**Confidence:** HIGH (based on existing v0.1.1 codebase, ECS networking patterns from Unity DOTS Netcode, Bevy replicon, Fishnet, and Mirror)

---

## Research Basis

This document draws on:
1. Full read of the existing `gecs_network` v0.1.1 addon (the system being overhauled)
2. Knowledge of Unity DOTS Netcode for Entities patterns (component ghost replication, predicted components, snapshot interpolation)
3. Knowledge of Bevy `bevy_replicon` (component-level replication rules, authority via markers, despawn propagation)
4. Knowledge of Godot-native multiplayer patterns (MultiplayerSynchronizer, High-level API)
5. The PROJECT.md requirements for v2

The v2 goal is: replace the current middleware-heavy system with a config-driven, component-declarative approach where marking a component as networked is sufficient — no manual RPC code.

**Confidence per source:**
- Existing codebase analysis: HIGH (direct reading)
- Unity DOTS / Bevy pattern knowledge: MEDIUM (training data, ~Aug 2025 cutoff, cannot verify against current docs)
- Godot 4.x multiplayer API: MEDIUM (training data — verify against official Godot docs before implementation)

---

## Table Stakes

Features users expect from ANY ECS networking layer. Missing any of these makes the system
unusable for real games.

### T1: Component-Level Sync Declaration
**Why Expected:** The entire value proposition. Developers must be able to mark a component as "sync this" without writing serialization or RPC code. Every mature ECS networking system (DOTS Netcode Ghosts, bevy_replicon `Replicate` component, Fishnet's NetworkBehaviour) works this way.
**Complexity:** Medium
**Notes:** In v0.1.1 this requires `extends SyncComponent` and `@export_group("HIGH")` annotations. V2 should collapse this to a simpler declaration — ideally a single property on the Component class or an annotation equivalent. The `@export_group` priority encoding is clever but fragile (typos silently fall through to default).

| Detail | Requirement |
|--------|-------------|
| Declaration site | On the component class, not in a separate config file |
| Granularity | Per-property (some properties synced, some local) |
| Zero overhead | If no components are marked networked, zero networking cost |

### T2: Automatic Entity Lifecycle Sync (Spawn / Despawn)
**Why Expected:** The most common multiplayer bug is entities appearing on server but not clients, or lingering after despawn. Every usable networking layer automates this. In v0.1.1 it exists but requires `CN_NetworkIdentity` to opt-in, plus `call_deferred` timing issues are a known footgun.
**Complexity:** Medium-High
**Notes:**
- Server spawns → all clients receive spawn with full component data
- Server despawns → all clients despawn (session-ID validated to prevent ghosts)
- Late joiners receive full world state on connect
- The v0.1.1 `call_deferred` timing issue (values set after `add_entity()` required) must be solved cleanly in v2

### T3: Authority Model (Who Owns What)
**Why Expected:** Without authority, all clients would try to simulate everything and immediately diverge. Every ECS networking framework has server authority as the baseline. In v0.1.1 this is `CN_NetworkIdentity.peer_id` (0 = server, 1 = host, N = client peer).
**Complexity:** Medium
**Notes:**
- Server-authoritative as default (safest, no cheating)
- Per-entity ownership (each entity has one authoritative peer)
- Systems must be able to query authority without runtime `is_server()` calls everywhere (v0.1.1 solves this via marker components `CN_LocalAuthority`, `CN_RemoteEntity`)
- The marker component approach (query-based authority filtering) is the ECS-idiomatic solution — matches DOTS Netcode's `GhostOwner` pattern exactly. Keep this in v2.

### T4: Priority-Based Sync Rates (Bandwidth Control)
**Why Expected:** Sending every property every frame at 60Hz is prohibitive. Real games need 1Hz for inventory, 10Hz for health, 20Hz for velocity, ~60Hz for position. This is standard — DOTS Netcode has ghost importance scaling, bevy_replicon has replication rules with conditions.
**Complexity:** Medium
**Notes:** V0.1.1 has REALTIME/HIGH/MEDIUM/LOW (0/20/10/1 Hz) with reliable/unreliable transport selection per tier. This is the right model. V2 should make declaration cleaner, not change the tiers.

### T5: Reliable vs Unreliable Transport Selection
**Why Expected:** Position/velocity tolerates packet loss (unreliable ordered). Health/death/inventory must not be lost (reliable). Every networking layer exposes this distinction.
**Complexity:** Low (Godot provides both via MultiplayerAPI)
**Notes:** V0.1.1 auto-selects based on priority (HIGH = unreliable, MEDIUM/LOW = reliable). This is correct and should be preserved in v2 — the developer should rarely need to override this.

### T6: Late Join / Mid-Session Join Support
**Why Expected:** Players join after a game has started. Without late join, every networked game needs a strict "join before start" requirement. This is almost always unacceptable.
**Complexity:** High
**Notes:** V0.1.1 serializes full world state on `peer_connected` and sends it to the new peer. This works but has edge cases with large worlds. V2 should preserve this pattern but make the world-state serialization more robust.

### T7: Peer Disconnect Cleanup
**Why Expected:** When a player leaves, their entities must be removed from all other clients. Without this, disconnected player entities become ghosts.
**Complexity:** Low-Medium
**Notes:** V0.1.1 handles this in `_on_peer_disconnected` by removing all entities where `net_id.peer_id == disconnected_peer_id`. This is correct behavior.

### T8: Zero Single-Player Overhead
**Why Expected:** The framework is used for single-player games too. Networking code must not run when there is no multiplayer session. Any allocation, polling, or signal cost in single-player mode is unacceptable.
**Complexity:** Low
**Notes:** V0.1.1 guards with `net_adapter.is_in_game()`. V2 must preserve this. The guard should be at the outermost layer.

### T9: Component Change Detection (Dirty Tracking)
**Why Expected:** Only sending properties that have changed since last sync tick is fundamental bandwidth optimization. Without this, every sync tick sends every property regardless of whether it changed.
**Complexity:** Medium
**Notes:** V0.1.1 uses a `_sync_cache` dictionary in `SyncComponent` and per-property approximate comparison (`is_equal_approx` for floats/vectors, exact for others). This is correct. The comparison must handle all Godot types including packed arrays.

### T10: Spawn-Only vs Continuous Sync Modes
**Why Expected:** Projectiles and effects don't need continuous updates — they have deterministic physics after spawn. Continuous sync for every projectile would flood the network. Both Bevy replicon and DOTS Netcode support "fire-and-forget" replication vs continuous replication.
**Complexity:** Low (declaration difference only)
**Notes:** V0.1.1 uses presence/absence of `CN_SyncEntity` to toggle modes. This is clean. V2 should keep this distinction but make it more explicit in the declaration.

---

## Differentiators

Features that separate GECS Networking from writing raw Godot multiplayer code, or from other ECS networking solutions. Not universally expected but highly valuable.

### D1: Declarative Authority Marker System
**Value Proposition:** Systems express authority requirements in their query, not in runtime code. A movement system that queries `with_all([C_Velocity, CN_LocalAuthority])` automatically skips remote entities without a single `if is_server()` check. This is the ECS-native way to handle authority.
**Complexity:** Low (marker components are trivial; query system already supports this)
**Notes:** V0.1.1 has this (`CN_LocalAuthority`, `CN_RemoteEntity`, `CN_ServerAuthority`, `CN_ServerOwned`) and it is the best differentiator in the system. Preserve and document prominently in v2. Matches DOTS Netcode's `GhostOwner`/`GhostAuthoredComponent` declarative model.

### D2: Relationship Synchronization
**Value Proposition:** GECS relationships (entity-to-entity links with typed components) are a core feature of the ECS. Being able to sync these across peers without manual code is unique — no other Godot ECS networking layer has this.
**Complexity:** High
**Notes:** V0.1.1 implements this via "creation recipes" (serialize relationship component + target reference, deserialize on client). Deferred entity resolution handles the case where the target entity hasn't spawned yet on the receiving peer. This is genuinely complex but worth keeping. V2 should ensure the API surface is clean.

### D3: Priority-Grouped Property Declaration (In-Component Annotation)
**Value Proposition:** Declaring sync priority per property group using `@export_group("HIGH")` keeps the data model and the sync policy in the same file. It's more maintainable than a separate config dictionary.
**Complexity:** Low-Medium
**Notes:** V0.1.1 introduced this in `SyncComponent`. The approach is good but the parsing logic needs to be robust (case sensitivity, unknown group names). V2 should validate group names at load time rather than silently falling through to default.

### D4: Transport Provider Abstraction
**Value Proposition:** Games that ship on Steam need GodotSteam's networking. Games on other platforms need ENet. Being able to swap transports without changing game code is a significant DX win.
**Complexity:** Medium (abstraction already exists in v0.1.1)
**Notes:** V0.1.1 has `transport_provider.gd` with ENet and Steam implementations. V2 should clean up the interface — the current v0.1.1 implementation is new (added in 0.1.1) and may have rough edges.

### D5: Periodic Full-State Reconciliation
**Value Proposition:** Over time, floating-point drift and lost reliable packets can cause state divergence between peers. A periodic "broadcast full state" corrects this without the developer knowing it happened.
**Complexity:** Medium
**Notes:** V0.1.1 has configurable `reconciliation_interval` (default 30s). This is a real differentiator — most simple multiplayer setups don't have reconciliation and accumulate bugs over long sessions.

### D6: Session ID Anti-Ghost Protection
**Value Proposition:** When a game resets and restarts, stale in-flight RPCs from the previous session can spawn entities in the new session. Session IDs prevent this class of ghost-entity bug.
**Complexity:** Low
**Notes:** V0.1.1 implements this. It is invisible to the developer but prevents a real class of subtle bugs. Keep in v2.

### D7: Server Time Synchronization
**Value Proposition:** For game logic that depends on synchronized timestamps (cooldown validation, event ordering), clients need a shared time reference. V0.1.1 implements NTP-style ping/pong time sync.
**Complexity:** Medium
**Notes:** This is a differentiator because most simple networking layers don't provide this. Required for any server-authoritative cooldown or timed event system. In v2 this should be exposed as a clean API (`network_sync.get_server_time()`) rather than internal state.

### D8: Authority Transfer at Runtime
**Value Proposition:** Vehicle enter/exit, item pickup, boss handoff — these require transferring who controls an entity. V0.1.1 has `transfer_authority(entity, new_peer_id)`. This is common in games but often missing from simple networking layers.
**Complexity:** Medium
**Notes:** The transfer must be server-initiated, validated, and broadcast to all peers atomically. V0.1.1 handles this.

### D9: NetAdapter Abstraction Layer
**Value Proposition:** The addon does not depend directly on Godot's global `multiplayer` singleton. Instead it goes through `NetAdapter` which can be stubbed in tests or replaced for custom multiplayer APIs. This makes the system testable and future-proof.
**Complexity:** Low
**Notes:** V0.1.1 has this. Testing networked systems without running two Godot instances is a significant DX benefit. V2 should preserve and document this for test authors.

---

## Anti-Features

Features to explicitly NOT build for v2. Either they belong in v3, they conflict with the v2 goals, or they add complexity that is disproportionate to their value at this stage.

### A1: Client-Side Prediction / Lag Compensation
**Why Avoid:** This is explicitly listed as out-of-scope in PROJECT.md for v2. Client prediction fundamentally changes the architecture (rollback, reconciliation loop, input buffering) and requires a full separate milestone to do correctly. Half-baked prediction is worse than none.
**What to Do Instead:** Document the spawn-only pattern for projectiles (no prediction, server-authoritative spawn). Server authority feels fine at LAN latency and reasonable for up to ~100ms WAN. Flag as v3 target.

### A2: P2P / Peer-to-Peer Networking
**Why Avoid:** PROJECT.md explicitly scopes to server-client only. P2P requires host migration, split authority models, and relay servers. This is a fundamentally different networking topology.
**What to Do Instead:** Ensure the `NetAdapter` abstraction doesn't preclude P2P in the future (don't hardcode assumptions about `is_server()` being the only authority). Keep the door open architecturally.

### A3: Built-In Lobby / Matchmaking
**Why Avoid:** Out of scope. GECS Networking is an in-game sync layer, not a session management system. Coupling it to lobbies or matchmaking would destroy reusability across projects.
**What to Do Instead:** Document that `NetworkSync.reset_for_new_game()` is the integration point between a lobby system and the networking layer.

### A4: Backwards Compatibility with v0.1.1
**Why Avoid:** PROJECT.md explicitly states "clean break, no backwards compatibility required." Trying to maintain compatibility would constrain the v2 design. The current v0.1.1 API has known rough edges (SyncConfig manual config, middleware pattern, timing footguns) that should be fixed cleanly.
**What to Do Instead:** Provide a migration guide in the v2 docs.

### A5: Automatic Serialization of Non-Export Properties
**Why Avoid:** Non-`@export` properties may contain Entity references, node references, or other non-serializable data. Auto-serializing them would require a full reflection system and would silently corrupt data. The rule "only `@export` properties sync" is a good constraint.
**What to Do Instead:** Document clearly in v2 that sync only applies to `@export` properties. Provide runtime warnings when a developer tries to sync a non-exportable type.

### A6: Networked Physics Simulation (Deterministic Physics)
**Why Avoid:** Deterministic physics across peers requires fixing floating-point behavior, physics step order, and random seeds — this is an engine-level concern, not an addon concern. Godot's physics engine is not deterministic across platforms.
**What to Do Instead:** Document the correct pattern: server simulates physics authoritatively, `CN_SyncEntity` + native MultiplayerSynchronizer syncs position/rotation to clients at ~60Hz with interpolation.

### A7: Automatic Interest Management / Spatial Culling
**Why Avoid:** Interest management (only sync entities near the player) is a performance optimization for large worlds that adds significant complexity to the spawn/despawn lifecycle. V2 should expose the hooks (`public_visibility` flag on `CN_SyncEntity`) but not implement policy.
**What to Do Instead:** Document the `public_visibility = false` + Godot MultiplayerSynchronizer visibility filter approach as the extension point. Leave the policy to game code.

### A8: Message/Event RPC System
**Why Avoid:** GECS Networking v2 is a state synchronization layer, not an event messaging layer. Adding a general-purpose RPC message bus would compete with game code's own RPC needs and blur the line between the addon and the game.
**What to Do Instead:** State changes in components are the v2 message bus. If a developer needs fire-and-forget events, they write one targeted RPC. Document this pattern explicitly.

---

## Feature Dependencies

```
T1 (Component-Level Sync Declaration)
    └── T4 (Priority-Based Sync Rates)
    └── T5 (Reliable vs Unreliable Transport)
    └── T9 (Component Change Detection)

T2 (Entity Lifecycle Sync)
    └── T3 (Authority Model) — only server broadcasts spawns
    └── T6 (Late Join) — world state = all current spawns
    └── T7 (Peer Disconnect Cleanup)
    └── D6 (Session ID Anti-Ghost)

T3 (Authority Model)
    └── D1 (Declarative Authority Marker System) — markers are derived from authority
    └── D8 (Authority Transfer)

T1 + T2 + T3 → D2 (Relationship Sync) — requires component sync + lifecycle + authority to work

D7 (Server Time Sync) — independent, but enables server-authoritative cooldowns

D4 (Transport Provider) — independent of core sync, wraps the multiplayer API

D5 (Full-State Reconciliation) → T6 (Late Join) — same world serialization path
```

---

## MVP Recommendation

A v2 that delivers the table stakes cleanly and improves on the v0.1.1 rough edges.

**Must build:**
1. T1 — Component-level sync declaration with cleaner API than `extends SyncComponent` + `@export_group`
2. T2 — Entity lifecycle sync (fixed: no more timing footgun with `add_entity()` ordering)
3. T3 — Authority model with declarative marker components
4. T4 + T5 — Priority rates and reliable/unreliable selection (keep v0.1.1 tiers)
5. T6 — Late join (preserve v0.1.1 world state serialization)
6. T7 + T8 — Disconnect cleanup and zero single-player overhead
7. T9 — Change detection (preserve v0.1.1 approximate comparison logic)
8. T10 — Spawn-only vs continuous modes (preserve v0.1.1 `CN_SyncEntity` toggle)
9. D1 — Authority markers (keep, this is the best feature of v0.1.1)
10. D6 — Session ID anti-ghost (keep, no DX cost, prevents real bug class)

**Should build (high ROI):**
- D2 — Relationship sync (unique differentiator, already implemented in v0.1.1, carry forward)
- D5 — Reconciliation (low implementation cost, high reliability benefit)
- D7 — Server time sync (required for server-authoritative cooldowns in any real game)
- D9 — NetAdapter abstraction (required for testability)

**Defer to v3:**
- D3 — In-component annotation (can improve DX incrementally, not blocking)
- D4 — Transport provider polish (v0.1.1 has it, may just need cleanup)
- D8 — Authority transfer (present in v0.1.1, carry forward but not priority for v2 redesign)
- A1 — Client prediction (explicitly deferred in PROJECT.md)

**Explicitly exclude:**
- A2, A3, A4, A5, A6, A7, A8 (see Anti-Features above)

---

## Complexity Notes by Feature

| Feature | Complexity | Primary Risk |
|---------|------------|--------------|
| T1 Component sync declaration | Medium | API design: how to declare without boilerplate |
| T2 Entity lifecycle sync | Medium-High | Timing: deferred spawn broadcast footgun; late join edge cases |
| T3 Authority model | Medium | Peer ID semantics (0=server, 1=host ambiguity in v0.1.1) |
| T4 Priority rates | Low | Already solved in v0.1.1 |
| T5 Reliable/unreliable | Low | Godot provides this natively |
| T6 Late join | High | Large worlds; race conditions; relationship graph rebuild |
| T7 Disconnect cleanup | Low-Medium | Entity ownership tracking |
| T8 Zero single-player overhead | Low | Guard at process entry point |
| T9 Change detection | Medium | Approximate comparison correctness for all Godot types |
| T10 Spawn-only vs continuous | Low | Declaration only |
| D1 Authority markers | Low | Query system already supports this |
| D2 Relationship sync | High | Creation recipes; deferred resolution; spawn payloads |
| D3 In-component annotation | Medium | GDScript reflection; parse robustness |
| D4 Transport provider | Medium | Interface design; Steam integration not in GECS repo |
| D5 Reconciliation | Medium | Full-state serialization scalability |
| D6 Session IDs | Low | Counter management |
| D7 Server time sync | Medium | NTP-style ping/pong; RTT estimation |
| D8 Authority transfer | Medium | Atomic broadcast; ordering guarantees |
| D9 NetAdapter abstraction | Low | Interface already designed in v0.1.1 |

---

## Known Gaps in v0.1.1 That v2 Must Address

These are not new features but required fixes that inform what "table stakes" means:

1. **`add_entity()` timing footgun** — Developers must set component values AFTER `add_entity()`. If they do it before, values are overwritten by `define_components()`. V2 must either fix this ordering constraint or make it impossible to violate.
2. **SyncConfig boilerplate** — Every project must create a `ProjectSyncConfig` subclass and register every component by name. If a component is forgotten, it silently syncs at MEDIUM priority (or not at all if filtering is wrong). V2 should make this opt-in from the component side, not require a central registry.
3. **Peer ID 0/1 ambiguity** — In v0.1.1, peer_id=0 and peer_id=1 both count as "server-owned" (`is_server_owned()` returns true for both). This is confusing: peer_id=1 is the host *player* who also acts as server. V2 should clarify this distinction.
4. **Model instantiation via SyncConfig** — The `model_component`, `character_body_component`, `animation_rig_component` strings in SyncConfig are a code smell. The networking layer should not know about game-specific node structures. V2 should remove these and provide hooks/signals instead.
5. **Middleware pattern is still needed but could be cleaner** — The `NetworkMiddleware` pattern is the right separation but requires boilerplate. V2 signals (`entity_spawned`, `local_player_spawned`) should be sufficient without needing a named middleware class.

---

## Sources

- Existing codebase: `addons/gecs_network/` (v0.1.1) — HIGH confidence, direct read
- Unity DOTS Netcode for Entities: GhostComponent, GhostOwner, PredictedGhostComponent patterns — MEDIUM confidence (training data, not verified against current Unity docs)
- Bevy `bevy_replicon` crate: `Replicated` component, `RepliconChannel`, authority via `has_authority` resource — MEDIUM confidence (training data)
- Godot 4.x MultiplayerSynchronizer, MultiplayerAPI docs — MEDIUM confidence (training data — verify before implementation)
- Fishnet (Unity): NetworkBehaviour, ObserverManager, SyncVar patterns — LOW confidence (training data only, used for pattern validation)

# Technology Stack

**Project:** GECS Networking v2 — Declarative ECS Networking
**Researched:** 2026-03-07
**Confidence:** HIGH (based on direct codebase analysis of existing gecs_network v0.1.1 + Godot 4.x API knowledge)

---

## Context: What Already Exists

The `addons/gecs_network` addon (v0.1.1) is a functional but complex networking layer. This research
targets what the v2 rewrite needs to keep, replace, and add. The existing stack is the primary
evidence source — it has already validated which Godot 4 APIs work in practice.

### Existing validated stack (keep as-is)

| Component | What It Is | Keep? |
|-----------|-----------|-------|
| `MultiplayerAPI` / `SceneMultiplayer` | Godot's built-in RPC system | YES — proven |
| `ENetMultiplayerPeer` | UDP transport (built into Godot 4) | YES — default transport |
| `MultiplayerSynchronizer` | Native node-level property sync | YES — handles transform |
| `@rpc` decorator | RPC method declaration | YES — required by Godot |
| `NetAdapter` class | Wraps `MultiplayerAPI` to decouple transport | YES — architecture win |
| `TransportProvider` base class | Pluggable peer creation (ENet/Steam) | YES — keep abstraction |
| `SyncConfig` resource | Priority/rate configuration | REPLACE — becomes per-component annotation |
| `NetworkSync` orchestrator node | Central RPC hub + handler delegation | REDESIGN |
| `SyncComponent` base class | `@export_group` priority parsing | REDESIGN — simplify |
| `CN_NetworkIdentity` component | Peer ID + authority logic | KEEP — solid design |
| `CN_LocalAuthority` / `CN_ServerAuthority` | Marker components for query filtering | KEEP |

---

## Recommended Stack for v2

### Layer 1: Transport (No Change)

Godot 4 ships three built-in transport options. v1 already validated ENet.

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `ENetMultiplayerPeer` | Godot 4.x built-in | Default UDP transport | Already validated in v0.1.x; zero external dependencies; reliable + unreliable channels built in |
| `OfflineMultiplayerPeer` | Godot 4.x built-in | Single-player passthrough | Zero overhead when not networked — satisfies PROJECT.md constraint |
| `WebRTCMultiplayerPeer` | Godot 4.x built-in | Browser / P2P future path | Out of scope for v2 but the `TransportProvider` abstraction preserves the path |

**Keep** `TransportProvider` base class and `ENetTransportProvider`. The abstraction costs nothing and the Steam transport already exists. Do not remove it for a clean break.

### Layer 2: RPC Routing (Minimal Change)

Godot requires `@rpc` methods to live on a Node in the scene tree. This constraint is proven by
v0.1.x — it is not negotiable without switching to a completely custom socket layer (out of scope).

| Technology | Purpose | Why |
|------------|---------|-----|
| `@rpc("authority", "reliable")` | Spawn, despawn, authority transfer, full-state reconciliation | Guaranteed delivery; order matters |
| `@rpc("any_peer", "unreliable_ordered")` | High-frequency component property updates (position, velocity) | Drop tolerance acceptable; newer packet supersedes |
| `@rpc("any_peer", "reliable")` | Component add/remove, relationship sync | Must not be lost |
| `@rpc("authority", "unreliable")` | Server time ping/pong | Latency measurement only |

**Keep** the handler delegation pattern from v0.1.x: all `@rpc` stubs live on one `NetworkSync`
node, inner logic lives in dedicated handler objects. This is the only way to satisfy Godot's
RPC routing requirement while keeping files manageable.

**Change**: consolidate the 11 individual `@rpc` stubs. v2 should use fewer, more generic RPCs
(e.g., `_sync_batch(data: Dictionary)` with a `type` key) to reduce the number of RPC
registrations, which improves late-join handshake speed.

### Layer 3: Property Synchronization (Redesign)

The v0.1.x `SyncComponent` base class works but has friction: developers must inherit from
`SyncComponent` instead of `Component`, and the `@export_group("HIGH")` convention is implicit.

For v2, move sync configuration to the component itself via a declarative annotation pattern:

| Technology | Purpose | Why |
|------------|---------|-----|
| `Component` base class (existing) | All components remain plain `Component` | No forced inheritance from `SyncComponent`; cleaner ECS design |
| Per-property sync metadata | Dictionary/annotation on `@export` vars | Developer declares intent at the property level, not at the class level |
| `get_property_list()` + `get_script().get_script_property_list()` | Runtime property introspection | Already proven in v0.1.x `SyncComponent._parse_property_priorities()` |

GDScript does not support custom annotations (as of Godot 4.x). The `@export_group` naming
convention from v0.1.x is the closest available mechanism and should be retained. The alternative
— a separate sync-config dictionary on each component class — requires more boilerplate than the
group convention.

**Keep** `@export_group("HIGH|MEDIUM|LOW|LOCAL|REALTIME")` as the sync priority declaration.
The v0.1.x implementation of this pattern is correct and should be ported directly.

### Layer 4: Entity Lifecycle Sync (Redesign)

v0.1.x spawn/despawn is functional but fragile (stale session IDs, deferred-broadcast race
conditions, double-spawn guards). v2 should keep the architecture but harden the protocol.

| Technology | Purpose | Why |
|------------|---------|-----|
| `entity.scene_file_path` | Scene-based spawn (for entities with nodes) | Godot's native scene system; clients load same scene |
| `Entity.new()` + component data | Programmatic spawn (for pure-data entities) | Already works in v0.1.x |
| `Component.serialize()` | Snapshot component state for spawn payload | Existing GECS serialization; proven reliable |
| `ResourceLoader.exists(path)` + `res://` prefix guard | Script/scene path validation | Security requirement — already implemented, keep it |
| Session ID monotonic counter | Stale spawn/despawn rejection | Already proven in v0.1.x; keep exact pattern |

### Layer 5: Authority Model (Keep)

v0.1.x `CN_NetworkIdentity` with `peer_id` + `set_multiplayer_authority()` is correct. Godot's
`Node.set_multiplayer_authority(peer_id)` is the authoritative API for RPC routing direction.

| Technology | Purpose | Why |
|------------|---------|-----|
| `Node.set_multiplayer_authority(peer_id)` | Routes RPCs to/from correct peer | Required by Godot's RPC system |
| `CN_NetworkIdentity.has_authority()` | Clean authority check in systems | Adapter pattern isolates `MultiplayerAPI` calls |
| `CN_LocalAuthority` / `CN_ServerAuthority` marker components | ECS query-level authority filtering | ECS-idiomatic; avoids network checks in query hot paths |
| `NetAdapter.is_server()` | Authority determination | Decoupled from `multiplayer.is_server()` for testability |

**Do not change** `CN_NetworkIdentity`, `CN_LocalAuthority`, or `CN_ServerAuthority`. These are
correct and stable.

### Layer 6: Native Transform Sync (Keep)

Godot's `MultiplayerSynchronizer` node handles transform interpolation natively. v0.1.x already
uses this for `CN_SyncEntity`. The native path avoids per-frame RPC overhead for the most
frequently-synced data.

| Technology | Purpose | Why |
|------------|---------|-----|
| `MultiplayerSynchronizer` | Per-node property sync with interpolation | Built-in interpolation; Godot handles delta compression |
| `CN_SyncEntity` component | Configures `MultiplayerSynchronizer` target and properties | ECS-friendly wrapper around native node |
| `sync_native_handler.gd` | Runtime `MultiplayerSynchronizer` setup | Already handles timing race (model must exist before sync node) |

**Keep** the two-tier sync architecture from v0.1.x: native sync for transform, RPC batching
for component data. This is architecturally correct.

### Layer 7: Serialization (Existing GECS)

v0.1.x relies on `Component.serialize()` for spawn snapshots and `get()` / `set()` for property
sync. This is correct — GECS already provides serialization infrastructure.

| Technology | Purpose | Why |
|------------|---------|-----|
| `Component.serialize()` (existing GECS) | Full component snapshot for spawn payloads | Handles all `@export` property types |
| `get(prop_name)` / `set(prop_name, value)` | Property-level sync (hot path) | GDScript native; no reflection overhead |
| `is_equal_approx()` for floats/vectors | Change detection without float precision noise | Already proven in `SyncComponent._has_changed()` |

**Do not reinvent** component serialization. The existing `Component.serialize()` + `@export`
convention is sufficient.

---

## What NOT to Use

| Rejected Technology | Why Not |
|---------------------|---------|
| Custom TCP/UDP sockets | Godot's `MultiplayerAPI` already abstracts this; custom sockets would require reimplementing RPC routing |
| WebSocket transport | Higher overhead than ENet for game state; ENet's unreliable channel is better for position sync |
| GodotSteam (as default) | Optional transport only — Steam SDK dependency makes the core addon non-portable |
| `MultiplayerSpawner` node | Conflicts with GECS's world-managed entity lifecycle; tested in v0.1.x and abandoned in favor of manual RPC spawns |
| Custom binary serialization | GDScript `Dictionary` → Godot's variant serializer is adequate for game state; not a bottleneck at typical player counts |
| GDNative/C++ extension for networking | Violates PROJECT.md constraint: GDScript only |
| Client-side prediction | Explicitly out of scope (PROJECT.md) |
| P2P / WebRTC | Explicitly out of scope (PROJECT.md) |

**On `MultiplayerSpawner`:** Godot 4's `MultiplayerSpawner` is designed for scene-tree spawning
but requires a fixed spawn node path and does not integrate with GECS's `World.add_entity()`
lifecycle. v0.1.x already proved manual RPC spawning is more controllable for ECS. Do not
revisit this.

---

## Integration Points with Existing GECS Core

| GECS Core API | How Networking v2 Uses It |
|---------------|--------------------------|
| `World.entity_added` signal | Trigger spawn broadcast on server |
| `World.entity_removed` signal | Trigger despawn broadcast on server |
| `World.component_added` signal | Trigger component sync, update sync index |
| `World.component_removed` signal | Trigger component removal RPC |
| `World.relationship_added` signal | Trigger relationship sync |
| `World.entities` array | World state serialization for late join |
| `World.entity_id_registry` dict | Entity lookup by network ID |
| `Entity.add_component()` | Apply received components on client |
| `Entity.remove_component()` | Apply received removals on client |
| `Entity.get_component()` | Authority checks, sync filtering |
| `Component.serialize()` | Spawn payload serialization |
| `entity.component_property_changed` signal | Change detection for continuous sync |
| `CommandBuffer` | Safe structural changes during iteration (use for network-driven changes) |

**The networking layer should never bypass `World.add_entity()` / `World.remove_entity()`.**
All entity lifecycle changes must go through the World so ECS indexing stays consistent.

---

## v2 Stack Delta Summary

What changes from v0.1.x to v2:

| Area | v0.1.x | v2 |
|------|--------|-----|
| Sync configuration | External `SyncConfig` resource with `component_priorities` dict | Per-component `@export_group` annotation (already exists in `SyncComponent`); no external config needed for basic cases |
| Component base class | Must extend `SyncComponent` for auto-sync | Extend plain `Component`; opt into sync via `@export_group` without base class change |
| RPC surface area | 11 individual `@rpc` stubs | Fewer generic batch RPCs |
| World state sync trigger | Manual `SyncConfig.model_ready_component` string | Declarative component flag or automatic detection |
| SyncConfig complexity | 15+ export vars for model, animation, body references | Remove model-specific configuration; projects handle post-spawn setup via signals |
| Testing | Tests exist but incomplete | Expand to cover v2 declarative API |

What stays identical:

- `ENetTransportProvider` / `TransportProvider` abstraction
- `NetAdapter` + `MultiplayerAPI` wrapper
- `CN_NetworkIdentity` authority model
- `CN_LocalAuthority` / `CN_ServerAuthority` markers
- Two-tier sync (native transform + RPC component data)
- Session ID for stale RPC rejection
- `res://` path validation for security
- Handler delegation pattern (keep files manageable)
- `CommandBuffer` integration for network-driven structural changes

---

## Installation

No new packages. All technologies are Godot 4.x built-ins or existing GECS code.

```bash
# No npm, no external dependencies.
# GECS Networking v2 is pure GDScript using Godot 4.x built-ins:
# - MultiplayerAPI (SceneMultiplayer)
# - ENetMultiplayerPeer
# - MultiplayerSynchronizer
# All from: godotengine.org/download
```

Godot version requirement: 4.2+ (for stable `MultiplayerSynchronizer` + UID file support).
The project uses Godot 4.x with UID files (.uid) present on all scripts confirming 4.2+.

---

## Sources

- `addons/gecs_network/` codebase (v0.1.1) — direct analysis, HIGH confidence
- `addons/gecs_network/docs/architecture.md` — existing design rationale
- `addons/gecs_network/CHANGELOG.md` — validated decisions from v0.1.0 → v0.1.1
- `.planning/PROJECT.md` — explicit constraints (GDScript only, Godot 4.x, zero single-player overhead)
- Godot 4.x `MultiplayerAPI`, `ENetMultiplayerPeer`, `MultiplayerSynchronizer` — standard engine APIs, HIGH confidence

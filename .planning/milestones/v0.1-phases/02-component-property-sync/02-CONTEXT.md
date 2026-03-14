# Phase 2: Component Property Sync — Context

**Gathered:** 2026-03-08
**Status:** Ready for research and planning

<domain>
## Phase Boundary

Wire priority-tiered batched property sync into the Phase 1 NetworkSync skeleton. Components that
should be continuously synced declare their sync rate via `@export_group` annotations on plain
`extends Component` classes. Only changed properties are sent each tick. Entities without CN_NetSync
are spawn-only. Phase 2 does NOT include native transform sync (Phase 3) or relationship sync
(Phase 4).

</domain>

<decisions>
## Implementation Decisions

### How Components Opt In to Property Sync

- Game components stay as plain `extends Component` — no subclassing required
- Developer adds `CN_NetSync` component to the entity to enable continuous property sync
- CN_NetSync automatically scans all other components on the entity for `@export_group`
  annotations matching the known priority names (REALTIME / HIGH / MEDIUM / LOW / SPAWN_ONLY / LOCAL)
- Properties under a recognized group are synced at that rate; properties outside any named group
  default to HIGH priority
- `CN_SyncEntity` is removed — CN_NetSync replaces its role as the "continuous sync" marker

**Developer workflow:**
```gdscript
class_name C_Health
extends Component          # plain Component, unchanged

@export_group("MEDIUM")    # CN_NetSync reads this annotation
@export var health: int = 100

@export_group("LOW")
@export var max_health: int = 100

@export_group("LOCAL")     # never synced, local-only
@export var _ui_flash: bool = false
```

```gdscript
# Entity setup:
entity.add_component(CN_NetworkIdentity.new(peer_id))
entity.add_component(CN_NetSync.new())   # enables continuous sync scanning
entity.add_component(C_Health.new())
```

### Spawn-Only Declaration

- `@export_group("SPAWN_ONLY")` — properties under this group are included in the spawn payload
  (via SpawnManager.serialize_entity) and are NEVER included in continuous sync batches
- Entities WITHOUT a CN_NetSync component are fully spawn-only (all their components are serialized
  at spawn, no continuous sync ticking)
- This preserves the v0.1.1 pattern: absence of the continuous-sync marker = spawn-only

**Example:**
```gdscript
class_name C_ProjectileConfig
extends Component

@export_group("SPAWN_ONLY")    # sent once at spawn, never re-synced
@export var damage: float = 25.0
@export var speed: float = 500.0
```

### SyncConfig Fate

- `sync_config.gd` is DELETED entirely
- `sync_component.gd` is DELETED (replaced by CN_NetSync)
- `components/cn_sync_entity.gd` is DELETED (replaced by CN_NetSync presence)
- The `Priority` enum (REALTIME / HIGH / MEDIUM / LOW) moves into `CN_NetSync`
- Tests for SyncConfig and SyncComponent are also deleted

### Sync Rate Configuration

- Sync intervals are configurable via Godot Project Settings, registered by the plugin
- Settings path: `gecs_network/sync/`
- Keys: `high_hz` (default 20), `medium_hz` (default 10), `low_hz` (default 2)
- REALTIME has no hz setting — it syncs every frame
- CN_NetSync reads these at startup and computes intervals:
  - `REALTIME_INTERVAL = 0.0` (every frame)
  - `HIGH_INTERVAL = 1.0 / ProjectSettings.get("gecs_network/sync/high_hz")`
  - `MEDIUM_INTERVAL = 1.0 / ProjectSettings.get("gecs_network/sync/medium_hz")`
  - `LOW_INTERVAL = 1.0 / ProjectSettings.get("gecs_network/sync/low_hz")`
- plugin.gd registers these with `add_project_setting()` in `_enter_tree()`

### Architecture: SyncSender and SyncReceiver

Following the SpawnManager pattern from Phase 1:
- `SyncSender` — RefCounted helper, holds `_pending_updates_by_priority`, drives timer logic,
  calls `_sync_components_reliable.rpc()` / `_sync_components_unreliable.rpc()`
- `SyncReceiver` — RefCounted helper, validates authority, applies received data to entities,
  sets `_applying_network_data` flag during apply

NetworkSync delegates to SyncSender/SyncReceiver via `_sender`/`_receiver` references (same
pattern as `_spawn_manager`). NetworkSync remains the only node with `@rpc` methods.

Two new RPCs added to NetworkSync:
```gdscript
@rpc("any_peer", "unreliable_ordered")
func _sync_components_unreliable(batch: Dictionary) -> void: ...

@rpc("any_peer", "reliable")
func _sync_components_reliable(batch: Dictionary) -> void: ...
```

REALTIME and HIGH use unreliable_ordered (low latency, tolerate drops).
MEDIUM and LOW use reliable (bandwidth efficiency, guaranteed delivery).

### Claude's Discretion

- Exact CN_NetSync scanning implementation (property iteration, caching after first scan)
- Dirty tracking cache structure (per-component, keyed by instance ID or component type)
- How `update_cache_silent()` works when applying received data (suppress sync-loop)
- Error handling when a component has `@export_group` with an unrecognized name
- Whether SyncSender polls CN_NetSync directly or subscribes to a signal
- Batch format on the wire: `{ entity_id: { comp_type: { prop: value } } }`
  (same as v0.1.1 — keep for simplicity)

</decisions>

<specifics>
## Specific Ideas

- `C_NetPosition` in `example_network/` is a plain `extends Component` with no group annotations.
  After Phase 2, it should add `@export_group("HIGH")` to get continuous sync of its position.
- `SyncComponent._has_changed()` has excellent float/vector/transform approximate comparison logic —
  this should be preserved verbatim in CN_NetSync (or a shared utility)
- The v0.1.1 `queue_relay_data()` pattern (server relays client updates to all peers) must be
  preserved — clients send owned-entity updates to server, server relays to all clients
- `should_broadcast()` logic must remain: server broadcasts all, client broadcasts only owned entities
- CN_NetworkIdentity sync must be blocked: server must reject any client attempt to sync
  CN_NetworkIdentity properties (prevents peer_id/ownership spoofing)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `sync_property_handler.gd` — v0.1.1 full send/receive implementation. Highly reusable as the
  basis for SyncSender + SyncReceiver. Contains: `update_sync_timers()`,
  `send_pending_updates_batched()`, `poll_sync_components_for_priority()`,
  `handle_apply_sync_data()`, `queue_relay_data()`. Read this carefully before implementing.
- `SyncComponent._has_changed()` — type-aware approximate comparison for float/vector/transform.
  Move into CN_NetSync or a shared utility; do not rewrite.
- `SyncComponent._deep_copy()` — value-type-aware deep copy for the dirty cache. Reuse.
- `SyncComponent._parse_property_priorities()` — @export_group scanner. Adapt into CN_NetSync.

### Phase 1 Integration Points (from network_sync.gd)

- Line 126: `# Phase 2+ will add property sync ticking here` — this is where SyncSender.tick()
  is called from `_process(delta)`
- Three critical invariants must NOT regress: `_applying_network_data`, node name, session_id in RPCs
- SpawnManager is already wired — SyncSender/SyncReceiver follow the same delegation pattern
- `_apply_component_data()` in SpawnManager must set `_applying_network_data = true` before
  applying and `false` after — SyncReceiver's apply path uses the same flag

### Files to Delete

- `addons/gecs_network/sync_config.gd`
- `addons/gecs_network/sync_component.gd`
- `addons/gecs_network/components/cn_sync_entity.gd`
- `addons/gecs_network/tests/test_sync_config.gd`
- `addons/gecs_network/tests/test_sync_component.gd` (if it exists and tests SyncComponent directly)
- `addons/gecs_network/tests/test_cn_sync_entity.gd` (if it exists)

### Files to Create

- `addons/gecs_network/components/cn_net_sync.gd` — new core component (Priority enum, @export_group
  scanner, dirty cache, check_changes_for_priority())
- `addons/gecs_network/sync_sender.gd` — new RefCounted, timer logic + batch sending
- `addons/gecs_network/sync_receiver.gd` — new RefCounted, authority validation + apply

### Files to Modify

- `addons/gecs_network/network_sync.gd` — wire _sender/_receiver, add 2 RPCs, update _process()
- `addons/gecs_network/plugin.gd` — register gecs_network/sync/* ProjectSettings

### Known Gotcha

- New `class_name` GDScript files require `godot --headless --import` to generate `.uid` files
  before the CLI test runner can resolve them. Do this after creating CN_NetSync, SyncSender,
  SyncReceiver.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-component-property-sync*
*Context gathered: 2026-03-08*

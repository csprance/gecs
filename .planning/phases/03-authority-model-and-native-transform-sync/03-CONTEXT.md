# Phase 3: Authority Model and Native Transform Sync - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Add authority marker components (`CN_LocalAuthority` / `CN_ServerAuthority`) to entities automatically at spawn/late-join, and wire Godot's native `MultiplayerSynchronizer` for position/rotation sync with built-in interpolation. Authority is assigned at spawn time only — mid-game transfer is out of scope. Phase 3 also deletes the deprecated `CN_ServerOwned` component and legacy v0.1.1 handlers.

</domain>

<decisions>
## Implementation Decisions

### Entity node type and CN_NativeSync target

- Entities in GECS are whatever scene root the developer uses (CharacterBody3D, Node3D, Node2D, plain Node) — the Entity script is attached by "Extend" in Godot's scene editor
- `CN_NativeSync` must NOT assume the entity IS a Node3D/Node2D
- CN_NativeSync exposes a configurable `root_path` export (default: `".."` = the entity node itself)
  - For CharacterBody3D entities (most common): root_path stays `".."`
  - For entities where position lives on a sub-node: set root_path to that node's name
- Default sync targets: `sync_position = true`, `sync_rotation = true`
- replication_interval is a direct export on CN_NativeSync (float, default 0.0 = every frame) — not tied to CN_NetSync's priority tier Project Settings

### Replication mode

- Default replication mode: `REPLICATION_MODE_ALWAYS` (sends every interval regardless of changes)
- Mode is overridable per-entity via `@export var replication_mode: int` on CN_NativeSync
- Fixed ALWAYS is NOT hardcoded — developers can set ON_CHANGE for mostly-static entities
- ALWAYS is the right default for moving entities (players, projectiles) where Godot's interpolation needs steady updates

### CN_NativeSync component shape

```gdscript
class_name CN_NativeSync
extends Component

@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var root_path: NodePath = ".."          # target node; ".." = entity node itself
@export var replication_interval: float = 0.0   # 0.0 = every frame
@export var replication_mode: int = 1           # 1 = REPLICATION_MODE_ALWAYS
```

### CN_ServerOwned cleanup

- `CN_ServerOwned` is **deleted** in Phase 3 — conflicting docs, not part of LIFE-05 spec
- `CN_ServerAuthority` (peer_id=0 only) is the canonical server-ownership marker
- `CN_LocalAuthority` is the canonical local-peer ownership marker

### Authority transfer

- Mid-game authority transfer is **out of scope for Phase 3**
- Phase 3 only handles initial marker injection at spawn time and late-join world state application
- Authority markers are assigned once (at spawn) and stay fixed for the entity's lifetime

### Claude's Discretion

- Exact CN_NetSync skip-list extension to exclude CN_NativeSync properties from batched RPC
- Idempotent marker injection implementation (remove-then-add on re-spawn)
- `update_visibility(0)` vs toggle hack for late-join visibility refresh — use documented API
- cleanup_native_sync() exact timing relative to entity.queue_free()
- Whether NativeSyncHandler is called from SpawnManager._apply_component_data() (Option A, recommended) or NetworkSync._on_entity_added() (Option B)

</decisions>

<specifics>
## Specific Ideas

- Entity scenes are created by: add root node (e.g., CharacterBody3D) → right-click → Extend → pick Entity. So entities inherit from whatever their scene root is. CN_NativeSync's `root_path = ".."` targets the entity node (= the scene root = the CharacterBody3D). This is the correct default for the typical GECS game workflow.
- The `sync_native_handler.gd` v0.1.1 targeted a `CharacterBody3D` sub-node via sync_config — that design is gone. In v2, the entity IS the CharacterBody3D.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `cn_local_authority.gd` — exists as stub, no changes needed
- `cn_server_authority.gd` — exists as stub, no changes needed
- `spawn_manager.gd` — extend `_apply_component_data()` to inject authority markers after CN_NetworkIdentity is deserialized
- `sync_native_handler.gd` (v0.1.1) — MultiplayerSynchronizer setup sequence is correct (lines 266-343); authority mapping `peer_id if peer_id > 0 else 1` must be preserved; model/animation/config logic NOT ported
- `cn_net_sync.gd` — `scan_entity_components()` skip-list must be extended to skip CN_NativeSync

### Established Patterns

- RefCounted delegation: `NativeSyncHandler.new(self)` follows same pattern as SpawnManager, SyncSender, SyncReceiver — NetworkSync holds `_native_sync_handler` reference, delegates setup/cleanup
- Critical ordering: replication_config BEFORE add_child, set_multiplayer_authority BEFORE add_child — activates replication at add_child time
- `_NetSync` is the child node name for MultiplayerSynchronizer — entity-local, no naming collision between entities

### Integration Points

- `network_sync.gd` — add `_native_sync_handler` wire, call cleanup in entity lifecycle
- `plugin.gd` — remove CN_SyncEntity CUSTOM_TYPE, add CN_NativeSync
- `spawn_manager.gd` — authority marker injection + NativeSyncHandler.setup_native_sync() call
- `network_sync._on_peer_connected()` — call `_deferred_refresh_visibility()` after world state RPC

### Files to Delete

- `addons/gecs_network/components/cn_sync_entity.gd` — deprecated stub, replaced by CN_NativeSync
- `addons/gecs_network/components/cn_server_owned.gd` — conflicting docs, deleted per user decision
- `addons/gecs_network/sync_native_handler.gd` — v0.1.1 handler, replaced by native_sync_handler.gd
- `addons/gecs_network/sync_config.gd` — stub kept for Phase 2 compat, now safe to delete

### Files to Create

- `addons/gecs_network/components/cn_native_sync.gd` — new component (see shape above)
- `addons/gecs_network/native_sync_handler.gd` — new RefCounted handler (adapted from v0.1.1 setup sequence)
- `addons/gecs_network/tests/test_authority_markers.gd` — Wave 0 stubs
- `addons/gecs_network/tests/test_native_sync_handler.gd` — Wave 0 stubs

</code_context>

<deferred>
## Deferred Ideas

- Mid-game authority transfer (`NetworkSync.transfer_authority(entity, new_peer_id)`) — future phase or insertion phase
- REPLICATION_MODE_ON_CHANGE as a common use case — available via replication_mode export, but no dedicated test coverage planned for Phase 3

</deferred>

---

*Phase: 03-authority-model-and-native-transform-sync*
*Context gathered: 2026-03-09*

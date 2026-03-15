> **Note:** This guide covers upgrading from v0.1.x. If you are starting fresh with v1.0.0, ignore this file.

# Migration Guide: v0.1.x to v2

> This guide covers the breaking changes introduced in GECS Network v2.
> The v2 branch is a clean break — no backward compatibility shims are provided.
> Use git history on the v0.1.x tags if you need the old code.

---

## Quick Reference

| v0.1.x                                               | v2                                                                       | Notes                                                                                           |
| ---------------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `SyncConfig` class                                   | `@export_group` on component properties                                  | Priority declared inline; no external registry                                                  |
| `extends SyncConfig`                                 | Delete — no base class needed                                            |                                                                                                 |
| `component_priorities = {"C_Health": Priority.HIGH}` | `@export_group("HIGH")` before health properties                         |                                                                                                 |
| `CN_SyncEntity` component                            | `CN_NativeSync` component                                                | Different properties; see docs/components.md                                                    |
| `C_SyncEntity.new(true, true, false)`                | `CN_NativeSync.new()` (defaults: sync_position=true, sync_rotation=true) |                                                                                                 |
| `extends SyncComponent`                              | `extends Component`                                                      | SyncComponent removed in v2                                                                     |
| `NetworkMiddleware` class                            | Direct signal connections to `NetworkSync`                               | Connect `entity_spawned` + `local_player_spawned` on the NetworkSync node                       |
| `NetworkSync.attach_to_world(world, config)`         | `NetworkSync.attach_to_world(world)`                                     | Second arg is optional NetAdapter, not a config object                                          |
| `CN_ServerOwned` marker                              | `CN_ServerAuthority` marker                                              | **Semantics changed**: host player (peer_id=1) no longer matches; server-owned = peer_id=0 only |
| `is_server_owned()` returns true for peer_id=0 or 1  | `has_component(CN_ServerAuthority)` true for peer_id=0 only              |                                                                                                 |
| `SyncConfig.Priority.HIGH` enum                      | `CN_NetSync.Priority.HIGH` enum                                          | Priority enum moved to CN_NetSync                                                               |
| No `CN_SyncEntity` = spawn-only                      | `@export_group("SPAWN_ONLY")` on properties                              | CN_NetSync must be present on both continuous and spawn-only entities                           |
| `sync_config.enable_reconciliation = true`           | `network_sync.reconciliation_interval = 30.0`                            | ProjectSetting default is 30.0 seconds                                                          |
| `sync_config.model_ready_component`                  | Not needed — SpawnManager uses CN_NetworkIdentity                        |                                                                                                 |
| `sync_config.transform_component`                    | Not needed — add CN_NativeSync component to entity                       |                                                                                                 |

---

## Step-by-Step Migration

### 1. Delete your SyncConfig subclass

Remove the file (e.g., `config/my_sync_config.gd`) and all references to it. Priority
is now declared per-property with `@export_group` annotations.

### 2. Delete your NetworkMiddleware subclass

Remove the file and replace it with direct signal connections in your main scene or
game manager:

```gdscript
# OLD — middleware subclass
var middleware = ExampleMiddleware.new()
NetworkSync.attach_to_world(world, config, middleware)

# NEW — direct connections
_network_sync = NetworkSync.attach_to_world(world)
_network_sync.entity_spawned.connect(_on_entity_spawned)
_network_sync.local_player_spawned.connect(_on_local_player_spawned)
```

### 3. Replace CN_SyncEntity with CN_NativeSync

On entities that need transform sync (position, rotation via MultiplayerSynchronizer):

```gdscript
# OLD
static func _create_sync_entity() -> CN_SyncEntity:
    var sync = CN_SyncEntity.new(true, false, false)
    return sync

# NEW — in define_components():
CN_NativeSync.new()   # Default: sync position + rotation
```

If you need custom properties, configure the `CN_NativeSync` component fields:

- `sync_position: bool = true`
- `sync_rotation: bool = true`
- `root_path: NodePath = ".."`
- `replication_interval: float = 0.0`

### 4. Add CN_NetSync to every synced entity

Every entity that syncs component properties now requires `CN_NetSync`:

```gdscript
func define_components() -> Array:
    return [
        CN_NetworkIdentity.new(peer_id),
        CN_NetSync.new(),           # NEW — required for property sync
        CN_NativeSync.new(),        # Optional — for transform sync
        C_Velocity.new(),
    ]
```

### 5. Change `extends SyncComponent` to `extends Component`

Find all component files that extend `SyncComponent` and change to `Component`:

```gdscript
# OLD
class_name C_FiringInput
extends SyncComponent

@export var is_firing: bool = false

# NEW
class_name C_FiringInput
extends Component

@export_group("HIGH")
@export var is_firing: bool = false
```

### 6. Add `@export_group` annotations to component properties

Replace the `SyncConfig.component_priorities` dict with inline annotations:

```gdscript
# OLD — in SyncConfig subclass:
component_priorities = {
    "C_Velocity": Priority.HIGH,
    "C_Health": Priority.MEDIUM,
    "C_XP": Priority.LOW,
}

# NEW — on each component:
class_name C_Velocity
extends Component

@export_group("HIGH")
@export var direction: Vector3 = Vector3.ZERO

# ---

class_name C_Health
extends Component

@export_group("MEDIUM")
@export var current: int = 100
@export var maximum: int = 100

# ---

class_name C_XP
extends Component

@export_group("LOW")
@export var total_xp: int = 0
```

### 7. Update authority checks

Replace `is_server_owned()` with component checks:

```gdscript
# OLD
if entity.get_component(CN_NetworkIdentity).is_server_owned():
    _do_server_work()

# NEW
if entity.has_component(CN_ServerAuthority):
    _do_server_work()
```

Replace authority marker references:

```gdscript
# OLD query
q.with_all([C_EnemyAI, CN_ServerOwned])

# NEW query
q.with_all([C_EnemyAI, CN_ServerAuthority, CN_LocalAuthority])
```

### 8. Update `attach_to_world()` call

Remove the SyncConfig argument:

```gdscript
# OLD
var net_sync = NetworkSync.attach_to_world(world, ExampleSyncConfig.new())

# NEW
var net_sync = NetworkSync.attach_to_world(world)
```

### 9. Update reconciliation configuration

```gdscript
# OLD
sync_config.enable_reconciliation = true
sync_config.reconciliation_interval = 30.0

# NEW
_network_sync.reconciliation_interval = 30.0   # Set on NetworkSync, not a config object
```

---

See `example_network/` for a complete working v2 example.

# Components

## CN_NetworkIdentity

Required for all networked entities. Stores ownership information and exposes authority helper methods.

```gdscript
CN_NetworkIdentity.new(peer_id)

# peer_id values:
# 0   = server-owned (enemies, projectiles, pickups)
# 1   = host player (server is also a player)
# 2+  = client players

# Methods:
net_id.is_server_owned()   # True ONLY if peer_id == 0 (host player peer_id=1 returns false)
net_id.is_player()         # True if peer_id > 0
net_id.is_local()          # True if peer_id matches local peer
net_id.has_authority()     # True if local peer has authority over this entity
```

**Important:** `is_server_owned()` returns `true` for `peer_id == 0` ONLY. The host player
(`peer_id == 1`) is NOT server-owned; it gets `CN_LocalAuthority` on the host machine.
Use `has_component(CN_ServerAuthority)` to check server ownership in queries.

## CN_NetSync

Required for all entities that sync component properties. `CN_NetSync` scans the entity's
components at spawn, discovers which properties belong to which priority tier, and drives the
priority-tiered send pipeline.

```gdscript
CN_NetSync.new()  # No arguments — configuration comes from @export_group on sibling components

enum Priority { REALTIME = 0, HIGH = 1, MEDIUM = 2, LOW = 3 }

# Key methods (called internally by SyncSender/SyncReceiver):
net_sync.scan_entity_components(entity)         # Build internal priority map from @export_group annotations
net_sync.check_changes_for_priority(priority)   # Return dirty properties for the given priority tier
net_sync.update_cache_silent(comp, prop, val)   # Update cache without marking dirty (echo-loop prevention)
```

### Priority Tiers via @export_group

Priority is declared directly on component properties using `@export_group` sentinel names:

| Group name | Rate | Transport | Use for |
|---|---|---|---|
| `"REALTIME"` | ~60 Hz | Unreliable | Critical real-time data (rare) |
| `"HIGH"` | 20 Hz | Unreliable | Velocity, input flags, animation state |
| `"MEDIUM"` | 10 Hz | Reliable | Health, AI state, XP |
| `"LOW"` | 1 Hz | Reliable | Inventory, stats, upgrades |
| `"SPAWN_ONLY"` | Once at spawn | Reliable | Projectile initial position/velocity |
| `"LOCAL"` | Never | — | Client-only state; never transmitted |

All properties under an `@export_group` sentinel inherit that tier until the next group is declared.

### Example: Component with mixed priorities

```gdscript
class_name C_NetVelocity
extends Component

@export_group("HIGH")
@export var direction: Vector3 = Vector3.ZERO  # Synced at 20 Hz
@export var speed: float = 0.0                 # Synced at 20 Hz

@export_group("LOCAL")
@export var predicted_position: Vector3 = Vector3.ZERO  # Never synced
```

### CN_NetSync is Required on Every Synced Entity

`CN_NetSync` must be present on the entity for any property sync to occur. This includes
spawn-only entities — the `SPAWN_ONLY` group still requires `CN_NetSync` to be on the entity.
Without `CN_NetSync`, no property data is sent at spawn or continuously.

## CN_NativeSync

Optional data-only component that instructs `NativeSyncHandler` to create a Godot
`MultiplayerSynchronizer` for this entity. Best for continuous transform sync (position,
rotation) where Godot's built-in interpolation is preferable to manual RPC sync.

```gdscript
CN_NativeSync.new()  # Default: sync position + rotation every frame

# All properties:
@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var root_path: NodePath = ".."         # ".." = the entity node itself
@export var replication_interval: float = 0.0  # 0.0 = every frame
@export var replication_mode: int = 1          # 1 = REPLICATION_MODE_ALWAYS
```

`CN_NativeSync` does not replace `CN_NetSync` — both are typically added together on
continuously-synced entities. `CN_NativeSync` handles position/rotation; `CN_NetSync` handles
component property sync.

**When to use vs CN_NetSync:**
- Use `CN_NativeSync` for transform (position, rotation) — Godot handles interpolation
- Use `CN_NetSync` + `@export_group` for all other component data (health, input, AI state)

## Authority Marker Components

SpawnManager automatically assigns these markers when an entity with `CN_NetworkIdentity` is
added to the world. **Do not assign or remove these manually** — SpawnManager uses an
idempotent remove-then-add pattern to ensure they are always correct.

| Marker | Assigned when | Typical use in queries |
|---|---|---|
| `CN_LocalAuthority` | Entity is owned by the local peer | Input systems, camera, local physics |
| `CN_RemoteEntity` | Entity is owned by a remote peer | Skip in physics, apply interpolation |
| `CN_ServerAuthority` | Entity has `peer_id == 0` (server-owned only) | Server-only processing |

**Marker assignment per peer type:**

| Entity owner | On server | On any client |
|---|---|---|
| Server (`peer_id=0`) | `CN_LocalAuthority` + `CN_ServerAuthority` | `CN_RemoteEntity` + `CN_ServerAuthority` |
| Host player (`peer_id=1`) | `CN_LocalAuthority` | `CN_RemoteEntity` |
| Client player (`peer_id=2+`) | `CN_RemoteEntity` | `CN_LocalAuthority` (on that client only) |

**Key distinction:** `CN_ServerAuthority` means `peer_id == 0` only. The host player
(`peer_id == 1`) is NOT a server-authority entity — it gets `CN_LocalAuthority` on the host
and `CN_RemoteEntity` on all other peers, same as any other player.

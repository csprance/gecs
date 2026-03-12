# Troubleshooting

For migration from v0.1.x, see `docs/migration-v1-to-v2.md`.

---

## 1. Parser Error: Class Not Found for Component Base

**Symptom:** GDScript parser error at startup or test run referencing an unknown component
base class.

**Cause:** A component file extends a v0.1.x base class that no longer exists.
All components in v2 extend `Component` directly.

**Fix:** Change the extends clause and add `@export_group` annotations for sync priority:

```gdscript
# WRONG — v0.1.x base class does not exist in v2
class_name C_MyInput
extends Component  # was: extends <old-base>

# CORRECT
class_name C_MyInput
extends Component

@export_group("HIGH")
@export var is_firing: bool = false
```

---

## 2. Component Class Not Found (Wrong Prefix or Old Name)

**Symptom:** Runtime error when creating a component instance — class not found.

**Cause:** v0.1.x component names used in entity definitions. All network components
use the `CN_` prefix in v2.

**Fix:** See the full name map in `docs/migration-v1-to-v2.md` (Quick Reference table).
Key points: `C_NetworkIdentity` → `CN_NetworkIdentity`; authority markers and sync entity
components have been renamed. The migration guide lists every change.

---

## 3. `attach_to_world()` Rejects Second Argument

**Symptom:** Error when passing a configuration object as the second argument to
`NetworkSync.attach_to_world()`.

**Cause:** The v2 signature takes an optional `NetAdapter`, not a config object. The
v0.1.x config class does not exist in v2.

**Fix:**

```gdscript
# WRONG — passing a config object that no longer exists
var net_sync = NetworkSync.attach_to_world(world, ExampleConfig.new())

# CORRECT
var net_sync = NetworkSync.attach_to_world(world)  # No config argument
```

If you need a custom networking backend: pass a `NetAdapter` subclass as the second argument.

---

## 4. Host Player Marked as Server-Owned

**Symptom:** A system that queries `CN_ServerAuthority` also fires for the host player
(peer_id = 1), producing incorrect behavior.

**Cause:** In v0.1.x, the server ownership check returned `true` for `peer_id == 0 OR 1`.
In v2, `CN_ServerAuthority` is assigned only for `peer_id == 0`.

**Expected behavior:**

| Entity | On server | On client |
|---|---|---|
| Host player (`peer_id=1`) | `CN_LocalAuthority` only | `CN_RemoteEntity` only |
| Server-owned (`peer_id=0`) | `CN_LocalAuthority` + `CN_ServerAuthority` | `CN_RemoteEntity` + `CN_ServerAuthority` |

**Fix:** Replace `is_server_owned()` calls with `has_component(CN_ServerAuthority)`.

---

## 5. Spawn-Only Entity Not Syncing / No Values on Clients

**Symptom:** Entity spawns on server but clients receive it with all default component values.

**Cause A:** `CN_NetSync` is missing from the entity. Without `CN_NetSync`, no component
property data is sent — not even at spawn.

**Fix A:** Add `CN_NetSync.new()` to `define_components()`.

**Cause B:** Component values were set BEFORE `add_entity()`.

**Fix B:** Set component values AFTER `add_entity()`. The deferred broadcast captures
end-of-frame values:

```gdscript
ECS.world.add_entity(projectile)   # define_components() runs — resets to defaults

# Set AFTER add_entity():
projectile.get_component(C_NetPosition).position = spawn_pos
projectile.get_component(C_NetVelocity).direction = shoot_dir
```

**Cause C:** Properties are missing `@export` — only `@export` properties are serialized.

**Cause D (v2-specific):** Spawn-only properties are declared with `@export_group("SPAWN_ONLY")`.
If `CN_NetSync` is absent from the entity, even SPAWN_ONLY properties are not sent.

---

## 6. `update_cache_silent()` Called on Wrong Object

**Symptom:** Stale cached values, or properties not updating after the first sync tick.

**Cause:** `update_cache_silent()` is a method on `CN_NetSync` (the component), not on
`NetworkSync` (the node). Calling it on the node fails silently or operates on the wrong cache.

**Fix:**

```gdscript
# WRONG — NetworkSync node has no such method
var ns = ECS.world.get_node("NetworkSync") as NetworkSync
ns.update_cache_silent(comp, "health", value)

# CORRECT — call on the CN_NetSync component instance
var net_sync = entity.get_component(CN_NetSync) as CN_NetSync
net_sync.update_cache_silent(comp, "health", value)
```

In practice: do NOT call `update_cache_silent()` inside custom receive handlers. The framework
calls it automatically after every receive handler returns. See `docs/custom-sync-handlers.md`.

---

## 7. Entity Sync Not Starting (No Properties Ever Received)

**Symptom:** Entity spawns on all peers but component properties never update after spawn.

**Cause:** `CN_NetSync` is not present on the entity. Without it, `SyncSender` never queries
the entity, and `SyncReceiver` has no cache to update.

**Fix:** Ensure every entity that needs property sync (including spawn-only) has
`CN_NetSync.new()` in `define_components()`.

---

## 8. Late Joiner Missing Entities

**Symptom:** Client connects after the game starts and cannot see existing entities.

**Checks:**

1. `NetworkSync` must be attached before any peer connects — call `attach_to_world()` in
   `_ready()` on the server, not deferred to a button press
2. `multiplayer.peer_connected` must be connected before the first peer joins
3. Verify `NetworkSync` is a child of the `World` node (not a sibling or orphan)

---

## 9. Reconciliation Not Running

**Symptom:** State drift accumulates over time; periodic full-state correction never fires.

**Checks:**

1. `reconciliation_interval` must be set to a positive value:
   ```gdscript
   _network_sync.reconciliation_interval = 30.0   # -1.0 means "use ProjectSetting default"
   ```
2. `broadcast_full_state()` only runs on server. Verify the call is server-side.
3. Check `gecs_network/sync/reconciliation_interval` in ProjectSettings — if the plugin
   registration failed, it defaults to 30.0 s, which may be acceptable.

# Troubleshooting

## Entity not syncing

1. Ensure entity has `CN_NetworkIdentity`
2. Check peer_id is set correctly
3. Verify NetworkSync is child of World

## Transform not syncing

1. Add `CN_SyncEntity` to entity
2. Or use component-based sync (C_Transform changes trigger RPC)
3. Check `sync_config.skip_component_types` doesn't include your component

## Late joiner missing entities

1. Ensure server has entities before client connects
2. Check `_on_peer_connected` is being called
3. Verify world state serialization works

## Performance issues

1. Use priority batching (default config)
2. Increase sync intervals for non-critical data
3. Enable component filtering to skip unnecessary syncs
4. Use native sync (CN_SyncEntity) for transform data

## Spawn-only entity appears at origin (0,0,0)

1. Ensure you set `C_Transform.position` AFTER `add_entity()`, not before
2. Check the property has `@export` so it serializes
3. The addon syncs Node3D position from C_Transform after spawn

## Spawn-only entity has wrong values (default instead of set values)

1. Set component values AFTER `add_entity()`, not before
2. The addon uses `call_deferred` to capture values at end of frame
3. If you set values before `add_entity()`, `define_components()` overwrites them

## Duplicate projectiles (prediction + server spawn)

1. **Don't spawn locally on client** - only server should spawn
2. Remove client-side prediction for spawn-only entities
3. Client waits for server's spawn broadcast

## Projectile spawns but doesn't move / has wrong velocity

1. Check `C_Velocity.direction` is set AFTER `add_entity()`
2. Ensure velocity property is `@export`
3. For spawn-only, continuous sync is disabled - values must be correct at spawn

## Input not reaching server (remote player actions not happening)

1. Ensure input component extends `SyncComponent`, not `Component`
2. Add `@export` to input properties
3. Add component to `SyncConfig.component_priorities` with HIGH priority
4. Verify client has `CN_LocalAuthority` on the player entity

## Spawn-only entity receiving continuous updates (breaking local simulation)

1. **Remove `CN_SyncEntity`** from the entity - its presence enables continuous sync
2. Entities without `CN_SyncEntity` only sync at spawn time
3. Check no other code is manually syncing the entity

## Migration from Game-Specific Code

1. Remove `Net` singleton references - use `net_adapter` methods
2. Remove manual marker assignment - NetworkSync handles it
3. Remove manual `MultiplayerSynchronizer` setup - use `CN_SyncEntity`
4. Update component imports to addon paths

Before:
```gdscript
if Net.is_server():
    entity.add_component(CN_ServerOwned.new())
```

After:
```gdscript
# Automatic! Just add CN_NetworkIdentity with correct peer_id
entity.add_component(CN_NetworkIdentity.new(0))  # Server-owned
```

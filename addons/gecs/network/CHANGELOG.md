# Changelog

All notable changes to the GECS Network addon will be documented in this file.

## [Unreleased]

### Fixed
- `CN_NetSync.scan_entity_components()` was never called at runtime — clients could not sync `C_PlayerInput` (or any `CN_NetSync`-tracked properties) to the server because `SyncSender` always saw an empty scan table. Fix: `NetworkSync._deferred_broadcast()` now scans server-side entities after authority markers are injected; `SpawnManager._apply_component_data()` now scans client-side entities after spawn setup completes.
- `main.gd._on_peer_disconnected_hook` was calling `world.remove_entity()` on the disconnected peer's entity, duplicating the cleanup already performed by `SpawnManager.on_peer_disconnected()`. The redundant removal could cause a double-free crash (`entity_removed` signal fired with a freed entity). Fix: removed entity cleanup from the hook — `SpawnManager` is the sole cleanup path.
- `world.remove_entity()` called `entity.free()` (immediate) before the `GECSEditorDebuggerMessages.entity_removed()` debug assert, causing a "previously freed" type-check error when an entity was not in the scene tree. Fix: the debug assert now runs before the free call.

## [2.0.0] — feature/gecs-network-v2

### Added
- `CN_NetSync` component — declarative priority-tiered property sync via `@export_group` annotations (REALTIME/HIGH/MEDIUM/LOW/SPAWN_ONLY/LOCAL)
- `CN_NativeSync` component — native Godot `MultiplayerSynchronizer` transform sync with interpolation
- `CN_LocalAuthority` marker component — replaces `is_multiplayer_authority()` calls in game systems
- `CN_ServerAuthority` marker component — server-owned entities (peer_id=0 only)
- `CN_RemoteEntity` marker component — remote-peer entities
- `SyncSender` — priority-tiered batched outbound RPC with dirty tracking
- `SyncReceiver` — authority-validated inbound apply with echo-loop guard
- `SpawnManager` — late-join full-state broadcast, deferred despawn, session ID anti-ghost
- `NativeSyncHandler` — creates and manages `MultiplayerSynchronizer` nodes for `CN_NativeSync` entities
- `SyncRelationshipHandler` — relationship sync with deferred resolution for non-deterministic spawn ordering
- `SyncReconciliationHandler` — periodic full-state reconciliation broadcast (default 30s, configurable)
- `NetworkSync.register_send_handler()` / `register_receive_handler()` — system-level sync overrides (ADV-03)
- ProjectSettings: `gecs_network/sync/high_hz`, `medium_hz`, `low_hz`, `reconciliation_interval`

### Removed
- `SyncConfig` class and subclass pattern — replaced by `@export_group` annotations on component properties
- `CN_SyncEntity` component — replaced by `CN_NativeSync`
- `CN_ServerOwned` marker — replaced by `CN_ServerAuthority` (semantics changed: host peer_id=1 is no longer server-owned)
- `SyncComponent` base class — components now extend `Component` directly
- `NetworkMiddleware` pattern — replaced by direct signal connections to `NetworkSync`
- `sync_spawn_handler.gd` — replaced by `spawn_manager.gd`
- `sync_property_handler.gd` — replaced by `sync_sender.gd` + `sync_receiver.gd`
- `sync_state_handler.gd` — replaced by authority marker injection in `spawn_manager.gd`

### Migration
See [docs/migration-v1-to-v2.md](docs/migration-v1-to-v2.md) for the full v0.1.x → v2 upgrade guide.

## [0.1.1] - Add Tests; Relationship Sync

### Added
- **Relationship Synchronization**: Full sync support for entity relationships across peers (`sync_relationship_handler.gd`)
- **Transport Provider Abstraction**: Pluggable transport layer supporting ENet, Steam, and custom providers
- **Unit Tests**: Test suite for network addon functionality
- **UID Files**: Godot 4.x UID file support for all scripts

### Changed
- **Component Renaming**: All network components now use `CN_` prefix (e.g., `CN_NetworkIdentity`, `CN_SyncEntity`)
- **Handler Extraction**: Code refactored into separate handler classes for better maintainability
- **Documentation**: Comprehensive README rewrite with usage examples and patterns

### Fixed
- **Null Reference Hardening**: Added guards against null refs, resource injection, and orphaned nodes
- **Performance**: Reduced per-frame allocations and eliminated O(n) scans in sync hot paths
- **MultiplayerAPI Cache**: Detect stale cache after session transitions
- **Sync Loop Guard**: Fixed sync-loop to prevent infinite recursion
- **World Null-Guard**: Added null-guard for world in relationship RPC handlers
- **Relationship Removal**: Fixed fallback removal to match target reference by script path for non-Entity types

### Security
- Addressed PR review issues for safety, security, and correctness

## [0.1.0] - Initial Release

- Initial release of gecs_network addon for multiplayer entity synchronization
- Component-based sync (CN_NetworkIdentity, CN_SyncEntity)
- Property synchronization with priority-based batching
- Spawn-only and continuous sync patterns
- Late join support

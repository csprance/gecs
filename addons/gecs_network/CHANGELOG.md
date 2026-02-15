# Changelog

All notable changes to the GECS Network addon will be documented in this file.

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

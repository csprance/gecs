# Phase 6: Cleanup, Documentation, and Example Network Update - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove all v0.1.x deprecated files (handlers, stubs, and their tests), rewrite the
`example_network/` project in-place using the v2 API, rewrite all documentation to match the
v2 architecture, and add a migration guide for users coming from v0.1.x. No new features. No
backward compatibility shims. This phase makes the repo reflect what was actually built in
Phases 1-5.

</domain>

<decisions>
## Implementation Decisions

### Dead Code Deletion

- **Delete all v0.1.x handlers** — `sync_spawn_handler.gd`, `sync_property_handler.gd`,
  `sync_state_handler.gd` and their `.uid` sidecars. These are fully replaced by
  `spawn_manager.gd`, `sync_sender.gd`, `sync_receiver.gd`, and `native_sync_handler.gd`.
- **Delete all deprecated stubs** — `sync_config.gd`, `cn_sync_entity.gd`, `cn_server_owned.gd`
  and their `.uid` sidecars. No compatibility shims; clean break.
- **Delete v0.1.x test files** — `test_sync_spawn_handler.gd`, `test_sync_state_handler.gd`
  and their `.uid` sidecars. (Note: `test_native_sync_handler.gd` is a v2 Phase 3 test — keep it.)
- **No archiving or legacy/ folders** — delete completely, rely on git history if anyone needs reference.

### Example Network Rewrite

- **Rewrite `example_network/` in-place** — same player/projectile scenario, v2 API throughout.
  Delete `ExampleSyncConfig` (was `extends SyncConfig`) and `ExampleMiddleware` (v1 pattern).
- **All four v2 features showcased:**
  1. `CN_NetSync` with priority tiers via `@export_group` annotations on component properties
  2. `CN_NativeSync` for player transform (MultiplayerSynchronizer, no manual RPC position sync)
  3. One custom sync handler registered in a System's `_ready()` (demonstrates ADV-03)
  4. Reconciliation configured via `NetworkSync.reconciliation_interval` property
- **Visual application** — direct signal connections in `main.gd` (connect to `entity_spawned`,
  `local_player_spawned`). No separate middleware class. This is the clean v2 pattern.

### Documentation Rewrite

- **Full rewrite of `README.md`** — new v2 Quick Start: (1) add `CN_NetSync` with `@export_group`
  to a component, (2) add `CN_NetworkIdentity` to entity, (3) attach `NetworkSync` to World.
  Remove all SyncConfig/CN_SyncEntity/NetworkMiddleware references. Update file structure table.
- **Full rewrites of all `docs/*.md` files** — all 9 docs reference v1 concepts and need v2
  replacements. Priority order: `components.md`, `architecture.md`, `configuration.md`,
  `sync-patterns.md`, `authority.md`, `best-practices.md`, `examples.md`, `troubleshooting.md`.
  `custom-sync-handlers.md` (written in Phase 5) needs review only — likely already v2-accurate.
- **Update `CHANGELOG.md`** — add a proper `## [2.0.0]` entry listing new components
  (CN_NetSync, CN_NativeSync, authority markers), removed components (SyncConfig, CN_SyncEntity,
  CN_ServerOwned), and removed files (v0.1.x handlers). Brief, not exhaustive.

### Migration Guide Format

- **Standalone `docs/migration-v1-to-v2.md`** — dedicated file in `docs/`, linked from README.
- **Quick reference table format** — v1 class/concept → v2 equivalent. Simple table, no extended
  code examples. Cover: `SyncConfig`, `CN_SyncEntity`, `NetworkMiddleware`, authority API
  (`is_server_owned()`), `SyncPriority` enum location.

### Claude's Discretion

- Exact content and structure of each rewritten doc file
- Whether to add GdUnit4 test stubs verifying the example project compiles (no integration tests needed)
- Order of subtasks within each plan wave
- Whether `plugin.gd` file structure listing in README should be updated or left to `docs/`

</decisions>

<code_context>
## Existing Code Insights

### Files to Delete (v0.1.x)

**Handlers:**
- `addons/gecs_network/sync_spawn_handler.gd` + `.uid`
- `addons/gecs_network/sync_property_handler.gd` + `.uid`
- `addons/gecs_network/sync_state_handler.gd` + `.uid`

**Stubs:**
- `addons/gecs_network/sync_config.gd` + `.uid`
- `addons/gecs_network/components/cn_sync_entity.gd` + `.uid`
- `addons/gecs_network/components/cn_server_owned.gd` + `.uid`

**Tests:**
- `addons/gecs_network/tests/test_sync_spawn_handler.gd` + `.uid` (if exists)
- `addons/gecs_network/tests/test_sync_state_handler.gd` + `.uid`

### Files to Rewrite (example_network/)

- `example_network/config/example_sync_config.gd` → delete (extends SyncConfig, v1 only)
- `example_network/network/example_middleware.gd` → delete (v1 middleware pattern)
- `example_network/main.gd` → update (direct signal connections instead of ExampleMiddleware)
- `example_network/entities/e_player.gd` → update (CN_NetSync + CN_NativeSync instead of CN_SyncEntity)
- `example_network/components/c_net_velocity.gd` → update (add CN_NetSync @export_group annotations)
- `example_network/components/c_player_input.gd` → update (add CN_NetSync priority annotation)

### Files to Rewrite (docs/)

- `addons/gecs_network/README.md` — full v2 rewrite
- `addons/gecs_network/docs/components.md` — full rewrite (CN_SyncEntity → CN_NetSync, CN_NativeSync)
- `addons/gecs_network/docs/architecture.md` — full rewrite (v2 handler architecture)
- `addons/gecs_network/docs/configuration.md` — full rewrite (no SyncConfig, use ProjectSettings)
- `addons/gecs_network/docs/sync-patterns.md` — full rewrite (spawn-only via CN_NetSync)
- `addons/gecs_network/docs/authority.md` — full rewrite (CN_LocalAuthority/CN_ServerAuthority)
- `addons/gecs_network/docs/best-practices.md` — full rewrite
- `addons/gecs_network/docs/examples.md` — full rewrite (v2 examples)
- `addons/gecs_network/docs/troubleshooting.md` — full rewrite
- `addons/gecs_network/docs/custom-sync-handlers.md` — review only (Phase 5, likely v2-accurate)

### Files to Create

- `addons/gecs_network/docs/migration-v1-to-v2.md` — new migration guide (table format)

### Established Patterns

- v2 components use `@export_group("Sync|REALTIME")` etc. to declare sync priority — this is the
  v2 equivalent of SyncConfig's priority registry
- `NetworkSync.attach_to_world(world)` is the v2 setup call (no SyncConfig parameter)
- Authority is queried by checking for `CN_LocalAuthority` / `CN_ServerAuthority` marker components
- `test_native_sync_handler.gd` is a v2 test (Phase 3, for NativeSyncHandler) — do NOT delete

</code_context>

<specifics>
## Specific Ideas

- The migration table should cover at minimum: `SyncConfig` → `@export_group` + CN_NetSync,
  `CN_SyncEntity` → `CN_NativeSync`, `NetworkMiddleware` → direct signal connections,
  `is_server_owned()` → `has_component(CN_ServerAuthority)` query
- The CHANGELOG `## [2.0.0]` entry should reference the PR/branch for the feature work so it's
  traceable
- The example custom sync handler should reuse the player movement prediction pattern from
  `docs/custom-sync-handlers.md` (already written in Phase 5) — don't invent a new scenario

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-cleanup-documentation-and-example-network-update-v1-to-v2-migration*
*Context gathered: 2026-03-12*

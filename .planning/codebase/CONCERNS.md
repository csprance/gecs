# Codebase Concerns

**Analysis Date:** 2026-03-17

## Tech Debt

**Unimplemented `QueryBuilder.compile()` method:**

- Issue: `compile(query: String) -> QueryBuilder` is declared but returns a blank `QueryBuilder.new(_world)` — no parsing logic exists
- Files: `addons/gecs/ecs/query_builder.gd:520`
- Impact: Any code that calls `compile()` will silently receive an empty query, returning all entities — could cause large-scale incorrect system processing with no error
- Fix approach: Implement a minimal DSL parser or remove the method entirely if not planned

**~~Dead code: `_move_entity_to_new_archetype()` slow path:~~ RESOLVED**

- Removed the dead method and its corresponding test (`test_slow_path_stale_edge_after_archetype_deletion`)
- The production `_move_entity_to_new_archetype_fast()` path already has its own ARCH-02 stale-edge guards

**`relationship_entity_index` built but never queried:**

- Issue: `relationship_entity_index` is populated on every `add_relationship`/`remove_relationship`, but nothing ever queries it for optimization — it was noted as "Optional for optimization"
- Files: `addons/gecs/ecs/world.gd:82,769-791`
- Impact: Wasted Dictionary operations on every relationship mutation; all relationship lookups still do O(N) per-entity scanning in `_filter_entities_global()`
- Fix approach: Either use it to accelerate `with_relationship()` queries or remove it to eliminate maintenance surface and the wasted per-mutation cost

**Duplicate `_find_component_by_type()` implementations:**

- Issue: Identical method exists in both `SpawnManager` and `SyncReceiver`; `SyncReceiver` even comments "Mirrors SpawnManager.\_find_component_by_type() exactly"
- Files: `addons/gecs/network/spawn_manager.gd:255`, `addons/gecs/network/sync_receiver.gd:181`
- Impact: If the lookup logic needs to change, it must be updated in both places
- Fix approach: Extract to a shared utility function, either as a static method on `NetworkSync` or a standalone helper file

**Plugin settings removal commented out:**

- Issue: `remove_gecs_project_setings()` (note: typo — "setings") is defined but the call in `_exit_tree()` is commented out; settings registered by the plugin are never cleaned up when the plugin is disabled
- Files: `addons/gecs/plugin.gd:18,74`
- Impact: Residual `gecs/*` entries remain in `project.godot` after disabling the plugin
- Fix approach: Uncomment the call, fix the typo, and ensure the removal uses `ProjectSettings.clear()` safely

**`command_buffer_flush_mode` stored as String, not enum:**

- Issue: The flush mode is compared as a string (`"PER_SYSTEM"`, `"PER_GROUP"`, `"MANUAL"`) rather than an enum value throughout world.gd and system.gd
- Files: `addons/gecs/ecs/system.gd:69`, `addons/gecs/ecs/world.gd:249,267`
- Impact: Silent mismatch if a user mistypes the string; no compile-time safety
- Fix approach: Define a `FlushMode` enum on `System` and use it everywhere; `@export_enum` can still show strings in the inspector

**`add_project_setting()` documentation parameter unused:**

- Issue: `add_project_setting()` accepts a `documentation: String` parameter but never uses it; the TODO comment acknowledges this
- Files: `addons/gecs/plugin.gd:26,28,34`
- Impact: API surface that signals intent but does nothing
- Fix approach: Use `ProjectSettings.set_setting_metadata()` (Godot 4.3+) or remove the parameter until the API is available

---

## Known Bugs

**Test `test_system_group_processes_entities_with_required_components` is failing:**

- Symptoms: System groups are not being set correctly, or groups are being overridden somewhere — the test is marked FIXME
- Files: `addons/gecs/tests/core/test_system.gd:72`
- Trigger: Adding systems with explicit `group` values then calling `world.process(delta)` (no group argument) appears to interfere
- Workaround: Call `world.process(delta, "group1")` explicitly rather than relying on default group routing

**Component `_init()` parameters without default values cause unrecoverable crash:**

- Symptoms: If the entity is re-initialized, components are reinstantiated with no args, crashing GDScript
- Files: `addons/gecs/tests/core/test_entity.gd:34`, `addons/gecs/ecs/entity.gd:88`
- Trigger: Any `Component` subclass whose `_init()` has required parameters (no defaults)
- Workaround: All `Component` subclasses must have default values for every `_init()` parameter; there is no framework-level guard

**Observer queries may hit stale archetype cache during batch add_entities():**

- Symptoms: In rare cases, an observer's `on_component_added` fires against a stale archetype cache entry when a second entity with a new component combination is added in the same batch
- Files: `addons/gecs/ecs/world.gd:1162-1167` (documented in code comment)
- Trigger: Observers registered + `add_entities()` batch with entities of different component compositions that create a new archetype mid-batch
- Workaround: Add entities individually or manually call `world._invalidate_cache()` after a mixed batch

---

## Security Considerations

**Hardcoded `sender_id != 1` for server authority check:**

- Risk: The client-side receive path rejects all batches not from peer 1. If a relay topology is used where the logical server is not peer 1, this guard silently drops all server data
- Files: `addons/gecs/network/sync_receiver.gd:109`, `addons/gecs/network/sync_relationship_handler.gd:296,345`
- Recommendations: Route the check through `net_adapter.get_server_peer_id()` so it is transport-abstraction-safe

**`_applying_network_data` flag has no exception safety:**

- Risk: GDScript has no `try/finally`. If a component `set()` call during `_apply_component_data()` triggers an error, `_applying_network_data` may be left as `true`, permanently silencing all outgoing sync from that peer
- Files: `addons/gecs/network/sync_receiver.gd:174-176`, `addons/gecs/network/spawn_manager.gd:219`
- Recommendations: Wrap in a deferred reset or verify that all property setters are free of side-effects that could leave the flag stuck

**Scene path validation allows arbitrary `res://` paths to be loaded:**

- Risk: On clients, `SpawnManager.handle_spawn_entity()` loads and instantiates any scene at `scene_path` so long as it starts with `res://` and exists. A malicious server can cause the client to instantiate any scene in the project
- Files: `addons/gecs/network/spawn_manager.gd:94-103,140-144`
- Recommendations: Maintain an allowlist of valid entity scene paths checked on both server serialization and client deserialization

---

## Performance Bottlenecks

**O(N) entity iteration in `SyncSender._poll_entities_for_priority()`:**

- Problem: Every tick, `SyncSender` iterates the entire `_world.entities` array to find networked entities
- Files: `addons/gecs/network/sync_sender.gd:64,133`
- Cause: No index of entities that have `CN_NetworkIdentity + CN_NetSync`; noted with a TODO comment
- Improvement path: Cache a query result for `with_all([CN_NetworkIdentity, CN_NetSync])` and invalidate only when the archetype changes

**Observer dispatch iterates all observers for every component event:**

- Problem: Each component add/remove/change loops over all observers and calls `_query()` to check entity match
- Files: `addons/gecs/ecs/world.gd:857-931`
- Improvement path: Build `component_path -> Array[Observer]` index at `add_observer()` time; skip observers not watching the changed component type

**Property inspection limit of 20 in debugger entity poll:**

- Problem: `_handle_debugger_message` hard-codes `min(20, prop_list.size())` when building the inspect payload
- Files: `addons/gecs/ecs/world.gd:1493`
- Improvement path: Restrict to `@export` properties only (usage flag filter) rather than capping by count

**`World.systems` property getter rebuilds flat array every access:**

- Problem: `systems` is a computed property that allocates a new array and appends all systems from every group on every access
- Files: `addons/gecs/ecs/world.gd:59-64`
- Improvement path: Cache the flat list and invalidate only when `add_system()` or `remove_system()` is called

---

## Fragile Areas

**`NetworkSync` must be named exactly `"NetworkSync"` for RPC routing:**

- Files: `addons/gecs/network/network_sync.gd:71,85`
- Why fragile: Godot RPC routing uses the node name path; if the node is renamed, all RPC calls silently fail
- Safe modification: Always use `NetworkSync.attach_to_world(world)` factory; never rename the node

**`_subsystems_cache` is initialized lazily but never invalidated:**

- Files: `addons/gecs/ecs/system.gd:107,257-258`
- Why fragile: `sub_systems()` is called once and cached; if a system's sub-systems change dynamically, the cache will serve stale queries forever
- Safe modification: Only modify `sub_systems()` return value at startup before the system processes for the first time

**`_apply_component_data` sets properties via string key without type checking:**

- Files: `addons/gecs/network/spawn_manager.gd:200-218`, `addons/gecs/network/sync_receiver.gd:167-173`
- Why fragile: `comp.set(prop, value)` is silent on type mismatch; a mismatched type from the network can silently corrupt component state
- Safe modification: Add `typeof(existing_comp.get(prop)) == typeof(value)` guard before each `set()` call

**`_query_cache` in `System._run_process()` uses first `query()` return permanently:**

- Files: `addons/gecs/ecs/system.gd:103,304-311`
- Why fragile: `_query_cache` is set once on first process call and never re-evaluated; if the query depends on state not yet ready when first called, the cached query may miss filters
- Safe modification: Do not build queries that reference external state at construction time; all query filters must be deterministic from component types alone

---

## Scaling Limits

**Archetype explosion with highly heterogeneous entities:**

- Current capacity: Archetype count grows as O(2^N) in the worst case where N = number of distinct component types independently added/removed
- Scaling path: Add archetype count monitoring to the debugger; discourage highly dynamic component-add/remove patterns in favor of using the `enabled` flag or tag components

**`reconciliation` full-state broadcast serializes all networked entities at once:**

- Current capacity: Default interval is 30 seconds; full-state payload serializes all `CN_NetworkIdentity` entities in one `rpc()` call
- Limit: With 100+ entities each carrying many components, the payload may exceed Godot's default RPC packet size limit (~65KB for ENet)
- Scaling path: Paginate reconciliation by sending entities in batches across multiple frames; add a configurable `reconciliation_batch_size` setting

---

## Dependencies at Risk

**`SteamTransportProvider` depends on runtime class availability:**

- Risk: If GodotSteam is installed but at an incompatible version, `create_host`/`create_client` calls may silently return non-OK codes with no further diagnostic
- Files: `addons/gecs/network/transports/steam_transport_provider.gd`
- Migration plan: Add version detection via `ClassDB.class_has_method()` check for the expected API surface before attempting to call it

**gdUnit4 test framework pin not enforced:**

- Risk: `addons/gdUnit4/` is vendored with no lockfile or version pin; the framework may be updated out of sync with the test suite
- Migration plan: Record the gdUnit4 version in a `GECS_DEPS.md` file or enforce version in CI via a checksum of the plugin manifest

---

## Missing Critical Features

**No client-side prediction or rollback:**

- Problem: There is no reconciliation pathway for the client's own entity when the server sends a correction
- Blocks: Any game requiring authoritative server movement (e.g. anti-cheat) will exhibit rubber-banding with no built-in correction
- Partially addressed by: `register_receive_handler()` allowing custom blending, but no helper or guide for implementing rollback

**No bandwidth throttling or entity visibility/interest management:**

- Problem: `SyncSender` broadcasts all entity changes to all peers every tick; no concept of visibility radius, area of interest, or per-peer exclusion
- Blocks: Games with more than ~20 simultaneously synced entities may saturate bandwidth
- Scaling path: Requires per-peer entity subscription lists, which would need changes to `SyncSender._dispatch_batch()` and `SpawnManager`

---

## Test Coverage Gaps

**System group routing bug is FIXME with no regression test:**

- What's not tested: Correct processing of entities when systems have non-default `group` values and `world.process(delta)` (no group) is called
- Files: `addons/gecs/tests/core/test_system.gd:72`
- Priority: High

**Parallel processing path (`parallel_processing = true`) has no tests:**

- What's not tested: `System._process_parallel()` and `WorkerThreadPool.add_task()` integration
- Files: `addons/gecs/ecs/system.gd:189-215`
- Priority: High

**`QueryBuilder.compile()` is never tested:**

- What's not tested: The stub `compile()` method
- Files: `addons/gecs/ecs/query_builder.gd:520`
- Priority: Medium

**Network layer tests use mock `NetAdapter` not real multiplayer:**

- What's not tested: Actual RPC dispatch, packet ordering, peer ID assignment, and reliable vs unreliable routing under real ENet conditions
- Files: `addons/gecs/tests/network/` (all test files)
- Priority: Medium

---

_Concerns audit: 2026-03-17_

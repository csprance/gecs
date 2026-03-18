# Architecture

**Analysis Date:** 2026-03-17

## Pattern Overview

**Overall:** Entity Component System (ECS) with archetype-based storage, integrated as a Godot 4.x addon

**Key Characteristics:**
- Data (Components) is strictly separated from logic (Systems)
- Entities are containers with no behavior; all behavior lives in Systems
- World is the central manager that owns archetypes, systems, observers, and the query cache
- Archetype storage groups entities by identical component signatures for cache-friendly, O(1) query matching
- A CommandBuffer provides deferred structural mutation to allow safe forward iteration

## Layers

**ECS Singleton (`ECS`):**
- Purpose: Global autoloaded access point; holds the active World reference; drives the process loop
- Location: `addons/gecs/ecs/ecs.gd`
- Contains: `world` property setter/getter, `process(delta, group)`, serialization helpers, `entity_preprocessors`/`entity_postprocessors`
- Depends on: World, QueryBuilder, GECSIO
- Used by: User game scripts (call `ECS.process(delta)` every frame)

**World:**
- Purpose: Manages all entities, systems, and observers; owns the archetype index and query cache; orchestrates system processing per frame
- Location: `addons/gecs/ecs/world.gd`
- Contains: `entities`, `archetypes` (signature → Archetype), `entity_to_archetype`, `systems_by_group`, `observers`, `query` property, `process()`, `add_entity()`, `remove_entity()`, `add_system()`, cache suppression helpers (`_begin_suppress`/`_end_suppress`)
- Depends on: Entity, System, Observer, QueryBuilder, Archetype, CommandBuffer, GECSIO
- Used by: ECS singleton, Systems (via `_world` reference), user scenes

**Archetype:**
- Purpose: Stores entities sharing an exact component signature; provides Structure-of-Arrays (SoA) column storage for cache-friendly iteration
- Location: `addons/gecs/ecs/archetype.gd`
- Contains: `signature` (FNV-1a hash), `entities` (flat array), `entity_to_index` (O(1) swap-remove), `columns` (component_path → Array), `enabled_bitset` (PackedInt64Array), add/remove edges for O(1) archetype transitions
- Depends on: Entity
- Used by: World (archetype registry), QueryBuilder (`archetypes()` call), System (iterates columns directly)

**Entity:**
- Purpose: Lightweight container node holding component instances and relationships
- Location: `addons/gecs/ecs/entity.gd`
- Contains: `components` (Dict[resource_path, Component]), `relationships` (Array[Relationship]), `id` (UUID), `enabled`, lifecycle hooks (`on_ready`, `on_destroy`, `on_enable`, `on_disable`), `define_components()` virtual
- Depends on: Component, Relationship, World (via ECS.world for archetype transitions)
- Used by: World, Systems, Observers

**Component:**
- Purpose: Data-only Resource containers; no logic or behavior
- Location: `addons/gecs/ecs/component.gd`
- Contains: `parent` (Entity backref), `property_changed` signal, `serialize()` helper
- Depends on: Nothing (extends Resource)
- Used by: Entity (stored in `components` dict), Systems (read/write via `entity.get_component()`)

**System:**
- Purpose: Logic nodes that operate on entities with specific components each frame
- Location: `addons/gecs/ecs/system.gd`
- Contains: `query()` virtual, `process(entities, components, delta)` virtual, `sub_systems()` virtual, `deps()` virtual, `setup()` virtual, `cmd` (CommandBuffer), `q` (QueryBuilder shortcut), `parallel_processing`, `command_buffer_flush_mode`, `_handle(delta)` internal driver
- Depends on: QueryBuilder, CommandBuffer, Archetype (column iteration), World
- Used by: World (called via `_handle(delta)` in `world.process()`)

**Observer:**
- Purpose: Reactive system that responds to component add/remove/change events on specific entities
- Location: `addons/gecs/ecs/observer.gd`
- Contains: `match()` virtual (QueryBuilder filter), `watch()` virtual (single component type), `on_component_added`, `on_component_removed`, `on_component_changed` callbacks
- Depends on: QueryBuilder, Entity, Component
- Used by: World (connects to entity/component signals)

**QueryBuilder:**
- Purpose: Fluent API for constructing entity queries; caches archetype match sets for hot-path performance
- Location: `addons/gecs/ecs/query_builder.gd`
- Contains: `with_all`, `with_any`, `with_none`, `with_relationship`, `with_group`, `enabled()`, `disabled()`, `iterate()`, `execute()`, `archetypes()`, `get_cache_key()` (FNV-1a hash)
- Depends on: World, Archetype, Relationship, ComponentQueryMatcher
- Used by: System (via `q`), direct ad-hoc queries via `ECS.world.query`

**CommandBuffer:**
- Purpose: Queues structural mutations (add/remove component/entity/relationship) as Callables; executes them after system processing to avoid invalidating iteration state
- Location: `addons/gecs/ecs/command_buffer.gd`
- Contains: `_commands` (Array[Callable]), `add_component`, `remove_component`, `add_components`, `remove_components`, `add_entity`, `remove_entity`, `add_relationship`, `remove_relationship`, `add_custom`, `execute()`, `clear()`, `is_empty()`
- Depends on: World, Entity, Relationship
- Used by: System (exposed as `cmd` property)

**Relationship:**
- Purpose: Typed link between an Entity and a target (Entity, Component instance, or Script archetype)
- Location: `addons/gecs/ecs/relationship.gd`
- Contains: `relation` (Component instance), `target`, `source`, `matches(other)`, wildcard null support, component query dictionary support, `valid()`
- Depends on: Component, Entity, ComponentQueryMatcher
- Used by: Entity (stored in `relationships`), QueryBuilder (relationship filtering)

**NetworkSync (optional):**
- Purpose: Attaches to a World to provide multiplayer entity lifecycle sync (spawn/despawn/property sync/reconciliation)
- Location: `addons/gecs/network/network_sync.gd`
- Contains: All `@rpc` declarations (Godot requirement), delegates to SpawnManager, SyncSender, SyncReceiver, NativeSyncHandler, SyncRelationshipHandler, SyncReconciliationHandler
- Depends on: World, Entity, NetAdapter, SpawnManager, SyncSender, SyncReceiver
- Used by: User game code via `NetworkSync.attach_to_world(world)`

## Data Flow

**Per-Frame Processing:**

1. User calls `ECS.process(delta)` or `ECS.process(delta, "group_name")` in `_process` or `_physics_process`
2. `ECS.process` delegates to `World.process(delta, group)`
3. World iterates `systems_by_group[group]` and calls `system._handle(delta)` for each active system
4. `System._handle` calls `_run_process(delta)` (or `_run_subsystems` if `sub_systems()` is overridden)
5. `_run_process` resolves the query cache (`_query_cache = query()` on first call), fetches matching archetypes via `QueryBuilder.archetypes()`
6. For structural queries (no relationship/group filters): iterates archetypes directly, reads `archetype.entities` and column arrays
7. For non-structural queries: gathers all entities from structural archetypes, then filters via `_filter_entities_global`
8. `System.process(entities, components, delta)` is called with matched entities and component arrays
9. After `process` returns: if `command_buffer_flush_mode == "PER_SYSTEM"`, `cmd.execute()` runs queued commands
10. After all systems in group complete: PER_GROUP command buffers are flushed
11. MANUAL command buffers require explicit `ECS.world.flush_command_buffers()` call

**Entity Addition:**

1. `World.add_entity(entity)` is called
2. World connects entity signals (`component_added`, `component_removed`, `relationship_added`, `relationship_removed`)
3. Entity is added to scene tree under `entity_nodes_root`
4. Cache invalidation is suppressed (`_begin_suppress`)
5. Entity is placed in the empty archetype (`_add_entity_to_archetype`)
6. `entity._initialize(components)` fires, calling `add_component` for each component
7. Each `add_component` emits `component_added` → World moves entity to the correct archetype
8. Cache suppression ends (`_end_suppress`), triggering a single cache invalidation
9. `entity_added` signal is emitted; ECS preprocessors run; debug data sent

**Query Execution:**

1. `QueryBuilder.execute()` checks `_cache_valid`; returns cached result for purely structural queries
2. For a cache miss: calls `World._query(all, any, exclude, enabled_filter, cache_key)`
3. World checks `_query_archetype_cache[cache_key]`; on miss, iterates all archetypes calling `archetype.matches_query()`
4. Matching archetypes are cached; entities are flattened from archetype entity arrays with enabled-bit filtering
5. Relationship and group filters are applied post-structural as entity-level passes

**State Management:**
- Archetype index is the primary entity index (replaces prior component-keyed dictionaries)
- Query archetype cache (`_query_archetype_cache`) maps query signature → Array[Archetype]; invalidated on any component add/remove
- Cache invalidation is batched via `_begin_suppress`/`_end_suppress` depth counter to avoid per-operation thrash
- Entity enabled/disabled state uses a `PackedInt64Array` bitset per archetype (no archetype splitting)

## Key Abstractions

**Archetype:**
- Purpose: Groups entities with identical component sets in flat arrays; enables O(1) query matching and cache-friendly column iteration (SoA layout)
- Examples: `addons/gecs/ecs/archetype.gd`
- Pattern: Flecs-inspired archetype graph with add/remove edges for O(1) archetype transitions; swap-remove for O(1) entity deletion

**QueryBuilder (fluent builder):**
- Purpose: Composes multi-criteria entity filters with result caching; reusable per system via lazy `_query_cache`
- Examples: `addons/gecs/ecs/query_builder.gd`
- Pattern: Builder pattern; cache key is FNV-1a hash of sorted component paths (structural only); relationship/group filters bypass cache

**CommandBuffer (deferred mutation):**
- Purpose: Enables safe forward iteration by queuing structural changes as Callables
- Examples: `addons/gecs/ecs/command_buffer.gd`
- Pattern: Command queue; single cache invalidation per `execute()` call via suppression bracket

**Relationship (typed entity links):**
- Purpose: Typed pair (relation component + target) for hierarchical queries
- Examples: `addons/gecs/ecs/relationship.gd`
- Pattern: Wildcard null matching, component query dictionaries for property-based relationship filtering

**Observer (reactive hooks):**
- Purpose: Event-driven callbacks for component lifecycle changes without polling
- Examples: `addons/gecs/ecs/observer.gd`
- Pattern: Signal-based; World connects/disconnects observer callbacks as entities are added/removed; `property_changed` must be explicitly emitted by Component setters

## Entry Points

**ECS Singleton:**
- Location: `addons/gecs/ecs/ecs.gd` (autoloaded as `ECS` by `addons/gecs/plugin.gd`)
- Triggers: Godot autoload on scene start
- Responsibilities: Hold active World, dispatch `ECS.process(delta)` to World, expose serialization helpers, manage pre/postprocessors

**World Node:**
- Location: `addons/gecs/ecs/world.gd`
- Triggers: Placed in scene tree; `ECS.world = world_instance` activates it
- Responsibilities: Initialize from scene tree (discover entities/systems/observers in `_ready`), run per-frame system processing, maintain archetype index and query cache

**Plugin Entry:**
- Location: `addons/gecs/plugin.gd`
- Triggers: Godot editor plugin activation
- Responsibilities: Register `ECS` autoload singleton, add debugger plugin, register project settings (`gecs/*` and `gecs/network/sync/*`)

**NetworkSync Attach:**
- Location: `addons/gecs/network/network_sync.gd`
- Triggers: `NetworkSync.attach_to_world(world)` called by user code
- Responsibilities: Wire World signals, create sub-handlers (SpawnManager, SyncSender, SyncReceiver, etc.), register all `@rpc` methods

## Error Handling

**Strategy:** Assertions for framework invariants; push_error/push_warning for recoverable conditions; no exceptions

**Patterns:**
- `assert(condition, "message")` for invariants that must hold (wrong API usage, type mismatches)
- `push_error(...)` for runtime errors that can be recovered from (missing parent World, RPC before ready)
- `is_instance_valid(entity)` guard baked into every CommandBuffer lambda to protect against freed entities
- Relationship `valid()` check auto-cleans stale relationships during `get_relationship()` calls

## Cross-Cutting Concerns

**Logging:** `GECSLogger` class (`addons/gecs/lib/logger.gd`); each class creates a domain-scoped instance (e.g., `GECSLogger.new().domain("World")`); controlled by `gecs/log_level` project setting

**Validation:** `ComponentQueryMatcher` (`addons/gecs/lib/component_query_matcher.gd`) handles all property-based query matching with operators (`_eq`, `_gte`, `_gt`, `_lte`, `_lt`)

**Debug mode:** `ECS.debug` boolean; when true, systems populate `lastRunData`, World tracks perf metrics, GECSEditorDebuggerMessages sends data to the editor debugger tab

**Serialization:** `GECSIO` (`addons/gecs/io/io.gd`) + `GECSSerializeConfig` (`addons/gecs/io/serialize_config.gd`); accessible via `ECS.serialize()`, `ECS.save()`, `ECS.deserialize()`

---

*Architecture analysis: 2026-03-17*

# Architecture Patterns

**Domain:** ECS framework internals — query caching, archetype management, observer/reactive systems
**Researched:** 2026-03-15
**Confidence:** HIGH — based entirely on direct source reading of world.gd, entity.gd, query_builder.gd, archetype.gd, observer.gd, system.gd, command_buffer.gd

---

## Recommended Architecture

GECS uses an archetype-based ECS with a two-level cache: an archetype-to-query mapping at the World level and a per-QueryBuilder result cache at the system level. Entities are grouped by their exact component set (archetype), archetypes are stored by FNV-1a hash of their component signature, and query results are cached as `Array[Archetype]` rather than `Array[Entity]`. This means a cache miss only triggers an archetype scan, not a full entity scan.

```
ECS (singleton)
  └── World (Node)
        ├── archetypes: Dict[sig:int -> Archetype]
        ├── entity_to_archetype: Dict[Entity -> Archetype]
        ├── _query_archetype_cache: Dict[cache_key:int -> Array[Archetype]]
        ├── entities: Array[Entity]
        ├── observers: Array[Observer]
        └── systems_by_group: Dict[group:String -> Array[System]]

Archetype (RefCounted)
  ├── signature: int             (FNV-1a hash of sorted component paths)
  ├── component_types: Array     (sorted resource paths)
  ├── entities: Array[Entity]    (flat, contiguous)
  ├── entity_to_index: Dict      (O(1) swap-remove index)
  ├── enabled_bitset: PackedInt64Array  (one bit per entity slot)
  ├── columns: Dict[path -> Array]      (SoA storage, mirrors entities array order)
  ├── add_edges: Dict[comp_path -> Archetype]   (archetype graph — stale bug site)
  └── remove_edges: Dict[comp_path -> Archetype]

QueryBuilder (RefCounted)
  ├── _world: World
  ├── _cache_valid: bool           (result-level cache gate)
  ├── _cached_result: Array        (entity-level result cache — second layer)
  ├── _cache_key: int              (pre-computed hash, one per QueryBuilder instance)
  └── _cache_key_valid: bool

QueryCacheKey (static)
  └── build(all, any, exclude) -> int   (domain-aware FNV hash)

Entity (Node)
  ├── components: Dict[resource_path -> Component]
  ├── _component_path_cache: Dict[component -> resource_path]
  ├── relationships: Array[Relationship]
  └── signals: component_added, component_removed, component_property_changed, ...

Observer (Node)
  ├── watch() -> Resource    (the component type to watch)
  └── match() -> QueryBuilder  (entity filter; empty = all entities)

System (Node)
  ├── _query_cache: QueryBuilder    (cached once, reused every frame)
  ├── cmd: CommandBuffer            (lazy-created)
  └── command_buffer_flush_mode: String  (PER_SYSTEM | PER_GROUP | MANUAL)

CommandBuffer (RefCounted)
  └── _commands: Array[Callable]    (closures with baked-in entity ref)
```

---

## Component Boundaries — What Talks to What

| Caller | Callee | Mechanism | Notes |
|--------|--------|-----------|-------|
| Entity.add_component | Entity.component_added signal | GDScript signal emit | World connects to this in add_entity |
| Entity.component_added signal | World._on_entity_component_added | signal callback | Triggers archetype move AND observer notification |
| Entity.component_removed signal | World._on_entity_component_removed | signal callback | Triggers archetype move AND observer notification |
| World._on_entity_component_added | World._move_entity_to_new_archetype_fast | direct call | Hot path for archetype transitions |
| World._move_entity_to_new_archetype_fast | Archetype.add_edges / remove_edges | dict lookup | Edge cache — the stale cache bug site |
| World._on_entity_component_added | World._handle_observer_component_added | direct call | Observer notification; fires after archetype move |
| World._handle_observer_* | Observer.on_component_added / removed / changed | direct call | No signal hop; direct method call on observer nodes |
| World.remove_entity | World._handle_observer_component_removed (loop) | direct call | Iterates entity.components.values() and calls handler |
| World.remove_entity | entity signals DISCONNECTED before observer loop | intent: prevent re-entrancy | But disconnection happens BEFORE observer loop, so signal chain is dead during notification |
| System._handle | System.cmd.execute() | direct call | PER_SYSTEM flush; happens after process() returns |
| System._run_process | QueryBuilder.archetypes() | method call | Returns cached Array[Archetype] from World._query_archetype_cache |
| QueryBuilder.execute | World._query | method call | Passes pre-computed cache key; World checks _query_archetype_cache |
| entity.enabled setter | World.cache_invalidated.emit() | signal emit | Bypasses _invalidate_cache(); directly emits world signal |
| add_components (entity.gd) | ECS.world._get_or_create_archetype | direct call | Batch path: skips signal for archetype move, goes direct |
| remove_components (entity.gd) | ECS.world._get_or_create_archetype | direct call | Same — batch path bypasses signal-based archetype move |

---

## Data Flow for Query Execution and Cache Invalidation

### Normal Query Path (cache warm)

```
System._handle(delta)
  -> System._run_process(delta)
       -> _query_cache.archetypes()        # QueryBuilder.archetypes()
            -> World.get_matching_archetypes(self)
                 -> _query_archetype_cache.has(cache_key)  # O(1) hit
                      -> return Array[Archetype]           # no entity scan
  -> for arch in archetypes:
       arch.entities.duplicate()           # snapshot for structural fast path
       process(entities, components, delta)
```

### Cache Miss Path

```
World._query(all, any, exclude, enabled_filter, cache_key)
  -> _query_archetype_cache miss
       -> for arch in archetypes.values():
            arch.matches_query(_all, _any, _exclude)   # O(n_archetypes * n_comp_types)
       -> _query_archetype_cache[cache_key] = matching
  -> flatten entities from matching archetypes
  -> return Array[Entity]
```

### Cache Invalidation Path (component added/removed)

```
entity.add_component(comp)
  -> component_added.emit(entity, comp)         # entity signal
       -> World._on_entity_component_added(entity, comp)
            -> _move_entity_to_new_archetype_fast(entity, old_arch, comp_path, true)
                 -> old_arch.get_add_edge(comp_path)     # check edge cache
                 -> if edge stale/missing: _get_or_create_archetype(sig, types)
                      -> if NEW archetype: _invalidate_cache("new_archetype_created")
                 -> old_arch.remove_entity(entity)       # swap-remove O(1)
                 -> new_arch.add_entity(entity)          # append + column populate
                 -> entity_to_archetype[entity] = new_arch
                 -> if old_arch empty: clear edges, erase from archetypes dict
            -> _invalidate_cache("entity_component_added")  # unconditional
                 -> _query_archetype_cache.clear()           # FULL wipe every time
                 -> cache_invalidated.emit()
                      -> all connected QueryBuilders: _cache_valid = false
            -> component_added.emit(entity, comp)       # world signal
            -> _handle_observer_component_added(entity, comp)
```

**Key observation:** `_invalidate_cache` clears the ENTIRE `_query_archetype_cache` dict on every single component add/remove. This is over-invalidation: if the entity moved between two existing archetypes (no new archetype was created), the archetype set has not changed and cached archetype lists are still valid. The cache should only be cleared when the archetype set changes (new archetype created or archetype deleted). This is the core "cache invalidation mess."

### Cache Invalidation Triggers (full inventory)

| Trigger | Location | Necessary? |
|---------|----------|------------|
| entity added to archetype | `_add_entity_to_archetype` | NO — archetype membership unchanged |
| entity component added | `_on_entity_component_added` | NO — only needed if archetype set changed |
| entity component removed | `_on_entity_component_removed` | NO — only needed if archetype set changed |
| new archetype created | `_get_or_create_archetype` | YES — new archetype may match existing queries |
| empty archetype removed | `_remove_entity_from_archetype` | YES — cached Array[Archetype] may contain dead reference |
| entity removed from archetype | `_remove_entity_from_archetype` | Partial — only if archetype deleted |
| empty archetype removed (fast path) | `_move_entity_to_new_archetype_fast` (inline) | YES |
| entity.enabled changed | `entity._on_enabled_changed` | NO — enabled state is bitset, archetype unchanged |
| command buffer flush | `CommandBuffer.execute` | YES — batches may have created/deleted archetypes |
| batch add/remove (world) | `add_entities` / `remove_entities` | Conditional — only if archetypes changed |
| purge | `World.purge` | YES |

The `_should_invalidate_cache` flag is a correct-direction optimization that suppresses intermediate invalidations during batches, but its scope is incomplete: many non-batch single-entity operations still call `_invalidate_cache` when the archetype set did not change.

---

## Known Bugs — Exact Code Locations

### Bug 1: Stale Archetype Edge Cache (Issue PR #81)

**File:** `world.gd`, `_move_entity_to_new_archetype_fast` (line ~1284)

**What happens:**
When an archetype empties out, its entry is deleted from `world.archetypes` and its edges are cleared. However, OTHER archetypes that hold edges POINTING TO the deleted archetype are not updated. On the next component add/remove that traverses such an edge, `get_add_edge` or `get_remove_edge` returns a stale `Archetype` object that is no longer in `world.archetypes`.

**Partial fix present:** Lines 1294-1298 re-add the archetype to `world.archetypes` if the edge resolves to an archetype not in the world dict. This prevents queries from missing the archetype, but it resurrects a potentially stale archetype that may have the wrong `columns` state (stale column arrays from before it was emptied).

**Missing:** There is no verification that the re-added archetype's internal state (columns, entities, entity_to_index) is consistent. A re-added empty archetype starts fresh on `add_entity`, but column initialization in `Archetype._init` sets up columns from `component_types`. If `component_types` is correct, columns will be rebuilt correctly as entities are added back. Whether this is always the case depends on whether `component_types` was cleared with the edges — it was not (edges are cleared, `component_types` is untouched). So the re-add path is likely correct but fragile.

**Root cause:** Bidirectional edge invalidation is missing. When archetype A is deleted, every archetype that held an `add_edge` or `remove_edge` pointing to A must clear those entries. The current code only clears A's own edges, not edges held by A's neighbors.

### Bug 2: Wrong Component Instance Emitted on remove_component (Issue #68)

**File:** `entity.gd`, `remove_component` (line ~222)

**What happens:** The `remove_component` method accepts a `component: Resource` parameter. Inside, when the component is found by resource path, it correctly retrieves the stored instance (`component_instance = components[resource_path]`). Then at line 239 it emits `component_removed.emit(self, component_instance)` — this looks correct.

However, there is a path confusion for the `_component_path_cache` lookup at lines 225-231:
```
if _component_path_cache.has(component):
    resource_path = _component_path_cache[component]
else:
    resource_path = component.resource_path    # Script path, not instance path
```
When `remove_component` is called with a Script (the class, not an instance) — which is the documented API for removing by type — `component.resource_path` is the Script's path, matching the key used in the `components` dict. So the path resolution is correct.

The real bug is in `_handle_observer_component_removed` in world.gd (line ~900). When `remove_entity` calls this method, it passes `comp` from `entity.components.values()`, which is the correct component instance. But `watch_component.resource_path == component.get_script().resource_path` — this comparison calls `component.get_script()` on a Component instance. This is correct.

**The actual #68 bug location:** In the single-component `remove_component` path, the `component_removed` signal is emitted with `component_instance` (the stored instance) — that is correct. The bug was that in an earlier version the signal may have emitted `component` (the script/class passed in, not the instance). This appears to have been partially fixed but the observer handler in `_handle_observer_component_removed` does not re-check whether the observer's `match()` query is satisfied, which is inconsistent with `_handle_observer_component_added` which does check.

### Bug 3: remove_entity Skips on_component_removed Observers (Issue #93)

**File:** `world.gd`, `remove_entity` (lines ~393-444)

**Exact sequence:**
1. Signals disconnected (lines 404-411) — `_on_entity_component_removed` no longer connected
2. `for comp in entity.components.values(): component_removed.emit(entity, comp); _handle_observer_component_removed(entity, comp)` (lines 415-417)
3. `_remove_entity_from_archetype(entity)` (line 437) — archetype cleanup
4. `entity.on_destroy()` + `queue_free()` (lines 440-444)

**The bug:** The signal is disconnected before the observer notification loop. This was intentional to prevent re-entrancy (the comment says so). But the direct call to `_handle_observer_component_removed` at line 417 is NOT filtered by the observer's `match()` query. Compare this to `_handle_observer_component_added` which does call `_query` to check if the entity matches the observer's filter. `_handle_observer_component_removed` skips this check and fires unconditionally for any entity with the watched component, regardless of whether the entity matched the observer's query.

**Secondary problem in remove_entity:** `entity.on_destroy()` is called AFTER `_remove_entity_from_archetype`. By the time `on_destroy` runs, the entity is already gone from all archetype storage. If `on_destroy` in user code calls any ECS query or modifies components, it operates on a partially torn-down entity. The component signals are already disconnected, so those operations would silently do nothing structural but could corrupt user state.

### Bug 4: Component Duplication on world.add_entity (Issue #53)

**File:** `entity.gd`, `_initialize` (lines ~88-113)

**Exact sequence when `add_entity` is called:**
1. Before `add_entity`: entity may already have components in `entity.components` (set via editor or before adding to world).
2. `_initialize` is called at line 345 of world.gd.
3. Inside `_initialize`: `temp_comps = components.values().duplicate_deep()` — deep copy of existing components.
4. `components.clear()` — wipes all existing components.
5. For each `temp_comp` in the copy: `add_component(comp)` — re-adds via the signal path, which causes archetype moves and signal emissions.
6. `component_resources.append_array(define_components())` — adds any code-defined components.
7. For each in `component_resources`: `add_component(res.duplicate(true))` — adds a DUPLICATE of the resource.

**The duplication:** Step 7 calls `res.duplicate(true)` on each resource in `component_resources`. This is intentional to give each entity its own data copy. But if the component was originally set with custom non-`@export` property values (e.g., `my_component.runtime_data = foo`), `duplicate(true)` only copies `@export` properties, resetting runtime properties to defaults. This is the issue #53 behavior: non-`@export` properties on components set before `add_entity` are silently lost.

**Secondary duplication path:** If an entity node in the scene tree has `component_resources` set in the editor AND also calls `define_components()` returning overlapping types, lines 102-103 filter out already-present component types — but only from `component_resources`, not from `define_components()`. The `append_array(define_components())` at line 99 comes before the filter at line 102, so define_components() output does not get filtered. However, since `add_component` replaces an existing component of the same type (lines 141-143 in `add_component`), duplicate component types from the same source are handled. The real loss is the data on the original instance.

### Bug 5: .enabled() Returns Disabled Entities (Issue #87)

**File:** `query_builder.gd`, `enabled()` method (lines ~169-173)

**What happens:** `enabled()` sets `_enabled_filter = true`. In `_internal_execute`, this passes `_enabled_filter` to `World._query`. In `World._query`, when `enabled_filter` is provided, it calls `archetype.get_entities_by_enabled_state(enabled_filter)` on each matching archetype.

`get_entities_by_enabled_state` reads the `enabled_bitset`. The bitset is written in `Archetype.add_entity` (line ~86: `_set_enabled_bit(index, entity.enabled)`) and updated in `update_entity_enabled_state`.

**The bug:** `entity._on_enabled_changed` (entity.gd line ~496) directly emits `ECS.world.cache_invalidated` rather than calling `ECS.world._invalidate_cache(...)`. This bypasses the `_should_invalidate_cache` flag check. But more importantly: when `disable_entity` is called in world.gd (line ~475), it disconnects the entity's component signals — which means subsequent `add_component` calls on a disabled entity will not trigger archetype updates. The bitset correctly reflects enabled state, but if a disabled entity gets components added or removed while disconnected, the archetype and bitset can diverge.

There is also a subtlety in the QueryBuilder: `_cache_key_valid` is set `false` and `_cache_valid` is set `false` when `enabled()` is called, but the result cache (`_cached_result`) is shared between enabled=true and enabled=null queries if the same QueryBuilder instance were reused with different `enabled()` calls. The per-system `_query_cache` is initialized once via `query()` so this does not normally occur in practice, but it is a latent hazard.

### Bug 6: with_reverse_relationship Broken (Issue #5)

**File:** `query_builder.gd`, `with_reverse_relationship` (lines ~141-148)

**What happens:** `with_reverse_relationship` looks up `_world.reverse_relationship_index[rev_key]`, which returns a list of entities (stored as `Array` not `Array[Entity]`). It then calls `self.with_all(...)` passing those entity instances as if they were component classes. `with_all` calls `ComponentQueryMatcher.process_component_list`, which expects component Scripts, not Entity instances. The result is a malformed query that either fails silently or matches nothing.

**Root cause:** The reverse relationship index stores target entities (the subjects of the relationship), not component types. The `with_reverse_relationship` method was designed to find entities that are targets of a given relationship type, but the implementation incorrectly maps this to a component set query.

---

## Patterns to Follow

### Pattern 1: Structural vs Non-Structural Query Separation

**What:** Separate query criteria into "structural" (which archetypes to scan) and "non-structural" (per-entity filtering of relationship, group, and component property queries).

**When:** Always. Archetype cache operates on structural criteria only. Non-structural filters are applied per-entity after archetype lookup.

**Current state:** This separation is implemented in `_query_has_non_structural_filters` (system.gd line ~383) and honored in both `_run_process` and `_run_subsystems`. The QueryBuilder's `get_cache_key` only hashes structural components. Relationships intentionally do not participate in `_query_archetype_cache`.

### Pattern 2: Archetype Cache Keyed to Archetype Set Changes Only

**What:** Invalidate `_query_archetype_cache` only when the set of archetypes changes (new archetype created, existing archetype deleted). Entity movement between existing archetypes does NOT change which archetypes match a query.

**When:** On `_get_or_create_archetype` (new) and on archetype deletion. NOT on every component add/remove.

**Current state (bug):** `_invalidate_cache` is called on every `_on_entity_component_added` and `_on_entity_component_removed`, even when the entity simply moves between two already-existing archetypes. This causes unnecessary full-cache wipes on hot paths.

### Pattern 3: Observer Match Check Symmetry

**What:** Both `_handle_observer_component_added` and `_handle_observer_component_removed` should apply the observer's `match()` filter before calling the observer callback. The component added path does this; the component removed path does not.

**When:** Always — the observer's query defines which entities it cares about. If an entity no longer has the watched component, it may also no longer match the observer's other criteria, but that is fine: the notification is still correct if the entity matched the observer's query AT THE TIME of removal.

**Current state (bug):** `_handle_observer_component_removed` fires unconditionally for any entity possessing the watched component, regardless of the observer's `match()` filter (world.gd lines 900-913). This causes observers to fire on entities they were never supposed to watch.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Full Cache Wipe on Entity Movement

**What:** Clearing `_query_archetype_cache` when an entity moves between two archetypes that already existed.

**Why bad:** The cache stores `Dict[query_hash -> Array[Archetype]]`. If no new archetype was created and no archetype was deleted, the Array[Archetype] mapping for every query is identical to what it was before. Clearing it forces every system to re-scan all archetypes on next query, which is O(n_archetypes * n_queries) work for a zero-information operation.

**Instead:** Track whether the archetype set changed. Clear only when `_get_or_create_archetype` creates a new one or an archetype is deleted.

### Anti-Pattern 2: Edge Invalidation Without Neighbor Cleanup

**What:** Clearing an archetype's own edges when it empties, without clearing references to it from neighbor archetypes.

**Why bad:** Neighboring archetypes still hold stale `add_edges[comp]` pointing to the deleted archetype object. The partial fix in `_move_entity_to_new_archetype_fast` re-registers the archetype when it's found via a stale edge, but this resurrects an object that was intentionally removed, making empty-archetype cleanup non-deterministic.

**Instead:** When deleting archetype A, traverse all neighbors in `A.add_edges.values()` and `A.remove_edges.values()` and clear their reciprocal edges pointing back to A.

### Anti-Pattern 3: Signal Disconnect Before Observer Notification

**What:** In `remove_entity`, entity signals are disconnected before the observer notification loop.

**Why bad:** The intent (prevent re-entrancy) is correct, but the consequence is that if an observer's `on_component_removed` callback calls any entity operation that would normally fire a signal (e.g., `entity.remove_component` as cleanup), nothing happens — no archetype update, no further observer notifications. This causes silent no-ops during entity teardown.

**Instead:** Disconnect signals AFTER the observer loop completes, or use a re-entrancy guard flag on the World that prevents recursive signal processing rather than disconnecting signals prematurely.

### Anti-Pattern 4: observer.match() Query Re-Execution on Every Notification

**What:** `_handle_observer_component_added` (and changed) calls `_query(all, any, exclude)` on EVERY component add event, for EVERY observer, to check if the entity matches the observer's filter. This is O(n_observers * n_archetypes) per component mutation.

**Why bad:** On a world with many observers and many archetypes, every component mutation triggers a full archetype scan per observer. Most observers watch a small subset of entities.

**Instead:** Use the archetype system: when an observer is added, pre-compute which archetypes it cares about. On component add, check only whether the entity's new archetype is in the observer's precomputed set.

---

## Scalability Considerations

| Concern | At 100 entities | At 10K entities | At 1M entities |
|---------|-----------------|-----------------|----------------|
| Cache invalidation | Negligible — few archetypes, cache rebuilds fast | Starts to matter — full scan on every add/remove | Unacceptable — must fix to structural-change-only |
| Observer notification | Fine | Noticeable if many observers | Must pre-compute observer archetype sets |
| Archetype edge staleness | Rare | Reproducible in stress tests | Critical — entities constantly moving archetypes |
| Enabled bitset filtering | O(n/64) — good | O(n/64) — good | O(n/64) — good, scales well |
| Column storage iteration | Excellent cache locality | Excellent | Excellent |
| Observer match() query re-execution | Fine | Slow with 10+ observers | Must cache observer archetype membership |

---

## Suggested Fix Order (Dependencies)

The bugs form a dependency graph. Fix in this order to avoid rework:

### Phase 1 — Observer Signal Chain (no dependencies, self-contained)

1. **Fix #68 partial**: Confirm `remove_component` emits the stored component instance, not the script passed in. Add regression test.
2. **Fix #93 (remove_entity observer symmetry)**: Add the `match()` query check to `_handle_observer_component_removed` to match the behavior of `_handle_observer_component_added`. Add regression test.
3. **Fix remove_entity ordering**: Move signal disconnect to AFTER the observer notification loop. This is a two-line reorder but requires careful testing for re-entrancy. Alternative: add a `_notifying_observers: bool` guard flag.

These three fixes share no dependencies on the cache or archetype fixes.

### Phase 2 — Cache Invalidation Audit (depends on Phase 1 being stable)

4. **Reduce over-invalidation**: Change `_on_entity_component_added` and `_on_entity_component_removed` to NOT call `_invalidate_cache`. Only `_get_or_create_archetype` and archetype deletion paths should clear the archetype cache. The QueryBuilder's per-query result cache (`_cache_valid`) should still be invalidated via the `cache_invalidated` signal on every structural mutation, but the archetype-level cache (`_query_archetype_cache`) should be stable across entity movement.
5. **Fix .enabled() returning disabled entities (#87)**: After fixing over-invalidation, verify the bitset path in `get_entities_by_enabled_state` against the actual enabled state. Add regression test for the scenario described in the issue.

### Phase 3 — Archetype Edge Cache (depends on Phase 2)

6. **Fix stale archetype edge cache (PR #81)**: Implement bidirectional edge invalidation. When an archetype is deleted (in `_move_entity_to_new_archetype_fast` and `_remove_entity_from_archetype`), traverse its edges and clear reciprocal entries from neighbors. This requires iterating the neighbors of the deleted archetype — which is exactly the `add_edges` and `remove_edges` dicts on the deleted archetype.
7. **Review PR #81 patch**: The existing partial fix (re-adding stale archetypes) should be removed once proper invalidation is in place. Re-adding a deleted archetype is a workaround for the symptom, not the cause.

### Phase 4 — Correctness Fixes (mostly independent, can run in parallel with Phase 3)

8. **Fix component duplication (#53)**: Decide the intended behavior for `_initialize`. If `component_resources` components set before `add_entity` should preserve runtime state, stop calling `res.duplicate(true)` on them; only duplicate components that come from the editor-set `component_resources` array. Components explicitly passed to `_initialize` (via `add_entity(entity, components)`) should also not be duplicated since the caller is passing specific instances.
9. **Fix with_reverse_relationship (#5)**: The reverse_relationship_index stores `Array[Entity]` (target entities). The method should use these entities directly, not pass them to `with_all`. The correct implementation would filter the already-queried entity set against the reverse index, not re-query by component type.

---

## Where the Messiness Is Concentrated

**world.gd is the complexity sink.** It contains:
- Archetype lifecycle management (_add, _remove, _move, _get_or_create)
- Two-path archetype transition (fast path with edge cache, slow path with set diff)
- Query execution and caching (_query, get_matching_archetypes)
- Observer notification (three separate handler methods with inconsistent behavior)
- Cache invalidation (_invalidate_cache called from ~8 different sites with varying necessity)
- Batch suppression flag (_should_invalidate_cache) that applies inconsistently

The **observer notification pattern** is duplicated three times (`_handle_observer_component_added`, `_handle_observer_component_removed`, `_handle_observer_component_changed`) with inconsistent behavior: added/changed check match() filter; removed does not.

The **cache invalidation** has two layers (archetype cache and QueryBuilder result cache) that are conflated: `_invalidate_cache` clears the archetype cache AND emits `cache_invalidated` which clears all QueryBuilder result caches. These are independent concerns. The archetype cache should only be cleared on archetype set changes. The QueryBuilder result cache should be cleared on any structural mutation (because results change when entities move between archetypes even if the archetype set stays the same).

**entity.gd's _initialize** is the second mess zone. The sequence of: copy existing components, clear, re-add via signals, append code-defined, filter duplicates, then add all — creates multiple archetype transitions per entity during initialization and loses non-@export property values.

---

## Sources

All findings are HIGH confidence — derived directly from source code in:
- `D:/code/gecs/addons/gecs/ecs/world.gd`
- `D:/code/gecs/addons/gecs/ecs/entity.gd`
- `D:/code/gecs/addons/gecs/ecs/query_builder.gd`
- `D:/code/gecs/addons/gecs/ecs/archetype.gd`
- `D:/code/gecs/addons/gecs/ecs/observer.gd`
- `D:/code/gecs/addons/gecs/ecs/system.gd`
- `D:/code/gecs/addons/gecs/ecs/command_buffer.gd`
- `D:/code/gecs/addons/gecs/ecs/query_cache_key.gd`
- `.planning/PROJECT.md`

No external sources consulted — all architecture claims are grounded in the actual code.

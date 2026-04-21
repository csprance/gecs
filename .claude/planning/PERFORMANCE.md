# GECS Performance TODO

Findings from perf audit against `reports/perf/` data and full codebase review (Godot 4.6-stable, 2026-03-28).
Items ordered by impact within each tier. Implement top-down.

**Validation key**: Each item validated against actual source code on 2026-03-28.

---

## P0 — Frame hot path (affects every system, every frame)

### P0-1: Skip `arch_entities.duplicate()` for systems using CommandBuffer

**File**: `addons/gecs/ecs/system.gd:366` | **Status**: DONE

Every frame, every archetype, every system: a full `Array[Entity]` copy.

```gdscript
# CURRENT — copies all N entity refs every frame
var snapshot_entities = arch_entities.duplicate()
```

The snapshot guards against "mutation skipping" when `remove_component` is called
mid-iteration and the entity swap-removes out of `arch.entities`. But when a system
uses `cmd` for all structural changes, those changes are deferred — the snapshot is
pure waste.

**Fix**: add a system export property and guard the copy:

```gdscript
## Set false when using cmd for ALL structural changes (no mid-iteration mutations).
## Skips the per-frame entity array copy — significant speedup for large entity counts.
@export var safe_iteration: bool = true

# In _run_process:
var snapshot_entities = arch_entities.duplicate() if safe_iteration else arch_entities
```

**Impact**: Eliminates N entity ref copies per frame per system. At 10k entities x 3
systems = 30k refs copied/frame -> 0.

---

### P0-2: Switch `entity.components` dictionary key from String -> int

**File**: `addons/gecs/ecs/entity.gd:71`, `entity.gd:359`, `entity.gd:366` | **Status**: DONE

Both `entity.components` and `archetype.columns` now use `Script.get_instance_id()` (int)
as dictionary keys instead of `resource_path` (String). Integer hash lookups are ~2-3x
faster in Godot's Dictionary.

```gdscript
# entity.gd
var components: Dictionary = {}          # int (script.get_instance_id()) -> Component
static func _comp_key(c) -> int:
    if c is Script: return c.get_instance_id()
    return c.get_script().get_instance_id()
func get_component(c): return components.get(_comp_key(c), null)
```

**Changes made**: entity.gd, archetype.gd, world.gd, system.gd, ecs.gd,
network files (spawn_manager, sync_receiver, cn_net_sync), and all affected tests.

**Impact**: Every `get_component` / `has_component` call in every user system is now
an integer lookup. With 1k entities x 3 components = 3k int lookups/frame instead of
3k string lookups/frame.

---

### P0-3: `has_relationship()` performs full iteration + validation on query filter hot path

**File**: `addons/gecs/ecs/entity.gd:521-522` | **Status**: DONE

`has_relationship()` delegates to `get_relationship()`, which iterates ALL relationships,
validates each one (checking `is_instance_valid` on targets/sources), removes invalid
ones, and emits `relationship_removed` signals for invalids. This is called from
`_filter_entities_global` (system.gd:427) for every entity with post-filter relationships.

```gdscript
# CURRENT — full iteration + validation + signal emission just to check existence
func has_relationship(relationship: Relationship) -> bool:
    return get_relationship(relationship) != null

# get_relationship iterates ALL rels, validates, removes invalids, emits signals
func get_relationship(relationship: Relationship) -> Relationship:
    var to_remove = []
    for rel in relationships:
        if not rel.valid():           # <-- is_instance_valid checks
            to_remove.append(rel)
            continue
        if rel.matches(relationship):
            for invalid_rel in to_remove:
                relationships.erase(invalid_rel)         # <-- O(n) erase
                relationship_removed.emit(self, invalid_rel)  # <-- signal emission
            return rel
    ...
```

**Fix**: add a fast-path `has_relationship()` that skips validation:

```gdscript
func has_relationship(relationship: Relationship) -> bool:
    for rel in relationships:
        if rel.matches(relationship):
            return true
    return false
```

**Impact**: With 100 entities x 3 post-filter relationships, eliminates 300 full
validation passes + potential signal emissions per frame. The `matches()` call itself
is already O(1) per relationship — validation is the bottleneck.

---

### P0-4: Eliminate per-frame `sub_systems()` allocation for non-subsystem Systems

**File**: `addons/gecs/ecs/system.gd:235` | **Status**: DONE

Every `_handle()` call invokes `sub_systems()` to check if the system uses subsystems.
The base implementation returns `[]`, which allocates a new empty `Array[Array]` on
every frame for every system that doesn't override it. Note: `_run_subsystems()` already
caches in `_subsystems_cache`, but `_handle()` calls `sub_systems()` before that cache
is checked.

```gdscript
# CURRENT — allocates empty array every frame for every non-subsystem system
func _handle(delta: float) -> void:
    ...
    var subs = sub_systems()       # <-- new Array[Array] allocation
    if not subs.is_empty():
        _run_subsystems(delta)
    else:
        _run_process(delta)
```

**Fix**: cache a `_has_subsystems` flag, set once on first call:

```gdscript
var _has_subsystems_cached: int = -1  # -1 = unchecked, 0 = no, 1 = yes

func _handle(delta: float) -> void:
    ...
    if _has_subsystems_cached == -1:
        _has_subsystems_cached = 1 if not sub_systems().is_empty() else 0
    if _has_subsystems_cached == 1:
        _run_subsystems(delta)
    else:
        _run_process(delta)
```

**Impact**: Eliminates 1 array allocation per system per frame. With 10 systems at
60fps = 600 unnecessary allocations/second -> 0.

---

### P0-5: Merge double archetype iteration in `_run_process` structural fast path

**File**: `addons/gecs/ecs/system.gd:348-379` | **Status**: DONE

The structural fast path iterates matching archetypes **twice**: first at lines 348-351
to check `has_entities` and count total entities (only used for debug data), then again
at 361-379 to actually process. The first loop is redundant.

```gdscript
# CURRENT — loop 1: check if any archetypes have entities
for arch in matching_archetypes:
    if not arch.entities.is_empty():
        has_entities = true
        total_entity_count += arch.entities.size()
# ... early return checks ...
# CURRENT — loop 2: actually iterate and process
for arch in matching_archetypes:
    var arch_entities = arch.entities
    if arch_entities.is_empty():
        continue
    ...
```

**Fix**: merge into a single loop with the `process_empty` check at the end:

```gdscript
var processed_any := false
for arch in matching_archetypes:
    var arch_entities = arch.entities
    if arch_entities.is_empty():
        continue
    processed_any = true
    # ... snapshot, build components, process ...

if not processed_any and process_empty:
    process([], [], delta)

if ECS.debug:
    # count entities only in debug mode
    ...
```

**Impact**: Halves the archetype iteration overhead in `_run_process`. With 5 matching
archetypes per system, eliminates 5 redundant `.is_empty()` + `.size()` calls per frame.

---

### P0-6: Cache `_query_has_non_structural_filters` result

**File**: `addons/gecs/ecs/system.gd:312`, `system.gd:263` | **Status**: DONE

`_query_has_non_structural_filters(qb)` is called every frame in `_run_process` (line 312) and for every subsystem in `_run_subsystems` (line 263). It checks 6+ array
emptiness conditions and may loop through `_all_components_queries` and
`_any_components_queries`. The result never changes after the query is built.

```gdscript
# CURRENT — recalculated every frame
var uses_non_structural := _query_has_non_structural_filters(_query_cache)
```

**Fix**: cache the result on the QueryBuilder:

```gdscript
# In QueryBuilder — set when query is modified (with_relationship, with_group, etc.)
var _has_non_structural: int = -1  # -1 = uncached

func has_non_structural_filters() -> bool:
    if _has_non_structural == -1:
        _has_non_structural = 1 if _compute_has_non_structural() else 0
    return _has_non_structural == 1
```

Invalidate on `clear()`, `with_relationship()`, `with_group()`, etc. (already reset
`_cache_valid` in those methods — add `_has_non_structural = -1` alongside).

**Impact**: Eliminates 6+ method calls and 2 potential loops per system per frame.

---

### P0-7: PER_GROUP and PER_SYSTEM flush mode checked via string comparison every frame

**File**: `addons/gecs/ecs/system.gd:241`, `world.gd:257-258` | **Status**: DONE

Every system's `_handle()` does `command_buffer_flush_mode == "PER_SYSTEM"` (string
comparison), and after group processing `world.process()` re-iterates all systems doing
`command_buffer_flush_mode == "PER_GROUP"` (another string comparison per system).

```gdscript
# system.gd:241 — every frame, every system
if command_buffer_flush_mode == "PER_SYSTEM" and has_pending_commands():
    cmd.execute()

# world.gd:257 — every frame, every system in group
for system in systems_by_group[group]:
    if system.command_buffer_flush_mode == "PER_GROUP" and system.has_pending_commands():
```

**Fix**: use an integer enum internally:

```gdscript
enum FlushMode { PER_SYSTEM, PER_GROUP, MANUAL }
var _flush_mode: int = FlushMode.PER_SYSTEM  # set from @export_enum string in _ready

# Hot path becomes integer comparison
if _flush_mode == FlushMode.PER_SYSTEM and has_pending_commands():
```

**Impact**: Replaces 2 string comparisons per system per frame with integer comparisons.

---

### P0-8: `has_pending_commands()` lazily creates CommandBuffer for every system

**File**: `addons/gecs/ecs/system.gd:96-100`, `system.gd:174-176` | **Status**: DONE

`has_pending_commands()` accesses the `cmd` property, which lazily creates a
`CommandBuffer` instance even when no commands were ever queued. This is called every
frame for PER_SYSTEM systems (system.gd:241) and for every system during PER_GROUP
flush (world.gd:258).

```gdscript
# system.gd:96-100 — lazy init on access
var cmd: CommandBuffer = null:
    get:
        if cmd == null:
            cmd = CommandBuffer.new(_world if _world else ECS.world)  # <-- allocation
        return cmd

# system.gd:174-176 — called every frame
func has_pending_commands() -> bool:
    return not cmd.is_empty()  # <-- triggers lazy init above
```

**Fix**: guard `has_pending_commands()` to avoid triggering lazy init:

```gdscript
func has_pending_commands() -> bool:
    return cmd != null and not cmd.is_empty()
```

**Impact**: Prevents unnecessary CommandBuffer allocations for systems that never use
`cmd`. With 10 systems at 60fps, eliminates up to 600 unnecessary object creations on
first frame, plus the getter overhead on subsequent frames.

---

## P1 — Cache miss path (affects first frame after structural changes)

### P1-1: Add `_component_type_set` Dictionary to Archetype for O(1) `has()` checks

**File**: `addons/gecs/ecs/archetype.gd:38`, `archetype.gd:183-199` | **Status**: CONFIRMED

`matches_query` uses `component_types.has(comp_type)` where `component_types` is a
sorted `Array`. `Array.has()` is O(n) linear scan. Called at lines 184, 191, and 199.

```gdscript
# CURRENT — O(n) per check, called for every archetype x every query component
for comp_type in all_comp_types:
    if not component_types.has(comp_type):   # line 184
        return false
```

**Fix**: add a parallel Dictionary and use it in `matches_query`:

```gdscript
## Parallel lookup set for O(1) has() checks in matches_query
var _component_type_set: Dictionary = {}  # String (comp_path) -> true

# In _init(), after building component_types:
for comp_type in component_types:
    if not (comp_type as String).begins_with("rel://"):
        _component_type_set[comp_type] = true

# In matches_query:
if not _component_type_set.has(comp_type):  # O(1) instead of O(n)
    return false
```

Keep `_component_type_set` in sync wherever `component_types` is mutated.

**Impact**: Closes the 2.35x cache hit/miss gap. With 50 archetypes x 3 query
components = 150 O(n) array scans -> 150 O(1) dict lookups on every cache miss.

---

### P1-2: Eliminate lambda allocation in `_query` and `get_matching_archetypes` cache-miss path

**File**: `addons/gecs/ecs/world.gd:1044-1047`, `world.gd:1174-1177` | **Status**: CONFIRMED

On every cache miss, a GDScript closure object is allocated and `.map()` creates a new
array. Appears identically in both `_query()` and `get_matching_archetypes()`.

```gdscript
# CURRENT — new lambda + new array allocated on every cache miss (appears TWICE)
var map_resource_path = func(x): return x.resource_path
var _all := all_components.map(map_resource_path)
var _any := any_components.map(map_resource_path)
var _exclude := exclude_components.map(map_resource_path)
```

**Fix**: replace with a plain loop into a pre-typed array (no closure, no `.map()`):

```gdscript
var _all: Array[String] = []
_all.resize(all_components.size())
for i in all_components.size():
    _all[i] = all_components[i].resource_path
```

Apply the same change to `_any` and `_exclude` in both `_query` and
`get_matching_archetypes` (consolidating the two functions would also remove the
duplication — see P2-1).

**Impact**: Removes GC-allocating closure + array on every cache miss call.

---

### P1-3: Eliminate `pair: Array` allocation per relationship in `QueryCacheKey.build`

**File**: `addons/gecs/ecs/query_cache_key.gd:76`, `query_cache_key.gd:105` | **Status**: CONFIRMED

For every relationship in a query, a 2-element Array is allocated, hashed, and
immediately discarded:

```gdscript
# CURRENT — heap allocation per relationship per key build
var pair: Array = []
pair.append(rel_id)
pair.append(target_id)
rel_ids.append(pair.hash())
```

**Fix**: combine with integer arithmetic — no allocation needed:

```gdscript
# FNV-1a style integer combine, no array
var combined = ((rel_id * 2654435761) ^ target_id) & 0x7FFFFFFFFFFFFFFF
rel_ids.append(combined)
```

Apply to both the `relationships` loop (line ~76) and `exclude_relationships` loop
(line ~105).

**Impact**: Eliminates 2 x N array allocations whenever query cache keys are built
(structural changes, world init).

---

### P1-4: Observer dispatch runs full `_query()` per matching observer on every component event

**File**: `addons/gecs/ecs/world.gd:898-973` | **Status**: CONFIRMED

When a component is added or its properties change, `_handle_observer_component_added`
and `_handle_observer_component_changed` loop over **ALL** observers. For each observer
watching the changed component type, a full `_query()` is executed just to check
`entities_matching.has(entity)`.

```gdscript
# CURRENT — full query for every matching observer on every component event
func _handle_observer_component_added(entity: Entity, component: Resource) -> void:
    for reactive_system in observers:
        var watch_component = _observer_watch_cache.get(reactive_system)
        if watch_component and ...:
            var query_builder = reactive_system.match()
            if query_builder:
                var entities_matching = _query(...)   # <-- full archetype scan possible
                matches = entities_matching.has(entity)  # <-- O(n) linear scan
```

Two separate issues:

1. Iterates ALL observers, not just those watching the changed component type
2. Runs a full `_query()` then does `Array.has()` (O(n)) to check one entity

**Fix (part 1)**: Build a `component_path -> Array[Observer]` index at `add_observer()`:

```gdscript
var _observer_by_component: Dictionary = {}  # String -> Array[Observer]

func add_observer(observer):
    ...
    var watch_comp = observer.watch()
    if watch_comp:
        var path = watch_comp.resource_path
        if not _observer_by_component.has(path):
            _observer_by_component[path] = []
        _observer_by_component[path].append(observer)
```

**Fix (part 2)**: Use `entity_to_archetype` + archetype cache to check membership
instead of running a full query:

```gdscript
# Check if entity's archetype is in the observer's cached matching archetypes
var entity_arch = entity_to_archetype.get(entity)
if entity_arch and matching_archetypes.has(entity_arch):
    matches = true
```

**Impact**: With 10 observers and frequent component adds, eliminates 10 full query
executions + 10 O(n) array scans per component event -> 1 dict lookup + 1 archetype check.

---

## P2 — Cleanup / maintainability with minor perf benefit

### P2-1: Consolidate `_query` and `get_matching_archetypes` cache-miss logic

**File**: `addons/gecs/ecs/world.gd:1038-1073`, `world.gd:1169-1205` | **Status**: CONFIRMED

Both functions contain identical archetype scanning + caching logic. Any fix to one
must be manually duplicated to the other (P1-1 and P1-2 above both hit this).

**Fix**: extract a private `_find_and_cache_matching_archetypes(cache_key, ...)` helper
that both call.

---

### P2-2: Remove double bitset capacity check in `Archetype.add_entity`

**File**: `addons/gecs/ecs/archetype.gd:96-97` | **Status**: CONFIRMED

`add_entity` calls `_ensure_bitset_capacity(index + 1)` (line 96), then
`_set_enabled_bit` which calls `_ensure_bitset_capacity` again (line 322). One of the
two calls is always redundant.

**Fix**: remove the explicit `_ensure_bitset_capacity` call on line 96; let
`_set_enabled_bit` handle it as the single point of truth.

---

### P2-3: Cache enabled/disabled entity lists in Archetype

**File**: `addons/gecs/ecs/archetype.gd:293-298` | **Status**: CONFIRMED

`get_entities_by_enabled_state` allocates a new `Array[Entity]` result on every call.
Systems using `.enabled()` hit this per archetype per frame.

**Fix**: maintain `_enabled_cache: Array[Entity]` and `_disabled_cache: Array[Entity]`
with a `_enabled_cache_dirty: bool` flag. Set dirty in `_set_enabled_bit`,
`add_entity`, `remove_entity`. Rebuild lazily on next `get_entities_by_enabled_state`
call.

---

### P2-4: Subsystem `comp_path` computation not cached

**File**: `addons/gecs/ecs/system.gd:296` | **Status**: CONFIRMED

In `_run_subsystems`, each subsystem recomputes component paths every frame:

```gdscript
# CURRENT — per-component, per-archetype, per-subsystem, per-frame
var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
```

The main system path caches these in `_component_paths` (line 307-311), but subsystems
don't get the same treatment.

**Fix**: cache component paths per subsystem tuple on first call, analogous to
`_component_paths`:

```gdscript
# In _run_subsystems, per subsystem tuple:
if not _subsystem_comp_paths_cache.has(subsystem_index):
    var paths: Array[String] = []
    for comp_type in iterate_comps:
        paths.append(comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path)
    _subsystem_comp_paths_cache[subsystem_index] = paths
var comp_paths = _subsystem_comp_paths_cache[subsystem_index]
```

**Impact**: Eliminates `is Script` type checks + property accesses per component per
archetype per subsystem per frame.

---

### P2-5: `QueryBuilder` allocated on every `world.query` / `q` property access

**File**: `addons/gecs/ecs/world.gd:76-80` | **Status**: CONFIRMED

Every access to `world.query` or the `q` shorthand in systems creates a **new**
`QueryBuilder` instance and checks a signal connection:

```gdscript
var query: QueryBuilder:
    get:
        var q: QueryBuilder = QueryBuilder.new(self)    # <-- allocation
        if not cache_invalidated.is_connected(q.invalidate_cache):
            cache_invalidated.connect(q.invalidate_cache)  # <-- signal connection
        return q
```

For systems, the `_query_cache` in `_run_process` means `query()` is called once and
cached. But ad-hoc queries from game code (`ECS.world.query.with_all([...]).execute()`)
allocate a new QueryBuilder each time, with the signal connection never cleaned up
(potential leak on hot ad-hoc query paths).

**Fix**: this is by-design for fresh builder state, but document that game code should
cache query builders when used in loops. Consider a pooling approach for the signal
connection leak.

**Impact**: Low for systems (cached), moderate for ad-hoc game code queries in loops.

---

### P2-6: `_run_subsystems` duplicate snapshot in structural path

**File**: `addons/gecs/ecs/system.gd:291` | **Status**: CONFIRMED

Subsystem structural path duplicates entities just like the main system path:

```gdscript
var arch_entities = archetype.entities.duplicate()
```

Same fix as P0-1 applies — when using `cmd`, the snapshot is unnecessary. The
`safe_iteration` flag from P0-1 should also apply to subsystem iteration paths.

---

## Benchmark checklist

After each change, run the relevant perf suite and confirm improvement:

```bash
# P0-1: safe_iteration flag
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_system_perf.gd"

# P0-2: int keys
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_component_perf.gd"
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_hotpath_breakdown.gd"

# P0-3/4/5/6: system hot path
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_system_perf.gd"

# P1-1: archetype set
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_cache_debug.gd"
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_query_perf.gd"

# P1-2/3: query key allocs
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_indexing_perf.gd"

# Full suite regression check
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance"
```

Key metrics to watch in `reports/perf/`:

- `hotpath_actual_system.jsonl` — overall system frame cost
- `cache_hit.jsonl` / `cache_miss.jsonl` — cache gap should close after P1-1
- `component_get.jsonl` — should improve after P0-2
- `entity_removal.jsonl` — (see out of scope below)

---

## Out of scope (tracked separately)

- **Entity removal O(n^2)** (`world.gd:448` `entities.find()` + `remove_at()`):
  Significant for bulk removal. Fix is swap-remove + `_entity_index: Dictionary` on
  `world.entities`, mirroring what Archetype already does. Deferred — entity removal
  is not on the per-frame hot path for most games.

- **Relationship slot key String construction** (`world.gd:1462-1472`):
  String concatenation per relationship add. Low frequency, acceptable.

- **Signal `is_connected()` O(n) checks on entity add/remove/enable/disable**
  (`world.gd:334-345`, `427-438`, `506-517`, `555-566`):
  Each of 6 entity signals is checked with `is_connected()` before connect/disconnect.
  `is_connected()` scans the signal's internal connection list. With bulk entity
  operations this compounds, but add/remove entity is not per-frame hot path.

- ~~**`relationship_entity_index` built but never queried**~~:
  No longer exists in current codebase (removed or never merged). Item struck.

# Technology Stack

**Project:** GECS Performance & Reliability Audit
**Researched:** 2026-03-15
**Scope:** GDScript / Godot 4.x techniques for ECS caching, signal management, and resource handling

---

## Recommended Stack

This is an existing GDScript-only framework. There are no external dependencies to add and no framework
choices to make. The "stack" question here is: which Godot 4.x APIs and GDScript patterns to use
inside the fixes and optimizations.

### Core Language Patterns

| Pattern | API / Syntax | Purpose | Why |
|---------|-------------|---------|-----|
| Typed arrays | `Array[Entity]`, `Array[Archetype]` | All entity/archetype collections | Godot 4 typed arrays are faster than untyped; compiler can elide runtime type checks |
| Integer Dictionary keys | `Dictionary = {}` with `int` keys | Archetype cache, query cache | Integer hash is cheaper than String hash; `instance_id` (int) is the right key for script identity |
| `Script.get_instance_id()` | Built-in | Component type identity in cache keys | Already used correctly in `QueryCacheKey.build()`; stable for script lifetime, avoids string allocation |
| `dictionary.get(key, default)` | Built-in | All cache lookups | Single call vs `has()` + `[]`; identical hash cost, one fewer opcode |
| `PackedInt64Array` | Built-in | Bitset storage (archetype enabled bits) | Already used in `Archetype.enabled_bitset`; contiguous int64 storage with no GC overhead |
| `append_array()` | Built-in | Entity result flattening | Faster than `+=` (avoids intermediate array allocation); already used in `_query()` |
| Local variable hoisting | GDScript idiom | Hot loops | Cache `entity.components` dict reference in a local before looping over it |
| `is_instance_valid()` | Built-in | Freed-entity guards | Required in CommandBuffer lambdas (already used); avoid calling `entity.method()` without it |

### Profiling and Benchmarking

| Tool | Where / How | What It Measures | Confidence |
|------|-------------|-----------------|-----------|
| `Time.get_ticks_usec()` | GDScript, any context | Wall-clock microseconds; used in `PerfHelpers.time_it()` and `world.perf_mark()` | HIGH — this is the correct timing primitive for GDScript micro-benchmarks |
| Godot editor Profiler panel | Debugger > Profiler tab | Per-function GDScript call counts and wall time | HIGH — built-in, no setup required; shows hottest functions across a frame |
| `Performance.add_custom_monitor()` | GDScript, runtime | Custom metrics visible in Debugger > Monitors | HIGH — official API since Godot 4.0; useful for tracking cache hit/miss ratio per frame |
| `EngineDebugger` capture | GDScript, editor builds | Custom debugger protocol messages | HIGH — already wired in GECS via `GECSEditorDebuggerMessages`; extend for cache audit data |
| JSONL perf tests | `reports/perf/*.jsonl` + `PerfHelpers.record_result()` | Regression baselines over time | HIGH — already in place; the canonical "did we improve?" signal |
| Godot 4.6 Tracy/Perfetto | Engine compile flag | C++ call-level profiling | MEDIUM — only useful if bugs trace to engine-side cost; not needed for GDScript-level audit |

### Data Structure Decisions

| Structure | Use In GECS | Performance Characteristic | Decision |
|-----------|------------|---------------------------|----------|
| `Dictionary` (String key) | `entity.components` (path -> component) | O(1) lookup; String hash cost is ~3-5x int hash | Keep — resource_path strings are already cached in `_component_path_cache`; correct |
| `Dictionary` (int key) | `archetypes` (sig -> Archetype), `entity_to_archetype` (Entity -> Archetype), `_query_archetype_cache` (int -> Array) | O(1) lookup; int hash is cheapest possible | Keep — already int-keyed; correct |
| `Array[Entity]` (typed) | `Archetype.entities`, `World.entities` | Typed array: faster iteration, smaller footprint than untyped | Keep; ensure typed annotation is preserved on every return path |
| `Array` (untyped) | `_all_components`, `_any_components`, `_exclude_components` in QueryBuilder | Untyped, holding Script references | Low risk — these arrays are tiny (2-8 elements); typing them `Array[Script]` would require enforcement of Script-only entries, which breaks the existing mixed-type design |
| `PackedInt64Array` | `Archetype.enabled_bitset` | Contiguous memory, no GC, O(1) bit ops | Keep — correct choice for per-entity boolean flags at scale |
| `Array[Archetype]` | `_query_archetype_cache` values | Typed array of RefCounted objects | Keep; the cache stores archetype references not entity copies, so the reference is stable |

### Signal Architecture Patterns

| Pattern | Current Usage | Recommendation | Why |
|---------|--------------|---------------|-----|
| Deferred signal connections with `is_connected()` guard | `add_entity`, `enable_entity` | Keep guard; it prevents double-connect | MEDIUM confidence — overhead is one bool check per add; correct |
| Disconnect before structural change | `remove_entity` disconnects before emitting `component_removed` | Keep — prevents re-entrancy | This is the right pattern; the existing observer bug #93 is that `remove_entity` fires `component_removed` on World but NOT through `_handle_observer_component_removed`; the signal chain is correct, the observer wiring call is missing |
| Observer match check via full `_query()` | `_handle_observer_component_added` and `_handle_observer_component_changed` | Replace `.has(entity)` linear scan with a direct `entity_to_archetype` lookup | See Pitfalls — calling `_query()` to get all matching entities then doing `entities_matching.has(entity)` is O(N); direct archetype membership check is O(1) |
| `cache_invalidated` signal broadcast | `World.cache_invalidated.emit()` → `QueryBuilder.invalidate_cache()` | Keep the pattern; tighten the conditions that trigger it | Over-invalidation on `enabled` toggle is the current problem — see Pitfalls |

### Caching Architecture

| Layer | Mechanism | Current State | Recommendation |
|-------|-----------|--------------|---------------|
| Archetype-to-query mapping | `_query_archetype_cache: Dictionary` (int -> Array[Archetype]) | Exists; invalidated globally on any component change | Keep global invalidation on structural changes (add/remove component, add/remove entity). Do NOT invalidate on `enabled` toggle — enabled state is stored in the bitset inside the archetype, not in which archetype the entity belongs to |
| QueryBuilder result cache | `_cache_valid` + `_cached_result` per QueryBuilder instance | Exists; invalidated via `cache_invalidated` signal | Keep; the stale edge cache bug (PR #81) is at the archetype transition layer, not here |
| Archetype edge cache | `Archetype.add_edges`, `Archetype.remove_edges` | Buggy — stale references after archetype is deleted | Fix: clear edges pointing TO a deleted archetype when that archetype is removed from `World.archetypes`; or skip edges entirely and let `_move_entity_to_new_archetype_fast` always re-derive the target |
| Component path cache | `Entity._component_path_cache` (Resource -> String) | Exists | Keep; avoids repeated `.get_script().resource_path` in hot path |

---

## What NOT to Use

| Anti-Pattern | Why | Alternative |
|-------------|-----|------------|
| `entity.get_component(C_Foo)` inside per-frame iteration | Calls `.resource_path` property every invocation | Cache `C_Foo.resource_path` as a module-level constant and use `entity.components.get(cached_path)` directly |
| Emitting `cache_invalidated` on `entity.enabled` toggle | Does not change archetype membership; only the bitset changes | Update bitset only; do not emit the signal |
| `Array.has()` for entity membership tests | O(N) linear scan | Use `entity_to_index.has(entity)` on the archetype (O(1) Dictionary lookup) |
| Creating a new `QueryBuilder` inside `_handle_observer_*` | Allocates a RefCounted object per observer per event | Reuse the observer's `q` reference; or check membership via `entity_to_archetype` directly |
| `func(x): return x.resource_path` lambda in `_query()` hot path | Lambda allocation per query miss | Pre-compute the resource path arrays at structural change time, not at query time |
| Calling `watch()` repeatedly on every observer notification | `watch()` is a virtual method that returns a Resource; calling it per event is wasteful | Cache the result of `watch()` on the observer at setup time |
| Untyped `Array` return from `_query()` | Loses compile-time type info | Return `Array[Entity]` consistently |

---

## Godot 4.x APIs Most Relevant to This Audit

| API | Location | What It Does | How GECS Uses It |
|-----|----------|-------------|-----------------|
| `Time.get_ticks_usec()` | `Time` singleton | Microsecond timer | `PerfHelpers`, `world.perf_mark()` |
| `Performance.add_custom_monitor()` | `Performance` singleton | Register per-frame callable metrics visible in Debugger > Monitors | Not yet used — add cache hit rate, archetype count, query miss count |
| `EngineDebugger.send_message()` | `EngineDebugger` | Send structured data to editor plugin | Already used in `GECSEditorDebuggerMessages` |
| `Signal.is_connected()` | Any signal | Prevent duplicate connections | Used in `add_entity`, `enable_entity` |
| `Object.get_instance_id()` | Any Object/Resource | Stable integer identity for lifetime of loaded resource | Used in `QueryCacheKey.build()` for component identity |
| `Script.resource_path` | Any Script | String path to .gd file; used as component type key | Used throughout as Dictionary key in `entity.components` |
| `Node.get_tree().get_nodes_in_group()` | SceneTree | Retrieve all nodes in a named group | Used in QueryBuilder group queries |
| `PackedInt64Array` | Built-in | Dense bit-packed int64 storage | `Archetype.enabled_bitset` |
| `RefCounted` | Base class | GC-managed objects without node overhead | QueryBuilder, Archetype, Relationship extend it |
| `call_deferred()` / `call_deferred_thread_group()` | Object | Schedule a call for end-of-frame | `Entity.deferred_remove_component()` |

---

## Baseline Performance Numbers (from JSONL reports, Godot 4.5-stable)

These are the numbers to beat after fixes. All times are for a single query execution.

| Test | Scale | Current Baseline (ms) | Notes |
|------|-------|-----------------------|-------|
| `hotpath_query_execution` | 100 | ~0.05 | Single query, cache warm, 1 archetype |
| `hotpath_query_execution` | 1000 | ~0.05 | Same — archetype cache eliminates scale cost |
| `hotpath_query_execution` | 10000 | ~0.05 | Same |
| `query_caching` (100 iterations) | 100 | ~2.0 | 100 queries in a loop |
| `query_caching` (100 iterations) | 1000 | ~2.2 | |
| `query_caching` (100 iterations) | 10000 | ~4.0 | Regression in dev4 build; 4.5-stable ~3.5 |

Key observation: `hotpath_query_execution` is already O(1) on scale with a warm cache (0.05ms at all scales). The query execution path is not the bottleneck for correctness. The work this milestone does is to ensure the cache stays warm (no spurious invalidations) and that it never returns stale results (edge cache and `enabled()` filter bugs).

---

## Installation

No new packages. This is GDScript-only.

```bash
# Run tests (Windows)
GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" \
  addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"

# Run only performance baseline
GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" \
  addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance"
```

---

## Sources

- Godot official docs — The Profiler: https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html
- Godot official docs — Custom performance monitors: https://docs.godotengine.org/en/stable/tutorials/scripting/debug/custom_performance_monitors.html
- Godot official docs — Performance class: https://docs.godotengine.org/en/stable/classes/class_performance.html
- Godot official docs — PackedStringArray / PackedArray types: https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html
- Godot official docs — Dictionary: https://docs.godotengine.org/en/stable/classes/class_dictionary.html
- GDScript typed array performance discussion (Godot forum): https://forum.godotengine.org/t/typed-vs-packed-array/3619
- GDScript VM optimizations PR (>40% speedup on typed code): https://github.com/godotengine/godot/pull/70838
- Godot 4.6 dev4 release notes (Tracy/Perfetto profiler support): https://godotengine.org/article/dev-snapshot-godot-4-6-dev-4/
- GECS source: `addons/gecs/ecs/world.gd`, `archetype.gd`, `query_builder.gd`, `entity.gd`, `query_cache_key.gd`
- GECS baselines: `reports/perf/hotpath_query_execution.jsonl`, `reports/perf/query_caching.jsonl`

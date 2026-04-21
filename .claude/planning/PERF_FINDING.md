# GECS Performance Analysis & Optimization Tracking

Last updated: 2026-04-03

---

## Part 1: Investigation Results (2026-04-03)

Investigated performance regressions by comparing today's (Apr 3) perf data against yesterday (Apr 2) and earliest recorded baselines (Oct 2025). Used `tools/perf_report.py` for automated comparison.

### 1. Query Performance: MASSIVE improvement (99% better vs earliest)

The archetype system + int-keyed components made queries nearly free:

| Test                 | Earliest (Oct 2025) | Today  | Change     |
| -------------------- | ------------------- | ------ | ---------- |
| query_with_all (10k) | 12.93ms             | 0.17ms | **-98.7%** |
| query_with_any (10k) | 25.88ms             | 0.24ms | **-99.1%** |
| query_complex (10k)  | 16.43ms             | 0.14ms | **-99.2%** |
| query_caching (10k)  | 556.79ms            | 4.26ms | **-99.2%** |

### 2. Entity/Component Structural Operations: Expected tradeoff, NOT new regressions

The "vs earliest" numbers look alarming but are misleading:

- **`component_addition`**: The jump from ~152ms to ~350ms happened on **2025-10-16** when the archetype system was first introduced — NOT in v7.2.0. Today's 431ms is within normal range (340-480ms) for the archetype era.
- **`entity_creation`**: Remarkably stable at 115-141ms across all versions. The "earliest" of 78.95ms was a single anomalous run. Today's 119.64ms is actually typical.
- **`multiple_component_addition`**: Each component add triggers an archetype move (column maintenance, edge lookup, signature calculation, cache invalidation). 3 components = 3 moves per entity. This is the fundamental cost of archetype-based ECS. The tradeoff is 99% faster queries.

**Verdict**: These are known, accepted tradeoffs from the archetype system (Oct 2025). No action needed.

### 3. system_no_matches: REAL regression — needs bisect

| Date           | Scale=10000 | Godot      | Notes                       |
| -------------- | ----------- | ---------- | --------------------------- |
| 2025-10-13     | 0.092ms     | 4.5-stable | Pre-archetype               |
| 2026-03-16     | 0.095ms     | 4.6-stable | Archetype era, pre-v7.2.0   |
| 2026-03-22     | 0.095ms     | 4.6-stable | **Last data before v7.2.0** |
| **2026-04-03** | **8.979ms** | 4.6-stable | **94x regression**          |

Scales linearly: 0.175ms@100, 0.942ms@1000, 8.979ms@10000. This is O(N) overhead where it should be O(1).

**What the test does**: Creates 10k entities with C_TestA, removes C_TestA from all, then times a single `world.process(0.016)`. The system should find 0 matching archetypes and return in <0.1ms.

**What code analysis shows**: After component removal, only ~3 archetypes exist. The `_run_process` path does: lazy query init → `get_matching_archetypes` (cache miss, scans 3 archetypes, finds 0) → return. This should cost <0.5ms. The 8.98ms is unexplained from code-reading alone.

**Suspects**:

1. **Uncommitted working tree changes** (see Section 6) — `system.gd` and `world.gd` have dirty changes
2. **GC pressure** from 10k component removals right before the timed section
3. **Signal accumulation** on `cache_invalidated` (unlikely — QBs are RefCounted)

**TODO**: Bisect by stashing uncommitted changes and re-running `test_system_no_matches` to confirm whether v7.2.0 or the working tree changes caused it.

### 4. Hotpath Regressions: Likely run variance (noise)

| Test                            | Mar 22  | Apr 2   | Apr 3   | Historical range |
| ------------------------------- | ------- | ------- | ------- | ---------------- |
| hotpath_data_read               | 14.81ms | 15.76ms | 18.21ms | 14-16ms          |
| hotpath_component_access_cached | 12.73ms | 13.13ms | 15.61ms | 12.5-14ms        |
| hotpath_component_access_helper | —       | 24.50ms | 24.28ms | 18-25ms          |

Today's readings are slightly high but within 1-2 standard deviations of historical range. Re-running would confirm whether this is noise.

**One real constant overhead**: `get_component()` changed from `components.get(component.resource_path, null)` to `components.get(_comp_key(component), null)`. The `_comp_key()` adds a function call + `is Script` type check per invocation. This explains `hotpath_component_access_helper` being ~31% worse vs earliest. Could be optimized by inlining.

### 5. Observer Regressions vs Earliest: Mixed picture

| Test                         | Earliest | Today   | Change            |
| ---------------------------- | -------- | ------- | ----------------- |
| observer_component_additions | 8105ms   | 3107ms  | **-61.7% BETTER** |
| observer_component_removals  | 890ms    | 186ms   | **-79.1% BETTER** |
| observer_property_changes    | 3041ms   | 1933ms  | **-36.4% BETTER** |
| observer_baseline_overhead   | 1450ms   | 1935ms  | +33.5% worse      |
| observer_frequent_changes    | 14438ms  | 19008ms | +31.6% worse      |

The first 3 improved dramatically. The latter tests regressed ~30%. The `observer_baseline_overhead` went from ~1450ms (stable Oct 2025) to ~1935ms. Worth investigating what changed in the observer notification path (likely the archetype move overhead during component add/remove that observers trigger).

### 6. Uncommitted Working Tree Changes (CRITICAL CONTEXT)

`git status` shows uncommitted modifications to `system.gd` and `world.gd`. **All perf data from today includes these changes.**

**system.gd uncommitted changes:**

- `command_buffer_flush_mode` changed from `@export_enum(...) String` to `@export FlushMode` enum
- `_flush_mode` int cache variable **REMOVED**
- `_internal_setup()` no longer does string→int conversion
- `_handle()` now compares `command_buffer_flush_mode == FlushMode.PER_SYSTEM` directly

**world.gd uncommitted changes:**

- `system._flush_mode` references changed to `system.command_buffer_flush_mode`

These changes are theoretically fine (enum comparison should be as fast as int), but need verification by running perf tests on clean v7.2.0 vs dirty tree.

---

## Part 2: Optimization TODO (from 2026-03-28 audit, updated)

Items ordered by impact within each tier. Status reflects implementation state.

### P0 — Frame hot path (affects every system, every frame)

| ID   | Item                                                                                     | Status   |
| ---- | ---------------------------------------------------------------------------------------- | -------- |
| P0-1 | Skip `arch_entities.duplicate()` for systems using CommandBuffer (`safe_iteration` flag) | **DONE** |
| P0-2 | Switch `entity.components` dict key from String → int (`Script.get_instance_id()`)       | **DONE** |
| P0-3 | `has_relationship()` fast-path — skip validation/cleanup                                 | **DONE** |
| P0-4 | Cache `sub_systems()` result — eliminate per-frame allocation                            | **DONE** |
| P0-5 | Merge double archetype iteration in `_run_process`                                       | **DONE** |
| P0-6 | Cache `_query_has_non_structural_filters` result                                         | **DONE** |
| P0-7 | Flush mode: string comparison → int enum comparison                                      | **DONE** |
| P0-8 | `has_pending_commands()` — avoid lazy CommandBuffer creation                             | **DONE** |

### P1 — Cache miss path (affects first frame after structural changes)

| ID   | Item                                                                                                           | Status    |
| ---- | -------------------------------------------------------------------------------------------------------------- | --------- |
| P1-1 | Add `_component_type_set` Dictionary to Archetype for O(1) `has()` checks in `matches_query`                   | CONFIRMED |
| P1-2 | Eliminate lambda allocation in `_query` / `get_matching_archetypes` cache-miss path                            | CONFIRMED |
| P1-3 | Eliminate `pair: Array` allocation per relationship in `QueryCacheKey.build`                                   | CONFIRMED |
| P1-4 | Observer dispatch: full `_query()` per matching observer on every component event → archetype membership check | CONFIRMED |

### P2 — Cleanup / minor

| ID   | Item                                                                                     | Status    |
| ---- | ---------------------------------------------------------------------------------------- | --------- |
| P2-1 | Consolidate `_query` and `get_matching_archetypes` cache-miss logic                      | CONFIRMED |
| P2-2 | Remove double bitset capacity check in `Archetype.add_entity`                            | CONFIRMED |
| P2-3 | Cache enabled/disabled entity lists in Archetype                                         | CONFIRMED |
| P2-4 | Subsystem component key computation not cached                                           | CONFIRMED |
| P2-5 | `QueryBuilder` allocated on every `world.query` access (by design, but signal leak risk) | CONFIRMED |
| P2-6 | Subsystem snapshot should respect `safe_iteration` flag                                  | CONFIRMED |

### NEW — From Apr 3 investigation

| ID  | Item                                                                                          | Priority | Status |
| --- | --------------------------------------------------------------------------------------------- | -------- | ------ |
| N1  | **Bisect `system_no_matches` 94x regression** — stash uncommitted changes, re-run test        | **P0**   | TODO   |
| N2  | Inline `_comp_key()` in `get_component`/`has_component` to eliminate function call overhead   | P1       | TODO   |
| N3  | Investigate observer_baseline_overhead +33% regression                                        | P2       | TODO   |
| N4  | Investigate `world.query` property getter signal leak (RefCounted + bound Callable retention) | P2       | TODO   |

---

## Architecture Notes

### Why structural ops are slower than pre-archetype era

Each `add_component`/`remove_component` triggers:

1. `entity.components[key] = component` (dict op)
2. Signal emission → `_on_entity_component_added/removed`
3. `_move_entity_to_new_archetype_fast`: edge lookup → if miss: `_calculate_entity_signature` (keys sort + hash) → `_get_or_create_archetype` → archetype column maintenance
4. `_invalidate_cache`: clear `_query_archetype_cache`, increment `cache_version`, emit `cache_invalidated`

### Why queries are 99% faster

Old: set intersection of `_component_index` entries — O(smallest_set × num_components)
New: archetype signature match — O(num_archetypes × num_query_components), typically O(5 × 1-3) = O(15) lookups regardless of entity count. Results cached until structural change.

---

## How to Run Analysis

```bash
# Run all perf tests
GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance"

# Compare today vs yesterday
python tools/perf_report.py

# Compare specific dates
python tools/perf_report.py --ref-date 2026-04-03 --cmp-date 2026-03-22

# Filter to one category
python tools/perf_report.py --category System --scale 10000

# Only show tests with >= 10% change
python tools/perf_report.py --min-diff 10

# Show all tests including uncategorized
python tools/perf_report.py --all
```

---

## Out of scope (tracked separately)

- **Entity removal O(n^2)** (`world.gd:451` `entities.find()` + `remove_at()`): Significant for bulk removal. Fix is swap-remove + index dict. Not on per-frame hot path.
- **Relationship slot key String construction** (`world.gd`): String concat per relationship add. Low frequency.
- **Signal `is_connected()` O(n) checks on entity add/remove/enable/disable**: Each of 6 entity signals checked. Not per-frame hot path.

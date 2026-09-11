# GECS Performance Guide & Audit

This document records the v8 performance audit that motivated the v9 overhaul, how GECS
compares architecturally to other ECS frameworks (FLECS in particular), what performance
is realistic in pure GDScript, and how to benchmark changes.

## Architecture: why queries are fast

GECS is a **hybrid archetype ECS**. Entities with identical component signatures share an
`Archetype` holding:

- a dense `entities` array + `entity_to_index` map (O(1) swap-remove),
- **SoA columns** per component type (`columns[comp_key]` index-aligned with `entities`) —
  `iterate()` hands systems the real column arrays, zero-copy,
- an `enabled_bitset` so enable/disable doesn't split archetypes,
- `add_edges`/`remove_edges` for O(1) archetype transitions after warmup.

Queries resolve to a **query → matching-archetypes cache**, so a cached query execution is
one dictionary lookup plus a flatten. This is the same core recipe FLECS uses (tables +
cached queries) and it holds up: cached query execution measured 0.1–0.4 ms over 10k
entities.

## The v8 audit: where it fell apart (measured @10k, Godot 4.6)

| Operation | v8 baseline | Root cause |
|---|---|---|
| Component add (single) | 43 µs | full query-cache wipe + signal fan-out per add |
| State transition (remove+add via cmd) | 140 µs/entity | CommandBuffer coalesced cache invalidation but **not** archetype moves (2 moves/entity) |
| Entity world-add | 50 µs | UUID string generation + 6 signal connects per entity + per-component archetype moves |
| Bulk add_entities | 62 µs/entity | looped add_entity — no real batching |
| Observer add-dispatch | 149 µs | entry-array duplicate per event + monitor eval allocations + cache-wipe emit fan-out |
| Property write (emitting setter) | ~21 µs floor | 2 signal hops + payload Dictionary per write |
| get_relationships | 27–34 µs/call | O(R) linear scan, repeated `get_script()` per candidate |
| Wildcard relationship query | 24.6 ms | String slot keys + constant cache misses |
| Stress-test 60 fps ceiling | ~688 entities | all of the above compounding |

The unifying insights:

1. **The query cache maps queries to archetypes, but was invalidated as if it mapped
   queries to entities.** An entity moving between two *existing* archetypes can never
   change which archetypes match a query — only archetype creation/deletion can. Yet every
   non-batched `add_component` cleared the whole cache and emitted `cache_invalidated` to
   every QueryBuilder ever vended by `world.query` (which also leaked builders by
   signal-connecting each one).
2. **Structural change is the expensive operation in any archetype ECS** (FLECS documents
   this trade-off too). Everything that multiplies structural work — per-component spawn
   transitions, deleting empty archetypes (destroying transition edges), replaying command
   buffers op-by-op — multiplies the pain.
3. **In GDScript the enemy is per-call overhead (~0.6 µs/call), signal dispatch (~3× a
   direct call), and per-frame allocations — not arithmetic.** Designs must batch loops
   over columns and avoid per-entity/per-event dispatch and allocation.

## FLECS comparison: what GECS adopts, and what it doesn't

| FLECS mechanism | GECS status |
|---|---|
| Archetype/SoA table storage | ✅ has it (columns hold Component object refs, not packed primitives — see "GDScript ceiling") |
| Cached queries | ✅ has it; v9 fixes invalidation to be archetype-set-scoped and incremental |
| Component → tables reverse index | ✅ relation-type index exists; v9 extends indexing for pairs |
| Keep empty tables (skip in queries) | ✅ v9 — preserves transition edges under churn; `World.compact()` reclaims |
| Deferred command queue / staging | ✅ CommandBuffer; v9 groups per-entity ops into single archetype moves |
| Change detection (per-column dirty state, `it.changed()`) | ✅ v9 — column write-versions + `q.changed()` archetype skipping |
| Entity ids with generation counts | ✅ v9 — single int64 handle replaces sequential ecs_id + UUID strings |
| Relationships as first-class pairs | ✅ pairs are part of the archetype signature; v9 interns them as ints |
| Observers / monitors on the query engine | ✅ Observer + on_match/on_unmatch |
| Prefabs (IsA inheritance) | ❌ Godot scenes/Resources already cover templating |
| Pipelines/phases (DependsOn graph) | ❌ out of scope; system groups + explicit `ECS.process(delta, group)` remain |
| Lockless multithreaded scheduler | ❌ GDScript VM overhead dominates; complexity not worth it |
| Compiled query DSL / query planner | ❌ QueryBuilder covers the practical subset |

## The GDScript ceiling: realistic expectations

- Function/Callable call overhead is ~0.6 µs; a per-entity callback design pays
  ~6 ms/frame at 10k entities *before doing any work*. GECS therefore passes systems whole
  archetype snapshots + SoA columns rather than calling per entity.
- Expect **1–2 orders of magnitude below native ECS** (FLECS/EnTT iterate millions of
  entities/frame; well-written GDScript handles tens of thousands in simple systems at
  60 fps, low thousands with non-trivial per-entity logic).
- Components stay Resource objects (inspector/serialization/network authoring wins);
  columns hold object references, so iteration is Variant-dispatch bound. That floor
  (~1.5–3 µs/entity/system) is close to optimal for GDScript — the v9 wins come from
  making structural ops and events cheap and from *skipping* work (`changed()`), not from
  faster iteration.
- To go beyond the ceiling in a real game: keep the ECS as the simulation authority and
  feed `RenderingServer` (MultiMesh) / `PhysicsServer` directly instead of one Node per
  entity. See the stress-test example for the Node-bound baseline.

## v9 results (release path: v8 vs v9, both `--no-gecs-debug`, Godot 4.7-dev5, same machine)

Structural mutation and eventing — the audit's targets (@10k unless noted):

| Benchmark | v8 | v9 | Δ |
|---|---|---|---|
| State transition via cmd (remove+add) | 1255 ms | 427 ms | **−66%** |
| State transition direct | 1279 ms | 639 ms | **−50%** |
| cmd flush isolation | 1218 ms | 377 ms | **−69%** |
| Bulk spawn (10k, one composition) | 2061 ms | 598 ms | **−71%** |
| Spawn/despawn churn (1k cycle) | 240 ms | 89 ms | **−63%**, cycle3 ≈ cycle1 |
| Multiple component adds (1k) | 231 ms | 109 ms | **−53%** |
| Old worst case: backwards bulk removal | 1272 ms | 127 ms | **−90%** |
| Entity world-add | 471 ms | 311 ms | −34% |
| Entity removal | 154 ms | 88 ms | −43% |
| Monitor transitions (20k transitions) | 3555 ms | 284 ms | **−92%** |
| Property write, zero observers | 86 ms | 48 ms | −45% |
| Observer ADDED dispatch | 1104 ms | 740 ms | −33% |

Change detection (v9-only): `changed()` system @10k entities, 1% writes/frame,
60 frames = **65 ms vs 900 ms** for the equivalent plain system — **13.8×** —
because untouched archetypes are skipped with one int compare.

Guarded fast paths (must-not-regress): cached query execute, `get/has_component`,
per-entity iteration, exact relationship queries — all flat-to-better.

Debug-mode note: `gecs/settings/debug_mode = true` used to cost a flat ~20 ms per
`world.process()` call in instrumentation alone — even with no debugger attached.
As of the debugger overhaul it is **near-zero when unattached** and **bounded when
attached**:

- **Unattached** (headless, or the editor's GECS tab not subscribed): the game
  builds no debugger payloads and sends nothing. The per-process overhead is within
  ~0.3 ms per 100 calls of debug-off. The gate is a single static-bool read
  (`GECSEditorDebuggerMessages.attached`) inside the existing `if ECS.debug:`
  release-strip guards.
- **Attached**: per-system telemetry is throttled to the tab's subscribed rate
  (default 10 Hz) rather than every frame; runtime-side min/max/avg aggregation
  still runs every frame so peaks are never lost. Lifecycle/property categories can
  be turned off from the tab to shed more cost.

Query-timing instrumentation (`world.perf_mark`, the `query_*`/`archetypes_*`
aggregates) is **opt-in** and off by default even with debug on — nothing in the
framework consumes it. Set `world.perf_instrumentation = true` before reading
`world.perf_get_frame_metrics()` / `perf_get_accum_metrics()` when profiling
queries.

## Benchmarking

- Suite: `addons/gecs/tests/performance/` (GdUnit4). Results append to
  `reports/perf/<test>.jsonl`; pre-v9 history is archived in `reports/perf/archive-pre-v9/`.
- Harness: `PerfHelpers.bench()` (warmup + median-of-N, schema v2) for new benchmarks;
  `time_it()`/`record_result()` (single-shot, schema v1) remain for legacy tests —
  expect ±10–20% noise on v1 numbers.
- Summary matrix: `"%GODOT_BIN%" --headless --path . -s res://tools/perf_summary.gd --
  reports/perf reports/perf/archive-pre-v9` writes `reports/perf/SUMMARY.md` with deltas
  vs the archived baseline.
- End-to-end ceiling: run `example_stress_test` — the HUD ramps entity count and appends
  FPS-threshold crossings to `reports/perf/stress_test_ramp.jsonl`.

Regression gates for any core change — these must NOT get slower:

- cached query execute (`query_with_all` etc.),
- `component_get` / `component_lookup`,
- per-entity system iteration (`hotpath_actual_system`),
- `relationship_query_exact`.

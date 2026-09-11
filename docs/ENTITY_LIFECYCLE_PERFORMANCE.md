# Measuring entity creation, destruction and churn

Use `tests/performance/test_entity_lifecycle_perf.gd` for comparable lifecycle
measurements. The older `test_entity_perf.gd` remains useful for historical trends,
but its single-add and bulk-add timings have different scene-tree settings, and
its churn timer excludes allocation and the deferred deletion flush.

## Run and compare

From the repository root in Git Bash:

```bash
GECS_PERF_LABEL=mako-baseline-01 EXTRA_GODOT_ARGS=--no-gecs-debug \
  tools/run_tests.sh -t 180 \
  res://addons/gecs/tests/core/test_entity_batch_lifecycle.gd \
  res://addons/gecs/tests/performance/test_entity_lifecycle_perf.gd

# Also measure bursts of 10,000 two-component entities.
GECS_CHURN_LARGE=1 GECS_PERF_LABEL=lifecycle-large EXTRA_GODOT_ARGS=--no-gecs-debug \
  tools/run_tests.sh -t 180 \
  res://addons/gecs/tests/performance/test_entity_lifecycle_perf.gd

python tools/perf_report.py --category Lifecycle --scale 1000 --label mako-baseline-01
```

Results append to `reports/perf/lifecycle_*.jsonl`. Use a distinct label for each
experiment and inspect only runs whose test summary passed. The report supports
`--ref-date` and `--cmp-date` for comparisons across dates. Records contain raw
samples, median/min/max/mean, nearest-rank p95, warmup count, Godot version, Git HEAD,
GECs debug mode, engine debug-build status, headless status and workload metadata.
Git HEAD does **not** describe uncommitted changes; retain a patch or commit alongside
the label. Disabling GECs debugging does **not** turn an editor executable into an
export release build.

## What is measured

Default scales are 100 and 1,000 entities. Each API receives fresh objects with the
same composition and uses the scene tree. The modes are direct single calls, batch
calls, and command buffers (including queue construction and execution). Each sample
creates, registers and removes the same cohort, then waits through a frame boundary.

| Phase | Includes |
| --- | --- |
| `create` | Allocation and initial component construction/attachment; no test `auto_free` bookkeeping or explicit naming |
| `add` | Scene-tree insertion, GECs initialization and registration; command queue overhead when applicable |
| `remove` | GECs teardown and scheduling `queue_free`; command queue overhead when applicable |
| `drain` | Wall time from the removal calls finishing until the next `process_frame` signal |
| `cycle` | Allocation through that next frame boundary, measured directly rather than summing phase medians |

`drain` includes engine scheduling and other work before the next frame. It is **not**
an isolated measurement of Godot's deletion CPU time. `cycle` is a synthetic workload's
elapsed time through a frame boundary, not a rendered game's frame time. Every sample
checks that the cohort was freed and that the expected resident count remains.
Assertions, logging and setup of persistent populations are outside measured intervals.

Four profiles distinguish costs:

- `nodes`: plain Godot Nodes with `add_child`/`queue_free`, an engine-only baseline.
- `empty`: GECs entities without components.
- `components`: entities with two already attached components.
- `resources`: two component templates in `component_resources`, exercising GECs'
  per-entity initialization copying. This is not a full PackedScene benchmark.

Phase tests discard two warmups and record seven samples. Churn tests record 30
consecutive samples after two warmups, both with an otherwise empty world and with
1,000 persistent entities. The world retains archetypes between cycles, but each
profile/mode starts after a purge. These measure warmed churn, not cold-start latency.
For seven samples p95 equals the maximum; even 30 samples provide only a preliminary
view of the tail. There are no hardware-dependent pass/fail timing thresholds.

Two additional experiments isolate alternatives and scaling:

- Pool enable/disable preserves entities, IDs and components. Setup and final disposal
  are untimed; game-specific reset work is excluded.
- Relationship stress removes 100 **unrelated** off-tree victims with 0, 100 or 1,000
  live relationship archetypes. Setup is untimed and identical across repetitions.
  Off-tree entities are freed synchronously. The scale is the victim count; relationship
  population is recorded separately and in the test name.

## Interpreting results and choosing work

### Initial measured baseline (2026-09-11)

Working tree based on `7fe0285`, run label `lifecycle-verified`, Godot 4.7-dev5
official Windows debug build, headless, GECs debug disabled. The combined validation
run passed 53 cases with zero errors, failures or orphans, including the large burst.
These are local measurements of synthetic fixtures, not production performance claims.

| Workload | Scale | Median ms |
| --- | ---: | ---: |
| Add attached two-component entities, loop | 1,000 | 55.390 |
| Add attached two-component entities, batch | 1,000 | 54.498 |
| Add attached two-component entities, command buffer | 1,000 | 57.341 |
| Remove same composition, loop (before deletion flush) | 1,000 | 16.936 |
| Remove same composition, batch (before deletion flush) | 1,000 | 16.157 |
| Add two-component resource templates, batch | 1,000 | 118.773 |
| Allocate/add/remove/drain two-component entities, batch | 1,000 | 97.671 |
| Allocate/add/remove/drain two-component entities, batch | 10,000 | 1,001.185 |
| Enable/disable pooled two-component entities (no game reset) | 1,000 | 17.582 |
| Remove unrelated victims, no relationship archetypes | 100 | 1.305 |
| Remove unrelated victims, 100 relationship archetypes | 100 | 3.754 |
| Remove unrelated victims, 1,000 relationship archetypes | 100 | 37.316 |

Thirty-sample batch churn at 1,000 entities per cycle measured median 99.326 ms,
p95 102.050 ms and max 102.091 ms. With 1,000 persistent residents it measured
median 99.008 ms, p95 111.346 ms and max 111.483 ms. These are elapsed synthetic
cycles through a frame boundary, not game frame-time measurements.

The loop/batch differences are small enough to avoid promising a meaningful speedup.
The unrelated-relationship experiment exposes a much stronger scaling problem to
address in the framework. Resource-template initialization is another profiling target:
even including allocation, the attached-component path took roughly 75 ms versus
127 ms for templates at 1,000 entities. Pooling is promising when its different
identity, memory and reset contract fits the game; the pool timing is not an
equivalent full lifecycle operation.

### Framework work versus game work

If `add` dominates, compare empty, attached-component and resource-template profiles.
The framework still initializes each entity and computes its final archetype separately.
Template property enumeration/copying and shared-composition registration are candidates
for profiling and optimization. Any fast path must preserve component independence,
`on_ready`, observers, aliases/IDs and per-entity signals. Do not skip lifecycle callbacks
or share mutable component instances just to improve the benchmark.

If removal grows with unrelated relationships, investigate
`World._cleanup_relationships_to_target`: it currently scans relationship archetypes
for each victim. A reverse index from target ID to referring entities/archetypes could
avoid those scans. It needs maintenance and tests for relationship mutations, target
deletion, retained empty archetypes, compact/purge and recycled IDs. This is a framework
cost even when the removed entity has no incoming relationships.

If the actual game's scene creation/deletion dominates, test a pool with a clear reset
contract. `disable_entities` and `enable_entity` retain identity and component state;
they are not replacements for `remove_entities` and `add_entities`. Use `.enabled()`
on queries that should exclude pooled entities. Reset positions, timers, ownership,
relationships, visuals, collision and child-node behavior as the game requires. Retained
objects consume memory and remain visible to queries without an enabled filter.

When gameplay allows it, spreading a large burst over several frames can reduce spikes
without reducing total work. Decide the acceptable spawn latency in the game. Command
buffers provide safe deferred structural changes; they still execute per-entity work
and should not be assumed to accelerate pure spawning/removal.

For MAKO's workload, replace `_make_nodes` with the actual entity PackedScene factory
and retain the same factory for all compared modes. Add the real observers, relationships,
systems, resident count, spawn rate and entity lifetime. Also profile the running game:
record spawn/despawn counts, frame p95/max and memory over time. Repeat with GECs debug
off and on, and in the intended export build. The headless Node baseline cannot predict
rendering, physics, network replication or game callback costs.

## Correctness guardrails

`tests/core/test_entity_batch_lifecycle.gd` covers independent component copies,
callback order and counts, actual deferred deletion, partial removal with swapped rows,
query freshness, ID retirement/reuse, archetype reuse, relationship cleanup on surviving
entities, and pool identity/state preservation. Existing observer/relationship suites
remain necessary when changing lifecycle internals. When removing the whole world,
pass `world.entities.duplicate()` so iteration does not traverse the array being mutated.

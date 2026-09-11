# GECS performance and developer experience review

Reviewed 2026-09-10 against working tree at `7fe0285`, including the existing uncommitted debugger changes. This is a review, not an implementation change.

## Recommendation

Make GECS the Godot ECS that explains what your simulation is doing. Build on its existing stepper, mutation causes, entity graphs, query runner, observers, and dependency tracker. The first product should answer **why an entity did not match a system**, then connect query changes to the recorded mutations that caused them. A reactive UI binding API is the strongest complementary everyday DX feature.

First repair the query execution inconsistencies below. New tooling and reactive APIs need a single trustworthy interpretation of a query.

## Validation and limits

- Existing core and debug suites: **574 tests passed**, zero reported failures/errors/skips, using `tools/run_tests.sh -t 240 res://addons/gecs/tests/core res://addons/gecs/tests/debug` on Godot 4.7-dev5.
- Four temporary targeted probes: three reproduced the defects below; one ruled out an initial packed-array alias/copy concern. The probes were removed after the review.
- Network and performance suites were not rerun. Performance figures below are existing September 8 records, not measurements of this working tree.
- No visual debugger QA or production-game profiling was performed. Proposed speedups need measurement; no multiplier is promised.
- User changes were preserved. Only this report remains from the review.

## Confirmed correctness gaps

### 1. Enabled filtering is lost in systems with post-filters

`addons/gecs/ecs/system.gd:644` gathers all entities from matching archetypes and calls `_filter_entities_global()` (`:804`). That helper checks relationships, groups, and component predicates, but does not check `_enabled_filter`. The subsystem fallback follows the same pattern (`:537`).

Reproduction: register an entity with `C_ObserverTest`, put it in a Godot group, disable it, and use `with_all([C_ObserverTest]).with_group([group]).enabled()` as a system query. `query.execute()` returns zero entities; the system processes one.

Impact: adding a group/property filter can silently cause a system to process disabled entities. Treat as high priority. Share filter semantics among execute, systems, subsystems, and stepping; preserve each execution mode's documented batching behavior.

### 2. Changed filtering is also lost in the post-filter execution path

The same fallback returns before the structural branch's change-key registration, baseline filtering, and baseline advancement (`system.gd:675` onward). Subsystems have the equivalent split.

Reproduction: a system query `with_all([C_ObserverTest]).with_group([group]).changed([C_ObserverTest])` sees one entity on its initial run and incorrectly sees it again on a second run with no writes.

Impact: changed-query correctness and performance depend on which other filters are present. Test combinations of enabled state, property/group/relationship filters, changed baselines, timers, and empty results. A compact parity matrix is more valuable here than more isolated feature tests.

### 3. Safe iteration snapshots entities but leaves component columns live

In `system.gd:705`, `safe_iteration` duplicates the entity array. The unfiltered `iterate()` path still takes live component columns with `arch.get_column()` (`:721`).

Reproduction: two entities share one component/archetype. Run a system with `safe_iteration = true` and `iterate([C_ObserverTest])`; remove that component from the first entity inside `process()`. The entity snapshot still has two entries, while its component column has one. Index alignment is broken.

Impact: callers relying on the advertised safe mutation mode can read another entity's component or access beyond the column. Snapshot the requested column arrays too in safe mode, or explicitly restrict the API; preserve zero-copy behavior in the default command-buffer mode. This is about row alignment, not deep-copying component values.

## Performance work, in priority order

### 1. Avoid collecting entities and then rediscovering their components

`system.gd:644-667` flattens candidate archetypes, filters the flat list, and rebuilds requested component arrays through per-entity `get_component()` calls (`:791`). Enabled/changed subsets also rebuild columns this way.

Resolve component keys once, filter row indices against existing archetype columns, and gather aligned output columns directly. Fuse enabled, changed, and property predicates where practical. Preserve the current single-call fallback contract; silently changing it to one callback per archetype can break per-call accumulators.

Add an optional row/batch view API later if profiling justifies it. Do not replace the existing API with a slower per-entity callback abstraction.

Benchmark: structural versus enabled/group/property/changed queries, with and without `iterate()`, at several selectivities and archetype counts. Track allocations and whole-system time.

### 2. Index incoming relationships and control target-driven fragmentation

`world.gd:2632` cleans incoming relationships by scanning relation-type archetype indexes and matching string suffixes for the target. Unrelated relationship tables contribute work, and an archetype indexed under multiple relation types can contribute duplicate source entities.

Maintain a target-handle-to-incoming-edges/source index through the existing mutation funnels. Removal should visit incoming edges, rather than all relation-bearing archetypes. Include direct and buffered mutation, deserialization, removed targets, and generational handle reuse in correctness coverage.

Separately, exact `(relation, target)` pairs participate in archetype identity (`world.gd:2784`), and the code already warns about archetype explosion (`:2818`). An opt-in non-fragmenting relationship storage policy could help rapidly changing targets such as targeting/ownership. It trades table matching for adjacency lookups or post-filtering; retain structural pairs where they perform well.

Benchmark unique-target cardinality, retargeting, target deletion, and retained empty archetypes. `compact()` reclaims empty tables but does not cure fragmentation among live entities. Actual relationship keys are still strings in these paths despite some documentation describing int interning.

### 3. Make low-frequency change-driven work cheap to author

`archetype.gd:114` scans all rows of a touched archetype to find changed entities. A small number of writes in one large archetype still incurs a full version scan, although processing only changed rows can be a substantial win.

Consider chunk-level dirty summaries first, or a bounded change log with overflow fallback. Multiple systems have independent baselines, so a single destructive dirty queue is not sufficient. Compare sparse and dense writes, multiple readers, timers, and structural churn before choosing a representation.

Property setters still enter the component signal, entity forwarding, and world observer/monitor path (`entity.gd:230`, `world.gd:1072`). An explicit coalesced write scope could stamp once and evaluate derivations once per flush/frame. Keep existing immediate observer delivery semantics intact; coalescing must be an explicit API choice.

The temporary packed-array probe confirmed mutation through a dictionary-retrieved alias updates the original array. Do not claim the current version-array access copies the whole array per write based on its COW comment.

### 4. Finish gating debugger construction, not just transport

Message subscription gating is already implemented. The old ~20 ms unattached-debugger issue in the handoff document is historical and should not be presented as a current finding.

However, `system.gd:443` still measures and aggregates with `ECS.debug`, and `:453` constructs `lastRunData` even without a subscription. The debug branch after structural iteration also counts all matching-archetype entities again.

Separate required profiling aggregation from optional detailed payload construction. Preserve explicit Performance monitor behavior. Benchmark debug off, unattached, subscribed metrics, lifecycle traffic, and active property watches. For subscribed mutation bursts, bound payload volume separately from the already-throttled system metrics.

### 5. Treat threading/native storage as later, workload-specific options

`system.gd:397` already offers parallel processing, but slices arrays and submits worker tasks before immediately waiting. Its default threshold is 50 entities. Establish a measured break-even point and consider range-based batches. Shared command buffers, Resources, static tracking hooks, and scene-tree access need explicit restrictions before expanding this API.

GECS columns store Resource references, not packed numeric component fields. A native/packed backend could raise the ceiling, but it brings authoring, synchronization, export, and debugging complexity. Keep it opt-in and justified by real workloads. A batched MultiMesh presentation adapter or measured spawn pooling may provide more practical value first.

## Existing benchmark evidence

September 8 JSONL entries in `reports/perf/`, Godot 4.7-dev5:

| Workload | Recorded duration | Interpretation |
|---|---:|---|
| 10k entities, 60 frames, 1% writes/frame, changed query | 57.993 ms | Aggregate benchmark duration, not per-frame time |
| Equivalent plain query | 852.759 ms | About 14.7x for this specific workload; not a universal speedup |
| Bulk spawn of 10k entities | 574.004 ms | Burst creation deserves end-to-end investigation |
| Command-buffer state transition of 10k entities | 433.819 ms | Structural churn remains material |

Most of these are single-shot records. Use the existing `PerfHelpers.bench()` warmup/repetition facility for comparisons, recreate mutation preconditions outside timing, and record build/debug mode, CPU, entity count, archetype count, and write density. Test on a supported stable Godot release as well as the current dev build.

## Standout feature: explainable simulation

The useful user flow is:

1. Select an entity and system; choose **Why isn't this running?**
2. Show each failed term: missing component, excluded state, disabled entity, failed property comparison, missing relationship, unchanged since baseline. Include scheduler causes: inactive, paused, timer gate, and whether the group was invoked.
3. Offer **Break when this changes**, including property predicates such as health falling below zero and query enter/exit.
4. Link recorded changes to the system/observer/command-buffer causes already supported by the step journal.
5. Show execution cost context: candidate rows, matched rows, archetypes, skipped rows, fallback path, and allocated/gathered columns.

Start with an on-demand query explanation API and debugger UI. Reuse runtime query semantics instead of maintaining another handwritten evaluator. Extend the existing cause log rather than rebuilding it.

A later opt-in flight recorder can keep bounded history for watched entities and export a diagnostic capture. Existing logs cap/render values and only sweep silent writes while paused, so they are not reversible state snapshots. Full rewind/replay requires explicit snapshot schemas, stable references, RNG/input/time capture, and boundaries for physics/network/external effects. Do not promise deterministic replay from today's serialization and journal alone.

This is a positioning recommendation, not a claim that no other ECS has tooling: [Flecs already has rich query/explorer support](https://www.flecs.dev/flecs/md_docs_2Queries.html) and [query-based alerts](https://www.flecs.dev/flecs/group__c__addons__alerts.html). The opportunity is a cohesive Godot editor workflow for explaining gameplay failures.

## Highest-value DX additions

1. **Computed values and UI bindings.** Build `world.computed(...)` / `bind(...)` on `GECSTracker` and observers: derive health text, inventory totals, quest availability, and action previews without hand-maintained subscriptions. Batch invalidation, recompute once, compare output, and dispose with the owning node. Today tracking is component-type-level and not re-entrant; it does not intercept arbitrary field/column reads. Begin conservatively, handle query entry/exit correctly, and require emitting setters/explicit writes for value changes.
2. **Component contracts and editor validation.** Declare required components, incompatible tags, singleton cardinality, and property invariants. Show actionable scene warnings and optional fixes before Play. Validate first; make automatic insertion an explicit policy, with cycle detection. [Bevy's required components](https://docs.rs/bevy/latest/bevy/prelude/trait.Component.html) are useful precedent, not a unique selling point by themselves.
3. **Typed system/component scaffolding.** An editor action generates component defaults and emitting setters, a system query with `iterate()`, typed locals, command-buffer examples, and navigation to the matching scripts. Prefer explicit generated GDScript over runtime reflection/callback machinery in hot loops.
4. **Query convenience with precise contracts.** Add early-exit `first()`/`exists()`, efficient `count()`, and `single()` that reports zero/multiple matches clearly. Current `execute_one()` (`query_builder.gd:450`) calls full `execute()`. Define result-array ownership so consumers know whether mutating returned arrays is supported.
5. **Versioned save schemas.** Component schema versions, field renames/defaults, and migration hooks make existing serialization more reliable over a game's lifetime. This is a useful prerequisite for diagnostic captures and eventual replay, rather than a second unrelated save system.

## Suggested delivery sequence

1. Repair the three reproduced gaps and add query-execution parity coverage.
2. Ship query explanations and accurate matched/candidate counts: small scope, immediate debugging value.
3. Optimize filtered column gathering and incoming relationship cleanup with measured regression gates.
4. Ship computed UI bindings with clear write/subscription lifetime rules.
5. Expand explanation tooling with conditional breakpoints and bounded capture; consider native storage or full replay only after workload evidence and explicit design.

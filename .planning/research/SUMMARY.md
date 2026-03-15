# Project Research Summary

**Project:** GECS Performance & Reliability Audit
**Domain:** ECS Framework — GDScript / Godot 4.x correctness, caching, and observer systems
**Researched:** 2026-03-15
**Confidence:** HIGH

## Executive Summary

GECS is a mature archetype-based ECS framework for Godot 4.x that already has the right structural foundations: FNV-1a-hashed archetype grouping, SoA column storage, edge-cache-accelerated archetype transitions, a two-level query cache, and a CommandBuffer for deferred structural mutations. The framework's architecture mirrors production ECS designs (Flecs, Unity DOTS) at a GDScript scale. The core problem is not design — it is implementation correctness: six discrete bugs (Issues #5, #53, #68, #87, #93, PR #81) create silent data loss, wrong observer callbacks, and stale query results that undermine the framework's documented guarantees. All six are fully understood and localized to specific line ranges in `world.gd`, `entity.gd`, and `query_builder.gd`.

The recommended approach is a dependency-ordered correctness audit across four tightly sequenced fix phases: observer signal chain first (no external dependencies), then cache invalidation scoping (depends on a stable observer baseline), then archetype edge cache hardening (depends on the corrected invalidation scope), and finally the two independent correctness fixes (component duplication and reverse-relationship query). Performance improvements are deliberately deferred until correctness is confirmed, because benchmark results are meaningless while entities can silently disappear from queries.

The primary risk is scope creep. The research identified a clear anti-feature list — FLECS feature parity, thread safety, debugger UI fixes, timer/tick systems — that must be deferred to separate milestones. A secondary risk is the `_should_invalidate_cache` flag pattern: GDScript has no `try/finally`, so any early return between the flag-set and the final flush leaves queries permanently stale. Every fix phase must audit early-return paths in batch operations.

## Key Findings

### Recommended Stack

This is a GDScript-only framework targeting Godot 4.x. There are no external dependencies, package managers, or framework choices involved. The "stack" question is which GDScript language features and Godot APIs to use in the fixes. Typed arrays (`Array[Entity]`, `Array[Archetype]`) are the single most important discipline: Godot 4's VM optimizer applies >40% speedups to typed code, and the existing codebase mixes typed and untyped returns inconsistently. Integer Dictionary keys (using `instance_id()` or FNV-1a hash) are already used correctly in the archetype and query caches and must be preserved. `PackedInt64Array` for the enabled bitset is the correct data structure and scales to 1M entities at O(n/64).

Profiling infrastructure is already in place (`PerfHelpers.time_it()`, JSONL baselines in `reports/perf/`). The canonical "did we improve?" signal is the `hotpath_query_execution` JSONL file, which currently shows O(1) scale behavior at all entity counts (0.05ms at 100, 1000, and 10000 entities) — confirming the archetype cache is working when warm. The `query_caching` baseline shows a regression at 10000 entities (4.0ms vs expected 3.5ms) which is likely explained by spurious full-cache wipes.

**Core technologies:**
- `Dictionary` with int keys: archetype and query cache lookups — O(1), cheapest possible hash
- `PackedInt64Array`: enabled bitset storage — contiguous memory, O(n/64) bitset ops, no GC overhead
- `Array[Entity]` typed arrays: entity storage in archetypes — faster iteration via VM typed array optimization
- `Time.get_ticks_usec()`: micro-benchmark timing — correct primitive for GDScript performance measurement
- `Performance.add_custom_monitor()`: not yet used, should be added for cache hit/miss rate tracking per frame

### Expected Features

The feature audit is grounded in direct source inspection of known open issues. The must-have features are all correctness properties — things the framework's documentation promises but currently violates.

**Must have (table stakes):**
- Correct query results on every call — Bug #87: `.enabled()` returns disabled entities from cache
- Observer fires with the correct live component instance — Bug #68: wrong instance may be emitted on `remove_component`
- `remove_entity` notifies all observers for every component — Bug #93: observer match filter bypassed in bulk-removal path
- Archetype membership stays consistent after component mutation — PR #81: entities silently drop from queries after archetype empty/re-create cycle
- Component instance identity preserved through `add_entity` — Bug #53: non-`@export` properties reset by `Resource.duplicate(true)` in `_initialize`
- `with_reverse_relationship` returns correct targets — Bug #5: method passes entity objects to `with_all`, which expects component Script types

**Should have (competitive differentiators, already implemented but need correctness audit):**
- Archetype edge cache for O(1) component transitions — valuable but currently the source of query dropout; must be fixed before advertising
- Observer/reactive system with `watch()` + `match()` separation — undermined by bugs #68 and #93; fix restores this differentiator
- CommandBuffer with configurable flush modes (PER_SYSTEM, PER_GROUP, MANUAL) — correct and documented; genuine differentiator, preserve invariants

**Defer (v2+):**
- FLECS feature parity (staging pipeline, sparse sets) — scope creep before correctness audit
- Thread-safe parallel system processing — GDScript is single-threaded; massive complexity for limited gain
- Debugger overlay/inspector UI fixes (#72, #75, #77) — separate problem domain
- Startup system lifecycle override (#82) — enhancement, not a correctness problem
- Automatic property-change detection without explicit signal emission

### Architecture Approach

GECS uses a two-level cache architecture: an archetype-set cache at the World level (`_query_archetype_cache: Dict[int -> Array[Archetype]]`) and a per-QueryBuilder result cache (`_cache_valid + _cached_result`). These two layers serve different purposes — the archetype cache answers "which archetypes match this query signature?" and should only be invalidated when the archetype set changes; the result cache answers "which entities are in those archetypes?" and must be invalidated on any structural mutation including entity movement. The current implementation conflates the two: `_invalidate_cache` clears both layers unconditionally on every component add/remove, even when the entity simply moves between two already-existing archetypes. This is the root of the spurious invalidation problem. The fix is surgical: restrict `_query_archetype_cache` invalidation to `_get_or_create_archetype` (new archetype) and archetype deletion events only.

The observer notification pattern is duplicated three times (`_handle_observer_component_added`, `_handle_observer_component_removed`, `_handle_observer_component_changed`) with inconsistent behavior: the added and changed handlers apply the observer's `match()` filter; the removed handler does not. This asymmetry is the direct cause of Bug #93's secondary problem (observers firing on entities they never watched). The world.gd file is the principal complexity sink: archetype lifecycle, two-path archetype transitions (edge-cache fast path + set-diff slow path), query execution + caching, observer notification, and cache invalidation all live in a single file.

**Major components:**
1. `world.gd` — archetype lifecycle, query execution, cache management, observer dispatch; the primary fix target
2. `entity.gd` — component storage, signal emission, `_initialize` sequence (source of Bug #53 duplication)
3. `archetype.gd` — SoA column storage, enabled bitset, swap-remove, edge cache; structurally sound, needs bidirectional edge cleanup
4. `query_builder.gd` — two-level result cache, filter composition, `with_reverse_relationship` (source of Bug #5)
5. `observer.gd` — `watch()` / `match()` contract; correct design undermined by world.gd notification asymmetry
6. `command_buffer.gd` — callable-based deferred mutations; correct and well-tested, preserve invariants

### Critical Pitfalls

1. **Stale archetype edge cache (PR #81)** — when an archetype empties and is erased, neighboring archetypes still hold edge references to the deleted object; subsequent entities using that edge land in an unregistered archetype invisible to all queries. Fix: bidirectional edge invalidation — when deleting archetype A, clear all reciprocal edges in A's neighbors. The current partial fix (re-registering stale archetypes) masks the symptom but must be replaced.

2. **Observer match() filter not applied on removal (Bug #93)** — `_handle_observer_component_removed` fires unconditionally for any entity with the watched component, regardless of the observer's `match()` query. The added/changed handlers do apply the filter. Fix: add the same `_query()` match check to the removed handler, or pre-compute observer archetype membership.

3. **Component non-@export properties reset on add_entity (Bug #53)** — `entity._initialize()` calls `Resource.duplicate(true)` on every component in `component_resources`; Godot's `duplicate(true)` only copies `@export` properties. Non-exported runtime state is silently lost. Fix: only duplicate components from editor-set `component_resources` that are actual shared scene resources; never duplicate components passed programmatically.

4. **Full archetype cache wipe on entity movement (over-invalidation)** — `_invalidate_cache` is called on every component add/remove, even when no archetype was created or deleted. This causes O(n_archetypes * n_queries) rebuild on every structural mutation. Fix: scope `_query_archetype_cache` invalidation to archetype-set changes only.

5. **Disconnect-before-notify ordering in remove_entity (Bug #93 secondary)** — entity signals are disconnected before the observer notification loop in `remove_entity`. Observer callbacks that call back into the entity API during `on_component_removed` get a half-torn-down entity with silent no-ops. Fix: move signal disconnect to after the observer loop completes, or use a re-entrancy guard flag.

## Implications for Roadmap

Based on the dependency graph established in both FEATURES.md and ARCHITECTURE.md, the fix order is non-negotiable: each phase's correctness is a prerequisite for validating the next phase. The suggested phase structure matches the dependency graph exactly.

### Phase 1: Observer Signal Chain Correctness
**Rationale:** Observer bugs (#68, #93) are self-contained — they have no dependencies on cache or archetype fixes. They must come first because observer tests are meaningless if the wrong component instance is delivered or if match() filters are not applied consistently. All subsequent regression tests for cache and archetype correctness will use observers to detect incorrect behavior, so the observer machinery must be reliable first.
**Delivers:** Correct `on_component_added` / `on_component_removed` / `on_component_changed` callbacks with the live instance, applied only to entities matching the observer's `match()` filter; correct behavior during `remove_entity` entity teardown.
**Addresses:** Bug #68 (wrong instance on remove), Bug #93 (match filter bypass, disconnect ordering), Pitfall 7 (signal connection leak on `property_changed`)
**Avoids:** Building any cache correctness tests on top of unreliable observer callbacks

### Phase 2: Cache Invalidation Scoping
**Rationale:** With the observer chain correct, cache behavior can be validated by asserting observer events against query results. The over-invalidation problem (#87, general cache wipe) is the primary performance regression source and must be fixed before any benchmark establishes a new baseline. The enabled filter bug (#87) depends on the archetype cache key being correctly scoped.
**Delivers:** `_query_archetype_cache` invalidated only on archetype-set changes; QueryBuilder result cache still invalidated on all structural mutations; `.enabled()` / `.disabled()` queries return strictly correct results; `_should_invalidate_cache` flag safe against interrupted batches.
**Addresses:** Bug #87 (enabled filter stale cache), over-invalidation anti-pattern, Pitfall 5 (batch flag not restored), Pitfall 6 (bitset off-by-one at 64/128 entity boundaries)
**Avoids:** Establishing performance baselines before correctness is confirmed

### Phase 3: Archetype Edge Cache Hardening
**Rationale:** The edge cache bug (PR #81) depends on Phase 2 being stable: the re-registration partial fix in `_move_entity_to_new_archetype_fast` interacts with cache invalidation paths. Once invalidation is correctly scoped, the edge cache can be fixed with proper bidirectional cleanup rather than workaround re-registration.
**Delivers:** Bidirectional edge invalidation — when archetype A is deleted, all neighbors clear their edges pointing to A; the partial re-registration workaround removed; slow-path `_move_entity_to_new_archetype` hardened with the same guard as the fast path.
**Addresses:** PR #81 (stale edge cache), Pitfall 8 (column desync after swap-remove), Pitfall 1 (root cause of entity query dropout)
**Avoids:** Fragile archetype resurrection masking the true state of the world archetype registry

### Phase 4: Component Lifecycle and Relationship Query Correctness
**Rationale:** Bug #53 (component duplication) and Bug #5 (reverse relationship) are independent of each other and of Phase 1-3. They are placed last because: (a) #53's regression tests require a working observer chain to detect the duplication (Phase 1); (b) #5's fix requires the query cache to be correct so the new code path can be validated end-to-end. Neither introduces new architectural dependencies.
**Delivers:** Non-`@export` component properties preserved through `add_entity`; `with_reverse_relationship` returns correct entity targets using a direct entity-identity check rather than misrouted `with_all` component query; Pitfall 10 (batch `add_components` pre-world bypass) documented and tested.
**Addresses:** Bug #53 (component duplication), Bug #5 (reverse relationship), Pitfall 14 (Godot `duplicate(true)` non-export Array/Dict subresources)
**Avoids:** Leaving the most user-visible data-loss bug (property reset) until after performance work

### Phase 5: Performance Baseline and Regression Infrastructure
**Rationale:** Only after all correctness bugs are fixed do performance numbers become meaningful. Phase 5 establishes clean baselines, adds `Performance.add_custom_monitor()` cache hit/miss tracking, and validates that the reduced-invalidation scope from Phase 2 produces measurable improvement in the `query_caching` JSONL benchmark.
**Delivers:** Updated JSONL baselines; `Performance.add_custom_monitor` for cache hit rate and archetype count; validation that `query_caching` regression at 10000 entities is resolved; incremental archetype match update (only scan new archetypes on cache miss) as a well-scoped optimization.
**Addresses:** Pitfall 13 (watch() called per notification — cache at add_observer time), Pitfall 9 (subsystem cache not cleared on world re-init)
**Avoids:** Premature optimization on top of incorrect behavior

### Phase Ordering Rationale

- **Observer before cache:** The observer chain is the primary diagnostic tool for verifying cache behavior in tests. Fixing it first makes every subsequent phase's tests reliable.
- **Cache scoping before edge hardening:** The edge cache re-registration workaround interacts with cache invalidation. Cleaning up invalidation first simplifies the edge fix and eliminates the workaround.
- **Correctness before performance:** `hotpath_query_execution` already shows O(1) behavior at all scales (0.05ms) when the cache is warm. The `query_caching` regression is almost certainly caused by spurious invalidations, which Phase 2 addresses. There is no performance work to do that is independent of correctness.
- **#53 and #5 last:** Independent fixes with no blockers other than a working test infrastructure, which Phases 1-3 establish.

### Research Flags

Phases that need no additional research (well-understood, exact code locations known):
- **Phase 1:** Bug locations are identified to specific line numbers in world.gd; fix patterns are standard (add match() check, reorder disconnect)
- **Phase 2:** Over-invalidation fix is architectural but straightforward; the two-layer cache separation is clearly described
- **Phase 3:** Root cause is bidirectional edge cleanup; pattern is well-documented in ECS literature (Flecs edge graph model)
- **Phase 4:** Both bugs have exact root causes; #5 fix pattern (entity-identity filter rather than component-type query) is clear

Phases that may benefit from targeted research during planning:
- **Phase 5 (incremental archetype match):** Adding incremental cache update (only scan new archetypes since last invalidation) is a meaningful optimization but requires careful design to avoid introducing new staleness windows. Recommend a focused research-phase task before implementation.
- **Phase 5 (observer archetype pre-computation):** Pre-computing which archetypes each observer cares about (Anti-Pattern 4 fix) is a non-trivial refactor of the notification path and warrants a design document before coding.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All findings from direct source inspection; no external libraries; Godot API references verified against official docs |
| Features | HIGH | Based on direct source inspection of known open issues; bug descriptions match source code line numbers |
| Architecture | HIGH | All architecture claims derived from actual source files in `addons/gecs/ecs/`; no external inference |
| Pitfalls | HIGH | All 14 pitfalls traced to specific code paths with line numbers; 6 confirmed against open issue tracker |

**Overall confidence:** HIGH

### Gaps to Address

- **Subsystem cache invalidation (Pitfall 9):** The `_subsystems_cache` stale-reference-after-world-purge issue is identified but no fix design exists. During Phase 5 planning, decide whether to clear the cache in `_exit_tree`, on world change, or in `System.reset()`.
- **`is_instance_valid` vs world-membership (Pitfall 12):** CommandBuffer lambda guards prevent crashes but not world-membership violations. The correct fix (check `world.entities.has(entity)` instead of `is_instance_valid`) has a performance cost. Needs a documented decision: is this a user responsibility or a framework guarantee?
- **Observer archetype pre-computation timeline:** Anti-Pattern 4 (O(n_observers * n_archetypes) per component mutation) is a known performance problem but fixing it requires restructuring the observer notification model. The research recommends deferring this to Phase 5 planning; if the user base grows to 10+ observers and 1000+ archetypes, this becomes critical.
- **Bitset off-by-one boundary (Pitfall 6):** The `_ensure_bitset_capacity` integer division for exactly-64, exactly-128 entity counts needs explicit trace-through during Phase 2. The research identifies it as a risk but does not confirm whether the current code is correct at those boundaries.

## Sources

### Primary (HIGH confidence)
- `addons/gecs/ecs/world.gd` — archetype lifecycle, cache invalidation, observer dispatch (direct source inspection)
- `addons/gecs/ecs/entity.gd` — component storage, `_initialize` duplication sequence (direct source inspection)
- `addons/gecs/ecs/archetype.gd` — SoA columns, enabled bitset, swap-remove, edge cache (direct source inspection)
- `addons/gecs/ecs/query_builder.gd` — two-level cache, `with_reverse_relationship` bug (direct source inspection)
- `addons/gecs/ecs/observer.gd`, `system.gd`, `command_buffer.gd` — supporting components (direct source inspection)
- `addons/gecs/tests/core/test_archetype_edge_cache.gd` — existing regression test patterns for PR #81
- `reports/perf/hotpath_query_execution.jsonl`, `reports/perf/query_caching.jsonl` — performance baselines
- Godot official docs — Performance class, custom monitors, PackedInt64Array, Dictionary
- Godot engine issue godotengine/godot#74918 — `Resource.duplicate(true)` array/dict subresource limitation
- Godot engine issue godotengine/godot#37222 — `duplicate()` non-`@export` variable behavior

### Secondary (MEDIUM confidence)
- [SanderMertens/ecs-faq](https://github.com/SanderMertens/ecs-faq) — ECS archetype cache patterns and deferred-operation rationale
- [Building an ECS #2: Archetypes and Vectorization — Sander Mertens](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) — archetype edge graph model
- [Flecs Tables and Storage — deepwiki](https://deepwiki.com/SanderMertens/flecs/2.4-tables-and-storage) — archetype edge cache and invalidation model
- [Unity DOTS Testing with ECS — deepwiki](https://deepwiki.com/needle-mirror/com.unity.entities/6.3-testing-with-ecs) — ECS test patterns
- GDScript typed array performance discussion (Godot forum) — typed vs packed array tradeoffs
- GDScript VM optimizations PR (>40% speedup on typed code): github.com/godotengine/godot/pull/70838

### Tertiary (LOW confidence)
- [Godot Resource duplicate pitfalls — Simon Dalvai](https://simondalvai.org/blog/godot-duplicate-resources/) — consistent with official issues but community blog

---
*Research completed: 2026-03-15*
*Ready for roadmap: yes*

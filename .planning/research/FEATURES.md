# Feature Landscape

**Domain:** ECS Framework — Reliability Audit (Godot 4.x / GDScript)
**Researched:** 2026-03-15
**Confidence:** HIGH — based on direct source inspection of GECS internals, known bug reports, existing test suite, and cross-referenced with Flecs/Unity DOTS ECS correctness literature.

---

## Table Stakes

Features users expect. Missing or incorrect = the framework is unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Query returns all matching entities, every call | Core contract of ECS; wrong results are silent data corruption | Medium | Bug #87: `.enabled()` filter returns disabled entities (archetype bitset not consulted during cache hit) |
| Observer fires exactly once per event, with the correct component instance | Reactive code is useless if it gets the wrong data or fires multiple times | Medium | Bug #68: `remove_component` may emit a Script type instead of the live instance; Bug #93: `remove_entity` must fire `on_component_removed` for all components |
| `remove_entity` notifies observers for every component before teardown | Observers that manage secondary state (e.g., cleanup handlers) depend on removal notification | High | Partially addressed in `world.gd` `remove_entity` via explicit loop, but signal disconnect happens BEFORE the loop — observer query matching against `_query()` works because signals aren't used for the removal path |
| Component instance identity preserved through add/remove cycle | Systems and observers receive the live instance they stored, not a duplicate or null | Medium | Bug #53: `_initialize` calls `res.duplicate(true)` on `component_resources`, resetting non-`@export` properties. Non-exported runtime state is silently lost. |
| Archetype membership stays consistent after entity/component mutation | An entity added to archetype A must never silently disappear from query results | High | PR #81 (stale archetype edge cache): empty archetype is purged from `world.archetypes` but remains cached in `add_edges`, so a subsequent entity using that edge lands in an unregistered archetype and drops out of all queries |
| `with_reverse_relationship` returns correct targets | Relationship queries are a documented API; broken = feature doesn't exist | High | Issue #5: `with_reverse_relationship` rewrites the query to `with_all(index_values)` — the index stores target Entity references, not component types, making the resulting `with_all` call semantically wrong |
| Cache invalidation fires when structural state changes | Stale cache = entities appearing/disappearing from queries between frames | Medium | Current logic invalidates on component add/remove (correct) and on enabled/disabled toggle (correct), but archetype edge cache bypass skips world registration, so invalidation never helps entities that never entered the world index |
| `enabled()` / `disabled()` query filter is consistent frame-to-frame | Disabling an entity must remove it from `enabled()` results immediately | Low | Bug #87: bitset is updated but archetype cache (`_query_archetype_cache`) is keyed only on structural components, ignoring enabled state; cached result includes disabled entities |
| Component `duplicate(true)` preserves all relevant state | Scene-placed entities and programmatic entities must behave identically | Medium | Issue #53: `duplicate(true)` copies `@export` vars but discards non-exported runtime-initialized properties; framework must either document this strictly or avoid deep duplication |
| CommandBuffer commands execute in queued order with single cache invalidation | Deferred-safe mutation is a documented guarantee | Low | Current implementation is correct; preserve this invariant |
| System process receives valid (non-freed) entities | Systems cannot safely iterate if entities are freed mid-loop | Low | CommandBuffer was introduced to solve this; `is_instance_valid` guard in lambdas covers this |

---

## Differentiators

Features that make GECS stand out. Not expected, but valued when correct.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Archetype-based SoA column storage with bitset enabled filtering | Cache-friendly iteration; enables Flecs-style direct array access; eliminates per-entity Dictionary lookup in hot path | High | Already implemented; needs correctness audit before advertising as reliable |
| Observer / reactive system with `watch()` + `match()` separation | Clean, declarative way to react to specific component events on specific entity subsets — rarer in GDScript ECS frameworks | Medium | Valuable differentiator but undermined by bugs #68 and #93 |
| CommandBuffer with configurable flush modes (PER_SYSTEM, PER_GROUP, MANUAL) | Lets developers choose between same-frame visibility and maximum batch performance | Medium | Correct and already documented; a genuine differentiator |
| Entity-level component signal chain (`property_changed`) | Allows fine-grained property-level reactivity without polling | Low | Correct; documented limitation that setters must manually emit is acceptable |
| Archetype edge cache for O(1) component transitions | Avoids full archetype scan on every component add/remove | Medium | Valuable but currently the source of query dropout (PR #81). Must be fixed before this can be advertised |
| JSONL benchmark reports for regression detection | Enables data-driven performance comparisons across commits | Low | Already implemented; extend to cover cache hit rates and observer dispatch overhead |
| Topological system sort via dependency declarations | Removes the most common source of frame-order bugs in ECS games | Low | Already implemented and tested; no action needed this milestone |

---

## Anti-Features

Features to deliberately NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| FLECS feature parity (staging pipeline, deferred archetype moves, sparse sets) | Scope creep; current archetype implementation needs correctness audit first — adding more complexity before fixing known bugs creates compounding debt | Finish correctness audit; benchmark; then decide whether to extend |
| Automatic property change detection (no-signal observer triggers) | Requires hooking GDScript property setters globally or polling every frame — both are expensive in GDScript; the current signal-based contract is explicit and debuggable | Keep explicit `property_changed.emit()` pattern; document it clearly |
| Thread-safe / parallel system processing | GDScript is single-threaded by design; Godot's WorkerThreadPool would require locking every Entity and World access; massive complexity for limited gain at GECS's target scale | Defer to a separate milestone; document as out-of-scope |
| Debugger overlay / inspector tooling fixes (#72, #75, #77) | Different problem domain; mixing UI bug fixes into a correctness audit is scope diffusion | Track as a separate milestone; do not mix with ECS data-path fixes |
| Startup system override (#82) | Enhancement, not a correctness problem; adding new lifecycle hooks before the existing ones are reliable is risky | Defer until after observer and cache bugs are closed |
| FLECS-style timer/tick system (PR #74) | Separate feature; the ECS core does not need it to be correct | Defer to its own PR/milestone |
| Weakly-typed component queries (arbitrary dict-based property matching at query time) | Already exists and is not a correctness gap; expanding it risks over-engineering the query layer before the structural cache is reliable | Do not extend; audit what exists |

---

## Feature Dependencies

The ordering below reflects what must be correct before a dependent feature can be trusted.

```
Component identity (#53) → Observer events (#68, #93) → all reactive code
Archetype edge cache (PR #81) → enabled/disabled filter (#87) → query correctness at scale
Query correctness (all above) → Benchmark validity → performance improvements
```

More specifically:

- **Bug #53 (component duplication)** must be fixed before observer tests are meaningful, because `on_component_removed` may receive a different instance than the one passed to `on_component_added`.
- **PR #81 (stale edge cache)** must be merged before any benchmark establishes a new baseline. Entities silently dropping out of queries makes throughput numbers meaningless.
- **Bug #87 (enabled filter stale cache)** can only be validated after the archetype cache key correctly encodes enabled state, or the cache is bypassed for enabled-filtered queries.
- **Bug #93 (remove_entity skips on_component_removed)** is now partially addressed in `world.gd` but the fix path (explicit loop + `_handle_observer_component_removed`) must be verified to fire with the correct component instance — it depends on Bug #68 being clean.
- **Bug #5 (with_reverse_relationship)** is independent of the above and can be fixed in isolation.

---

## MVP Correctness Scope for This Milestone

Fix in this order (dependency-driven):

1. **Bug #53** — Component non-`@export` properties reset. Fix `_initialize` to not call `duplicate(true)` on components that are already live instances when added programmatically. The dupe is only needed for scene-resource components that would otherwise be shared references.
2. **PR #81** — Stale archetype edge cache. Ensure that when a cached edge target archetype is retrieved and not in `world.archetypes`, it is re-registered before the entity is placed into it.
3. **Bug #68** — Wrong component instance in `component_removed` signal. The `remove_component` fallback path (`component.resource_path` when not in `_component_path_cache`) handles a Script argument, but should verify the emitted value is always the stored instance, not the Script type.
4. **Bug #93** — `remove_entity` skips `on_component_removed`. Verify the explicit loop in `world.remove_entity` reaches every observer with the correct entity+component pair; write regression tests confirming the count is exact.
5. **Bug #87** — `.enabled()` returns disabled entities from cached results. The fix is to exclude enabled state from the structural archetype cache key but apply bitset filtering at flatten time (already partially done in `_query`), and ensure the QueryBuilder result cache (`_cache_valid`) is invalidated on enabled state change.
6. **Bug #5** — `with_reverse_relationship` broken. The index stores Entity targets, not component types; `with_all` cannot consume Entity references. Needs a dedicated query path that checks entity identity, not component types.

Defer: All items in the Anti-Features table.

---

## Observer/Reactive System Correctness Requirements

A production-quality observer implementation must satisfy these invariants:

1. **Correct instance**: `on_component_added(entity, component)` receives the same object that `entity.get_component(T)` would return at that moment.
2. **Correct instance on removal**: `on_component_removed(entity, component)` receives the instance that was stored — not a Script reference, not a duplicate, not null.
3. **Fires on entity destruction**: If an entity is removed from the world, each component it holds triggers `on_component_removed` on all registered observers before the entity is freed.
4. **No double-fire**: Removing an entity must not cause an observer to fire twice for the same component (the signal-disconnect-before-loop pattern in `world.remove_entity` prevents this; must be maintained).
5. **Query filter is respected**: An observer with a `match()` query must not fire for entities that do not satisfy that query at the time of the event. For component removal, the entity may no longer satisfy the query by the time the event fires — the framework must decide and document which snapshot (before or after removal) is used for matching.
6. **No stale entity references after free**: Observers must not hold references to entities that have been freed. The `is_instance_valid` pattern in CommandBuffer lambdas is the correct model.

---

## Query Caching Correctness Requirements

1. **Structural invalidation**: Any change to which archetype an entity belongs to (component add/remove) must invalidate the archetype-level query cache (`_query_archetype_cache`). Currently done via `_invalidate_cache()`.
2. **Enabled-state invalidation**: Toggling `entity.enabled` must invalidate the entity-level result cache in QueryBuilder (`_cache_valid`). Currently the bitset is updated but the QueryBuilder instance's `_cache_valid` flag may survive across the state change.
3. **Edge cache re-registration**: When an archetype is retrieved from an edge cache entry and that archetype is no longer in `world.archetypes`, it must be re-added before the entity is placed into it. Otherwise the archetype is invisible to all queries.
4. **Single source of truth for cache keys**: The cache key must deterministically encode exactly the components that define structural membership. Enabled state is NOT structural (uses bitset overlay), so it must NOT be in the cache key, but must be applied at query-result-collection time.
5. **Batch invalidation is correct**: The `_should_invalidate_cache = false` batch pattern in `add_entities` / `remove_entities` must still result in exactly one full invalidation at the end of the batch — not zero.

---

## Entity Lifecycle Management Correctness Requirements

1. **Add → Initialize → Signal**: Components added before `world.add_entity` must be replayed through `_initialize` so observers and archetype indexing see them.
2. **Remove → Notify → Free**: `world.remove_entity` must: (a) disconnect signals, (b) emit `component_removed` for each component via the direct observer path, (c) emit `entity_removed`, (d) remove from archetype, (e) call `on_destroy`, (f) free. No step may be skipped.
3. **Disable/enable symmetry**: Disabling an entity must move it out of `enabled()` results immediately; enabling must restore it immediately. No query should see a disabled entity in an `enabled()` result in the same or following frame.
4. **No dangling archetype references**: After `remove_entity`, `entity_to_archetype` must not retain a key for the freed entity.
5. **ID registry coherence**: `entity_id_registry` must be updated atomically with entity add/remove so `get_entity_by_id` never returns a freed entity.

---

## Test Coverage Patterns for ECS Correctness

Based on inspection of the existing test suite and ECS correctness literature, the following patterns ensure thorough coverage:

### Pattern 1: Mutation-then-query (structural correctness)
Perform a structural mutation (add/remove component), then assert query results. Must cover:
- Add component to entity that previously had none
- Remove component from entity (entity drops from query)
- Add second component (entity moves to new archetype)
- Rapid add/remove cycles (edge cache stress)

### Pattern 2: Observer event sequence validation
Assert the exact sequence of events, not just counts:
- `on_component_added` fires with the correct instance
- `on_component_removed` fires with the same instance that was added
- `remove_entity` causes `on_component_removed` for every component, exactly once each
- No spurious events for entities that don't match `match()` query

### Pattern 3: Enabled/disabled filter isolation
Assert that `enabled()` and `disabled()` queries return strictly disjoint sets, and that toggling `entity.enabled` moves the entity between those sets immediately.

### Pattern 4: Regression test per bug
Each fixed bug gets its own named test that reproduces the failure sequence exactly. These tests must:
- Set up the minimum state to trigger the bug
- Assert the broken behavior (as a red test before the fix, documented in commit)
- Assert the correct behavior after the fix

### Pattern 5: Component identity assertions
After `add_entity`, after `remove_entity`, and after component replacement:
- Assert `entity.get_component(T)` returns the exact instance that was passed in (object identity, not just type match)
- Assert `on_component_removed` callback receives the same reference as what `get_component` returned before removal

### Pattern 6: Cache hit / cache miss parity
Run the same query twice in sequence, assert the second call returns the same entities as the first. Then mutate (add/remove entity or component) and assert the third call reflects the mutation.

### Pattern 7: Batch operation atomicity
Use `add_entities` / `remove_entities` with batches; assert that partial-batch intermediate state is never visible to queries (i.e., the batch fires a single cache invalidation, not N).

---

## Sources

- Direct inspection: `addons/gecs/ecs/world.gd`, `entity.gd`, `query_builder.gd`, `archetype.gd`, `command_buffer.gd`, `observer.gd`
- Direct inspection: `addons/gecs/tests/core/test_observers.gd`, `test_archetype_edge_cache.gd`, `test_world.gd`, `test_entity.gd`
- Project bug references: Issues #5, #53, #68, #87, #93; PR #81
- [SanderMertens/ecs-faq](https://github.com/SanderMertens/ecs-faq) — ECS correctness patterns (MEDIUM confidence via WebSearch)
- [Building an ECS #2: Archetypes and Vectorization](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) — swap-remove and bitset patterns (MEDIUM confidence via WebSearch)
- [Flecs Tables and Storage](https://deepwiki.com/SanderMertens/flecs/2.4-tables-and-storage) — archetype edge cache and invalidation model (MEDIUM confidence via WebSearch)
- [Unity DOTS Testing with ECS](https://deepwiki.com/needle-mirror/com.unity.entities/6.3-testing-with-ecs) — ECS test patterns (MEDIUM confidence via WebSearch)

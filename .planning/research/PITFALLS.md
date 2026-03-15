# Domain Pitfalls

**Domain:** ECS caching, observer notification systems, entity lifecycle management (GDScript / Godot 4.x)
**Researched:** 2026-03-15
**Confidence:** HIGH — derived from direct code analysis of the GECS source tree plus verification against known open issues.

---

## Critical Pitfalls

Mistakes that cause incorrect query results, silent data loss, or full-system rewrites.

---

### Pitfall 1: Stale Archetype Edge Cache After Empty-Archetype Cleanup

**What goes wrong:**
When an archetype becomes empty its entry is erased from `world.archetypes` and its edges are cleared (`add_edges.clear()`). If a second entity later triggers the same component-add path, `_move_entity_to_new_archetype_fast` can retrieve the deleted archetype object from the *other* side's edge cache (the old archetype was also set as the `remove_edge` of the target archetype) and add the entity to it — without re-registering it in `world.archetypes`. Any subsequent query scans `archetypes.values()` and misses that archetype entirely.

**Why it happens:**
Edge caches store direct Archetype object references, not signatures. When `archetypes.erase(sig)` runs, the object lives on as long as any other archetype still holds a pointer to it via its own `add_edges` or `remove_edges`. The fix in `_move_entity_to_new_archetype_fast` (lines 1296-1298 in world.gd) addresses this for the add path, but the slow-path `_move_entity_to_new_archetype` has identical logic and may have a similar window depending on call order.

**Consequences:**
Entities silently drop out of all queries a frame after the first entity with that component combination is removed. This is the bug documented in PR #81 and reproduced in `test_archetype_edge_cache.gd`.

**Warning signs:**
- Query returns fewer results than expected after any `remove_entity` call.
- Symptoms are intermittent: they only appear when the *first* entity to reach an archetype is destroyed before any other entity joins it.
- `world.archetypes.size()` drops without a matching increase when a second entity adds the same components.

**Prevention:**
- After retrieving an archetype from any edge cache, always check `archetypes.has(archetype.signature)` before proceeding and re-register if absent.
- Apply the same re-registration guard to the slow-path `_move_entity_to_new_archetype` function, not just the fast path.
- Never clear `add_edges` / `remove_edges` unless you are also certain no other archetype holds a back-reference to this one.
- Regression test: create archetype X with one entity, remove that entity (empties and erases archetype X), then add a new entity with the same component set and confirm query finds it. See `test_archetype_edge_cache.gd` for the established pattern.

**Phase that should address it:** Cache invalidation / archetype hardening phase.

---

### Pitfall 2: remove_entity Skips on_component_removed for Observers (Issue #93)

**What goes wrong:**
`world.remove_entity` disconnects entity signals *before* iterating `entity.components.values()` to fire `component_removed`. The observer handler `_handle_observer_component_removed` is called directly after each `component_removed.emit()`, so component-removed observers do fire. However the signal disconnect happens at the top of `remove_entity` (lines 404-411), which means any *side-effect* call inside an observer's `on_component_removed` that calls `entity.remove_component()` will silently no-op because the `component_removed` signal on the entity is no longer connected to `_on_entity_component_removed`.

**Why it happens:**
The disconnect-before-notify ordering is intentional to prevent re-entrancy loops, but it creates a window where observers that call back into the entity API during `on_component_removed` get a half-torn-down entity. The entity's own `component_removed` signal still fires from `entity.remove_component()` but the world is no longer listening.

**Consequences:**
Observer callbacks during entity destruction receive the entity in an indeterminate state. Components may appear missing or present depending on iteration order. Side-effects that queue further removals silently vanish.

**Warning signs:**
- Observer `on_component_removed` fires zero times or fewer times than expected when an entity is destroyed (not when a component is individually removed from a live entity).
- Calling `entity.has_component(X)` inside `on_component_removed` returns `false` for components that have not yet been iterated.

**Prevention:**
- Do not call `entity.remove_component()` or any mutating entity API from inside `on_component_removed` when you cannot guarantee the entity is still live. Use a CommandBuffer instead.
- Regression test: add an observer, destroy an entity with two watched components, assert the observer fires exactly once per component. Also assert no double-fire when remove_entity is used vs. individual remove_component calls.

**Phase that should address it:** Observer signal chain fix phase.

---

### Pitfall 3: Wrong Component Instance Emitted to Observers on remove_entity (Issue #68)

**What goes wrong:**
In `_on_entity_component_removed` (world.gd line 755-768), the component is identified via `component.resource_path` (a Script property). When `remove_entity` calls `component_removed.emit(entity, comp)` directly (lines 415-417), `comp` is the live instance. But in the normal `remove_component` path (entity.gd line 239), the emitted `component_instance` is also correct. The divergence is in what `watch_component.resource_path == component.get_script().resource_path` compares: it calls `.get_script().resource_path` on the `component` argument, which fails with a null reference if the component was already freed or if it is a Script reference rather than an instance.

**Why it happens:**
The `remove_component` single-item path emits the live resource instance. The `remove_entity` bulk-removal path iterates `entity.components.values()` which also yields instances. However, in some call orderings (especially when `_initialize` replays component additions), the instance that ends up in `entity.components` may differ from the instance originally added if a duplicate was introduced. See Issue #53 below.

**Consequences:**
Observer `on_component_removed` receives a component instance whose data may not match what the observer expects, or `get_script()` returns null causing a silent skip.

**Warning signs:**
- Observer `on_component_removed` fires but `component` argument has default values instead of the values at removal time.
- Observer fires zero times for `remove_entity` but fires correctly for manual `remove_component`.

**Prevention:**
- Assert in tests that the instance passed to `on_component_removed` is the exact same object (same `get_instance_id()`) that was originally added and last read via `entity.get_component()`.
- Regression test: add a component with a custom property value, remove the entity, assert observer receives the component with that custom value intact.

**Phase that should address it:** Observer signal chain fix phase.

---

### Pitfall 4: Component Property Reset on Entity Add Due to Duplicate (Issue #53)

**What goes wrong:**
`entity._initialize()` calls `components.values().duplicate_deep()`, clears `components`, then re-adds each component via `add_component(comp)`. It also calls `add_component(res.duplicate(true))` for every entry in `component_resources`. `Resource.duplicate(true)` in Godot 4 only copies properties that carry `PROPERTY_USAGE_STORAGE`, which is tied to `@export`. Non-`@export` properties (plain `var` fields) are reset to their default values in the duplicate.

**Why it happens:**
Godot's `Resource.duplicate()` uses the property list, which only includes exported properties by default. Non-exported vars are initialised to their `_init` defaults in the new instance. This is documented Godot behaviour but is easy to miss when designing components.

**Consequences:**
Any component property that is not `@export` will silently reset to its default value when the entity is added to the world. This is a data-correctness bug that manifests as game logic anomalies (e.g., a health component's internal timer resetting to 0 every time the entity enters a world).

**Warning signs:**
- Component properties read inside a system have default values even though they were set before `add_entity`.
- Bug disappears if the property is changed to `@export`.
- `duplicate_deep()` on the components dict in `_initialize` line 93 propagates the same problem if the source instance already had reset values.

**Prevention:**
- All state that must survive the `add_entity` lifecycle must be declared with `@export` or use a custom `_duplicate` / `_copy_from` override.
- Test: create a component, set a non-`@export` property to a non-default value, add the entity, read the property after `_initialize` completes, assert it equals the set value.
- If non-`@export` state is intentional (e.g., runtime-only caches), document this explicitly on the component class.

**Phase that should address it:** Component lifecycle correctness phase.

---

### Pitfall 5: Query Cache Not Invalidated When _should_invalidate_cache Is False During Batch

**What goes wrong:**
`add_entities` and `remove_entities` temporarily set `_should_invalidate_cache = false` and fire a single invalidation at the end. If an exception, early return, or `assert` failure interrupts the batch after the flag is set to `false` but before the restore and final invalidation run, the cache flag is left in the suppressed state. All subsequent structural changes are silently swallowed — queries return permanently stale results for the rest of the frame or until the next natural invalidation.

**Why it happens:**
GDScript has no `try/finally` construct. The pattern relies on unconditional sequential execution. Any early return between `_should_invalidate_cache = false` (line 336) and `_invalidate_cache(...)` (line 349) in `add_entity` leaves the flag in the wrong state.

**Consequences:**
Entities added or removed after a failed batch are invisible to all queries. This is a silent correctness failure with no error output.

**Warning signs:**
- After a world purge + re-populate sequence, queries return zero results.
- `world.get_cache_stats()["cached_queries"]` shows entries after purge when it should be 0.
- Intermittent failures in tests that add entities inside a loop with conditional logic.

**Prevention:**
- Always restore `_should_invalidate_cache` before any conditional return path.
- Consider wrapping the flag toggle in a helper that guarantees restoration (or use a `finally` equivalent via deferred calls).
- Regression test: interrupt `add_entities` at a known point and verify `_should_invalidate_cache` returns to its original value and that a subsequent query is correct.

**Phase that should address it:** Cache invalidation audit phase.

---

### Pitfall 6: .enabled() Query Returns Disabled Entities (Issue #87)

**What goes wrong:**
`QueryBuilder.enabled()` sets `_enabled_filter = true` and passes it to `world._query`. Inside `_query`, the enabled filter is handled by `archetype.get_entities_by_enabled_state(enabled_filter)`. The bitset logic in `Archetype._get_enabled_bit` returns `false` for any index beyond the current `enabled_bitset` array bounds (line 291-295). New entities appended to an archetype call `_ensure_bitset_capacity` then `_set_enabled_bit`. If `entity.enabled` is `true` at add time, the bit is set correctly. However, if a batch operation suppresses the archetype's `add_entity` path or if the bitset capacity check has an off-by-one, newly added enabled entities may read as disabled from queries using `.enabled()`.

**Why it happens:**
The `_ensure_bitset_capacity` function rounds up to 64-bit boundaries (`(required_size + 63) / 64`). If integer division truncates incorrectly for certain entity counts (e.g., exactly 64 entities), the capacity may be one word short. The `_get_enabled_bit` guard returns `false` when `int64_index >= enabled_bitset.size()`, which reads as disabled.

**Consequences:**
`.enabled()` queries silently exclude entities that are actually enabled. Gameplay systems that filter by enabled state see fewer entities than exist.

**Warning signs:**
- Entity count from `.enabled()` query does not match `entities.filter(func(e): return e.enabled).size()`.
- Bug appears only when entity count crosses a multiple of 64.
- Adding one more entity to the world makes the bug disappear (shifts all indices).

**Prevention:**
- Regression test: add exactly 64, 65, 128, and 129 entities all with `enabled = true`, run `.enabled()` query, assert returned count equals entity count.
- Verify `_ensure_bitset_capacity` with `required_size = 64`: `(64 + 63) / 64 = 1` (integer division) — this may be insufficient if index 63 needs int64 index 0 but the array is not yet allocated. Trace through boundary cases explicitly.

**Phase that should address it:** Query filter correctness phase.

---

## Moderate Pitfalls

---

### Pitfall 7: Signal Connection Leak on Component property_changed

**What goes wrong:**
`entity.add_component` connects `component.property_changed` to `entity._on_component_property_changed` with an `is_connected` guard (entity.gd line 148). However, `entity.remove_component` (entity.gd lines 222-242) does not disconnect `property_changed`. If the same component instance is later added back to a different entity or reused, its `property_changed` signal still fires the old handler, causing phantom observer notifications on the wrong entity.

**Why it happens:**
The disconnect was omitted from `remove_component`. The `is_connected` guard on add prevents duplicate connections on the *same* component-entity pair, but does not prevent a component from accumulating connections to multiple entities if it is transferred.

**Consequences:**
Component property changes notify the wrong entity's observer chain. Memory is not leaked (GDScript RefCounted manages lifetime) but event correctness is broken.

**Warning signs:**
- Observer `on_component_changed` fires for entities that do not currently own the component.
- Changing a property on component C triggers observer for entity A even after C was moved to entity B.

**Prevention:**
- Disconnect `property_changed` in `remove_component` unconditionally.
- Regression test: add component to entity A, remove it, add the same instance to entity B, mutate the property, assert observer fires for entity B only (not entity A).

**Phase that should address it:** Observer signal chain fix phase.

---

### Pitfall 8: Column Array Desynchronisation After Swap-Remove

**What goes wrong:**
`Archetype.remove_entity` uses swap-remove: it moves the last entity to the removed slot, then pops the last slot. It updates `entity_to_index` for the swapped entity and mirrors the same swap across all `columns` arrays. If any code path removes an entity from `entities` or `entity_to_index` without going through `Archetype.remove_entity` (e.g., direct mutation in a test or a future utility method), the column arrays fall out of sync. Index `i` in `columns["c_velocity.gd"]` no longer corresponds to index `i` in `entities`.

**Why it happens:**
Three parallel data structures (`entities`, `entity_to_index`, `columns`) must be kept in sync by a single atomic operation. Any partial update corrupts all three.

**Consequences:**
Systems using `iterate()` receive component data from the wrong entity. Errors are silent — values are wrong, not null.

**Warning signs:**
- `archetype.get_column(path)[i]` returns a component instance whose `parent` is not `archetype.entities[i]`.
- Inconsistency shows up only after a removal, not before.

**Prevention:**
- Never remove an entity from an archetype by any path other than `Archetype.remove_entity`.
- Add an invariant check in test setup that verifies `columns[path].size() == entities.size()` for all component paths after every structural operation.
- Regression test: remove entity at index 0 when 3 entities exist, verify all columns still have size 2 and index-0 data matches `entities[0]`.

**Phase that should address it:** Cache invalidation audit and archetype hardening phase.

---

### Pitfall 9: _subsystems_cache Not Invalidated When sub_systems() Definition Changes

**What goes wrong:**
`System._run_subsystems` caches the result of `sub_systems()` in `_subsystems_cache` on first call and never clears it. If a system dynamically changes its subsystem list (or is reused across world purge/reinit without being freed), the stale subsystem queries continue running. This is especially hazardous if the old query references components or archetypes from the previous world instance.

**Why it happens:**
`_subsystems_cache` is populated lazily but never invalidated (system.gd lines 257-258). There is no hook that clears it when the world is re-initialised.

**Consequences:**
After a world purge + new world init cycle, subsystems execute against the new world's entities using query objects bound to the old world instance.

**Warning signs:**
- After `world.purge` followed by a new `world.initialize`, subsystem-using systems query zero entities or throw null errors.
- `_subsystems_cache[i][0]._world` points to the freed old world.

**Prevention:**
- Clear `_subsystems_cache` in a `reset()` or `_exit_tree()` hook, or re-evaluate it when `_world` changes.
- Regression test: add a system with subsystems, purge the world, create a new world, re-add the system, process one frame, assert the subsystem's query runs against the new world.

**Phase that should address it:** Observer / system lifecycle cleanup phase.

---

### Pitfall 10: Batch add_components / remove_components Bypass Signal-Based Observer Notification

**What goes wrong:**
`entity.add_components` (entity.gd lines 166-215) intentionally skips per-component `add_component` calls and manually moves the archetype once. Signals are emitted at the end in a loop. However, if the entity is not yet in `entity_to_archetype` (i.e., the entity was not yet added to the world), the archetype transition block is skipped entirely, meaning the world's `_on_entity_component_added` handler never fires, and observers are never notified.

**Why it happens:**
The batch path optimises for the common in-world case. The pre-world case falls through silently because `ECS.world.entity_to_archetype.has(self)` is `false`.

**Consequences:**
Components added via `add_components` before `add_entity` are not indexed in the archetype until `_initialize` replays them. If `_initialize` is called, this is correct. But if `add_components` is called on an already-initialised entity that is somehow not yet tracked (edge case during deferred setup), components are stored in `entity.components` but not in the archetype, making the entity invisible to queries on those components.

**Warning signs:**
- `entity.has_component(X)` returns `true` but a query for X does not include the entity.
- Bug reproduces only during deferred system setup or before the entity is fully registered.

**Prevention:**
- Use `entity.add_component` (singular) when adding components before `add_entity`.
- Do not use `add_components` on entities that are not yet registered in the world.
- Regression test: add two components to a pre-world entity using `add_components`, then call `world.add_entity`, then query for both components and assert the entity is found.

**Phase that should address it:** Component lifecycle correctness phase.

---

## Minor Pitfalls

---

### Pitfall 11: QueryBuilder Cached Result Includes Freed Entities

**What goes wrong:**
`QueryBuilder._cached_result` stores raw entity references. If an entity is removed from the world and freed between two calls to the same `execute()` call site, the cached array still holds the freed pointer. The `_cache_valid` flag is reset by `cache_invalidated.emit()` from the world, but only if the QueryBuilder instance was connected to `cache_invalidated` at creation time (world.gd lines 73-78). A QueryBuilder created with `QueryBuilder.new(world)` directly (bypassing the `world.query` property) is never connected and its cache is never invalidated.

**Prevention:**
- Always obtain QueryBuilder instances via `ECS.world.query` or `_world.query`, never via direct `QueryBuilder.new()` outside of test code.
- In tests, obtain query builders through the world property to ensure cache invalidation wiring is present.
- Regression test: create a QueryBuilder manually, add an entity, invalidate via remove_entity, call execute() again, assert the stale entity is not present.

---

### Pitfall 12: GDScript `is_instance_valid` Guard in CommandBuffer Lambdas Does Not Prevent Stale Archetype State

**What goes wrong:**
CommandBuffer lambdas capture entity references and guard with `is_instance_valid(entity)`. This prevents crashes on freed entities. However, an entity that was removed from the world (via another lambda in the same `execute()` call) but not yet freed (still in the scene tree awaiting `queue_free`) will pass `is_instance_valid` and the subsequent `add_component` / `remove_component` will operate on an entity that is no longer tracked by any archetype. The world's `entity_to_archetype` has already had the entity erased by `_remove_entity_from_archetype`, so the component signal handler `_on_entity_component_added` attempts a lookup that silently fails.

**Prevention:**
- When queuing both a `remove_entity` and a `add_component` on the same entity in the same buffer, ensure the `remove_entity` command comes last, or check `world.entities.has(entity)` inside custom commands.
- Document that `is_instance_valid` is not a substitute for world-membership checks.

---

### Pitfall 13: Observer watch() Called on Every Notification Pass

**What goes wrong:**
`_handle_observer_component_added`, `_handle_observer_component_removed`, and `_handle_observer_component_changed` each call `reactive_system.watch()` inside a loop over all observers (world.gd lines 875, 904, 924). `watch()` must be a trivial accessor returning a preloaded Script, but if a subclass returns a freshly constructed object (e.g., `return C_Health.new()`), this allocates a new Resource every notification cycle.

**Prevention:**
- `watch()` must return a Script reference (e.g., `return C_Health`), not an instance.
- Cache the result of `watch()` per observer at `add_observer` time rather than calling it in the hot notification path.

---

### Pitfall 14: Godot Resource.duplicate(true) Does Not Copy Non-@export Array/Dictionary Subresources

**What goes wrong:**
Even `duplicate(true)` (deep) does not duplicate subresources stored inside `Array` or `Dictionary` properties unless those properties carry `PROPERTY_USAGE_STORAGE`. This is a documented Godot engine limitation (tracked in godotengine/godot#74918). Components that store arrays of nested Resources (e.g., `var buffs: Array[C_Buff] = []`) will share the backing array across duplicated component instances.

**Prevention:**
- Use `@export` on any Array or Dictionary property in a Component if it must survive duplication.
- Alternatively, implement a custom `copy_from(other)` method on the Component class and call it instead of `duplicate()` in `_initialize`.
- Regression test: create a component with a non-export array, add two entities using the same component template, mutate the array on one entity's component, assert the other entity's component is unchanged.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Observer signal chain fix (#93, #68) | Disconnect order in `remove_entity` causing half-torn-down observer state | Fix disconnect to happen after all observer notifications; use CommandBuffer for observer side-effects |
| Archetype edge cache hardening (PR #81) | Slow-path `_move_entity_to_new_archetype` missing the re-registration guard | Apply same guard as fast path; add regression test from `test_archetype_edge_cache.gd` pattern |
| Query filter correctness (#87 enabled filter) | Bitset off-by-one at 64/128/192 entity boundaries | Test boundary counts explicitly; trace `_ensure_bitset_capacity` integer division |
| Component duplication fix (#53) | `Resource.duplicate(true)` drops non-`@export` state | Require `@export` on all component state; add duplicate-and-verify test |
| Cache invalidation audit | `_should_invalidate_cache` flag left `false` after interrupted batch | Audit every early-return path between flag-set and flag-restore; add restore-on-error test |
| Benchmark improvements | Archetype scan on every query miss rebuilds entire match list | Only scan new archetypes added since last invalidation (incremental match update) — but only after correctness is confirmed |
| Regression test suite | Tests that create QueryBuilder with `QueryBuilder.new(world)` bypass cache invalidation wiring | All test fixtures must use `world.query` property, not direct construction |

---

## Sources

- Direct analysis of `addons/gecs/ecs/world.gd`, `entity.gd`, `archetype.gd`, `observer.gd`, `system.gd`, `command_buffer.gd`, `query_builder.gd` (GECS source, 2026-03-15)
- GECS issue tracker references: #93, #68, #87, #53, #5, PR #81 (cited in `.planning/PROJECT.md`)
- `addons/gecs/tests/core/test_archetype_edge_cache.gd` — existing regression tests documenting the PR #81 fix pattern
- Godot engine issue godotengine/godot#74918: `Resource.duplicate(true)` does not duplicate subresources inside Array/Dictionary
- Godot engine issue godotengine/godot#37222: `duplicate()` does not copy non-`@export` variable values in Resources
- [ECS FAQ — SanderMertens](https://github.com/SanderMertens/ecs-faq) — general ECS archetype cache patterns and deferred-operation rationale
- [Building an ECS #2: Archetypes and Vectorization — Sander Mertens](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) — archetype edge graph caching model
- [Godot Resource duplicate pitfalls — Simon Dalvai](https://simondalvai.org/blog/godot-duplicate-resources/) — MEDIUM confidence (community blog, consistent with official issues)

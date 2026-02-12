### GECS AI Coding Guide

Concise, codebase-specific instructions for AI agents. Focus only on proven patterns in this repo.

#### Core Runtime (under `addons/gecs/ecs/`)

Entity (`entity.gd`): Node holding components (data) + relationships. Provides `add_component()`, `has_component()`, `add_relationship()`.
Component (`component.gd`): Resource, data-only `@export` fields. Emits `property_changed` manually to trigger observers.
System (`system.gd`): Override `query()` returning a `QueryBuilder`; implement `process(entities, components, delta)`. Use `iterate([...])` in query for batch column access (components array order matches iterate list). Optional `sub_systems()` returns `[QueryBuilder, Callable]` tuples.
Observer (`observer.gd`): Reactive system: implement `watch()` (returns component instance) and handlers (`on_component_added/removed/changed`). Property changes require explicit signal emission in component setter.
World (`world.gd`): Owns entities, systems, observers, archetype & relationship indices. Provides `world.query` (pooled `QueryBuilder`), archetype cache, enabled/disabled filtering baked into signatures.
ECS (`ecs.gd`): Autoload singleton exposing `ECS.world` and `ECS.process(delta, group?)`.

#### QueryBuilder Essentials (`query_builder.gd`)

Chaining: `with_all([...])`, `with_any([...])`, `with_none([...])`, `with_relationship([...])`, `without_relationship([...])`, `with_group([...])`, `without_group([...])`, `.enabled()`, `.disabled()`, `.iterate([CompA, CompB])`.
Component property filters supported via dictionaries: `with_all([{C_Health: {"current": {"_lt": 20}}}])`.
`execute()` returns entities; `archetypes()` returns matching archetypes for high-performance column access.
Cache keys (FNV-1a) reused between World `_query` and archetype retrieval; relationship changes invalidate query cache.

#### Archetype & Performance Model

Entities grouped by component signature (+ enabled bit) → O(1) query intersection using archetype match + result flattening only when needed. Enable/disable moves entity to distinct archetype; `.enabled()` / `.disabled()` skip entity-level filtering.
Use `iterate()` or `archetypes()` inside systems for tight loops: access columns via `archetype.get_column(component_resource_path)`.
Parallel processing: set `parallel_processing=true` and `parallel_threshold` on a System; only use pure data logic (no scene tree access) inside `process()` when parallel.

#### Relationships (`relationship.gd`)

Create: `Relationship.new(C_Likes.new(), target_entity)` or with property queries: `Relationship.new({C_Buff: {'duration': {'_gt':10}}}, {C_Player: {'level': {'_gte':5}}})`.
Wildcard: pass `null` as relation or target. Removal supports count limiting: `entity.remove_relationship(Relationship.new(C_Damage.new(), null), 2)`.
Reverse queries: `with_reverse_relationship([...])` maps target → sources via index.

#### CommandBuffer (`command_buffer.gd`)

Callable-based deferred execution for safe structural changes during system iteration. Each queue method appends a lambda with baked-in `is_instance_valid` guard to `Array[Callable]`. Commands execute in exact queued order.

System property: `cmd: CommandBuffer` (lazy-initialized). Queue methods: `add_component()`, `remove_component()`, `add_components()`, `remove_components()`, `add_entity()`, `remove_entity()`, `add_relationship()`, `remove_relationship()`, `add_custom()`. Inspection: `is_empty()`, `size()`, `get_stats()`. Manual: `execute()`, `clear()`.

Flush modes (`command_buffer_flush_mode` export on System):
- **PER_SYSTEM** (default): auto-executes after each system completes
- **PER_GROUP**: auto-executes after all systems in group complete
- **MANUAL**: requires explicit `ECS.world.flush_command_buffers()`

Pattern: use `cmd.remove_entity(entity)` instead of `ECS.world.remove_entity(entity)` inside system `process()` for safe forward iteration. Use `cmd.add_component(entity, comp)` instead of `entity.add_component(comp)` when modifying entities during iteration.

#### Reactive Patterns

Emit `property_changed` from component setters to enable observers. Observers internally call `match()` query then fire callbacks if entity remains in result set for add/change; removal bypasses query check.

#### Testing & Perf Workflow

Test root: `addons/gecs/tests/` (core + performance). Always prefix paths with `res://`.
Windows: `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"`. Linux/macOS: `addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests"`.
Specific test method: `runtest.sh -a "res://addons/gecs/tests/core/test_entity.gd::test_add_and_get_component"` (no spaces around `::`).
Performance tests log JSONL to `reports/perf/` with fields: `timestamp,test,scale,time_ms,godot_version`. Keep filenames stable for tooling (`tools/perf_viewer`).
Perf viewer task (uv): see VS Code task "Perf Viewer: Generate Report & Open" or run `uv run perf-viewer --dir reports/perf --out perf_report.html`.

#### Conventions

Naming: Components `C_Foo`, Systems `FooSystem`, Observers `FooObserver`. Files often prefixed (`c_foo.gd`, `s_foo.gd`). Data-only components—push logic to Systems/Observers.
System grouping via `@export var group`; process selectively: `ECS.process(delta, "physics")`.
Use `q` shortcut (world-bound) inside systems & observers; avoid manual scene-tree scans beyond groups (QueryBuilder handles indexing).

#### Safe Extension Guidelines

Add new query predicates by following patterns in `query_builder.gd` (invalidate cache on structural changes; integrate with relationship signals if needed).
When altering archetype logic, maintain signature stability (sorted component paths + enabled bit) to preserve cache correctness.
Document user-facing API changes in `addons/gecs/README.md`; add/adjust tests (include property query + relationship edge cases; perf tests for scaling).

#### Common Pitfalls

Missing `res://` in test paths → tests not discovered.
Adding behavior to Components → breaks data-only design (move to System/Observer).
Forgetting to emit `property_changed` → observers won’t trigger on mutations.
Not using `iterate()` for batch loops → unnecessary per-entity `get_component()` overhead.
Scene tree access inside parallel system processing → undefined behavior (avoid).

#### Release Process

Tag (`git tag vX.Y.Z && git push`) to generate `release-vX.Y.Z` and `godot-asset-library-vX.Y.Z` (no tests). Don’t hand-edit release branches.

#### Example Optimized System

```gdscript
class_name VelocitySystem
extends System
func query():
    return q.with_all([C_Velocity, C_Transform]).iterate([C_Velocity, C_Transform])
func process(entities: Array[Entity], components: Array, delta: float) -> void:
    var velocities = components[0]
    var transforms = components[1]
    for i in entities.size():
        transforms[i].transform.global_position += velocities[i].velocity * delta
```

#### Agent Checklist Before Commit

1. Query usage follows builder chain & avoids manual scans.
2. Components remain data-only; property setters emit signal if observers required.
3. Systems using performance paths rely on `iterate()` / `archetypes()`; parallel flag only with safe code.
4. Added/changed behaviors have matching tests; performance-impacting changes log JSONL.
5. No release branch modification; docs updated if public API changed.

Feedback welcome—request clarification for any unclear section to iterate.

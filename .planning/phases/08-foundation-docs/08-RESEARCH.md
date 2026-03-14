# Phase 8: Foundation Docs - Research

**Researched:** 2026-03-13
**Domain:** GDScript documentation accuracy — GECS v6.8.1 API verification
**Confidence:** HIGH

## Summary

Phase 8 rewrites three "first-touch" docs: GETTING_STARTED.md, CORE_CONCEPTS.md, and SERIALIZATION.md. The primary task is not discovering new technology — it is verifying every API call, class name, and method signature shown in the existing docs against the actual `.gd` source files, then rewriting with corrections.

All three existing docs have accuracy problems. GETTING_STARTED has style violations (emoji-heavy, verbose preamble) and shows `entity.global_position` as if Entity extends Node3D, which it does not — Entity extends Node. CORE_CONCEPTS contains invented variable names (e.g., `sprite_comp`, `transform_comp`) in code examples that reference variables never declared. SERIALIZATION is the most accurate of the three but its data structure section shows `GecsData.version = "0.1"` when the actual source has `"0.2"`, and it omits the `GECSSerializeConfig` fields that developers will encounter.

**Primary recommendation:** Use the verified API table below as the source of truth when writing every code example. Run each example mentally against the source before including it.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Rewrite depth: per-doc judgment (light edit vs full rewrite)
- Rewrites may add new sections if they close clear gaps (e.g., CommandBuffer wasn't in GETTING_STARTED)
- Prefer minimal code examples — just enough to show the API signature works
- CORE_CONCEPTS: keep ECS philosophy framing but trim if bloated; intro not just reference
- Strip all emojis from headers and body text
- No lengthy intro paragraphs — lead with content immediately
- No version stamp at the top
- Keep blockquote callout boxes (`> **Note:** ...`) but no emoji in them
- No trailing "By the end of this guide..." preamble
- SERIALIZATION: full accurate API doc — system is real (ECS.serialize/save/deserialize, GECSSerializeConfig, GecsData all verified in source)
- Document both save formats: text .tres and binary .res
- Cover GECSSerializeConfig fields — devs will hit them
- GETTING_STARTED: keep both entity paths (scene-based and code-based)
- Terminal state: dev has built minimal complete ECS loop — entity + component + system + ECS.process()
- Mention CommandBuffer briefly with a link to CORE_CONCEPTS — do not teach it in GETTING_STARTED
- Installation: brief (2-3 lines) — copy to addons/, enable plugin, verify ECS autoload — link to README for detail

### Claude's Discretion
- Exact structure and section ordering within each doc
- Whether CORE_CONCEPTS gets a brief "why ECS" intro or cuts straight to class-by-class reference
- Which specific examples to use in minimal code samples (just make them accurate)
- Cross-linking strategy between the three docs

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CORE-01 | Developer can follow GETTING_STARTED end-to-end without hitting code that doesn't compile or APIs that don't exist | API verification table below; identified broken patterns in existing doc |
| CORE-02 | CORE_CONCEPTS accurately reflects the real ECS singleton, World, Entity, Component, System APIs — no invented methods | Full source audit of entity.gd, system.gd, ecs.gd, world.gd, query_builder.gd |
| CORE-06 | SERIALIZATION verified against actual code — or clearly marked as removed/changed | io.gd, serialize_config.gd, gecs_data.gd, gecs_entity_data.gd all read and verified |
</phase_requirements>

---

## Standard Stack

This phase produces Markdown documentation only. No new libraries or dependencies.

### Tooling for Verification
| Tool | Version | Purpose |
|------|---------|---------|
| Godot 4.6 | stable | Target runtime — all API calls must match this version |
| GDScript | built-in | Language for all code examples |
| Markdown | standard | Doc format for all three files |

### Files Being Rewritten
| File | Current State | Action |
|------|--------------|--------|
| `addons/gecs/docs/GETTING_STARTED.md` | Emoji-heavy, contains broken spatial-entity pattern, missing CommandBuffer mention | Full rewrite |
| `addons/gecs/docs/CORE_CONCEPTS.md` | Good structure, several invented variable names in examples, query section references non-existent `with_reverse_relationship` as query builder method name (correct name confirmed below) | Light edit with targeted example fixes |
| `addons/gecs/docs/SERIALIZATION.md` | Mostly accurate, missing GECSSerializeConfig detail, wrong version string, missing `include_related_entities` behavior | Light edit with config section addition |

---

## Architecture Patterns

### Verified GECS API — Complete Reference for Code Examples

This section documents every public API that docs may reference. Derived directly from source files.

#### ECS Singleton (`ecs.gd` — class `_ECS`, autoloaded as `ECS`)

```gdscript
# Properties
ECS.world: World              # get/set — current active World
ECS.wildcard                  # null — use in relationship queries
ECS.debug: bool               # from ProjectSettings gecs/debug_mode
ECS.entity_preprocessors: Array[Callable]
ECS.entity_postprocessors: Array[Callable]

# Methods
ECS.process(delta: float, group: String = "") -> void
ECS.get_components(entities, component_type, default_component = null) -> Array
ECS.serialize(query: QueryBuilder, config: GECSSerializeConfig = null) -> GecsData
ECS.save(gecs_data: GecsData, filepath: String, binary: bool = false) -> bool
ECS.deserialize(gecs_filepath: String) -> Array[Entity]

# Signals
ECS.world_changed(world: World)
ECS.world_exited
```

#### Entity (`entity.gd` — class `Entity extends Node`)

```gdscript
# Exported properties
entity.id: String
entity.enabled: bool
entity.component_resources: Array[Component]
entity.serialize_config: GECSSerializeConfig

# Public properties
entity.components: Dictionary          # resource_path -> Component
entity.relationships: Array[Relationship]

# Component methods
entity.add_component(component: Resource) -> void
entity.add_components(_components: Array) -> void
entity.remove_component(component: Resource) -> void
entity.remove_components(_components: Array) -> void
entity.remove_all_components() -> void
entity.get_component(component: Resource) -> Component  # pass the Script class
entity.has_component(component: Resource) -> bool       # pass the Script class

# Relationship methods
entity.add_relationship(relationship: Relationship) -> void
entity.add_relationships(_relationships: Array) -> void
entity.remove_relationship(relationship: Relationship, limit: int = -1) -> void
entity.remove_relationships(_relationships: Array, limit: int = -1) -> void
entity.remove_all_relationships() -> void
entity.get_relationship(relationship: Relationship) -> Relationship
entity.get_relationships(relationship: Relationship) -> Array[Relationship]
entity.has_relationship(relationship: Relationship) -> bool

# Lifecycle overrides (virtual — override in subclasses)
entity.on_ready() -> void
entity.on_destroy() -> void
entity.on_disable() -> void
entity.on_enable() -> void
entity.define_components() -> Array

# Signals
entity.component_added(entity, component)
entity.component_removed(entity, component)
entity.component_property_changed(entity, component, property_name, old_value, new_value)
entity.relationship_added(entity, relationship)
entity.relationship_removed(entity, relationship)
```

> **CRITICAL:** Entity extends `Node`, NOT `Node3D` or `Node2D`. To use spatial properties, the scene root node must be `Node3D`/`Node2D` and the Entity script is attached to it. `entity.global_position` is only accessible if the scene root is a spatial node — do NOT write it as if it always exists.

#### World (`world.gd` — class `World extends Node`)

```gdscript
# Exported properties
world.entity_nodes_root: NodePath
world.system_nodes_root: NodePath
world.default_serialize_config: GECSSerializeConfig

# Public properties
world.entities: Array[Entity]
world.systems_by_group: Dictionary
world.query: QueryBuilder              # always returns a fresh QueryBuilder

# Entity management
world.add_entity(entity: Entity, components = null, add_to_tree = true) -> void
world.add_entities(_entities: Array, components = null) -> void
world.remove_entity(entity: Entity) -> void
world.purge(should_free = true, keep := []) -> void

# System management
world.add_system(system: System, topo_sort: bool = false) -> void
world.add_systems(_systems: Array, topo_sort: bool = false) -> void
world.remove_system(system, topo_sort: bool = false) -> void

# Processing
world.process(delta: float, group: String = "") -> void
world.flush_command_buffers() -> void   # for MANUAL flush mode
```

#### System (`system.gd` — class `System extends Node`)

```gdscript
# Exported properties
system.group: String
system.process_empty: bool
system.active: bool
system.parallel_processing: bool
system.parallel_threshold: int          # default 50
system.command_buffer_flush_mode: String  # "PER_SYSTEM" | "PER_GROUP" | "MANUAL"

# Public properties
system.paused: bool
system.q: QueryBuilder                  # shortcut for ECS.world.query
system.cmd: CommandBuffer               # auto-initialized on first access

# Virtual methods to override
system.query() -> QueryBuilder
system.process(entities: Array[Entity], components: Array, delta: float) -> void
system.sub_systems() -> Array[Array]
system.setup() -> void
system.deps() -> Dictionary[int, Array]

# Enum
System.Runs.Before
System.Runs.After
```

#### QueryBuilder (`query_builder.gd` — class `QueryBuilder extends RefCounted`)

```gdscript
# Filtering methods (all return self for chaining)
q.with_all(components: Array = []) -> QueryBuilder
q.with_any(components: Array = []) -> QueryBuilder
q.with_none(components: Array = []) -> QueryBuilder
q.with_relationship(relationships: Array = []) -> QueryBuilder
q.without_relationship(relationships: Array = []) -> QueryBuilder
q.with_reverse_relationship(relationships: Array = []) -> QueryBuilder  # confirmed real method
q.with_group(groups: Array[String] = []) -> QueryBuilder
q.without_group(groups: Array[String] = []) -> QueryBuilder
q.enabled() -> QueryBuilder
q.disabled() -> QueryBuilder
q.iterate(components: Array = []) -> QueryBuilder

# Execution
q.execute() -> Array[Entity]
q.matches(entity_list) -> Array
q.combine(another_query: QueryBuilder) -> QueryBuilder
q.clear() -> QueryBuilder

# NOTE: with_group takes Array[String], not a single String
# CORRECT:   q.with_group(["area_1"])
# INCORRECT: q.with_group("area_1")
```

#### CommandBuffer (`command_buffer.gd` — class `CommandBuffer extends RefCounted`)

```gdscript
cmd.add_component(entity: Entity, component: Resource) -> void
cmd.remove_component(entity: Entity, component_type: Variant) -> void
cmd.add_components(entity: Entity, components: Array) -> void
cmd.remove_components(entity: Entity, component_types: Array) -> void
cmd.add_entity(entity: Entity) -> void
cmd.remove_entity(entity: Entity) -> void
cmd.add_relationship(entity: Entity, relationship: Relationship) -> void
cmd.remove_relationship(entity: Entity, relationship: Relationship, limit: int = -1) -> void
cmd.add_custom(callable: Callable) -> void
cmd.execute() -> void
cmd.clear() -> void
cmd.is_empty() -> bool
```

#### Serialization Classes

```gdscript
# GECSSerializeConfig (serialize_config.gd)
class GECSSerializeConfig extends Resource:
    @export var include_all_components: bool = true
    @export var components: Array = []               # component types to include when include_all_components = false
    @export var include_relationships: bool = true
    @export var include_related_entities: bool = true  # auto-include entities referenced by relationships

# GecsData (gecs_data.gd)
class GecsData extends Resource:
    @export var version: String = "0.2"              # NOTE: "0.2" not "0.1" as shown in old doc
    @export var entities: Array[GecsEntityData] = []

# GecsEntityData (gecs_entity_data.gd)
class GecsEntityData extends Resource:
    @export var entity_name: String = ""
    @export var scene_path: String = ""
    @export var components: Array[Component] = []
    @export var relationships: Array[GecsRelationshipData] = []
    @export var auto_included: bool = false
    @export var id: String = ""
```

---

## Issues Found in Existing Docs

### GETTING_STARTED.md Issues

| Line | Issue | Correct Version |
|------|-------|----------------|
| Headers throughout | Emoji in every header and body (`📋`, `⚡`, `🎮`, etc.) | Strip all emojis |
| Line 5 | "By the end..." preamble | Remove preamble, lead with content |
| Line 54-58 | `entity.global_position` used in `e_player.gd` as if it always exists | Spatial access requires Node3D/Node2D as scene root — add clear conditional or remove |
| Line 188-196 | `add_components([...])` then separate `add_child` then `add_entity` — sequencing is fine but `add_entity` does `add_to_tree=true` by default, so manual `add_child` before `add_entity` may cause double-add | Recommend `ECS.world.add_entity(entity)` and let world manage tree placement, OR set `add_to_tree=false` explicitly |
| Line 209 | "Run your project! 🎉" | Remove emoji |
| Line 256 | Scene tree diagram mentions `SystemGroup` node type | `SystemGroup` is not a GECS class — should say `Node` (systems are just nodes under a parent Node) |
| Missing | No CommandBuffer mention | Add a brief mention with link |
| `on_ready()` usage | Shows syncing `entity.global_position` inside `on_ready()` but `entity` extends `Node` not `Node3D` — this only works if instantiated from a Node3D scene | Add clear context that this requires a Node3D-rooted scene |

### CORE_CONCEPTS.md Issues

| Line | Issue | Correct Version |
|------|-------|----------------|
| Line 87-88 | `transform_comp.transform = self.global_transform` — `transform_comp` is never declared, `c_trs` was the variable name | Use `c_trs.transform = self.global_transform` or provide a complete example |
| Line 140-145 | `sprite_comp.mesh_instance = mesh_instance` and `transform_comp.transform = self.global_transform` — `sprite_comp` and `transform_comp` undeclared | Fix variable names to match declarations |
| Line 415 | `ECS.world.query` in the fluent example references `r_attacking_player` and `r_fleeing` — these look like pre-built Relationship instances, not class names | Clarify or replace with a proper example |
| Missing | No mention of CommandBuffer in Systems section, yet the LifetimeSystem example uses `cmd.remove_entity(entity)` | Add brief explanation of `cmd` property before using it in examples |
| Line 380 | `Runs.After: [ECS.wildcard]` — `ECS.wildcard` is a null value, not a sentinel for "all systems" in deps | Needs verification; the `deps()` pattern using `ECS.wildcard` should be tested |
| Query section | `with_reverse_relationship` is listed as a valid QueryBuilder method — CONFIRMED REAL in source | Keep this — it is correct |
| `with_group` usage | `with_group("group_name")` shown as single string | Actual signature is `with_group(groups: Array[String])` — must use `with_group(["group_name"])` |

### SERIALIZATION.md Issues

| Location | Issue | Correct Version |
|----------|-------|----------------|
| Data Structure section | `version = "0.1"` shown in example | Source has `version: String = "0.2"` |
| API Reference | Missing `GECSSerializeConfig` fields | Add section covering all 4 fields |
| Limitations section | "No entity relationships (planned feature)" | This is WRONG — relationships ARE serialized. `include_relationships: bool = true` is a real config field and the serializer handles relationships in Pass 2 |
| `ECS.world.purge()` usage | Shown in load_game — correct call, but signature is `purge(should_free = true, keep := [])` | Fine as shown, but doc could mention the `keep` param |
| Binary format description | "~60% smaller" — this is an unverified claim | Flag as approximate or remove the claim |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting broken API calls | Manual grep | Read source directly, compare signatures | Source is authoritative |
| Format of .tres file examples | Manually composing | Use the real output format from io.gd | The actual format is well-defined |

---

## Common Pitfalls

### Pitfall 1: Spatial Properties on Entity
**What goes wrong:** Developer copies `entity.global_position` from GETTING_STARTED and gets a null method error because their entity extends `Node`, not `Node3D`.
**Why it happens:** Entity extends `Node`. Spatial properties only exist when the scene root is `Node3D` or `Node2D` and the entity script is attached to that root.
**How to avoid:** In GETTING_STARTED, make it explicit that `global_position` only works in Option A (scene-based with a Node3D root). Show the conditional guard: `if entity is Node3D:`.
**Warning signs:** "Invalid get index 'global_position' on base 'Node'" in console.

### Pitfall 2: `with_group` Argument Type
**What goes wrong:** `q.with_group("my_group")` passes a String. The real signature is `with_group(groups: Array[String])`. GDScript silently coerces in some versions but this is not guaranteed.
**Why it happens:** Existing CORE_CONCEPTS doc showed `with_group("group_name")` as a string.
**How to avoid:** Always use array syntax: `q.with_group(["my_group"])`.

### Pitfall 3: `add_entity` and Manual `add_child`
**What goes wrong:** Developer calls `add_child(entity)` then `ECS.world.add_entity(entity)`. Since `add_entity` defaults to `add_to_tree=true`, if the entity is already in the tree it ends up with two parents or a reparent error.
**Why it happens:** GETTING_STARTED showed both calls sequentially without explaining the interaction.
**How to avoid:** Either use `ECS.world.add_entity(entity)` alone (World handles tree placement), or pass `add_to_tree=false` if manually managing the scene tree.

### Pitfall 4: Invented Variables in Examples
**What goes wrong:** Developer copies `sprite_comp.mesh_instance = mesh_instance` from CORE_CONCEPTS and gets an "Identifier not declared" error.
**Why it happens:** The existing doc used variables (`sprite_comp`, `transform_comp`) without declaring them.
**How to avoid:** Every code example must be self-contained or explicitly reference a previous declaration.

### Pitfall 5: Relationships Are Serialized (False Limitation in Old Doc)
**What goes wrong:** Developer reads "No entity relationships (planned feature)" in SERIALIZATION.md and builds a custom relationship persistence system unnecessarily.
**Why it happens:** The old doc said this. It is false — relationships are serialized in Pass 2 of `GECSIO.serialize_entities`.
**How to avoid:** Remove this false limitation entirely. Document `include_relationships` and `include_related_entities` config fields.

### Pitfall 6: `GecsData.version` Value
**What goes wrong:** Developer checks `data.version == "0.1"` for compatibility logic and it always fails because current version is `"0.2"`.
**Why it happens:** Old doc showed `version = "0.1"` in the .tres example.
**How to avoid:** Use `"0.2"` in all examples.

---

## Code Examples

Verified patterns from source files.

### Minimal Complete ECS Loop (GETTING_STARTED terminal state)
```gdscript
# Source: entity.gd, system.gd, ecs.gd, world.gd
# main.gd
extends Node

@onready var world: World = $World

func _ready():
    ECS.world = world
    var entity = Entity.new()
    ECS.world.add_entity(entity, [C_Health.new(100), C_Velocity.new()])

func _process(delta):
    ECS.process(delta)
```

### Scene-Based Entity (spatial, requires Node3D scene root)
```gdscript
# e_player.gd — attach to a Node3D root in e_player.tscn
class_name Player
extends Entity

func define_components() -> Array:
    return [C_Health.new(100), C_Velocity.new()]

func on_ready():
    # Only works because this scene root is Node3D
    var c_vel = get_component(C_Velocity) as C_Velocity
    if c_vel:
        c_vel.direction = Vector3.RIGHT
```

### Code-Based Entity (pure data)
```gdscript
class_name GameTimer
extends Entity

func define_components() -> Array:
    return [C_Timer.new(30.0)]
```

### System with CommandBuffer (safe forward iteration)
```gdscript
# Source: system.gd, command_buffer.gd
class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var lt = entity.get_component(C_Lifetime) as C_Lifetime
        lt.remaining -= delta
        if lt.remaining <= 0.0:
            cmd.remove_entity(entity)
```

### Sub-Systems Pattern
```gdscript
# Source: system.gd sub_systems()
class_name DamageSystem
extends System

func sub_systems() -> Array[Array]:
    return [
        [q.with_all([C_Health, C_Damage]), apply_damage],
        [q.with_all([C_Health]).with_none([C_Dead]).iterate([C_Health]), regenerate],
    ]

func apply_damage(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        var h = entity.get_component(C_Health) as C_Health
        var d = entity.get_component(C_Damage) as C_Damage
        h.current -= d.amount
        entity.remove_component(C_Damage)

func regenerate(entities: Array[Entity], components: Array, delta: float) -> void:
    var healths = components[0]
    for i in entities.size():
        healths[i].current = minf(healths[i].current + healths[i].regen_rate * delta, healths[i].maximum)
```

### Serialization — Full Save/Load Cycle
```gdscript
# Source: ecs.gd, io.gd
func save_game(slot: int) -> void:
    var q = ECS.world.query.with_all([C_Persistent])
    var data = ECS.serialize(q)
    ECS.save(data, "user://saves/slot_%d.tres" % slot, true)  # binary = true -> saves as .res

func load_game(slot: int) -> void:
    ECS.world.purge()
    var entities = ECS.deserialize("user://saves/slot_%d.tres" % slot)
    for entity in entities:
        ECS.world.add_entity(entity)
```

### GECSSerializeConfig — Selective Serialization
```gdscript
# Source: serialize_config.gd
# Serialize only specific component types, include relationships
var config = GECSSerializeConfig.new()
config.include_all_components = false
config.components = [C_Health, C_Inventory]   # only these types
config.include_relationships = true
config.include_related_entities = false         # don't pull in relationship targets

var q = ECS.world.query.with_all([C_Player])
var data = ECS.serialize(q, config)
```

### World-level Serialize Config (default for all entities)
```gdscript
# Source: world.gd, entity.gd get_effective_serialize_config()
# Set in Inspector on the World node, or in code:
ECS.world.default_serialize_config = GECSSerializeConfig.new()
# Entity.serialize_config overrides the world default for that specific entity
```

### QueryBuilder — Correct with_group Syntax
```gdscript
# Source: query_builder.gd — with_group takes Array[String]
q.with_group(["area_1"])                     # correct
q.with_group(["area_1", "area_2"])           # match entities in either group
q.without_group(["disabled"])                # exclude entities in group
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Backwards iteration for safe entity removal | Forward iteration + `cmd.remove_entity()` | v6.8.0 CommandBuffer | Simplifies all systems that remove entities |
| Manual `entity.component_resources` for components | Both `component_resources` (Inspector) and `define_components()` (code) | v5.x | Two valid patterns — doc both |
| Single archetype per entity | Archetype storage system for O(1) queries | v6.x | Transparent to developers, no API change |

**Deprecated/outdated:**
- Backwards iteration pattern (`for i in range(entities.size() - 1, -1, -1)`): still works but CommandBuffer is preferred
- `ECS.world.process()` called directly: valid but `ECS.process()` is the preferred shorthand

---

## Open Questions

1. **`ECS.wildcard` in `deps()` pattern**
   - What we know: `ECS.wildcard = null`. The CORE_CONCEPTS example shows `Runs.After: [ECS.wildcard]` to mean "run after all systems".
   - What's unclear: Whether `null` in the deps array is special-cased in the topological sort to mean "wildcard" or if this is a documentation error.
   - Recommendation: Read `world.gd` topological sort implementation to verify before documenting this pattern. If uncertain, omit this specific pattern from CORE_CONCEPTS in this phase.

2. **`SystemGroup` node type**
   - What we know: GETTING_STARTED's scene diagram shows `SystemGroup` as a node type. No such class exists in `addons/gecs/ecs/`.
   - What's unclear: Whether it's a user-defined Node or a misidentification.
   - Recommendation: Replace all `SystemGroup` references with `Node` in the scene structure diagram.

3. **`entity.global_position` in `on_ready()`**
   - What we know: Entity extends Node. `global_position` only exists on Node3D/Node2D. The current GETTING_STARTED example calls it unconditionally.
   - What's unclear: Whether the intended pattern is (a) always use a spatial scene root, or (b) check before accessing.
   - Recommendation: In GETTING_STARTED, show the spatial case explicitly with a clear comment that the scene root is Node3D. For the code-based entity path, do not mention `global_position` at all.

---

## Validation Architecture

`nyquist_validation` key is absent from `.planning/config.json` — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | gdUnit4 (project-installed) |
| Config file | `addons/gdUnit4/runtest.cmd` / `runtest.sh` |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"` |
| Full suite command | Same with `-c` (continue on failures) |

### Phase Requirements → Test Map

This is a documentation-only phase. No GDScript code is written. Tests are not applicable in the traditional sense.

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| CORE-01 | Every code block in GETTING_STARTED compiles | manual-only | N/A | Copy-paste each block into a Godot project and verify |
| CORE-02 | Every method name in CORE_CONCEPTS exists in source | manual-only | N/A | Cross-reference against source files (done in this research) |
| CORE-06 | Serialization doc matches actual serialize/save/deserialize behavior | manual-only | N/A | Verified against io.gd, serialize_config.gd, gecs_data.gd |

**Justification for manual-only:** This phase rewrites Markdown files. The verification is textual cross-referencing of method signatures against `.gd` source — done during authoring, not via automated test. The existing test suite (`addons/gecs/tests/`) runs ECS logic tests that indirectly validate the API is what docs say it is.

### Sampling Rate
- **Per task commit:** Run `GODOT_BIN=... addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core"` to confirm no `.gd` source was accidentally modified.
- **Per wave merge:** Full test suite to confirm the codebase is unchanged.
- **Phase gate:** All three docs reviewed against API table in this research document. Full suite green (confirming no source changes).

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements (no new code to test).

---

## Sources

### Primary (HIGH confidence)
- `addons/gecs/ecs/ecs.gd` — ECS singleton: process, serialize, save, deserialize, get_components, wildcard, world property
- `addons/gecs/ecs/entity.gd` — Entity: all component/relationship/lifecycle methods, serialize_config @export
- `addons/gecs/ecs/world.gd` — World: add_entity, add_entities, remove_entity, purge, add_system, flush_command_buffers, default_serialize_config
- `addons/gecs/ecs/system.gd` — System: all exports, q, cmd, process, query, sub_systems, setup, deps, Runs enum
- `addons/gecs/ecs/query_builder.gd` — QueryBuilder: with_all, with_any, with_none, with_relationship, without_relationship, with_reverse_relationship, with_group, without_group, iterate, execute
- `addons/gecs/ecs/command_buffer.gd` — CommandBuffer: all add/remove methods, execute, clear, is_empty
- `addons/gecs/io/io.gd` — GECSIO: serialize, save, deserialize, serialize_entities, deserialize_gecs_data
- `addons/gecs/io/serialize_config.gd` — GECSSerializeConfig: all 4 @export fields
- `addons/gecs/io/gecs_data.gd` — GecsData: version="0.2", entities array
- `addons/gecs/io/gecs_entity_data.gd` — GecsEntityData: all 6 @export fields

### Secondary (MEDIUM confidence)
- `addons/gecs/docs/GETTING_STARTED.md` — reviewed for structural intent, errors catalogued above
- `addons/gecs/docs/CORE_CONCEPTS.md` — reviewed for structural intent, errors catalogued above
- `addons/gecs/docs/SERIALIZATION.md` — reviewed for structural intent, errors catalogued above
- `CLAUDE.md` — project overview and patterns

---

## Metadata

**Confidence breakdown:**
- API signatures: HIGH — read directly from source `.gd` files
- Issue cataloguing: HIGH — compared existing docs line-by-line against source
- Architecture patterns: HIGH — derived from source, not training data
- Open questions: MEDIUM — require additional source verification before resolving

**Research date:** 2026-03-13
**Valid until:** 2026-06-13 (stable APIs; any GECS source change invalidates)

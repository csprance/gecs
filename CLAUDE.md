# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GECS is a lightweight, performant Entity Component System (ECS) framework for Godot 4.x that integrates seamlessly with Godot's node system. The framework provides a query-based entity filtering system with optimized component indexing.

## Core Architecture

### ECS Components

The framework is built around six main classes:

- **Entity** (`addons/gecs/entity.gd`): Container nodes that hold components and relationships. Entities extend Godot's Node class and can be placed in the scene tree.
- **Component** (`addons/gecs/component.gd`): Data-only resources that extend Godot's Resource class. Components hold properties but no logic.
- **System** (`addons/gecs/system.gd`): Processing nodes that operate on entities with specific components. Systems contain the game logic.
- **World** (`addons/gecs/world.gd`): Manager for all entities and systems, handles querying and processing.
- **CommandBuffer** (`addons/gecs/ecs/command_buffer.gd`): Callable-based deferred execution buffer for safe structural changes during iteration.
- **ECS Singleton** (`addons/gecs/ecs.gd`): Global access point for the current World instance. Also handles deferred system setup timing.

### Query System

The QueryBuilder (`addons/gecs/query_builder.gd`) provides powerful entity filtering:

- `with_all([Components])` - Entities must have all specified components
- `with_any([Components])` - Entities must have at least one component
- `with_none([Components])` - Entities must not have these components
- `with_relationship([Relations])` - Entities must have these relationships
- `with_group("group_name")` - Filter by Godot groups

### Sub-Systems

Group related logic into one system. Each subsystem is a `[QueryBuilder, Callable]` tuple, with an optional third element for a `SystemTimer`:

```gdscript
func sub_systems() -> Array[Array]:
    return [
        [q.with_all([C_Velocity]).enabled(), process_onscreen],
        [q.with_all([C_Velocity]).disabled(), process_offscreen, _offscreen_timer],
    ]
```

When a subsystem has a timer, the framework advances it each frame and skips the subsystem if it hasn't ticked.

### System Processing

Systems are organized by groups and processed via:

```gdscript
# Process specific system group
ECS.process(delta, "physics")

# Process all systems
ECS.process(delta)
```

### CommandBuffer System

**NEW in v6.8.0** - The CommandBuffer system allows safe structural changes (add/remove components, entities, relationships) during iteration without backwards iteration or defensive snapshots.

#### Problem It Solves

Before CommandBuffer, systems needed awkward workarounds:
- **Backwards iteration**: `for i in range(entities.size() - 1, -1, -1)`
- **Defensive snapshots**: `var snapshot = entities.duplicate()` (O(N) memory overhead)

#### Basic Usage

```gdscript
class_name MySystem
extends System

func query():
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], components: Array, delta: float):
    # Use forward iteration with CommandBuffer
    for entity in entities:
        if should_delete(entity):
            cmd.remove_entity(entity)  # Queued for later
        if should_transform(entity):
            cmd.remove_component(entity, C_OldState)
            cmd.add_component(entity, C_NewState.new())
    # Auto-executes after system completes (based on flush mode)
```

#### Command Buffer API

```gdscript
# Queue component operations
cmd.add_component(entity, component)
cmd.remove_component(entity, component_type)
cmd.add_components(entity, [comp1, comp2])
cmd.remove_components(entity, [type1, type2])

# Queue entity operations
cmd.add_entity(entity)
cmd.remove_entity(entity)

# Queue relationship operations
cmd.add_relationship(entity, relationship)
cmd.remove_relationship(entity, relationship, limit)

# Custom operations
cmd.add_custom(callable)  # For complex multi-step operations

# Manual control (normally automatic)
cmd.execute()  # Execute queued commands
cmd.clear()    # Discard queued commands
```

#### Flush Modes

Systems configure when commands execute via the `FlushMode` enum:

**PER_SYSTEM (default)** - Executes immediately after each system completes:
```gdscript
@export var command_buffer_flush_mode: FlushMode = FlushMode.PER_SYSTEM
```
- Commands execute immediately after system completes
- Later systems in the same frame see the changes
- Safest default, maintains same-frame visibility

**PER_GROUP** - Executes at the end of the process group:
```gdscript
func setup():
    command_buffer_flush_mode = FlushMode.PER_GROUP
```
- Commands execute after ALL systems in the group complete
- Later groups or next frame will see the changes
- Good for spawning/cleanup within a single process() call
- Auto-executed, no manual flush needed

**MANUAL** - Requires manual flush call:
```gdscript
func setup():
    command_buffer_flush_mode = FlushMode.MANUAL
```
- Commands are queued but NOT auto-executed
- **Must manually call** `ECS.world.flush_command_buffers()`
- Maximum batching (single cache invalidation for all queued commands)
- Best for cross-group batching or precise control

**Example with MANUAL mode:**
```gdscript
func _process(delta):
    ECS.process(delta, "physics")   # Systems may queue commands
    ECS.process(delta, "render")    # More systems may queue commands
    ECS.world.flush_command_buffers()  # Execute all MANUAL commands at once
```

#### Performance Benefits

- **Single cache invalidation** per `execute()` call instead of one per operation
- **Deferred execution** allows safe forward iteration without snapshots
- **No memory overhead** from defensive snapshots
- **Correct ordering** — commands execute in exact queued order, preserving user intent
- **Freed entity safety** — each lambda bakes in an `is_instance_valid` guard

#### Migration Example

**Before (backwards iteration):**
```gdscript
func process(entities: Array[Entity], components: Array, delta: float):
    for i in range(entities.size() - 1, -1, -1):
        if should_delete(entities[i]):
            ECS.world.remove_entity(entities[i])
```

**After (CommandBuffer):**
```gdscript
func process(entities: Array[Entity], components: Array, delta: float):
    for entity in entities:
        if should_delete(entity):
            cmd.remove_entity(entity)
```

### SystemTimer (Tick Rate Control)

Systems run every frame by default. The `SystemTimer` class allows systems to run at a fixed interval, fire once after a delay, or share a tick source for synchronized execution.

#### Basic Usage

```gdscript
class_name AIDecisionSystem
extends System

func setup():
    set_tick_rate(0.5)  # Run every 500ms instead of every frame

func process(entities: Array[Entity], components: Array, delta: float):
    # This only runs when the timer ticks
    for entity in entities:
        recalculate_ai(entity)
```

#### Shared Timers

Multiple systems can share the same `SystemTimer` instance. They are guaranteed to execute on the exact same frame:

```gdscript
var timer = SystemTimer.new()
timer.interval = 0.2

physics_step.tick_source = timer
collision_resolve.tick_source = timer
# Both systems tick together every 200ms
```

Or share via `set_tick_rate()`:

```gdscript
# In system A's setup:
var timer = set_tick_rate(0.5)
# Pass to system B:
system_b.tick_source = timer
```

#### One-Shot Timers

```gdscript
func setup():
    set_tick_rate(3.0, true)  # Fire once after 3 seconds, then stop
```

#### SystemTimer API

```gdscript
var timer = SystemTimer.new()
timer.interval = 1.0           # Seconds between ticks
timer.single_shot = false      # true = fire once and deactivate
timer.active = true            # Can be paused independently
timer.ticked                   # Read-only: true on the frame the timer fired
timer.tick_count               # Total ticks since creation/reset
timer.time_elapsed             # Accumulated time since last tick

timer.reset()                  # Reset to initial state (active, zero elapsed)
```

#### Key Behaviors

- **No timer = every frame**: Systems without `tick_source` are unchanged
- **Timers advance in World.process()**: Before any system in the group runs, all unique timers for that group are advanced once
- **Overshoot is carried forward**: `time_elapsed = time_elapsed - interval` prevents drift over time
- **Paused systems don't block shared timers**: The timer keeps ticking; the paused system simply skips execution

### Observers (Reactive Queries)

GECS `Observer` is the **reactive** counterpart to `System`: instead of running every frame against a set of matching entities, an observer fires callbacks in response to **events** (component added/removed/changed, relationship added/removed, query-membership transitions, and custom user events).

An observer is modeled as a **query that declares which events it reacts to**. The `QueryBuilder` grows fluent `on_*` methods that chain on top of the normal filter methods (`with_all`, `with_any`, etc.).

#### Minimal example

```gdscript
class_name HealthObserver
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Health, C_Player]).on_added().on_removed()

func each(event: Variant, entity: Entity, payload: Variant) -> void:
    match event:
        Observer.Event.ADDED:   print("Health granted: ", payload)
        Observer.Event.REMOVED: print("Health lost from: ", entity.name)
```

#### Fluent event modifiers

```gdscript
q.with_all([C_Health])
    .on_added()                              # fires when C_Health added to matching entity
    .on_removed()                            # fires when C_Health removed
    .on_changed([&"amount"])                 # optional property filter
    .on_match()                              # monitor: entity enters query match set
    .on_unmatch()                            # monitor: entity leaves query match set
    .on_relationship_added([C_ChildOf])      # optional relation-type filter
    .on_relationship_removed()
    .on_event(&"damage_dealt")               # custom event subscription
```

Queries with zero `on_*` modifiers behave exactly like System queries — nothing changes for existing System code.

#### Observer.Event values & payload shape

| Event | Payload |
|---|---|
| `Observer.Event.ADDED` | the component [Resource] instance just added |
| `Observer.Event.REMOVED` | the component [Resource] instance just removed (entity still valid) |
| `Observer.Event.CHANGED` | `{component, property, new_value, old_value}` Dictionary |
| `Observer.Event.MATCH` | `null` |
| `Observer.Event.UNMATCH` | `null` |
| `Observer.Event.RELATIONSHIP_ADDED` | the [Relationship] instance |
| `Observer.Event.RELATIONSHIP_REMOVED` | the [Relationship] instance |
| `StringName` custom | whatever `emit_event()` passed |

#### Query monitors (`on_match` / `on_unmatch`)

A query with `.on_match()` or `.on_unmatch()` enters **monitor mode**: the framework tracks which entities currently satisfy the full query and fires `on_match` exactly once when an entity transitions in, and `on_unmatch` exactly once when it transitions out. Intermediate component churn that doesn't change membership fires nothing.

```gdscript
class_name CombatTargetMonitor
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Player, C_Alive, C_InCombat]).on_match().on_unmatch()

func each(event: Variant, entity: Entity, _payload: Variant) -> void:
    match event:
        Observer.Event.MATCH:   add_to_target_list(entity)
        Observer.Event.UNMATCH: remove_from_target_list(entity)
```

Monitors also fire `on_unmatch` when an entity is removed from the world.

#### Custom events

Anywhere — in a System, game code, or another observer — emit a custom event via `ECS.world.emit_event(name, entity, data)`. Any observer whose query declared `.on_event(name)` receives the event through `each` (the event argument is the `StringName`).

```gdscript
# Emitter
ECS.world.emit_event(&"damage_dealt", target, {"amount": 10, "source": attacker})

# Observer
func query() -> QueryBuilder:
    return q.with_all([C_Alive]).on_event(&"damage_dealt")

func each(event: Variant, entity: Entity, data: Variant) -> void:
    entity.get_component(C_Health).hp -= data.amount
```

#### sub_observers — same shape as sub_systems

Compose multiple reactive axes in one node. Each tuple is `[QueryBuilder (with events), Callable]`, mirroring `sub_systems` exactly. The callable signature is `(event, entity, payload)` — identical to `each`.

```gdscript
func sub_observers() -> Array[Array]:
    return [
        # Component-event sub-observer
        [q.with_all([C_Health]).on_added().on_removed(), _on_health_life],
        # Monitor sub-observer
        [q.with_all([C_Player, C_Alive]).on_match().on_unmatch(), _on_alive_state],
        # Relationship sub-observer
        [q.with_all([C_Unit]).on_relationship_added([C_ChildOf]), _on_parented],
        # Custom-event sub-observer
        [q.with_all([C_Player]).on_event(&"damage_dealt"), _on_damage],
    ]

func _on_health_life(event, entity, payload): ...
func _on_alive_state(event, entity, _payload): ...
```

**Important:** `q` is a fresh builder on every access (matches `System.q`), so `q.with_all(...)` in one tuple does not leak state into another.

#### yield_existing

```gdscript
@export var yield_existing: bool = true
```

Set `yield_existing = true` (property on the `Observer` node) and at `setup()` the framework retroactively fires:
- `on_added` for every component instance on entities that currently satisfy the entry's query (for entries declaring `.on_added()`).
- `on_match` for every currently-matching entity (for monitor entries).

Off by default — cost scales with world size.

**Scene-tree ordering note:** `World.initialize()` registers observers *before* entities, so `yield_existing` on a scene-tree Observer sees an empty entity list and retro-fires nothing. That's fine — every entity added after the observer registers is delivered through normal dispatch (`component_added` → ADDED event), so scene-tree entities still trigger the observer. `yield_existing` is primarily useful for observers added at runtime *after* entities already exist.

**Per-sub-observer override:** each `sub_observers()` tuple accepts an optional 4th element `[QueryBuilder, Callable, SystemTimer|null, yield_existing_override]`. `true` forces retroactive fire for this tuple regardless of the parent's flag; `false` suppresses it. `null`/omitted inherits the parent's `yield_existing`.

**Group filters don't transition monitors:** `with_group("name").on_match().on_unmatch()` will fire MATCH/UNMATCH when structural component changes bring the entity in/out of the query, but Godot group membership changes are not hooked by the ECS — adding/removing a node from a group won't re-evaluate the monitor. Pair group filters with a component marker (e.g. `C_Target`) if you need transition events.

**REMOVED / RELATIONSHIP_REMOVED fire only for matched entities:** the framework evaluates the full query against the entity *virtually treating the removed piece as still present*, so an observer with `with_all([C_A, C_B]).on_removed()` fires REMOVED only for entities that satisfied the filter before the removal — not for entities that had `C_A` but never had `C_B`.

**Property-query monitors transition on property changes:** a monitor like `q.with_all([{C_Health: {"hp": {"_gt": 0}}}]).on_match().on_unmatch()` fires UNMATCH when `hp` crosses the threshold via a property setter that emits `property_changed` — no structural mutation required.

**Custom events accept null entity for broadcast:** `world.emit_event(&"game_paused")` (no entity) delivers the event to every subscriber of that name regardless of their entity filter. Subscribers with filtered queries should gate on `entity == null` inside `each()` if they handle both scoped and broadcast events.

#### Observer parity with System

Observers share the System lifecycle and infrastructure:

- `setup()` — one-shot init after registration.
- `active: bool`, `paused: bool` — skip dispatch when off.
- `cmd: CommandBuffer` — lazy, queue structural changes from callbacks.
- `command_buffer_flush_mode: FlushMode` — `PER_CALLBACK` (default) or `MANUAL`.
- `lastRunData: Dictionary` — debugger integration.

#### Why use `cmd` in an Observer (different reasons than a System)

Systems use `cmd` primarily to avoid **iteration hazards** — deferring add/remove until after the entity loop completes so the iteration doesn't skip entries or invalidate the archetype cache mid-walk. Observers aren't iterating anything; they're a callback for a single event on a single entity. So the motivations are different:

1. **Break event cascades.** A mutation inside an Observer callback (e.g. `entity.add_component(C_X)`) synchronously fires any observer watching `C_X.on_added` — which might mutate more, which fires more observers, etc. Queueing through `cmd` defers those triggers until after the current callback returns, so chained logic is flat rather than recursive.
2. **Avoid stale-cache observations.** The Observer is running *inside* a mutation path that may have suppressed cache invalidation (e.g. during `add_entity` / batch operations). Performing more direct mutations at that point risks observing stale query state. Deferring through `cmd` means the current mutation finishes and the cache stabilizes before your changes apply.
3. **Batch across multiple events.** With `FlushMode.MANUAL`, an observer can accumulate structural changes from many events (e.g. queue a spawn per `&"damage_dealt"` received) and apply them all at once when `ECS.world.flush_command_buffers()` is called — typically at a known safe point between process groups.
4. **Safe monitor reactions.** When an `on_match` or `on_unmatch` handler reacts by mutating components that *would cause another monitor transition*, `cmd` lets the current transition settle before the next one is evaluated.

What Observers do **not** need `cmd` for: forward-vs-backward iteration safety, `safe_iteration = false` escapes, or "don't skip entities in this loop" — none of those apply because observers don't loop.

**Rule of thumb:** in a System, reach for `cmd` whenever you're mutating structure. In an Observer, reach for `cmd` when your callback triggers further mutations — otherwise a direct mutation is fine.

#### Property-change observers

`Observer.Event.CHANGED` only fires when a component explicitly emits `Component.property_changed`. Direct property assignment does **not** trigger observers; this is intentional for performance. Components that want change events must implement a setter that emits `property_changed`:

```gdscript
@export var health: int = 100 : set = set_health
func set_health(new_value: int) -> void:
    var old_value = health
    health = new_value
    property_changed.emit(self, "health", old_value, new_value)
```

#### Legacy API (deprecated shim)

The pre-existing Observer API — `watch() -> Resource`, `match() -> QueryBuilder`, `on_component_added/removed/changed` — continues to work unchanged via an internal shim. Existing observers do **not** need migration. For new code, prefer `query()` + `each()` or `sub_observers()`.

## Development Commands

### Running Tests with GdUnit4

The project uses gdUnit4 for testing. Tests are located in `addons/gecs/tests/`.
No test should be created anywhere else other than `addons/gecs/tests/`

#### Prerequisites

**Windows:**

```cmd
# Set environment variable (one-time setup)
setx GODOT_BIN "D:\path\to\Godot.exe"

# Enable colored console output (one-time setup)
REG ADD HKCU\CONSOLE /f /v VirtualTerminalLevel /t REG_DWORD /d 1
```

**Mac/Linux:**

```bash
# Set environment variable (add to ~/.bashrc or ~/.zshrc)
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

# Make script executable
chmod +x ./addons/gdUnit4/runtest.sh
```

#### Basic Test Commands

**IMPORTANT:** Always use `res://` prefix for file paths!

```bash
# Windows
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core/test_world.gd"
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c

# Linux/Mac
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests"
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/core/test_world.gd"
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests" -c
```

#### Running Specific Tests

```bash
# Run specific test file (use res:// prefix!)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/core/test_entity.gd"

# Run specific test method with :: syntax (NO SPACES)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/core/test_entity.gd::test_add_and_get_component"

# Run multiple test directories
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/core" -a "res://addons/gecs/tests/performance"

# Ignore specific tests (opposite selection)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance" -i "TestEntityPerf:test_entity_creation"

# Continue on failures (don't fail fast)
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests" -c

# Use specific test configuration
addons/gdUnit4/runtest.sh -conf GdUnitRunner.cfg
```

#### Command Line Options

- `-a, --add`: Add test suite/directory to execution (REQUIRED)
- `-i, --ignore`: Ignore specific test suite or test case
- `-c, --continue`: Continue on test failures (don't fail fast)
- `-conf, --config`: Run tests from specific config file
- `--help`: Show all available commands
- `--help-advanced`: Show advanced options

#### Parameterized Tests

GdUnit4 supports parameterized tests to run the same test with different inputs:

```gdscript
# Example: test with multiple scales
func test_entity_creation(scale: int, test_parameters := [[100], [1000], [10000]]):
    var entities = []

    for i in scale:
        entities.append(Entity.new())

    # Test will run 3 times with scale = 100, 1000, 10000
```

#### Common Gotchas

1. **Always use `res://` prefix** for file paths
2. **No spaces around `::`** when running specific test methods
3. **Path format matters**: Windows uses backslashes in regular paths but forward slashes with `res://`
4. **Test names are case-sensitive**
5. **Make sure GODOT_BIN is set** before running tests

### Performance Testing

Simple performance tests that record timing data to JSONL files for easy graphing:

```bash
# Run all performance tests
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance"

# Run specific performance category
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_entity_perf.gd"
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_component_perf.gd"
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_query_perf.gd"
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_system_perf.gd"

# Run specific test with specific scale
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_entity_perf.gd::test_entity_creation"
```

**Performance Results:**

- Each test writes to `reports/perf/{test_name}.jsonl`
- One JSON per line format for easy parsing
- Track performance over time by test name and scale
- Example: `reports/perf/entity_creation.jsonl`

```jsonl
{"timestamp":"2025-01-13T10:23:45","test":"entity_creation","scale":100,"time_ms":12.5,"godot_version":"4.5"}
{"timestamp":"2025-01-13T11:30:12","test":"entity_creation","scale":100,"time_ms":11.8,"godot_version":"4.5"}
```

**Using Parameterized Tests:**
Performance tests use GdUnit4's parameterized test feature to automatically run tests at different scales (100, 1000, 10000 entities). Each scale generates a separate result entry.

### Creating Releases

GECS uses an automated release workflow that creates clean distribution branches for different use cases.

**To create a new release:**

1. **Tag the release** (use semantic versioning):

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **The GitHub workflow automatically creates two branches:**
   - `release-v1.0.0` - For submodule users (addon contents at root level)
   - `godot-asset-library-v1.0.0` - For Godot Asset Library submissions (proper `addons/gecs/` structure)

**Both branches contain:**

- Clean addon code (no test directories)
- README.md and LICENSE files
- Production-ready GECS framework

**For users:**

```bash
# Submodule installation
git submodule add -b release-v1.0.0 https://github.com/your-repo/gecs.git gecs

# Asset Library - submit the godot-asset-library-v1.0.0 branch
```

**Version numbering:** Use semantic versioning (v1.0.0, v1.1.0, v2.0.0, etc.)

### Development Structure

**Component Creation:**

```gdscript
class_name C_MyComponent
extends Component

@export var my_property: float = 0.0
```

**Entity Creation:**

```gdscript
class_name MyEntity
extends Entity

func define_components() -> Array:
    return [C_Transform.new(), C_Velocity.new()]
```

**System Creation:**

```gdscript
class_name MySystem
extends System

func query():
    return q.with_all([C_Transform, C_Velocity])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var transform = entity.get_component(C_Transform)
        var velocity = entity.get_component(C_Velocity)
        transform.position += velocity.direction * velocity.speed * delta
```

## Script Templates

The project provides script templates in `script_templates/Node/` for:

- `component.gd` - Component template
- `entity.gd` - Entity template
- `system.gd` - System template
- `observer.gd` - Observer (reactive system) template

## Key Files to Understand

- `addons/gecs/ecs/ecs.gd` - ECS singleton, global World access, deferred system setup coordination
- `addons/gecs/ecs/world.gd` - Core world management, entity indexing, query caching, system group processing
- `addons/gecs/ecs/system.gd` - Base system class with CommandBuffer integration and flush modes
- `addons/gecs/ecs/system_timer.gd` - Tick rate control for systems (interval, one-shot, shared timers)
- `addons/gecs/ecs/command_buffer.gd` - Callable-based deferred command execution
- `addons/gecs/query_builder.gd` - Query system implementation
- `addons/gecs/relationship.gd` - Entity relationship system
- `addons/gecs/observer.gd` - Reactive systems for component changes
- `addons/gecs/array_extensions.gd` - Optimized set operations for queries

## Relationships System

GECS supports entity relationships for hierarchical queries with two matching modes:

### Type Matching (Default)

```gdscript
# Add relationship
entity.add_relationship(Relationship.new(C_ChildOf.new(), parent_entity))

# Query by type (matches any component of this type)
q.with_relationship([Relationship.new(C_ChildOf.new(), parent_entity)])

# Check relationships by type
entity.has_relationship(Relationship.new(C_Damage.new(), target))
```

### Component Query Matching

```gdscript
# Query relationships by property criteria
var high_damage = q.with_relationship([
    Relationship.new({C_Damage: {'amount': {"_gte": 50}}}, target)
]).execute()

# Query both relation AND target properties
var strong_buffs = q.with_relationship([
    Relationship.new(
        {C_Buff: {'duration': {"_gt": 10}}},
        {C_Player: {'level': {"_gte": 5}}}
    )
]).execute()
```

### Limited Removal (NEW in v5.1+)

```gdscript
# Remove specific number of relationships
entity.remove_relationship(Relationship.new(C_Damage.new(), null), 1)  # Remove 1 damage
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 3)    # Remove up to 3 buffs
entity.remove_relationship(Relationship.new(C_Effect.new(), null))     # Remove all effects (default)

# Remove with component queries
entity.remove_relationship(
    Relationship.new({C_Damage: {'amount': {"_gt": 20}}}, null),
    2  # Remove up to 2 high-damage effects
)
```

## Common Patterns

- Components are data-only containers with @export properties
- Systems contain all game logic and process entities by component queries
- Entities are automatically indexed by components for efficient querying
- Use `ECS.world.query` to build and execute entity queries
- Systems can be grouped and processed at different intervals (physics vs render)

## Project Configuration

This is a Godot 4.x project with the following key settings:

- **ECS Singleton**: Auto-loaded at `res://addons/gecs/ecs.gd`
- **Debug Logging**: `gecs.log_level=4` in project settings
- **Enabled Plugins**: GECS (`res://addons/gecs/plugin.cfg`) and gdUnit4 (`res://addons/gdUnit4/plugin.cfg`)


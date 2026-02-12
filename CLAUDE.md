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

Systems can configure when commands execute:

**PER_SYSTEM (default)** - Executes immediately after each system completes:
```gdscript
@export_enum("PER_SYSTEM", "PER_GROUP", "MANUAL") var command_buffer_flush_mode: String = "PER_SYSTEM"
```
- Commands execute immediately after system completes
- Later systems in the same frame see the changes
- Safest default, maintains same-frame visibility

**PER_GROUP** - Executes at the end of the process group:
```gdscript
func _init():
    command_buffer_flush_mode = "PER_GROUP"
```
- Commands execute after ALL systems in the group complete
- Later groups or next frame will see the changes
- Good for spawning/cleanup within a single process() call
- Auto-executed, no manual flush needed

**MANUAL** - Requires manual flush call:
```gdscript
func _init():
    command_buffer_flush_mode = "MANUAL"
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


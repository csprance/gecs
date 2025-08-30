# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GECS is a lightweight, performant Entity Component System (ECS) framework for Godot 4.x that integrates seamlessly with Godot's node system. The framework provides a query-based entity filtering system with optimized component indexing.

## Core Architecture

### ECS Components

The framework is built around five main classes:

- **Entity** (`addons/gecs/entity.gd`): Container nodes that hold components and relationships. Entities extend Godot's Node class and can be placed in the scene tree.
- **Component** (`addons/gecs/component.gd`): Data-only resources that extend Godot's Resource class. Components hold properties but no logic.
- **System** (`addons/gecs/system.gd`): Processing nodes that operate on entities with specific components. Systems contain the game logic.
- **World** (`addons/gecs/world.gd`): Manager for all entities and systems, handles querying and processing.
- **ECS Singleton** (`addons/gecs/ecs.gd`): Global access point for the current World instance.

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

## Development Commands

### Running Tests

The project uses gdUnit4 for testing. Tests are located in `addons/gecs/tests/`.

**Prerequisites:**
Set the GODOT_BIN environment variable to your Godot executable path.

**Test Commands:**

```bash
# Windows
addons/gdUnit4/runtest.cmd -a "addons\\gecs\\tests"
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/test_world.gd
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/ -c

# Linux/Mac
addons/gdUnit4/runtest.sh -a "addons\\gecs\\tests"
addons/gdUnit4/runtest.sh -a res://addons/gecs/tests/test_world.gd
addons/gdUnit4/runtest.sh -a res://addons/gecs/tests/ -c
```

### Performance Testing

Comprehensive performance test suite available for tracking optimization effectiveness:

```bash
# Windows
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_master.gd
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_master.gd::test_performance_smoke_test
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_[entities|components|queries|systems|arrays|integration].gd

# Linux/Mac
addons/gdUnit4/runtest.sh -a res://addons/gecs/tests/performance/performance_test_master.gd
addons/gdUnit4/runtest.sh -a res://addons/gecs/tests/performance/performance_test_master.gd::test_performance_smoke_test
addons/gdUnit4/runtest.sh -a res://addons/gecs/tests/performance/performance_test_[entities|components|queries|systems|arrays|integration].gd
```

Performance tests cover all critical ECS operations and provide regression detection. See `addons/gecs/docs/PERFORMANCE_TESTING.md` for detailed documentation.

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

func process(entity: Entity, delta: float):
    # Process each matching entity
```

## Script Templates

The project provides script templates in `script_templates/Node/` for:

- `component.gd` - Component template
- `entity.gd` - Entity template
- `system.gd` - System template
- `observer.gd` - Observer (reactive system) template

## Key Files to Understand

- `addons/gecs/world.gd` - Core world management and entity indexing
- `addons/gecs/query_builder.gd` - Query system implementation
- `addons/gecs/relationship.gd` - Entity relationship system
- `addons/gecs/observer.gd` - Reactive systems for component changes

## Relationships System

GECS supports entity relationships for hierarchical queries:

```gdscript
# Add relationship
entity.add_relationship(Relationship.new(R_ChildOf, parent_entity))

# Query relationships
q.with_relationship([R_ChildOf])
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

## Core Files to Understand

The GECS framework architecture is built around these key files:

- `addons/gecs/world.gd` - Core world management with component indexing and query caching
- `addons/gecs/query_builder.gd` - Optimized entity filtering with performance optimizations
- `addons/gecs/relationship.gd` - Entity relationship system for hierarchical queries
- `addons/gecs/observer.gd` - Reactive systems for component changes
- `addons/gecs/array_extensions.gd` - Optimized set operations for queries

# Coding Conventions

**Analysis Date:** 2026-03-17

## Naming Patterns

**Files:**
- GDScript files use `snake_case.gd`
- Components: `c_<name>.gd` (e.g., `c_velocity.gd`, `c_transform.gd`)
- Systems: `s_<name>.gd` (e.g., `s_movement.gd`, `s_network_sync.gd`)
- Entities: `e_<name>.gd` (e.g., `e_player.gd`)
- Tests: `test_<name>.gd` (e.g., `test_world.gd`, `test_entity.gd`)
- Handlers: `<name>_handler.gd` (e.g., `sync_native_handler.gd`)

**Classes:**
- Components: `C_PascalCase` prefix (e.g., `C_Velocity`, `C_Transform`, `C_NetPosition`)
- Systems: `S_PascalCase` prefix (e.g., `S_Movement`, `S_NetworkSync`)
- Entities: `E_PascalCase` prefix (e.g., `E_Player`)
- Core framework classes: plain `PascalCase` (e.g., `Entity`, `Component`, `System`, `World`, `QueryBuilder`)
- Test classes: `Test_PascalCase` or `TestPascalCase` (e.g., `TestWorld`, `TestEntity`)

**Variables and Properties:**
- Instance variables: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- @export properties on components: `snake_case` descriptive names (e.g., `velocity`, `speed`, `sync_interval`)
- Private/internal intent signaled by leading underscore: `_internal_var`

**Functions:**
- All functions: `snake_case`
- Virtual/override functions follow Godot conventions: `_ready`, `_process`, `_init`
- Framework lifecycle hooks: `query()`, `process()`, `define_components()`
- Test functions: `test_<description>` (e.g., `test_add_and_get_component`)

**Parameters:**
- `snake_case`, descriptive (e.g., `entity`, `component`, `delta`, `entities`)

## Code Style

**Formatting:**
- GDScript standard indentation (tabs, not spaces)
- No trailing whitespace
- Blank lines between functions
- Type hints used on export variables and function signatures where beneficial

**Linting:**
- GDScript built-in language rules enforced by Godot editor
- No external linter config detected

**Type Annotations:**
- Component properties use `@export` with explicit types: `@export var speed: float = 0.0`
- Function signatures in core framework classes use typed parameters: `func process(entities: Array[Entity], components: Array, delta: float) -> void`
- Return types annotated on non-trivial functions: `-> void`, `-> Array`, `-> bool`

## Import Organization

**Order:**
- No explicit import system (GDScript uses `class_name` for global access)
- `class_name` declaration at top of file
- `extends` declaration immediately after `class_name`
- `@export` variables declared before non-exported variables
- Constants declared before variables

**Example Pattern:**
```gdscript
class_name C_Velocity
extends Component

const MAX_SPEED = 100.0

@export var speed: float = 0.0
@export var direction: Vector2 = Vector2.ZERO

var _internal_state: bool = false
```

## Documentation Patterns

**Doc Comments:**
- `##` double-hash used for documentation comments on classes, properties, and functions
- Single `#` for inline implementation comments
- Doc comments appear immediately above the item they document

**Class Documentation:**
```gdscript
## A component that holds velocity data for an entity.
## Used by S_Movement to apply movement each frame.
class_name C_Velocity
extends Component
```

**Property Documentation:**
```gdscript
## The movement speed in units per second.
@export var speed: float = 0.0

## Normalized direction vector.
@export var direction: Vector2 = Vector2.ZERO
```

**Function Documentation:**
```gdscript
## Processes all entities with velocity components.
## [param entities] - Array of matching entities
## [param delta] - Frame time in seconds
func process(entities: Array[Entity], components: Array, delta: float) -> void:
```

**TODO/FIXME Comments:**
- `# TODO:` for planned work
- `# FIXME:` for known bugs
- `# DEPRECATED:` on stubs kept for compatibility (e.g., `cn_sync_entity.gd`)

## Error Handling

**Strategy:**
- GDScript does not use exceptions; errors handled via return values and logging
- Null checks before accessing optional components
- `is_instance_valid()` guard used for freed entity safety (particularly in CommandBuffer lambdas)

**Patterns:**
```gdscript
# Null guard before component use
var comp = entity.get_component(C_Velocity)
if comp == null:
    return

# is_instance_valid guard in CommandBuffer lambdas
cmd.add_custom(func():
    if not is_instance_valid(entity):
        return
    entity.queue_free()
)

# Push error for unexpected states
if world == null:
    push_error("ECS: World is not set. Cannot process.")
    return
```

**Assertions:**
- `assert()` used in tests, not in production code
- Production code uses conditional checks with early returns

## Logging

**Framework:** Custom `gecs` logger, configured via project settings (`gecs.log_level=4`)

**Log Level Setting:**
- Configured in `project.godot` as `gecs/log_level`
- Level 4 = debug/verbose in development

**Patterns:**
- Framework internal logging uses a log utility (not raw `print`)
- `print()` acceptable in example/demo code
- Debug logs wrapped in level checks to avoid performance cost in production
- Key events logged: entity added/removed, component indexed/deindexed, system processed, query executed

**Example:**
```gdscript
# Framework internal logging pattern
if ECS.log_level >= LOG_LEVEL_DEBUG:
    print("[GECS] Entity added: ", entity.name)
```

## Component Design

**Rule:** Components are data-only — no logic, no functions beyond optional `_init`.

**Correct:**
```gdscript
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0
```

**Incorrect:** Business logic, method calls, signal connections inside components.

## System Design

**Rule:** Systems contain all game logic. Query is defined in `query()`, logic runs in `process()`.

```gdscript
class_name S_Movement
extends System

func query():
    return q.with_all([C_Transform, C_Velocity])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var transform = entity.get_component(C_Transform)
        var velocity = entity.get_component(C_Velocity)
        transform.position += velocity.direction * velocity.speed * delta
```

**CommandBuffer usage:** Always use `cmd.*` for structural changes during iteration rather than direct mutation.

## Module Design

**Exports:**
- Classes registered globally via `class_name`
- No barrel/index files (not applicable in GDScript)
- Each `.gd` file is one class

**Plugin Structure:**
- Addon code lives entirely under `addons/gecs/`
- Tests live under `addons/gecs/tests/`
- No test code in production addon paths

---

*Convention analysis: 2026-03-17*

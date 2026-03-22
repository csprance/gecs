# Testing Patterns

**Analysis Date:** 2026-03-17

## Test Framework

**Runner:**
- GdUnit4 (Godot unit testing framework)
- Config: `addons/gdUnit4/GdUnitRunner.cfg`
- Plugin: `addons/gdUnit4/plugin.cfg`

**Assertion Library:**
- GdUnit4 built-in assertions (`assert_that`, `assert_bool`, `assert_int`, `assert_str`, `assert_array`, `assert_object`, etc.)

**Run Commands:**
```bash
# Windows - Run all tests
GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"

# Windows - Run specific test file
GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core/test_world.gd"

# Run specific test method (no spaces around ::)
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core/test_entity.gd::test_add_and_get_component"

# Continue on failures
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c
```

## Test File Organization

**Location:**
- All tests live under `addons/gecs/tests/`
- Core tests: `addons/gecs/tests/core/`
- Performance tests: `addons/gecs/tests/performance/`
- No tests outside `addons/gecs/tests/` — this is a hard rule

**Naming:**
- Test files: `test_<subject>.gd` (e.g., `test_world.gd`, `test_entity.gd`, `test_query.gd`)
- Test class names match file: `TestWorld`, `TestEntity`, `TestQuery`
- Test methods: `test_<description_of_behavior>` (e.g., `test_add_and_get_component`)

**Structure:**
```
addons/gecs/tests/
├── core/
│   ├── test_world.gd
│   ├── test_entity.gd
│   ├── test_query.gd
│   ├── test_system.gd
│   ├── test_component.gd
│   ├── test_command_buffer.gd
│   └── test_relationship.gd
└── performance/
    ├── test_entity_perf.gd
    ├── test_component_perf.gd
    ├── test_query_perf.gd
    └── test_system_perf.gd
```

## Test Structure

**Class Declaration:**
```gdscript
extends GdUnitTestSuite
```

**Suite Organization:**
```gdscript
extends GdUnitTestSuite

# --- Lifecycle ---

func before_test() -> void:
    # Runs before each test method
    # Set up fresh World, entities, components

func after_test() -> void:
    # Runs after each test method
    # Cleanup if not using auto_free

func before() -> void:
    # Runs once before all tests in the suite

func after() -> void:
    # Runs once after all tests in the suite

# --- Tests ---

func test_some_behavior() -> void:
    # Arrange
    var world = auto_free(World.new())
    # Act
    # Assert
```

**Lifecycle Hooks:**
- `before()` — suite-level setup (once per class)
- `after()` — suite-level teardown (once per class)
- `before_test()` — per-test setup (runs before each `test_*` method)
- `after_test()` — per-test teardown (runs after each `test_*` method)

## auto_free Pattern

**Purpose:** Automatically frees Godot objects (Nodes, Resources) after each test to prevent memory leaks and cross-test contamination.

**Usage:**
```gdscript
func test_entity_has_component() -> void:
    # Wrap any Node or Resource in auto_free()
    var world = auto_free(World.new())
    var entity = auto_free(Entity.new())
    var component = auto_free(C_Health.new())

    world.add_entity(entity)
    entity.add_component(component)

    assert_bool(entity.has_component(C_Health)).is_true()
```

**Rules:**
- Always use `auto_free()` for `Node` and `Resource` instances created in tests
- Do NOT call `queue_free()` manually on `auto_free()` objects — the framework handles it
- Scene runner objects are automatically managed by GdUnit4 and do not need `auto_free()`

## Assertions

**Boolean:**
```gdscript
assert_bool(value).is_true()
assert_bool(value).is_false()
```

**Equality:**
```gdscript
assert_that(actual).is_equal(expected)
assert_int(count).is_equal(3)
assert_str(name).is_equal("player")
assert_float(speed).is_equal_approx(1.5, 0.01)
```

**Null:**
```gdscript
assert_object(component).is_not_null()
assert_object(result).is_null()
```

**Arrays:**
```gdscript
assert_array(entities).has_size(3)
assert_array(entities).contains([entity_a, entity_b])
assert_array(entities).is_empty()
assert_array(entities).is_not_empty()
```

**Object type:**
```gdscript
assert_object(obj).is_instanceof(C_Velocity)
```

## Mocking

**Framework:** GdUnit4 built-in mock/spy system (`mock()`, `spy()`)

**Basic Mock:**
```gdscript
func test_system_called() -> void:
    var mock_system = mock(System)
    do_return(true).on(mock_system).is_processing()
    verify(mock_system).process(any_array(), any_array(), any_float())
```

**Spy (wrap real object):**
```gdscript
func test_world_spy() -> void:
    var real_world = auto_free(World.new())
    var spy_world = spy(real_world)
    spy_world.add_entity(auto_free(Entity.new()))
    verify(spy_world).add_entity(any_class(Entity))
```

**Argument Matchers:**
```gdscript
any()              # matches any value
any_int()          # matches any int
any_float()        # matches any float
any_string()       # matches any String
any_array()        # matches any Array
any_class(MyClass) # matches any instance of MyClass
```

**What to Mock:**
- External system dependencies (e.g., network singletons)
- Heavy Node hierarchies not under test
- Systems when testing World orchestration only

**What NOT to Mock:**
- Core ECS classes (Entity, Component, World) — use real instances
- Components — always use real data objects
- The subject under test itself

## Mock Classes (Inline Test Helpers)

For ECS tests, inline minimal classes are defined within test files to avoid cross-file dependencies:

```gdscript
class TestComponent extends Component:
    @export var value: int = 0

class TestEntity extends Entity:
    pass

class TestSystem extends System:
    var processed_count: int = 0

    func query():
        return q.with_all([TestComponent])

    func process(entities: Array[Entity], components: Array, delta: float) -> void:
        processed_count += entities.size()
```

**Pattern:** Inner test classes keep test helpers scoped to the file and avoid polluting the global `class_name` namespace.

## Fixtures and Factories

**Test Data Setup Pattern:**
```gdscript
extends GdUnitTestSuite

var world: World
var entity: Entity

func before_test() -> void:
    world = auto_free(World.new())
    entity = auto_free(Entity.new())
    world.add_entity(entity)

func _make_entity_with_velocity(speed: float) -> Entity:
    var e = auto_free(Entity.new())
    var vel = C_Velocity.new()
    vel.speed = speed
    e.add_component(vel)
    world.add_entity(e)
    return e
```

**Location:**
- Fixtures are defined inline within test files (no separate fixture directory)
- Helper factory methods prefixed with `_make_` or `_create_`
- Shared setup in `before_test()` lifecycle hook

## Parameterized Tests

**Framework:** GdUnit4 native parameterized test support via `test_parameters`.

**Pattern:**
```gdscript
func test_entity_creation(scale: int, test_parameters := [[100], [1000], [10000]]):
    var entities = []
    for i in scale:
        entities.append(auto_free(Entity.new()))
    assert_int(entities.size()).is_equal(scale)
    # Test runs 3 times: scale=100, scale=1000, scale=10000
```

**Multiple Parameters:**
```gdscript
func test_component_query(component_count: int, entity_count: int,
    test_parameters := [[5, 100], [10, 500], [20, 1000]]):
    # Runs with each [component_count, entity_count] pair
    pass
```

**Use Cases:**
- Performance tests at varying scales (100, 1000, 10000 entities)
- Boundary condition tests with different input values
- Equivalence class testing

## Performance Tests

**Location:** `addons/gecs/tests/performance/`

**Output:** Each test writes to `reports/perf/{test_name}.jsonl`

**Format:**
```jsonl
{"timestamp":"2025-01-13T10:23:45","test":"entity_creation","scale":100,"time_ms":12.5,"godot_version":"4.5"}
```

**Pattern:**
```gdscript
func test_entity_creation(scale: int, test_parameters := [[100], [1000], [10000]]):
    var start = Time.get_ticks_msec()
    for i in scale:
        var e = auto_free(Entity.new())
        world.add_entity(e)
    var elapsed = Time.get_ticks_msec() - start
    _write_perf_result("entity_creation", scale, elapsed)
```

**Run Performance Tests:**
```bash
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance"
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/performance/test_entity_perf.gd"
```

## Scene Runner

**Purpose:** GdUnit4's scene runner loads and drives a full Godot scene for integration-level tests.

**Pattern:**
```gdscript
func test_system_in_scene() -> void:
    var runner = scene_runner("res://addons/gecs/tests/scenes/test_world_scene.tscn")
    await runner.simulate_frames(10)
    var world_node = runner.get_scene().get_node("World")
    assert_object(world_node).is_not_null()
    runner.simulate_key_pressed(KEY_SPACE)
    await runner.simulate_frames(1)
```

**Notes:**
- Scene runner objects are managed by GdUnit4 — do not call `auto_free()` on them
- Use for testing full ECS pipeline (World + Systems + Entities in tree)
- Use unit tests (no scene runner) for isolated component/query logic

## Coverage

**Requirements:** No enforced coverage threshold detected.

**View Coverage:**
```bash
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c
# Coverage report generated in reports/ directory by GdUnit4
```

## Test Types

**Unit Tests:**
- Scope: Single class in isolation (Entity, Component, QueryBuilder, CommandBuffer)
- Location: `addons/gecs/tests/core/`
- Approach: Instantiate class directly, call methods, assert state

**Integration Tests:**
- Scope: World + System + Entity interaction
- Location: `addons/gecs/tests/core/test_world.gd`, `test_system.gd`
- Approach: Build minimal ECS graph, run `ECS.process()`, assert results

**Performance Tests:**
- Scope: Throughput and timing at scale
- Location: `addons/gecs/tests/performance/`
- Approach: Parameterized scale tests, write JSONL results

**E2E / Scene Tests:**
- Framework: GdUnit4 scene runner
- Use: Full scene loading with real node tree
- Scope: Limited; most ECS logic testable without scenes

## Common Patterns

**Testing Component Add/Get:**
```gdscript
func test_add_and_get_component() -> void:
    var entity = auto_free(Entity.new())
    var comp = C_Health.new()
    comp.current = 50.0
    entity.add_component(comp)
    var retrieved = entity.get_component(C_Health)
    assert_object(retrieved).is_not_null()
    assert_float(retrieved.current).is_equal(50.0)
```

**Testing Query Results:**
```gdscript
func test_query_returns_matching_entities() -> void:
    var world = auto_free(World.new())
    var e1 = auto_free(Entity.new())
    var e2 = auto_free(Entity.new())
    e1.add_component(C_Velocity.new())
    world.add_entity(e1)
    world.add_entity(e2)  # no velocity
    var results = world.query.with_all([C_Velocity]).execute()
    assert_array(results).has_size(1)
    assert_array(results).contains([e1])
```

**Testing CommandBuffer Deferred Execution:**
```gdscript
func test_command_buffer_removes_entity() -> void:
    var world = auto_free(World.new())
    var entity = auto_free(Entity.new())
    world.add_entity(entity)
    var cmd = auto_free(CommandBuffer.new(world))
    cmd.remove_entity(entity)
    assert_array(world.entities).has_size(1)  # still present before execute
    cmd.execute()
    assert_array(world.entities).has_size(0)  # removed after execute
```

**Testing Relationships:**
```gdscript
func test_relationship_query() -> void:
    var world = auto_free(World.new())
    var parent = auto_free(Entity.new())
    var child = auto_free(Entity.new())
    child.add_relationship(Relationship.new(C_ChildOf.new(), parent))
    world.add_entity(parent)
    world.add_entity(child)
    var results = world.query.with_relationship([
        Relationship.new(C_ChildOf.new(), parent)
    ]).execute()
    assert_array(results).has_size(1)
    assert_array(results).contains([child])
```

---

*Testing analysis: 2026-03-17*

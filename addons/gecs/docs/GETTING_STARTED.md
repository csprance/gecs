# Getting Started

## Installation

1. Copy `addons/gecs/` into your project's `addons/` folder.
2. Enable the plugin in `Project > Project Settings > Plugins`.
3. Verify `ECS` appears in `Project > Project Settings > AutoLoads`. See the [README](../../../../README.md) for full setup detail.

## Core Concepts in 30 Seconds

Entities are nodes that hold data via Components. Systems process entities by querying for the components they care about. The World tracks all entities and drives system processing. Nothing communicates directly — data flows through components, logic lives in systems.

## Your First Entity

### Option A: Scene-based entity (spatial)

Create a scene with a `Node3D` (or `Node2D`) root, then attach a script that extends `Entity`:

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

> **Note:** This pattern requires the scene root to be `Node3D` or `Node2D`. Entity extends `Node` — spatial properties (`global_position`, `global_transform`, etc.) are only available when the scene root is a spatial node. For purely data-driven entities, use Option B.

### Option B: Code-based entity (pure data)

Extend `Entity` directly with no scene file needed:

```gdscript
class_name GameTimer
extends Entity

func define_components() -> Array:
    return [C_Timer.new(30.0)]
```

## Your First Component

Components are data-only resources:

```gdscript
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0
```

> **Note:** Component `_init` arguments must all have default values, or Godot will crash when GECS instantiates the component internally.

## Your First System

Systems contain all game logic. Override `query()` to select entities and `process()` to operate on them:

```gdscript
class_name HealthSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Health])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var health = entity.get_component(C_Health) as C_Health
        if health.current <= 0.0:
            print("Entity died: ", entity.name)
```

## Wiring It Together

The World node and System nodes belong in the scene tree. Set `ECS.world` before calling `ECS.process()`:

```gdscript
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

`add_entity` places the entity in the scene tree by default (`add_to_tree = true`). Do not call `add_child` before `add_entity` — the World manages tree placement.

## Safe Structural Changes (CommandBuffer)

Systems can safely add or remove entities and components during iteration using the built-in `cmd` buffer. This avoids manual backwards iteration. See [Core Concepts](CORE_CONCEPTS.md) for details.

## Next Steps

- [Core Concepts](CORE_CONCEPTS.md) — full API reference for Entity, Component, System, World, and QueryBuilder
- [Serialization](SERIALIZATION.md) — saving and loading game state

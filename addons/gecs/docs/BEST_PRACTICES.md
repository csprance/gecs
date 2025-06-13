# GECS Best Practices Guide

> **Write maintainable, performant ECS code**

This guide covers proven patterns and practices for building robust games with GECS. Apply these patterns to keep your code clean, fast, and easy to debug.

## 📋 Prerequisites

- Completed [Getting Started Guide](GETTING_STARTED.md)
- Understanding of [Core Concepts](CORE_CONCEPTS.md)

## 🧱 Component Design Patterns

### Keep Components Pure Data

Components should only hold data, never logic or behavior.

```gdscript
# ✅ Good - Pure data component
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0
@export var regeneration_rate: float = 1.0

func _init(max_health: float = 100.0):
    maximum = max_health
    current = max_health
```

```gdscript
# ❌ Avoid - Logic in components
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0

# This belongs in a system, not a component
func take_damage(amount: float):
    current -= amount
    if current <= 0:
        print("Entity died!")
```

### Use Composition Over Inheritance

Build entities by combining simple components rather than complex inheritance hierarchies.

```gdscript
# ✅ Good - Composable components
player.add_component(C_Health.new(100))
player.add_component(C_Movement.new(Vector2(200, 300)))
player.add_component(C_Input.new())
player.add_component(C_Sprite.new("player.png"))

# Same components can be reused for enemies
enemy.add_component(C_Health.new(50))
enemy.add_component(C_Movement.new(Vector2(100, 0)))
enemy.add_component(C_AI.new())
enemy.add_component(C_Sprite.new("enemy.png"))
```

### Design for Configuration

Make components easily configurable through export properties.

```gdscript
# ✅ Good - Configurable component
class_name C_Movement
extends Component

@export var speed: float = 100.0
@export var acceleration: float = 500.0
@export var friction: float = 800.0
@export var max_speed: float = 300.0
@export var can_fly: bool = false

func _init(spd: float = 100.0, can_fly_: bool = false):
    speed = spd
    can_fly = can_fly_
```

## ⚙️ System Design Patterns

### Single Responsibility Principle

Each system should handle one specific concern.

```gdscript
# ✅ Good - Focused systems
class_name MovementSystem extends System
func query(): return q.with_all([C_Position, C_Velocity])

class_name RenderSystem extends System
func query(): return q.with_all([C_Position, C_Sprite])

class_name HealthSystem extends System
func query(): return q.with_all([C_Health])
```

### Use System Groups for Processing Order

Organize systems into logical groups and process them in the right order.

```gdscript
# Main.gd
func _ready():
    # Setup systems in groups
    world.add_system(InputSystem.new(), "input")
    world.add_system(MovementSystem.new(), "physics")
    world.add_system(RenderSystem.new(), "render")

func _process(delta):
    ECS.process(delta, "input")
    ECS.process(delta, "physics")
    ECS.process(delta, "render")
```

### Early Exit for Performance

Return early from system processing when no work is needed.

```gdscript
# ✅ Good - Early exit patterns
class_name HealthRegenerationSystem extends System

func query():
    return q.with_all([C_Health]).with_none([C_Dead])

func process(entity: Entity, delta: float):
    var health = entity.get_component(C_Health)

    # Early exit if already at max health
    if health.current >= health.maximum:
        return

    # Apply regeneration
    health.current = min(health.current + health.regeneration_rate * delta, health.maximum)
```

## 🏗️ Code Organization Patterns

### GECS Naming Conventions

```gdscript
# ✅ GECS Standard naming patterns:

# Components: C_ComponentName class, c_component_name.gd file
class_name C_Health extends Component      # c_health.gd
class_name C_Position extends Component    # c_position.gd

# Systems: SystemNameSystem class, s_system_name.gd file
class_name MovementSystem extends System   # s_movement.gd
class_name RenderSystem extends System     # s_render.gd

# Entities: EntityName class, e_entity_name.gd file
class_name Player extends Entity           # e_player.gd
class_name Enemy extends Entity            # e_enemy.gd

# Observers: ObserverNameObserver class, o_observer_name.gd file
class_name HealthUIObserver extends Observer  # o_health_ui.gd
```

### File Organization

```
project/
├── entities/
│   ├── e_player.gd
│   ├── e_enemy.gd
│   └── e_projectile.gd
├── components/
│   ├── c_health.gd
│   ├── c_movement.gd
│   └── c_sprite.gd
├── systems/
│   ├── s_movement.gd
│   ├── s_collision.gd
│   └── s_render.gd
└── observers/
    ├── o_health_ui.gd
    └── o_damage_effect.gd
```

## 🎮 Common Game Patterns

### Player Character Pattern

```gdscript
# e_player.gd
class_name Player extends Entity

func _ready():
    add_component(C_Health.new(100))
    add_component(C_Movement.new(200.0))
    add_component(C_Input.new())
    add_group("player")
```

### Projectile Pattern

```gdscript
# e_projectile.gd
class_name Projectile extends Entity

func _ready():
    add_component(C_Position.new())
    add_component(C_Velocity.new())
    add_component(C_Timer.new(5.0))  # Auto-destroy after 5 seconds
    add_group("projectile")
```

## 🚀 Performance Best Practices

### Cache Expensive Queries

```gdscript
# ✅ Good - Cache expensive queries
class_name CombatSystem extends System

var _attackers_query: Query
var _targets_query: Query

func _ready():
    _attackers_query = ECS.world.query.with_all([C_Attack, C_Position]).build()
    _targets_query = ECS.world.query.with_all([C_Health, C_Position]).build()

func process_all(delta: float):
    var attackers = _attackers_query.execute()
    var targets = _targets_query.execute()
    # Process combat...
```

### Use Specific Queries

```gdscript
# ✅ Good - Specific query
class_name PlayerInputSystem extends System
func query():
    return q.with_all([C_Input, C_Movement]).with_group("player")

# ❌ Avoid - Overly broad queries
class_name UniversalMovementSystem extends System
func query():
    return q.with_all([C_Position])  # Too broad - matches everything
```

## 🎯 Next Steps

Now that you understand best practices:

1. **Apply these patterns** in your projects
2. **Learn advanced topics** in [Core Concepts](CORE_CONCEPTS.md)
3. **Optimize performance** with [Performance Guide](PERFORMANCE_OPTIMIZATION.md)

**Need help?** [Join our Discord](https://discord.gg/eB43XU2tmn) for community discussions and support.

---

_"Good ECS code is like a well-organized toolbox - every component has its place, every system has its purpose, and everything works together smoothly."_

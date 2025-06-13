# GECS Performance Optimization Guide

> **Make your ECS games run fast and smooth**

This guide shows you how to optimize your GECS-based games for maximum performance. Learn to identify bottlenecks, optimize queries, and design systems that scale.

## 📋 Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Best Practices](BEST_PRACTICES.md)
- A working GECS project to optimize

## 🎯 Performance Fundamentals

### The ECS Performance Model

GECS performance depends on three key factors:

1. **Query Efficiency** - How fast you find entities
2. **Component Access** - How quickly you read/write data
3. **System Design** - How well your logic is organized

Most performance gains come from optimizing these in order of impact.

## 🔍 Profiling Your Game

### Enable Built-in Profiling

Always profile before optimizing. GECS provides built-in performance tracking:

```gdscript
# Main.gd
func _ready():
    # Enable performance tracking
    ECS.world.enable_profiling = true

func _process(delta):
    ECS.process(delta)

    # Print performance stats every second
    if Engine.get_process_frames() % 60 == 0:
        print("ECS Performance:")
        print("  Query time: ", ECS.world.get_profiling_data("queries"))
        print("  System time: ", ECS.world.get_profiling_data("systems"))
        print("  Total entities: ", ECS.world.entity_count)
```

### Use Godot's Built-in Profiler

Monitor your game's performance in the Godot editor:

1. **Run your project** in debug mode
2. **Open the Profiler** (Debug → Profiler)
3. **Look for ECS-related spikes** in the frame time
4. **Identify the slowest systems** in your processing groups

## ⚡ Query Optimization

### 1. Use Query Caching

Cache expensive queries instead of rebuilding them:

```gdscript
# ✅ Good - Cached queries
class_name CombatSystem extends System

var _damage_dealers_query: Query
var _damage_receivers_query: Query

func _ready():
    # Build queries once
    _damage_dealers_query = ECS.world.query.with_all([C_Attack, C_Position]).build()
    _damage_receivers_query = ECS.world.query.with_all([C_Health, C_Position])
                                  .with_none([C_Dead]).build()

func process_all(delta: float):
    var attackers = _damage_dealers_query.execute()
    var targets = _damage_receivers_query.execute()
    # Process combat...
```

```gdscript
# ❌ Slow - Rebuilding queries every frame
func process_all(delta: float):
    var attackers = ECS.world.query.with_all([C_Attack, C_Position]).execute()
    var targets = ECS.world.query.with_all([C_Health, C_Position])
                              .with_none([C_Dead]).execute()
    # This rebuilds query structures every frame!
```

### 2. Optimize Query Specificity

More specific queries run faster:

```gdscript
# ✅ Fast - Specific query
class_name PlayerInputSystem extends System
func query():
    return q.with_all([C_Input, C_Movement]).with_group("player")
    # Only matches 1 entity typically

# ✅ Fast - Type-specific query
class_name ProjectileSystem extends System
func query():
    return q.with_all([C_Projectile, C_Velocity])
    # Only matches projectiles
```

```gdscript
# ❌ Slow - Overly broad query
class_name UniversalSystem extends System
func query():
    return q.with_all([C_Position])
    # Matches almost everything in the game!

func process(entity: Entity, delta: float):
    # Now we need expensive type checking
    if entity.has_component(C_Player):
        # Handle player...
    elif entity.has_component(C_Enemy):
        # Handle enemy...
    # This defeats the purpose of ECS!
```

### 3. Minimize with_any Queries

`with_any` queries are slower than `with_all`. Use sparingly:

```gdscript
# ✅ Better - Split into specific systems
class_name PlayerMovementSystem extends System
func query(): return q.with_all([C_Player, C_Movement])

class_name EnemyMovementSystem extends System
func query(): return q.with_all([C_Enemy, C_Movement])
```

```gdscript
# ❌ Slower - Generic with_any query
class_name MovementSystem extends System
func query():
    return q.with_all([C_Movement])
          .with_any([C_Player, C_Enemy])
    # This has to check both component types for every entity
```

## 🧱 Component Design for Performance

### Keep Components Lightweight

Smaller components = faster memory access:

```gdscript
# ✅ Good - Lightweight components
class_name C_Position extends Component
@export var position: Vector2

class_name C_Velocity extends Component
@export var velocity: Vector2

class_name C_Health extends Component
@export var current: float
@export var maximum: float
```

```gdscript
# ❌ Heavy - Bloated component
class_name MegaComponent extends Component
@export var position: Vector2
@export var velocity: Vector2
@export var health: float
@export var mana: float
@export var inventory: Array[Item] = []
@export var abilities: Array[Ability] = []
@export var dialogue_history: Array[String] = []
# Too much data in one place!
```

### Minimize Property Changes

Component property changes trigger index updates. Batch changes when possible:

```gdscript
# ✅ Good - Batch changes
func apply_damage(entity: Entity, damage: float):
    var health = entity.get_component(C_Health)
    var new_health = health.current - damage

    # Single property update
    health.current = clamp(new_health, 0, health.maximum)

    # Add death state in one operation if needed
    if health.current <= 0:
        entity.add_component(C_Dead.new())
```

### Use Flags Instead of Components for Simple States

Adding/removing components is more expensive than toggling boolean flags:

```gdscript
# ✅ Fast - Flag-based states
class_name C_EntityState extends Component
@export var is_stunned: bool = false
@export var is_invisible: bool = false
@export var is_invulnerable: bool = false

# Change states by setting flags
func stun_entity(entity: Entity):
    entity.get_component(C_EntityState).is_stunned = true

# Systems check flags
class_name MovementSystem extends System
func process(entity: Entity, delta: float):
    var state = entity.get_component(C_EntityState)
    if state.is_stunned:
        return  # Skip movement
```

## ⚙️ System Performance Patterns

### Early Exit Strategies

Return early when no processing is needed:

```gdscript
class_name HealthRegenerationSystem extends System

func process(entity: Entity, delta: float):
    var health = entity.get_component(C_Health)

    # Early exits for common cases
    if health.current >= health.maximum:
        return  # Already at full health

    if health.regeneration_rate <= 0:
        return  # No regeneration configured

    # Only do expensive work when needed
    health.current = min(health.current + health.regeneration_rate * delta, health.maximum)
```

### Process Only What Changed

Track changes to avoid unnecessary processing:

```gdscript
class_name SpriteUpdateSystem extends System

# Track which entities need updates
var _dirty_entities: Array[Entity] = []

func _ready():
    # Listen for component changes
    ECS.world.component_changed.connect(_on_component_changed)

func _on_component_changed(entity: Entity, component: Component):
    if component is C_Sprite or component is C_Position:
        if entity not in _dirty_entities:
            _dirty_entities.append(entity)

func process_all(delta: float):
    # Only process entities that changed
    for entity in _dirty_entities:
        update_sprite_position(entity)

    _dirty_entities.clear()
```

### Batch Entity Operations

Group entity operations together:

```gdscript
# ✅ Good - Batch creation
func spawn_enemy_wave():
    var enemies: Array[Entity] = []

    # Create all entities
    for i in range(50):
        var enemy = create_enemy()
        enemies.append(enemy)

    # Add all to world at once
    ECS.world.add_entities(enemies)

# ✅ Good - Batch removal
func cleanup_dead_entities():
    var dead_entities = ECS.world.query.with_all([C_Dead]).execute()
    ECS.world.remove_entities(dead_entities)
```

## 📊 Performance Targets

### Frame Rate Targets

Aim for these processing times per frame:

- **60 FPS target**: ECS processing < 16ms per frame
- **30 FPS target**: ECS processing < 33ms per frame
- **Mobile target**: ECS processing < 8ms per frame

### Entity Scale Guidelines

GECS handles these entity counts well with proper optimization:

- **Small games**: 100-500 entities
- **Medium games**: 500-2000 entities
- **Large games**: 2000-10000 entities
- **Massive games**: 10000+ entities (requires advanced optimization)

## 🎯 Next Steps

1. **Profile your current game** to establish baseline performance
2. **Apply query optimizations** from this guide
3. **Redesign heavy components** into lighter, focused ones
4. **Implement system improvements** like early exits and batching
5. **Consider advanced techniques** like pooling and spatial partitioning for demanding scenarios

**Need more help?** Check the [Troubleshooting Guide](TROUBLESHOOTING.md) for specific performance issues.

---

_"Fast ECS code isn't about clever tricks - it's about designing systems that naturally align with how the framework works best."_

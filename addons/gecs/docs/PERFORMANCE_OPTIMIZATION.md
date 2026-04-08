# GECS Performance Optimization Guide

> **Make your ECS games run fast and smooth**

This guide shows you how to optimize your GECS-based games for maximum performance. Learn to identify bottlenecks, optimize queries, and design systems that scale.

## Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Best Practices](BEST_PRACTICES.md)
- A working GECS project to optimize

## Performance Fundamentals

### The ECS Performance Model

GECS performance depends on three key factors:

1. **Query Efficiency** - How fast you find entities
2. **Component Access** - How quickly you read/write data
3. **System Design** - How well your logic is organized

Most performance gains come from optimizing these in order of impact.

## Profiling Your Game

### Monitor Query Cache Performance

Always profile before optimizing. GECS provides query cache statistics for performance monitoring:

```gdscript
# Main.gd
func _process(delta):
    ECS.process(delta)

    # Print cache performance stats every second
    if Engine.get_process_frames() % 60 == 0:
        var cache_stats = ECS.world.get_cache_stats()
        print("ECS Performance:")
        print("  Query cache hits: ", cache_stats.get("cache_hits", 0))
        print("  Query cache misses: ", cache_stats.get("cache_misses", 0))
        print("  Total entities: ", ECS.world.entities.size())

        # Reset stats for next measurement period
        ECS.world.reset_cache_stats()
```

### Use Godot's Built-in Profiler

Monitor your game's performance in the Godot editor:

1. **Run your project** in debug mode
2. **Open the Profiler** (Debug → Profiler)
3. **Look for ECS-related spikes** in the frame time
4. **Identify the slowest systems** in your processing groups

## Query Optimization

### 1. Choose the Right Query Method

Query performance ranking (10,000 entities, Godot 4.6):

1. **`.enabled()` / `.disabled()` queries**: **~0.1ms** (Fastest - Use when possible!)
2. **`.with_all([Components])` queries**: **~0.2ms** (Excellent for most use cases)
3. **`.with_any([Components])` queries**: **~0.3ms** (Good for OR-style queries)
4. **`.with_group(["name"])` queries**: **~13.6ms** (Avoid for performance-critical code)

**Performance Recommendations:**

```gdscript
# FASTEST - Use enabled/disabled queries when you only need active entities
class_name ActiveSystemsOnly extends System
func query():
    return q.enabled()  # Constant-time O(1) performance!

# EXCELLENT - Component-based queries (heavily optimized cache)
class_name MovementSystem extends System
func query():
    return q.with_all([C_Position, C_Velocity])  # ~0.2ms for 10K entities

# GOOD - Use with_any sparingly, split into multiple systems when possible
class_name DamageableSystem extends System
func query():
    return q.with_any([C_Player, C_Enemy]).with_all([C_Health])

# AVOID - Group queries are the slowest
class_name PlayerSystem extends System
func query():
    return q.with_group(["player"])  # Consider using components instead
    # Better: q.with_all([C_Player])
```

### 2. Use Proper System Query Pattern

GECS automatically handles query optimization when you follow the standard pattern:

```gdscript
# Good - Standard GECS pattern (automatically optimized)
class_name MovementSystem extends System

func query():
    return q.with_all([C_Position, C_Velocity]).with_none([C_Frozen])

func process(entities: Array[Entity], components: Array, delta: float):
    # Process each entity
    for entity in entities:
        var pos = entity.get_component(C_Position)
        var vel = entity.get_component(C_Velocity)
        pos.value += vel.value * delta
```

```gdscript
# Avoid - Manual query building in process methods
func process(entities: Array[Entity], components: Array, delta: float):
    # Don't do this - bypasses automatic query optimization
    var custom_entities = ECS.world.query.with_all([C_Position]).execute()
    # Process custom_entities...
```

### 3. Optimize Query Specificity

More specific queries run faster:

```gdscript
# Fast - Use enabled filter for active entities only
class_name PlayerInputSystem extends System
func query():
    return q.with_all([C_Input, C_Movement]).enabled()
    # Super fast enabled filtering + component matching

# Fast - Specific component query
class_name ProjectileSystem extends System
func query():
    return q.with_all([C_Projectile, C_Velocity])
    # Only matches projectiles - very specific
```

```gdscript
# Slow - Overly broad query
class_name UniversalSystem extends System
func query():
    return q.with_all([C_Position])
    # Matches almost everything in the game!

func process(entities: Array[Entity], components: Array, delta: float):
    # Now we need expensive type checking in a loop
    for entity in entities:
        if entity.has_component(C_Player):
            # Handle player...
        elif entity.has_component(C_Enemy):
            # Handle enemy...
        # This defeats the purpose of ECS!
```

### 4. Smart Use of with_any Queries

`with_any` queries are **much faster than before** but still slower than `with_all`. Use strategically:

```gdscript
# Good - with_any for legitimate OR scenarios
class_name DamageSystem extends System
func query():
    return q.with_any([C_Player, C_Enemy, C_NPC]).with_all([C_Health])
    # When you truly need "any of these types with health"

# Better - Split when entities have different behavior
class_name PlayerMovementSystem extends System
func query(): return q.with_all([C_Player, C_Movement])

class_name EnemyMovementSystem extends System
func query(): return q.with_all([C_Enemy, C_Movement])
# Split systems = simpler logic + better performance
```

### 5. Avoid Group Queries for Performance-Critical Code

Group queries are now the slowest option. Use component-based queries instead:

```gdscript
# Slow - Group-based query (~13.6ms for 10K entities)
class_name PlayerSystem extends System
func query():
    return q.with_group(["player"])

# Fast - Component-based query (~0.2ms for 10K entities)
class_name PlayerSystem extends System
func query():
    return q.with_all([C_Player])
```

## Component Design for Performance

### Keep Components Lightweight

Smaller components = faster memory access:

```gdscript
# Good - Lightweight components
class_name C_Position extends Component
@export var position: Vector2

class_name C_Velocity extends Component
@export var velocity: Vector2

class_name C_Health extends Component
@export var current: float
@export var maximum: float
```

```gdscript
# Heavy - Bloated component
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

### Minimize Component Additions/Removals

Adding and removing components requires index updates. Batch component operations when possible:

```gdscript
# Good - Batch component operations
func setup_new_enemy(entity: Entity):
    # Add multiple components in one batch
    entity.add_components([
        C_Health.new(),
        C_Position.new(),
        C_Velocity.new(),
        C_Enemy.new()
    ])

# Good - Single component change when needed
func apply_damage(entity: Entity, damage: float):
    var health = entity.get_component(C_Health)
    health.current = clamp(health.current - damage, 0, health.maximum)

    if health.current <= 0:
        entity.add_component(C_Dead.new())  # Single component addition
```

### Choose Between Boolean Properties vs Components Based on Usage

The choice between boolean properties and separate components depends on how frequently states change and how many entities need them.

#### Use Boolean Properties for Frequently-Changing States

When states change often, boolean properties avoid expensive index updates:

```gdscript
# Good for frequently-changing states (buffs, status effects, etc.)
class_name C_EntityState extends Component
@export var is_stunned: bool = false
@export var is_invisible: bool = false
@export var is_invulnerable: bool = false

class_name MovementSystem extends System
func query():
    return q.with_all([C_Position, C_Velocity, C_EntityState])
    # All entities that might need states must have this component

func process(entities: Array[Entity], components: Array, delta: float):
    for entity in entities:
        var state = entity.get_component(C_EntityState)
        if state.is_stunned:
            continue  # Just a property check - no index updates

        # Process movement...
```

**Tradeoffs:**

- Fast state changes (no index rebuilds)
- Simple property checks in systems
- All entities need the state component (memory overhead)
- Less precise queries (can't easily find "only stunned entities")

#### Use Separate Components for Rare or Permanent States

When states are long-lasting or infrequent, separate components provide precise queries:

```gdscript
# Good for rare/permanent states (player vs enemy, permanent abilities)
class_name MovementSystem extends System
func query():
    return q.with_all([C_Position, C_Velocity]).with_none([C_Paralyzed])
    # Precise query - only entities that can move

# Separate systems can target specific states precisely
class_name ParalyzedSystem extends System
func query():
    return q.with_all([C_Paralyzed])  # Only paralyzed entities
```

**Tradeoffs:**

- Memory efficient (only entities with states have components)
- Precise queries for specific states
- State changes trigger expensive index updates
- Complex queries with multiple exclusions

#### Guidelines:

- **High-frequency changes** (every few frames): Use boolean properties
- **Low-frequency changes** (minutes apart): Use separate components
- **Related states** (buffs/debuffs): Group into property components
- **Distinct entity types** (player/enemy): Use separate components

## System Performance Patterns

### Early Exit Strategies

Return early when no processing is needed:

```gdscript
class_name HealthRegenerationSystem extends System

func process(entities: Array[Entity], components: Array, delta: float):
    for entity in entities:
        var health = entity.get_component(C_Health)

        # Early exits for common cases
        if health.current >= health.maximum:
            continue  # Already at full health

        if health.regeneration_rate <= 0:
            continue  # No regeneration configured

        # Only do expensive work when needed
        health.current = min(health.current + health.regeneration_rate * delta, health.maximum)
```

### Batch Entity Operations

Group entity operations together. Use CommandBuffer for deferred execution with single cache invalidation:

```gdscript
# Best - Use CommandBuffer in systems for bulk operations
class_name CleanupSystem extends System

func query():
    return q.with_all([C_Dead])

func process(entities: Array[Entity], components: Array, delta: float):
    for entity in entities:
        cmd.remove_entity(entity)  # Queued, single cache invalidation when flushed

# Good - Batch creation outside of systems
func spawn_enemy_wave():
    var enemies: Array[Entity] = []
    for i in range(50):
        var enemy = Entity.new()
        setup_enemy_components(enemy)
        enemies.append(enemy)
    ECS.world.add_entities(enemies)
```

**CommandBuffer flush modes** (`command_buffer_flush_mode: FlushMode`) for performance tuning:
- **FlushMode.PER_SYSTEM** (default) — safe, flushes after each system
- **FlushMode.PER_GROUP** — batches all systems in a group, flushes once at end
- **FlushMode.MANUAL** — maximum batching, requires explicit `ECS.world.flush_command_buffers()` call

## Performance Targets

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

## Next Steps

1. **Profile your current game** to establish baseline performance
2. **Apply query optimizations** from this guide
3. **Redesign heavy components** into lighter, focused ones
4. **Implement system improvements** like early exits and batching
5. **Consider advanced techniques** like pooling and spatial partitioning for demanding scenarios

## Additional Performance Features

### Query Cache Statistics

Monitor query performance with built-in cache tracking:

```gdscript
# Get detailed cache performance data
var stats = ECS.world.get_cache_stats()
print("Cache hit rate: ", stats.get("cache_hits", 0) / (stats.get("cache_hits", 0) + stats.get("cache_misses", 1)))
```

**Need more help?** Check the [Troubleshooting Guide](TROUBLESHOOTING.md) for specific performance issues.


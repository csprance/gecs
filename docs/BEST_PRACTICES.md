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
# ✅ Good - Composable components via define_components() or scene setup
class_name Player
extends Entity

func define_components() -> Array:
    return [
        C_Health.new(100),
        C_Transform.new(),
        C_Input.new()
    ]

class_name Enemy
extends Entity

func define_components() -> Array:
    return [
        C_Health.new(50),
        C_Transform.new(),
        C_AI.new()
    ]
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

Organize systems into logical groups using scene-based organization. Systems are grouped in scene nodes and processed in the correct order.

```gdscript
# main.gd - Process systems in correct order
func _process(delta):
    world.process(delta, "run-first")  # Initialization systems
    world.process(delta, "input")      # Input handling
    world.process(delta, "gameplay")   # Game logic
    world.process(delta, "ui")         # UI updates
    world.process(delta, "run-last")   # Cleanup systems

func _physics_process(delta):
    world.process(delta, "physics")    # Physics systems
    world.process(delta, "debug")      # Debug systems
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

Organize your ECS files by theme for better scalability:

```
project/
├── components/
│   ├── ai/              # AI-related components
│   ├── animation/       # Animation components
│   ├── gameplay/        # Core gameplay components
│   ├── gear/           # Equipment/gear components
│   ├── item/           # Item system components
│   ├── multiplayer/    # Multiplayer-specific
│   ├── relationships/  # Relationship components
│   ├── rendering/      # Visual/rendering
│   └── weapon/         # Weapon system
├── entities/
│   ├── enemies/        # Enemy entities
│   ├── gameplay/       # Core entities
│   ├── items/          # Item entities
│   └── ui/             # UI entities
├── systems/
│   ├── combat/         # Combat systems
│   ├── core/           # Core ECS systems
│   ├── gameplay/       # Gameplay systems
│   ├── input/          # Input systems
│   ├── interaction/    # Interaction systems
│   ├── physics/        # Physics systems
│   └── ui/             # UI systems
└── observers/
    └── o_transform.gd   # Reactive systems
```

## 🎮 Common Game Patterns

### Player Character Pattern

```gdscript
# e_player.gd
class_name Player
extends Entity

func on_ready():
    # Common pattern: sync scene transform to component
    if has_component(C_Transform):
        var transform_comp = get_component(C_Transform)
        transform_comp.transform = global_transform
    add_to_group("player")
```

### Enemy Pattern

```gdscript
# e_enemy.gd
class_name Enemy
extends Entity

func on_ready():
    # Sync transform and add to enemy group
    if has_component(C_Transform):
        var transform_comp = get_component(C_Transform)
        transform_comp.transform = global_transform
    add_to_group("enemies")
```

## 🚀 Performance Best Practices

### Choose the Right Query Method ⭐ NEW!

**Query Performance Ranking** (v5.0.0-rc4+):

```gdscript
# 🏆 FASTEST - Enabled/disabled queries (constant time)
class_name ActiveEntitiesOnly extends System
func query():
    return q.enabled(true)  # ~0.05ms for any number of entities

# 🥈 EXCELLENT - Component queries (heavily optimized)
class_name MovementSystem extends System
func query():
    return q.with_all([C_Position, C_Velocity])  # ~0.6ms for 10K entities

# 🥉 GOOD - Use with_any strategically
class_name DamageableSystem extends System
func query():
    return q.with_any([C_Player, C_Enemy]).with_all([C_Health])  # ~5.6ms for 10K

# 🐌 AVOID - Group queries are slowest
class_name PlayerSystem extends System
func query():
    return q.with_group("player")  # ~16ms for 10K entities
    # Better: q.with_all([C_Player])
```

### Use Batch Processing for Performance

```gdscript
# ✅ Good - Batch processing with process_all
class_name TransformSystem
extends System

func query():
    return q.with_all([C_Transform])

func process_all(entities: Array, _delta):
    # Batch access to components for better performance
    var transforms = ECS.get_components(entities, C_Transform)
    for i in range(entities.size()):
        entities[i].global_transform = transforms[i].transform
```

### Use Specific Queries

```gdscript
# ✅ BEST - Combine enabled filter with components
class_name ActivePlayerInputSystem extends System
func query():
    return q.with_all([C_Input, C_Movement]).enabled(true)
    # Super fast: enabled filtering + component matching

# ✅ GOOD - Specific component query
class_name ProjectileSystem extends System
func query():
    return q.with_all([C_Projectile, C_Velocity])  # Fast and specific

# ❌ AVOID - Group-based queries (slow)
class_name PlayerSystem extends System
func query():
    return q.with_group("player")  # Use q.with_all([C_Player]) instead

# ❌ AVOID - Overly broad queries
class_name UniversalMovementSystem extends System
func query():
    return q.with_all([C_Transform])  # Too broad - matches everything
```

## 🎭 Entity Prefabs (Scene Files)

### Using Godot Scenes as Entity Prefabs

The most powerful pattern in GECS is using Godot's scene system (.tscn files) as entity prefabs. This combines ECS data with Godot's visual editor:

```
e_player.tscn Structure:
├── Player (Entity node - extends your e_player.gd class)
│   ├── MeshInstance3D (visual representation)
│   ├── CollisionShape3D (physics collision)
│   ├── AudioStreamPlayer3D (sound effects)
│   └── SkeletonAttachment3D (for equipment)
```

**Benefits of Scene-based Prefabs:**

- **Visual Editing**: Design entities in Godot's 3D editor
- **Component Assignment**: Set up ECS components in the Inspector
- **Godot Integration**: Leverage existing Godot nodes and systems
- **Reusability**: Instantiate the same prefab multiple times
- **Version Control**: Scene files work well with git

**Setting up Entity Prefabs:**

1. **Create scene with Entity as root**: `e_player.tscn` with `Player` entity node.
   - Another trick here is to add a CharacterBody3d and then extend that CharacterBody3D with the e_player.gd script this way you get Entity class and CharacterBody3D class data
2. **Add visual/physics children**: Add MeshInstance3D, CollisionShape3D, etc. as children
3. **Configure components in Inspector**: Add components to the `component_resources` array
4. **Save as reusable prefab**: Save the .tscn file for instantiation
5. **Set up on_ready()**: Handle any initialization logic

### Component Assignment in Prefabs

**Method 1: Inspector Assignment (Recommended)**

Set up components directly in the Godot Inspector:

```gdscript
# In e_player.tscn entity root node Inspector:
# Component Resources array:
# - [0] C_Health.new() (max: 100, current: 100)
# - [1] C_Transform.new() (synced with scene transform)
# - [2] C_Input.new() (for player controls)
# - [3] C_LocalPlayer.new() (mark as local player)
```

**Method 2: define_components() (Programmatic)**

```gdscript
# e_player.gd attached to Player.tscn root
class_name Player
extends Entity

func define_components() -> Array:
    return [
        C_Health.new(100),
        C_Transform.new(),
        C_Input.new(),
        C_LocalPlayer.new()
    ]

func on_ready():
    # Initialize after components are ready
    if has_component(C_Transform):
        var transform_comp = get_component(C_Transform)
        transform_comp.transform = global_transform
    add_to_group("player")
```

**Method 3: Hybrid Approach**

```gdscript
# Core components via Inspector, dynamic components via script
func on_ready():
    # Sync scene transform to component
    if has_component(C_Transform):
        var transform_comp = get_component(C_Transform)
        transform_comp.transform = global_transform

    # Add conditional components based on game state
    if GameState.is_multiplayer:
        add_component(C_NetworkSync.new())

    if GameState.debug_mode:
        add_component(C_DebugInfo.new())
```

### Instantiating Entity Prefabs

**Basic Spawning Pattern:**

```gdscript
# Spawn system or main scene
@export var player_prefab: PackedScene
@export var enemy_prefab: PackedScene

func spawn_player(position: Vector3) -> Entity:
    var player = player_prefab.instantiate() as Entity
    player.global_position = position
    get_tree().current_scene.add_child(player)  # Add to scene
    ECS.world.add_entity(player)  # Register with ECS
    return player

func spawn_enemy(position: Vector3) -> Entity:
    var enemy = enemy_prefab.instantiate() as Entity
    enemy.global_position = position
    get_tree().current_scene.add_child(enemy)
    ECS.world.add_entity(enemy)
    return enemy
```

**Advanced Spawning with SpawnSystem:**

```gdscript
# s_spawner.gd
class_name SpawnerSystem
extends System

func query():
    return q.with_all([C_SpawnPoint])

func process(entity: Entity, delta: float):
    var spawn_point = entity.get_component(C_SpawnPoint)

    if spawn_point.should_spawn():
        var spawned = spawn_point.prefab.instantiate() as Entity
        spawned.global_position = entity.global_position
        get_tree().current_scene.add_child(spawned)
        ECS.world.add_entity(spawned)

        spawn_point.mark_spawned()
```

**Prefab Management Best Practices:**

```gdscript
# Organize prefabs in preload statements
const PLAYER_PREFAB = preload("res://entities/gameplay/e_player.tscn")
const ENEMY_PREFAB = preload("res://entities/enemies/e_enemy.tscn")
const WEAPON_PREFAB = preload("res://entities/items/e_weapon.tscn")

# Or use a prefab registry
class_name PrefabRegistry

static var prefabs = {
    "player": preload("res://entities/gameplay/e_player.tscn"),
    "enemy": preload("res://entities/enemies/e_enemy.tscn"),
    "weapon": preload("res://entities/items/e_weapon.tscn")
}

static func spawn(prefab_name: String, position: Vector3) -> Entity:
    var prefab = prefabs[prefab_name]
    var entity = prefab.instantiate() as Entity
    entity.global_position = position
    get_tree().current_scene.add_child(entity)
    ECS.world.add_entity(entity)
    return entity
```

## 🏗️ Main Scene Architecture

### Scene Structure Pattern

Organize your main scene using the proven structure pattern:

```
Main.tscn
├── World (World node)
├── DefaultSystems (Node - instantiated from default_systems.tscn)
│   ├── run-first (Node - SystemGroup)
│   │   ├── VictimInitSystem
│   │   └── EcsStorageLoad
│   ├── input (Node - SystemGroup)
│   │   ├── ItemSystem
│   │   ├── WeaponsSystem
│   │   └── PlayerControlsSystem
│   ├── gameplay (Node - SystemGroup)
│   │   ├── GearSystem
│   │   ├── DeathSystem
│   │   └── EventSystem
│   ├── physics (Node - SystemGroup)
│   │   ├── FrictionSystem
│   │   ├── CharacterBody3DSystem
│   │   └── TransformSystem
│   ├── ui (Node - SystemGroup)
│   │   └── UiVisibilitySystem
│   ├── debug (Node - SystemGroup)
│   │   └── DebugLabel3DSystem
│   └── run-last (Node - SystemGroup)
│       ├── ActionsSystem
│       └── PendingDeleteSystem
├── Level (Node3D - for level geometry)
└── Entities (Node3D - spawned entities go here)
```

### Systems Setup in Main Scene

**Scene-based Systems Setup (Recommended)**

Use scene composition to organize systems. The default_systems.tscn contains all systems organized by execution groups:

```gdscript
# main.gd - Simple main scene setup
extends Node

@onready var world: World = $World

func _ready():
    Bootstrap.bootstrap()  # Initialize any game-specific setup
    ECS.world = world
    # Systems are automatically registered via scene composition
```

**Creating a Default Systems Scene:**

1. Create `default_systems.tscn` with system groups as Node children
2. Add individual system scripts as children of each group
3. Instantiate this scene in your main scene
4. Systems are automatically discovered and registered by the World

### Processing Systems by Group

```gdscript
# main.gd - Process systems in correct order
extends Node3D

func _process(delta):
    if ECS.world:
        ECS.process(delta, "input")     # Handle input first
        ECS.process(delta, "core")      # Core logic
        ECS.process(delta, "gameplay")  # Game mechanics
        ECS.process(delta, "render")    # UI/visual updates last

func _physics_process(delta):
    if ECS.world:
        ECS.process(delta, "physics")   # Physics systems
```

## 🛠️ Common Utility Patterns

### Transform Synchronization

Common transform synchronization patterns:

```gdscript
# Sync entity transform TO component (scene → component)
static func sync_transform_to_component(entity: Entity):
    if entity.has_component(C_Transform):
        var transform_comp = entity.get_component(C_Transform)
        transform_comp.transform = entity.global_transform

# Sync component transform TO entity (component → scene)
static func sync_component_to_transform(entity: Entity):
    if entity.has_component(C_Transform):
        var transform_comp = entity.get_component(C_Transform)
        entity.global_transform = transform_comp.transform

# Common usage in entity on_ready()
func on_ready():
    sync_transform_to_component(self)  # Sync scene position to C_Transform
```

### Component Helpers

Build helpers for common component operations:

```gdscript
# Helper functions you can add to your project
static func add_health_to_entity(entity: Entity, max_health: float):
    var health = C_Health.new(max_health)
    entity.add_component(health)
    return health

static func damage_entity(entity: Entity, amount: float):
    if entity.has_component(C_Health):
        var health = entity.get_component(C_Health)
        health.current = max(0, health.current - amount)
        return health.current <= 0  # Return true if entity died
    return false
```

## 🎛️ Relationship Management Best Practices

### Limited Removal Patterns

**Use Descriptive Constants:**

```gdscript
# ✅ Good - Clear intent with constants
const WEAK_CLEANSE = 1
const MEDIUM_CLEANSE = 3
const STRONG_CLEANSE = -1  # All

# ✅ Good - Stack-based constants
const SINGLE_STACK = 1
const PARTIAL_STACKS = 3
const ALL_STACKS = -1

func cleanse_debuffs(entity: Entity, power: int):
    match power:
        1: entity.remove_relationship(Relations.any_debuff(), WEAK_CLEANSE)
        2: entity.remove_relationship(Relations.any_debuff(), MEDIUM_CLEANSE)
        3: entity.remove_relationship(Relations.any_debuff(), STRONG_CLEANSE)
```

**Validate Before Removal:**

```gdscript
# ✅ Excellent - Safe removal with validation
func safe_partial_heal(entity: Entity, heal_amount: int):
    var damage_rels = entity.get_relationships(Relations.any_damage())
    if damage_rels.is_empty():
        print("Entity has no damage to heal")
        return

    var to_heal = min(heal_amount, damage_rels.size())
    entity.remove_relationship(Relations.any_damage(), to_heal)
    print("Healed ", to_heal, " damage effects")

# ✅ Good - Helper function with built-in safety
func remove_poison_stacks(entity: Entity, stacks_to_remove: int):
    if stacks_to_remove <= 0:
        return
    entity.remove_relationship(Relations.poison_effect(), stacks_to_remove)
```

**System Integration Patterns:**

```gdscript
# ✅ Excellent - Integration with game systems
class_name StatusEffectSystem extends System

func process_cleanse_spell(caster: Entity, target: Entity, spell_power: int):
    # Calculate cleanse strength based on spell power and caster stats
    var cleanse_strength = calculate_cleanse_strength(caster, spell_power)

    # Apply graduated cleansing based on strength
    match cleanse_strength:
        1..3:   target.remove_relationship(Relations.any_debuff(), 1)
        4..6:   target.remove_relationship(Relations.any_debuff(), 2)
        7..9:   target.remove_relationship(Relations.any_debuff(), 3)
        _:      target.remove_relationship(Relations.any_debuff())  # Remove all

func process_antidote_item(user: Entity, antidote_strength: int):
    # Remove poison based on antidote quality
    user.remove_relationship(Relations.poison_effect(), antidote_strength)

    # Remove poison resistance temporarily to prevent immediate repoison
    user.add_relationship(Relations.poison_immunity(), 5.0)  # 5 second immunity

class_name InventorySystem extends System

func consume_item_stack(entity: Entity, item_type: Script, count: int):
    # Consume specific number of items from inventory
    entity.remove_relationship(
        Relationship.new(C_HasItem.new(), item_type),
        count
    )

func use_consumable(entity: Entity, item: Component, quantity: int = 1):
    # Use consumable items with quantity
    entity.remove_relationship(
        Relationship.new(C_HasItem.new(), item),
        quantity
    )
```

**Performance Optimization:**

```gdscript
# ✅ Good - Cache relationships for multiple operations
func optimize_bulk_removal(entity: Entity):
    # Cache the relationship for reuse
    var poison_rel = Relations.poison_effect()
    var damage_rel = Relations.any_damage()

    # Multiple targeted removals
    entity.remove_relationship(poison_rel, 2)      # Remove 2 poison
    entity.remove_relationship(damage_rel, 1)      # Remove 1 damage
    entity.remove_relationship(poison_rel, 1)      # Remove 1 more poison

# ✅ Excellent - Batch removal patterns
func batch_cleanup(entities: Array[Entity]):
    var cleanup_rel = Relations.temporary_effect()

    for entity in entities:
        # Remove up to 3 temporary effects from each entity
        entity.remove_relationship(cleanup_rel, 3)
```

## 🎯 Next Steps

Now that you understand best practices:

1. **Apply these patterns** in your projects
2. **Learn advanced topics** in [Core Concepts](CORE_CONCEPTS.md)
3. **Optimize performance** with [Performance Guide](PERFORMANCE_OPTIMIZATION.md)

**Need help?** [Join our Discord](https://discord.gg/eB43XU2tmn) for community discussions and support.

---

_"Good ECS code is like a well-organized toolbox - every component has its place, every system has its purpose, and everything works together smoothly."_

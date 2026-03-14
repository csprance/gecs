# GECS Core Concepts Guide

> **Deep understanding of Entity Component System architecture**

This guide explains the fundamental concepts that make GECS powerful.

## Prerequisites

- Completed [Getting Started Guide](GETTING_STARTED.md)
- Basic GDScript knowledge
- Understanding of Godot's node system

## Why ECS?

### The Problem with Traditional OOP

Traditional object-oriented approaches often bundle data and behavior together. Over time, this can become unwieldy and force complicated inheritance structures:

```gdscript
# Traditional OOP — inheritance problems
class BaseCharacter:
    # Lots of shared code

class Player extends BaseCharacter:
    # Player-specific code mixed with shared code

class Enemy extends BaseCharacter:
    # Enemy-specific code, some overlap with Player

class Boss extends Enemy:
    # Even more inheritance complexity
```

### The ECS Solution

ECS keeps data (components) separate from logic (systems), providing clear organization around three core concepts:

1. **Entities** – IDs or "slots" for your game objects
2. **Components** – Pure data objects that define state (e.g., velocity, health)
3. **Systems** – Logic that processes entities with specific components

This pattern simplifies organization, collaboration, and refactoring. Systems only act upon relevant components. Entities can freely change their makeup without breaking the overall design.

## GECS Architecture

GECS extends standard ECS with Godot-specific features:

- **Integration with Godot nodes** - Entities can be scenes, Components are resources
- **World management** - Central coordination of entities and systems
- **ECS singleton** - Global access point for queries and processing
- **Advanced queries** - Property-based filtering and relationship support
- **Relationship system** - Define complex associations between entities

## Entities

### Entity Fundamentals

Entities are the core data containers you work with in GECS. They're Godot nodes extending `Entity.gd` that hold components and relationships.

**Creating Entities in Code:**

```gdscript
# Create entity class with components
class_name MyEntity extends Entity

func define_components() -> Array:
    return [C_Transform.new(), C_Velocity.new(Vector3.UP)]

# Use the entity
var e_my_entity = MyEntity.new()
ECS.world.add_entity(e_my_entity)
```

**Entity Prefabs (Recommended):**
Since GECS integrates with Godot, create scenes with Entity root nodes and save as `.tscn` files. These "prefabs" can include child nodes for visualization while maintaining ECS data organization.

```gdscript
# e_player.gd - Entity prefab
class_name Player
extends Entity

func on_ready():
    # Sync transform from scene to component
    # Only valid when this entity's scene root is Node3D — Entity extends Node, not Node3D
    var c_trs = get_component(C_Transform) as C_Transform
    if not c_trs:
        return
    c_trs.transform = self.global_transform
```

> **Note:** `self.global_transform` is only available when the entity's scene root is `Node3D` (or `Node2D` for 2D). Entity extends `Node` — spatial properties do not exist on a plain Node scene root.

### Entity Lifecycle

Entities have a managed lifecycle:

1. **Initialization** - Entity added to world, components loaded from `component_resources`
2. **define_components()** - Called to add components via code
3. **on_ready()** - Setup initial states, sync transforms
4. **on_destroy()** - Cleanup before removal
5. **on_disable()/on_enable()** - Handle enable/disable states

> **Note:** In GECS v5.0+, entity logic should be handled by Systems, not in entity methods. Entities are pure data containers.

### Entity Naming Conventions

**GECS follows consistent naming patterns throughout the framework:**

- **Class names**: `ClassCase` representing the thing they are
- **File names**: `e_entity_name.gd` using snake_case

**Examples:**

```gdscript
# e_player.gd
class_name Player extends Entity

# e_enemy.gd
class_name Enemy extends Entity

# e_projectile.gd
class_name Projectile extends Entity

# e_pickup_item.gd
class_name PickupItem extends Entity
```

### Entity as Glue Code

Entities can serve as initialization and connection points:

```gdscript
class_name Player
extends Entity

@onready var mesh_instance = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D

func on_ready():
    # Connect scene nodes to components
    var c_sprite = get_component(C_Sprite) as C_Sprite
    if c_sprite:
        c_sprite.mesh_instance = mesh_instance

    # Sync editor-placed transform to component
    # Only valid when scene root is Node3D
    var c_trs = get_component(C_Transform) as C_Transform
    if c_trs:
        c_trs.transform = self.global_transform
```

## Components

### Component Fundamentals

Components are pure data containers - they store state but contain no game logic.

```gdscript
# c_health.gd - Example component
class_name C_Health
extends Component


## How much total health this entity has
@export var maximum := 100.0
## The current health value
@export var current := 100.0

func _init(max_health: float = 100.0):
    maximum = max_health
    current = max_health
```

### Component Design Principles

**Data Only:**

```gdscript
# Good - Pure data
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0
@export var regeneration_rate: float = 1.0
```

**No Game Logic:**

```gdscript
# Avoid - Logic in components
class_name C_Health
extends Component

@export var current: float = 100.0

func take_damage(amount: float):  # This belongs in a system!
    current -= amount
    if current <= 0:
        print("Entity died!")
```

### Component Naming Conventions

**GECS uses a consistent C\_ prefix system:**

- **Class names**: `C_ComponentName` in ClassCase
- **File names**: `c_component_name.gd` in snake_case
- **Organization**: Group by purpose in folders

**Examples:**

```gdscript
# c_health.gd
class_name C_Health extends Component

# c_transform.gd
class_name C_Transform extends Component

# c_velocity.gd
class_name C_Velocity extends Component

# c_user_input.gd
class_name C_UserInput extends Component

# c_sprite_renderer.gd
class_name C_SpriteRenderer extends Component
```

**File Organization:**

```
components/
├── gameplay/
│   ├── c_health.gd
│   ├── c_damage.gd
│   └── c_inventory.gd
├── physics/
│   ├── c_transform.gd
│   ├── c_velocity.gd
│   └── c_collision.gd
└── rendering/
    ├── c_sprite.gd
    └── c_mesh.gd
```

### Adding Components

**Via Editor (Recommended):**
Add to entity's `component_resources` array in Inspector - these auto-load when entity is added to world.

**Via define_components():**

```gdscript
# e_player.gd - Define components programmatically
class_name Player
extends Entity

func define_components() -> Array:
    return [
        C_Health.new(100),
        C_Transform.new(),
        C_Input.new()
    ]

# Via Inspector: Add to component_resources array
# Components automatically loaded when entity added to world

# Dynamic addition (less common):
var entity = Player.new()
entity.add_component(C_StatusEffect.new("poison"))
ECS.world.add_entity(entity)
```

## Systems

### System Fundamentals

Systems contain game logic and process entities based on component queries. They should be small, atomic, and focused on one responsibility.

Systems have two main parts:

- **Query** - Defines which entities to process based on components/relationships
- **Process** - The function that runs on entities

### CommandBuffer

Every System exposes a `cmd: CommandBuffer` property. Use it to queue structural changes (add/remove entities, components, relationships) that execute safely after the current iteration completes — no backwards loops required.

### System Types

**Entity Processing:**

```gdscript
class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], components: Array, delta: float):
    for entity in entities:
        var c_lifetime = entity.get_component(C_Lifetime) as C_Lifetime
        c_lifetime.lifetime -= delta

        if c_lifetime.lifetime <= 0:
            cmd.remove_entity(entity)  # Queued via CommandBuffer, safe during iteration
```

**Optimized Batch Processing with iterate():**

```gdscript
class_name VelocitySystem
extends System

func query() -> QueryBuilder:
    # Use iterate() to get component arrays for faster access
    return q.with_all([C_Velocity]).iterate([C_Velocity])

func process(entities: Array[Entity], components: Array, delta: float):
    # components[0] contains all C_Velocity components
    var velocities = components[0]

    for i in entities.size():
        # Direct array access is faster than get_component()
        var position: Vector3 = entities[i].transform.origin
        position += velocities[i].velocity * delta
        entities[i].transform.origin = position
```

### Sub-Systems

Group related logic into one system file - all subsystems use the unified signature:

```gdscript
class_name DamageSystem
extends System

func sub_systems():
    return [
        # [query, callable] - all use same unified process signature
        [
            q
            .with_all([C_Health, C_Damage]),
            damage_entities
        ],
        [
            q
            .with_all([C_Health])
            .with_none([C_Dead])
            .iterate([C_Health]),
            regenerate_health
        ]
    ]

func damage_entities(entities: Array[Entity], components: Array, delta: float):
    # Process entities with damage
    for entity in entities:
        var c_health = entity.get_component(C_Health)
        var c_damage = entity.get_component(C_Damage)
        c_health.current -= c_damage.amount
        entity.remove_component(c_damage)

        if c_health.current <= 0:
            entity.add_component(C_Dead.new())

func regenerate_health(entities: Array[Entity], components: Array, delta: float):
    # Batch process using component arrays from iterate()
    var healths = components[0]
    for i in entities.size():
        healths[i].current = min(healths[i].current + 1 * delta, healths[i].maximum)
```

### System Dependencies

Control system execution order with dependencies:

```gdscript
class_name RenderSystem
extends System

func deps() -> Dictionary[int, Array]:
    return {
        Runs.After: [MovementSystem, TransformSystem],  # Run after these
        Runs.Before: [UISystem]  # Run before this
    }
```

### System Naming Conventions

- **Class names**: `SystemNameSystem` in ClassCase (TransformSystem, PhysicsSystem)
- **File names**: `s_system_name.gd` (s_transform.gd, s_physics.gd)

### System Lifecycle

Systems follow Godot node lifecycle:

- `setup()` - Initial setup after system is added to world
- `process(entities, components, delta)` - Unified method called each frame for matching entities
- System groups for organized processing order

## Query System

### Query Builder

GECS uses a fluent API for building entity queries:

```gdscript
var target = get_player_entity()  # example: look up a specific entity
ECS.world.query
    .with_all([C_Health, C_Position])                                      # Must have all these components
    .with_any([C_Player, C_Enemy])                                         # Must have at least one of these
    .with_none([C_Dead, C_Disabled])                                       # Must not have any of these
    .with_relationship([Relationship.new(C_IsAttacking.new(), target)])    # Must have this relationship
    .without_relationship([Relationship.new(C_IsFleeing.new(), ECS.wildcard)])  # Must not have this
    .with_reverse_relationship([Relationship.new(C_ChildOf.new(), ECS.wildcard)])  # Must be target of this
    .iterate([C_Health])                                                    # Fetch for fast batch access
```

### Query Methods

**Basic Query Operations:**

```gdscript
var entities = query.execute()                    # Get matching entities
var filtered = query.matches(entity_list)         # Filter existing list
var combined = query.combine(another_query)       # Combine queries
```

### Query Types Explained

**with_all** - Entities must have ALL specified components:

```gdscript
# Find entities that can move and be damaged
q.with_all([C_Position, C_Velocity, C_Health])
```

**with_any** - Entities must have AT LEAST ONE of the components:

```gdscript
# Find players or enemies (anything controllable)
q.with_any([C_Player, C_Enemy])
```

**with_none** - Entities must NOT have any of these components:

```gdscript
# Find living entities (exclude dead/disabled)
q.with_all([C_Health]).with_none([C_Dead, C_Disabled])
```

### Component Property Queries

Query based on component data values:

```gdscript
# Find entities with low health
q.with_all([{C_Health: {"current": {"_lt": 20}}}])

# Find fast-moving entities
q.with_all([{C_Velocity: {"speed": {"_gt": 100}}}])

# Find entities with specific states
q.with_all([{C_State: {"current_state": {"_eq": "attacking"}}}])
```

**Supported Operators:**

- `_eq` - Equal to
- `_ne` - Not equal to
- `_gt` - Greater than
- `_lt` - Less than
- `_gte` - Greater than or equal
- `_lte` - Less than or equal
- `_in` - Value in list
- `_nin` - Value not in list

## Relationships

### Relationship Fundamentals

Relationships link entities together for complex associations. They consist of:

- **Source** - Entity that has the relationship
- **Relation** - Component defining the relationship type
- **Target** - Entity or type being related to

```gdscript
# Create relationship components
class_name C_Likes extends Component
class_name C_Loves extends Component
class_name C_Eats extends Component
@export var quantity: int = 1

# Create entities
var e_bob = Entity.new()
var e_alice = Entity.new()
var e_heather = Entity.new()
var e_apple = Food.new()

# Add relationships
e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))        # bob likes alice
e_alice.add_relationship(Relationship.new(C_Loves.new(), e_heather))    # alice loves heather
e_heather.add_relationship(Relationship.new(C_Likes.new(), Food))       # heather likes food (type)
e_heather.add_relationship(Relationship.new(C_Eats.new(5), e_apple))    # heather eats 5 apples
```

### Relationship Queries

**Specific Relationships:**

```gdscript
# Any entity that likes alice
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)])

# Any entity that eats 5 apples
ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)])

# Any entity that likes the Food type
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), Food)])
```

**Wildcard Relationships:**

```gdscript
# Any entity with any relation toward heather
ECS.world.query.with_relationship([Relationship.new(ECS.wildcard, e_heather)])

# Any entity that likes anything
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), ECS.wildcard)])

# Any entity with any relation to Enemy type
ECS.world.query.with_relationship([Relationship.new(ECS.wildcard, Enemy)])
```

**Reverse Relationships:**

```gdscript
# Find entities that are being liked by someone
ECS.world.query.with_reverse_relationship([Relationship.new(C_Likes.new(), ECS.wildcard)])
```

### Relationship Best Practices

**Reuse Relationship Objects:**

```gdscript
# Reuse for performance
var r_likes_apples = Relationship.new(C_Likes.new(), e_apple)
var r_attacking_players = Relationship.new(C_IsAttacking.new(), Player)

# Consider a static relationships class
class_name Relationships

static func attacking_players():
    return Relationship.new(C_IsAttacking.new(), Player)

static func chasing_anything():
    return Relationship.new(C_IsChasing.new(), ECS.wildcard)
```

## World Management

### World Lifecycle

The World is the central manager for all entities and systems:

```gdscript
# main.gd - Simple scene-based setup
extends Node

@onready var world: World = $World

func _ready():
    Bootstrap.bootstrap()  # Initialize game-specific setup
    ECS.world = world
    # Systems are automatically registered via scene composition

# Process systems by groups in order
func _process(delta):
    world.process(delta, "run-first")  # Initialization
    world.process(delta, "input")      # Input handling
    world.process(delta, "gameplay")   # Game logic
    world.process(delta, "ui")         # UI updates
    world.process(delta, "run-last")   # Cleanup

func _physics_process(delta):
    world.process(delta, "physics")    # Physics systems
    world.process(delta, "debug")      # Debug systems
```

### System Groups and Processing Order

Organize systems using scene-based composition with execution groups:

```
default_systems.tscn Structure:
├── run-first (SystemGroup)
│   ├── VictimInitSystem
│   └── EcsStorageLoad
├── input (SystemGroup)
│   ├── ItemSystem
│   ├── WeaponsSystem
│   └── PlayerControlsSystem
├── gameplay (SystemGroup)
│   ├── GearSystem
│   ├── DeathSystem
│   └── EventSystem
├── physics (SystemGroup)
│   ├── FrictionSystem
│   ├── CharacterBody3DSystem
│   └── TransformSystem
├── ui (SystemGroup)
│   └── UiVisibilitySystem
├── debug (SystemGroup)
│   └── DebugLabel3DSystem
└── run-last (SystemGroup)
    ├── ActionsSystem
    └── PendingDeleteSystem
```

**Scene Setup Benefits:**

- **Visual Organization**: See system hierarchy in Godot editor
- **Easy Reordering**: Drag systems between groups
- **Inspector Configuration**: Set system properties in editor
- **Reusable Scenes**: Share system configurations between projects

## Data-Driven Architecture

### Composition Over Inheritance

Build entities by combining simple components rather than complex inheritance:

```gdscript
# Composition approach in entity definition
class_name Player extends Entity

func define_components() -> Array:
    return [
        C_Health.new(100),
        C_Movement.new(200.0),
        C_Input.new(),
        C_Inventory.new()
    ]

# Same components reused for different entity types
enemy.add_component(C_Health.new(50))
enemy.add_component(C_Movement.new(100.0))
enemy.add_component(C_AI.new())
enemy.add_component(C_Sprite.new("enemy.png"))
```

### Modular System Design

Keep systems small and focused:

```gdscript
# Focused systems (good pattern)
class_name MovementSystem extends System
# Only handles position updates

class_name CollisionSystem extends System
# Only handles collision detection

class_name HealthSystem extends System
# Only handles health changes
```

This ensures:

- **Easier debugging** - Clear separation of concerns
- **Better reusability** - Systems work across different entity types
- **Simplified testing** - Each system can be tested independently
- **Performance optimization** - Systems can be profiled and optimized individually

## Next Steps

Now that you understand GECS's core concepts:

1. **Apply these patterns** in your own projects
2. **Experiment with relationships** for complex entity interactions
3. **Design component hierarchies** that support your game's needs
4. **Learn optimization techniques** in [Performance Guide](PERFORMANCE_OPTIMIZATION.md)
5. **Master common patterns** in [Best Practices Guide](BEST_PRACTICES.md)
6. **Persist game state** using the [Serialization Guide](SERIALIZATION.md)

## Related Documentation

- **[Getting Started](GETTING_STARTED.md)** - Build your first ECS project
- **[Serialization](SERIALIZATION.md)** - Persist entity and component state across sessions
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Make your games run fast
- **[Troubleshooting](TROUBLESHOOTING.md)** - Solve common issues

---

_"Understanding ECS is about shifting from 'what things are' to 'what things have' and 'what operates on them.' This separation of data and logic is the key to scalable game architecture."_

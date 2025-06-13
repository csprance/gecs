# GECS Core Concepts Guide

> **Deep understanding of Entity Component System architecture**

This guide explains the fundamental concepts that make GECS powerful. After reading this, you'll understand how to architect games using ECS principles and leverage GECS's unique features.

## 📋 Prerequisites

- Completed [Getting Started Guide](GETTING_STARTED.md)
- Basic GDScript knowledge
- Understanding of Godot's node system

## 🎯 Why ECS?

### The Problem with Traditional OOP

Traditional object-oriented approaches often bundle data and behavior together. Over time, this can become unwieldy and force complicated inheritance structures:

```gdscript
# ❌ Traditional OOP problems
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

## 🏗️ GECS Architecture

GECS extends standard ECS with Godot-specific features:

- **Integration with Godot nodes** - Entities can be scenes, Components are resources
- **World management** - Central coordination of entities and systems
- **ECS singleton** - Global access point for queries and processing
- **Advanced queries** - Property-based filtering and relationship support
- **Relationship system** - Define complex associations between entities

## 🎭 Entities

### Entity Fundamentals

Entities are the core data containers you work with in GECS. They're Godot nodes extending `Entity.gd` that hold components and relationships.

**Creating Entities in Code:**

```gdscript
var e_my_entity = Entity.new()
e_my_entity.add_components([C_Transform.new(), C_Velocity.new(Vector3.UP)])
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
    Utils.sync_transform(self)
```

### Entity Lifecycle

Entities have a managed lifecycle:

1. **Initialization** - Entity added to world, components loaded from `component_resources`
2. **define_components()** - Called to add components via code
3. **on_ready()** - Setup initial states, sync transforms
4. **on_update(delta)** - Called by systems each frame
5. **on_destroy()** - Cleanup before removal
6. **on_disable()/on_enable()** - Handle enable/disable states

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
    var sprite_comp = get_component(C_Sprite)
    if sprite_comp:
        sprite_comp.mesh_instance = mesh_instance

    # Sync editor-placed transform to component
    Utils.sync_transform(self)
```

## 📦 Components

### Component Fundamentals

Components are pure data containers - they store state but contain no game logic.

```gdscript
# c_health.gd - Example component
class_name C_Health
extends Component

## How much total health this entity has
@export var total := 100
## The current health value
@export var current := 100

func _init(max_health: int = 100):
    total = max_health
    current = max_health
```

### Component Design Principles

**Data Only:**

```gdscript
# ✅ Good - Pure data
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0
@export var regeneration_rate: float = 1.0
```

**No Game Logic:**

```gdscript
# ❌ Avoid - Logic in components
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

**Via Code:**

```gdscript
var health_component = C_Health.new()
health_component.max_health = 150
entity.add_component(health_component)
```

## ⚙️ Systems

### System Fundamentals

Systems contain game logic and process entities based on component queries. They should be small, atomic, and focused on one responsibility.

Systems have two main parts:

- **Query** - Defines which entities to process based on components/relationships
- **Process** - The function that runs on entities

### System Types

**Single Entity Processing:**

```gdscript
class_name LifetimeSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entity: Entity, delta: float):
    var c_lifetime = entity.get_component(C_Lifetime) as C_Lifetime
    c_lifetime.lifetime -= delta

    if c_lifetime.lifetime <= 0:
        ECS.world.remove_entity(entity)
```

**Batch Processing (More Efficient):**

```gdscript
class_name TransformSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Transform])

func process_all(entities: Array, _delta):
    var transforms = ECS.get_components(entities, C_Transform) as Array[C_Transform]
    for i in range(entities.size()):
        entities[i].global_transform = transforms[i].transform
```

### Sub-Systems

Group related logic into one system file:

```gdscript
class_name DamageSystem
extends System

func sub_systems():
    return [
        # Handles damage on entities with health
        [ECS.world.query.with_all([C_Health]).with_any([C_Damage, C_HeavyDamage]).with_none([C_Death, C_Invulnerable]), health_damage_subsys],
        # Handles damage on breakable entities
        [ECS.world.query.with_all([C_Breakable, C_Health, C_HeavyDamage]).with_none([C_Death, C_Invulnerable]), breakable_damage_subsys],
    ]

func health_damage_subsys(entity: Entity, _delta: float):
    var c_damage = entity.get_component(C_Damage) as C_Damage
    var c_health = entity.get_component(C_Health) as C_Health

    if c_damage:
        c_health.current -= c_damage.amount
        entity.remove_component(C_Damage)

        if c_health.current <= 0:
            entity.add_component(C_Death.new())

func breakable_damage_subsys(entity: Entity, delta: float):
    # Handle breakable-specific damage logic
    pass
```

### System Naming Conventions

- **Class names**: `SystemNameSystem` in ClassCase (TransformSystem, PhysicsSystem)
- **File names**: `s_system_name.gd` (s_transform.gd, s_physics.gd)

### System Lifecycle

Systems follow Godot node lifecycle:

- `on_ready()` - Initial setup after components loaded
- `process(delta)` or `process_all(entities, delta)` - Called each frame for matching entities
- System groups for organized processing order

## 🔍 Query System

### Query Builder

GECS uses a fluent API for building entity queries:

```gdscript
ECS.world.query
    .with_all([C_Health, C_Position])          # Must have all these components
    .with_any([C_Player, C_Enemy])             # Must have at least one of these
    .with_none([C_Dead, C_Disabled])           # Must not have any of these
    .with_relationship([r_attacking_player])    # Must have these relationships
    .without_relationship([r_fleeing])          # Must not have these relationships
    .with_reverse_relationship([r_parent_of])   # Must be target of these relationships
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

## 🔗 Relationships

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

## 🌍 World Management

### World Lifecycle

The World is the central manager for all entities and systems:

```gdscript
# Setup world
var world = World.new()
add_child(world)
ECS.world = world

# Add systems
world.add_system(InputSystem.new(), "input")
world.add_system(MovementSystem.new(), "physics")
world.add_system(RenderSystem.new(), "render")

# Process by groups
func _process(delta):
    ECS.process(delta, "input")
    ECS.process(delta, "physics")
    ECS.process(delta, "render")
```

### System Groups and Processing Order

Organize systems into logical groups for proper execution order:

```gdscript
# Input first
world.add_system(PlayerInputSystem.new(), "input")
world.add_system(AISystem.new(), "input")

# Then physics/logic
world.add_system(MovementSystem.new(), "physics")
world.add_system(CollisionSystem.new(), "physics")
world.add_system(HealthSystem.new(), "physics")

# Finally rendering
world.add_system(AnimationSystem.new(), "render")
world.add_system(RenderSystem.new(), "render")
world.add_system(UISystem.new(), "render")
```

## 🔄 Data-Driven Architecture

### Composition Over Inheritance

Build entities by combining simple components rather than complex inheritance:

```gdscript
# ✅ Composition approach
player.add_component(C_Health.new(100))
player.add_component(C_Movement.new(200.0))
player.add_component(C_Input.new())
player.add_component(C_Inventory.new())

# Same components reused for different entity types
enemy.add_component(C_Health.new(50))
enemy.add_component(C_Movement.new(100.0))
enemy.add_component(C_AI.new())
enemy.add_component(C_Sprite.new("enemy.png"))
```

### Modular System Design

Keep systems small and focused:

```gdscript
# ✅ Focused systems
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

## 🎯 Next Steps

Now that you understand GECS's core concepts:

1. **Apply these patterns** in your own projects
2. **Experiment with relationships** for complex entity interactions
3. **Design component hierarchies** that support your game's needs
4. **Learn optimization techniques** in [Performance Guide](PERFORMANCE_OPTIMIZATION.md)
5. **Master common patterns** in [Best Practices Guide](BEST_PRACTICES.md)

## 📚 Related Documentation

- **[Getting Started](GETTING_STARTED.md)** - Build your first ECS project
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Make your games run fast
- **[Troubleshooting](TROUBLESHOOTING.md)** - Solve common issues

---

_"Understanding ECS is about shifting from 'what things are' to 'what things have' and 'what operates on them.' This separation of data and logic is the key to scalable game architecture."_

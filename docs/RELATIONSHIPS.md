# Relationships in GECS

> **Link entities together for complex game interactions**

Relationships allow you to connect entities in meaningful ways, creating dynamic associations that go beyond simple component data. This guide shows you how to use GECS's relationship system to build complex game mechanics.

## 📋 Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Query System](CORE_CONCEPTS.md#query-system)

## 🔗 What are Relationships?

Think of **components** as the data that makes up an entity's state, and **relationships** as the links that connect entity to entity. Relationships can be simple links or carry data about the connection itself.

In GECS, relationships consist of three parts:

- **Source** - Entity that has the relationship (e.g., Bob)
- **Relation** - Component defining the relationship type (e.g., "Likes")
- **Target** - Entity or type being related to (e.g., Alice)

This creates powerful queries like "find all entities that like Alice" or "find all enemies attacking the player."

## 🎯 Core Relationship Concepts

### Relationship Components

Relationships use components to define their type and can carry data:

```gdscript
# c_likes.gd - Simple relationship
class_name C_Likes
extends Component

# c_loves.gd - Another simple relationship
class_name C_Loves
extends Component

# c_eats.gd - Relationship with data
class_name C_Eats
extends Component

@export var quantity: int = 1

func _init(qty: int = 1):
    quantity = qty
```

### Creating Relationships

```gdscript
# Create entities
var e_bob = Entity.new()
var e_alice = Entity.new()
var e_heather = Entity.new()
var e_apple = Food.new()

# Add to world
ECS.world.add_entity(e_bob)
ECS.world.add_entity(e_alice)
ECS.world.add_entity(e_heather)
ECS.world.add_entity(e_apple)

# Create relationships
e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))        # bob likes alice
e_alice.add_relationship(Relationship.new(C_Loves.new(), e_heather))    # alice loves heather
e_heather.add_relationship(Relationship.new(C_Likes.new(), Food))       # heather likes food (type)
e_heather.add_relationship(Relationship.new(C_Eats.new(5), e_apple))    # heather eats 5 apples

# Remove relationships
e_alice.remove_relationship(Relationship.new(C_Loves.new(), e_heather)) # alice no longer loves heather
```

## 🔍 Relationship Queries

### Basic Relationship Queries

**Query for Specific Relationships:**

```gdscript
# Any entity that likes alice
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)])

# Any entity that eats 5 apples
ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)])

# Any entity that likes the Food entity type
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), Food)])
```

**Exclude Relationships:**

```gdscript
# Entities with any relation toward heather that don't like bob
ECS.world.query
    .with_relationship([Relationship.new(ECS.wildcard, e_heather)])
    .without_relationship([Relationship.new(C_Likes.new(), e_bob)])
```

### Wildcard Relationships

Use `ECS.wildcard` (or `null`) to query for any relation or target:

```gdscript
# Any entity with any relation toward heather
ECS.world.query.with_relationship([Relationship.new(ECS.wildcard, e_heather)])

# Any entity that likes anything
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), ECS.wildcard)])
ECS.world.query.with_relationship([Relationship.new(C_Likes.new())])  # Omitting target = wildcard

# Any entity with any relation to Enemy entity type
ECS.world.query.with_relationship([Relationship.new(ECS.wildcard, Enemy)])
```

### Reverse Relationships

Find entities that are the **target** of relationships:

```gdscript
# Find entities that are being liked by someone
ECS.world.query.with_reverse_relationship([Relationship.new(C_Likes.new(), ECS.wildcard)])

# Find entities being attacked
ECS.world.query.with_reverse_relationship([Relationship.new(C_IsAttacking.new())])

# Find food being eaten
ECS.world.query.with_reverse_relationship([Relationship.new(C_Eats.new(), ECS.wildcard)])
```

## 🎮 Game Examples

### Combat System with Relationships

```gdscript
# Combat relationship components
class_name C_IsAttacking extends Component
@export var damage: float = 10.0

class_name C_IsTargeting extends Component
class_name C_IsAlliedWith extends Component

# Create combat entities
var player = Player.new()
var enemy1 = Enemy.new()
var enemy2 = Enemy.new()
var ally = Ally.new()

# Setup relationships
enemy1.add_relationship(Relationship.new(C_IsAttacking.new(25.0), player))
enemy2.add_relationship(Relationship.new(C_IsTargeting.new(), player))
player.add_relationship(Relationship.new(C_IsAlliedWith.new(), ally))

# Combat system queries
class_name CombatSystem extends System

func get_entities_attacking_player():
    var player = get_player_entity()
    return ECS.world.query.with_relationship([
        Relationship.new(C_IsAttacking.new(), player)
    ]).execute()

func get_player_allies():
    var player = get_player_entity()
    return ECS.world.query.with_reverse_relationship([
        Relationship.new(C_IsAlliedWith.new(), player)
    ]).execute()
```

### Hierarchical Entity System

```gdscript
# Hierarchy relationship components
class_name C_ParentOf extends Component
class_name C_ChildOf extends Component
class_name C_OwnerOf extends Component

# Create hierarchy
var parent = Entity.new()
var child1 = Entity.new()
var child2 = Entity.new()
var weapon = Weapon.new()

# Setup parent-child relationships
parent.add_relationship(Relationship.new(C_ParentOf.new(), child1))
parent.add_relationship(Relationship.new(C_ParentOf.new(), child2))
child1.add_relationship(Relationship.new(C_ChildOf.new(), parent))
child2.add_relationship(Relationship.new(C_ChildOf.new(), parent))

# Setup ownership
child1.add_relationship(Relationship.new(C_OwnerOf.new(), weapon))

# Hierarchy system queries
class_name HierarchySystem extends System

func get_children_of_entity(entity: Entity):
    return ECS.world.query.with_relationship([
        Relationship.new(C_ParentOf.new(), entity)
    ]).execute()

func get_parent_of_entity(entity: Entity):
    return ECS.world.query.with_reverse_relationship([
        Relationship.new(C_ParentOf.new(), entity)
    ]).execute()
```

## 🏗️ Relationship Best Practices

### Performance Optimization

**Reuse Relationship Objects:**

```gdscript
# ✅ Good - Reuse for performance
var r_likes_apples = Relationship.new(C_Likes.new(), e_apple)
var r_attacking_players = Relationship.new(C_IsAttacking.new(), Player)

# Use the same relationship object multiple times
entity1.add_relationship(r_attacking_players)
entity2.add_relationship(r_attacking_players)
```

**Static Relationship Factory (Recommended):**

```gdscript
# ✅ Excellent - Organized relationship management
class_name Relationships

static func attacking_players():
    return Relationship.new(C_IsAttacking.new(), Player)

static func attacking_anything():
    return Relationship.new(C_IsAttacking.new(), ECS.wildcard)

static func chasing_players():
    return Relationship.new(C_IsChasing.new(), Player)

static func interacting_with_anything():
    return Relationship.new(C_Interacting.new(), ECS.wildcard)

static func equipped_on_anything():
    return Relationship.new(C_EquippedOn.new(), ECS.wildcard)

# Usage in systems:
var attackers = ECS.world.query.with_relationship([Relationships.attacking_players()]).execute()
var chasers = ECS.world.query.with_relationship([Relationships.chasing_anything()]).execute()
```

### Naming Conventions

**Relationship Components:**

- Use descriptive names that clearly indicate the relationship
- Follow the `C_VerbNoun` pattern when possible
- Examples: `C_Likes`, `C_IsAttacking`, `C_OwnerOf`, `C_MemberOf`

**Relationship Variables:**

- Use `r_` prefix for relationship instances
- Examples: `r_likes_alice`, `r_attacking_player`, `r_parent_of_child`

## 🎯 Next Steps

Now that you understand relationships:

1. **Design relationship schemas** for your game's entities
2. **Experiment with wildcard queries** for dynamic systems
3. **Combine relationships with component queries** for powerful filtering
4. **Optimize with static relationship factories** for better performance
5. **Learn advanced patterns** in [Best Practices Guide](BEST_PRACTICES.md)

## 📚 Related Documentation

- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding the ECS fundamentals
- **[Component Queries](COMPONENT_QUERIES.md)** - Advanced property-based filtering
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Optimize relationship queries

---

_"Relationships turn a collection of entities into a living, interconnected game world where entities can react to each other in meaningful ways."_

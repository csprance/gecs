# Relationships in GECS

> **Link entities together for complex game interactions**

Relationships allow you to connect entities in meaningful ways, creating dynamic associations that go beyond simple component data. This guide shows you how to use GECS's relationship system to build complex game mechanics.

## 📋 Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Query System](CORE_CONCEPTS.md#query-system)

## 🔗 What are Relationships?

Think of **components** as the data that makes up an entity's state, and **relationships** as the links that connect entities to other entities, components, or types. Relationships can be simple links or carry data about the connection itself.

In GECS, relationships consist of three parts:

- **Source** - Entity that has the relationship (e.g., Bob)
- **Relation** - Component defining the relationship type (e.g., "Likes", "Damaged")
- **Target** - What is being related to: Entity, Component instance, or archetype (e.g., Alice, FireDamage component, Enemy class)

## 🎯 Relationship Types

GECS supports three powerful relationship patterns:

### 1. **Entity Relationships** 
Link entities to other entities:
```gdscript
# Bob likes Alice (entity to entity)
e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))
```

### 2. **Component Relationships** 
Link entities to component instances for type hierarchies:
```gdscript
# Entity has fire damage (entity to component)
entity.add_relationship(Relationship.new(C_Damaged.new(), C_FireDamage.new(50)))
```

### 3. **Archetype Relationships**
Link entities to classes/types:
```gdscript
# Heather likes all food (entity to type)
e_heather.add_relationship(Relationship.new(C_Likes.new(), Food))
```

This creates powerful queries like "find all entities that like Alice", "find all entities with fire damage", or "find all entities damaged by anything".

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

### Component-Based Relationships

Link entities to **component instances** for powerful type hierarchies and data systems:

```gdscript
# Damage system using component targets
class_name C_Damaged extends Component
class_name C_FireDamage extends Component
    @export var amount: int = 0
    func _init(dmg: int = 0): amount = dmg

class_name C_PoisonDamage extends Component
    @export var amount: int = 0
    func _init(dmg: int = 0): amount = dmg

# Entity has multiple damage types
entity.add_relationship(Relationship.new(C_Damaged.new(), C_FireDamage.new(50)))
entity.add_relationship(Relationship.new(C_Damaged.new(), C_PoisonDamage.new(25)))

# Query for entities with any damage type (wildcard)
var damaged_entities = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), null)
]).execute()

# Query for entities with specific fire damage amount
var fire_damaged_50 = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), C_FireDamage.new(50))
]).execute()

# Query for entities with any fire damage (archetype)
var any_fire_damaged = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), C_FireDamage)
]).execute()
```

### Weak vs Strong Matching

Control how precisely relationships are matched:

```gdscript
# Strong matching (default) - exact component data match
entity.has_relationship(Relationship.new(C_Damaged.new(), C_FireDamage.new(50)), false)

# Weak matching - matches by component type, ignores data values
entity.has_relationship(Relationship.new(C_Damaged.new(), C_FireDamage.new(999)), true)

# Get actual damage data using weak matching
var damage_rel = entity.get_relationship(
    Relationship.new(C_Damaged.new(), C_FireDamage.new(999)), true, true
)
if damage_rel:
    print("Fire damage amount: ", damage_rel.target.amount)  # Actual damage value
```

**When to Use Each:**
- **Strong Matching**: Find entities with exact damage amounts, specific buff values
- **Weak Matching**: Find entities with "any fire damage", "any buff of this type"

**Important: Query System Behavior**
- **World queries always use strong matching**: `ECS.world.query.with_relationship()` uses exact component data matching
- **Entity queries support both**: Use `entity.has_relationship(rel, weak)` to control matching mode
- **For flexible type-based queries**: Combine world queries with manual filtering or use entity-level weak matching

**Advanced: Custom Matching with equals() Override**

For precise control over relationship matching, override the `equals()` method in your components:

```gdscript
class_name C_DamageRange extends Component
    @export var min_damage: float = 0.0
    @export var max_damage: float = 100.0
    @export var damage_type: String = "physical"
    
    func _init(min_dmg: float = 0.0, max_dmg: float = 100.0, type: String = "physical"):
        min_damage = min_dmg
        max_damage = max_dmg
        damage_type = type
    
    # Custom equals - only match damage type, ignore damage values
    func equals(other: Component) -> bool:
        if not other is C_DamageRange:
            return false
        return damage_type == other.damage_type

# Usage example:
entity.add_relationship(Relationship.new(C_HasEffect.new(), C_DamageRange.new(50, 100, "fire")))

# This will match any fire damage regardless of amount due to custom equals()
var has_fire_damage = entity.has_relationship(
    Relationship.new(C_HasEffect.new(), C_DamageRange.new(0, 0, "fire")), false
)
```

This allows you to create sophisticated matching rules while still using strong matching in queries.

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

### Status Effect System with Component Relationships

This example shows how to build a flexible status effect system using component-based relationships:

```gdscript
# Status effect marker
class_name C_HasEffect extends Component

# Damage type components
class_name C_FireDamage extends Component
    @export var damage_per_second: float = 10.0
    @export var duration: float = 5.0
    func _init(dps: float = 10.0, dur: float = 5.0):
        damage_per_second = dps
        duration = dur

class_name C_PoisonDamage extends Component
    @export var damage_per_tick: float = 5.0
    @export var ticks_remaining: int = 10
    func _init(dpt: float = 5.0, ticks: int = 10):
        damage_per_tick = dpt
        ticks_remaining = ticks

# Buff type components  
class_name C_SpeedBuff extends Component
    @export var multiplier: float = 1.5
    @export var duration: float = 10.0
    func _init(mult: float = 1.5, dur: float = 10.0):
        multiplier = mult
        duration = dur

class_name C_StrengthBuff extends Component
    @export var bonus_damage: float = 25.0
    @export var duration: float = 8.0
    func _init(bonus: float = 25.0, dur: float = 8.0):
        bonus_damage = bonus
        duration = dur

# Apply various effects to entities
func apply_status_effects():
    # Player gets fire damage and speed buff
    player.add_relationship(Relationship.new(C_HasEffect.new(), C_FireDamage.new(15.0, 8.0)))
    player.add_relationship(Relationship.new(C_HasEffect.new(), C_SpeedBuff.new(2.0, 12.0)))
    
    # Enemy gets poison and strength buff
    enemy.add_relationship(Relationship.new(C_HasEffect.new(), C_PoisonDamage.new(8.0, 15)))
    enemy.add_relationship(Relationship.new(C_HasEffect.new(), C_StrengthBuff.new(30.0, 10.0)))

# Status effect processing system
class_name StatusEffectSystem extends System

func query():
    # Get all entities with any status effects
    return ECS.world.query.with_relationship([Relationship.new(C_HasEffect.new(), null)])

func process_fire_damage():
    # Find entities with any fire damage effect
    var fire_damaged = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_FireDamage)
    ]).execute()
    
    for entity in fire_damaged:
        # Use weak matching to get the actual fire damage data
        var fire_rel = entity.get_relationship(
            Relationship.new(C_HasEffect.new(), C_FireDamage.new()), true, true
        )
        var fire_damage = fire_rel.target as C_FireDamage
        
        # Apply damage
        apply_damage(entity, fire_damage.damage_per_second * delta)
        
        # Reduce duration
        fire_damage.duration -= delta
        if fire_damage.duration <= 0:
            entity.remove_relationship(fire_rel)

func process_speed_buffs():
    # Find entities with speed buffs using archetype matching
    var speed_buffed = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_SpeedBuff)
    ]).execute()
    
    for entity in speed_buffed:
        # Get actual speed buff data
        var speed_rel = entity.get_relationship(
            Relationship.new(C_HasEffect.new(), C_SpeedBuff.new()), true, true
        )
        var speed_buff = speed_rel.target as C_SpeedBuff
        
        # Apply speed modification
        apply_speed_modifier(entity, speed_buff.multiplier)
        
        # Handle duration
        speed_buff.duration -= delta
        if speed_buff.duration <= 0:
            entity.remove_relationship(speed_rel)

func remove_all_effects_from_entity(entity: Entity):
    # Remove all status effects using wildcard
    var all_effects = entity.get_relationships(Relationship.new(C_HasEffect.new(), null))
    for effect_rel in all_effects:
        entity.remove_relationship(effect_rel)

func get_entities_with_damage_effects():
    # Get entities with any damage type effect (fire or poison)
    var fire_damaged = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_FireDamage)
    ]).execute()
    
    var poison_damaged = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_PoisonDamage)
    ]).execute()
    
    # Combine results
    var all_damaged = {}
    for entity in fire_damaged:
        all_damaged[entity] = true
    for entity in poison_damaged:
        all_damaged[entity] = true
        
    return all_damaged.keys()
```

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

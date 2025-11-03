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

# Remove with limits (NEW)
e_player.remove_relationship(Relationship.new(C_Poison.new(), null), 1)  # Remove only 1 poison stack
e_enemy.remove_relationship(Relationship.new(C_Buff.new(), null), 3)     # Remove up to 3 buffs
e_hero.remove_relationship(Relationship.new(C_Damage.new(), null), -1)   # Remove all damage (default)
```

## 🔍 Relationship Queries

### Basic Relationship Queries

**Query for Specific Relationships:**

```gdscript
# Any entity that likes alice (type matching)
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)])

# Any entity that eats apples (type matching)
ECS.world.query.with_relationship([Relationship.new(C_Eats.new(), e_apple)])

# Any entity that eats 5 or more apples (component query)
ECS.world.query.with_relationship([
    Relationship.new({C_Eats: {'quantity': {"_gte": 5}}}, e_apple)
])

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

# Query for entities with fire damage >= 50 using component query
var high_fire_damaged = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), {C_FireDamage: {"amount": {"_gte": 50}}})
]).execute()

# Query for entities with any fire damage (type matching)
var any_fire_damaged = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), C_FireDamage)
]).execute()
```

### Matching Modes

GECS relationships support two matching modes:

#### Type Matching (Default)
Matches relationships by component type, ignoring property values:

```gdscript
# Matches any C_Damaged relationship regardless of amount
entity.has_relationship(Relationship.new(C_Damaged.new(), target))

# Matches any fire damage effect by type
entity.has_relationship(Relationship.new(C_Damaged.new(), C_FireDamage.new()))

# Query for any entities with fire damage (type matching)
var any_fire_damaged = ECS.world.query.with_relationship([
    Relationship.new(C_Damaged.new(), C_FireDamage)
]).execute()
```

#### Component Query Matching
Match relationships by specific property criteria using dictionaries:

```gdscript
# Match C_Damaged relationships where amount >= 50
var high_damage = ECS.world.query.with_relationship([
    Relationship.new({C_Damaged: {'amount': {"_gte": 50}}}, target)
]).execute()

# Match fire damage with specific duration
var lasting_fire = ECS.world.query.with_relationship([
    Relationship.new(
        C_Damaged.new(),
        {C_FireDamage: {'duration': {"_gt": 5.0}}}
    )
]).execute()

# Match both relation AND target with queries
var strong_buffs = ECS.world.query.with_relationship([
    Relationship.new(
        {C_Buff: {'duration': {"_gt": 10}}},
        {C_Player: {'level': {"_gte": 5}}}
    )
]).execute()
```

**When to Use Each:**
- **Type Matching**: Find entities with "any fire damage", "any buff of this type"
- **Component Queries**: Find entities with exact damage amounts, specific buff durations, or property criteria

### Component Queries in Relationships

Query relationships by specific property values using dictionaries:

```gdscript
# Query by relation property
var heavy_eaters = ECS.world.query.with_relationship([
    Relationship.new({C_Eats: {'amount': {"_gte": 5}}}, e_apple)
]).execute()

# Query by target component property
var high_hp_targets = ECS.world.query.with_relationship([
    Relationship.new(C_Targeting.new(), {C_Health: {'hp': {"_gte": 100}}})
]).execute()

# Query operators: _eq, _ne, _gt, _lt, _gte, _lte, _in, _nin, func
var special_damage = ECS.world.query.with_relationship([
    Relationship.new(
        {C_Damage: {'type': {"_in": ["fire", "ice"]}}},
        null
    )
]).execute()

# Complex multi-property queries
var critical_effects = ECS.world.query.with_relationship([
    Relationship.new(
        {C_Effect: {
            'damage': {"_gt": 20},
            'duration': {"_gte": 10.0},
            'type': {"_eq": "critical"}
        }},
        null
    )
]).execute()
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

## 🎛️ Limited Relationship Removal

> **Control exactly how many relationships to remove for fine-grained management**

The `remove_relationship()` method now supports a **limit parameter** that allows you to control exactly how many matching relationships to remove. This is essential for stack-based systems, partial healing, inventory management, and fine-grained effect control.

### Basic Syntax

```gdscript
entity.remove_relationship(relationship, limit)
```

**Limit Values:**
- `limit = -1` (default): Remove **all** matching relationships
- `limit = 0`: Remove **no** relationships (useful for testing/validation)
- `limit = 1`: Remove **one** matching relationship
- `limit > 1`: Remove **up to that many** matching relationships

### Core Use Cases

#### 1. **Stack-Based Systems**

Perfect for buff/debuff stacks, damage over time effects, or any system where effects can stack:

```gdscript
# Poison stack system
class_name C_PoisonStack extends Component
@export var damage_per_tick: float = 5.0

# Apply poison stacks
entity.add_relationship(Relationship.new(C_PoisonStack.new(3.0), null))
entity.add_relationship(Relationship.new(C_PoisonStack.new(3.0), null))
entity.add_relationship(Relationship.new(C_PoisonStack.new(3.0), null))
entity.add_relationship(Relationship.new(C_PoisonStack.new(3.0), null))  # 4 poison stacks

# Antidote removes 2 poison stacks
entity.remove_relationship(Relationship.new(C_PoisonStack.new(), null), 2)
# Entity now has 2 poison stacks remaining

# Strong antidote removes all poison
entity.remove_relationship(Relationship.new(C_PoisonStack.new(), null))  # Default: remove all
```

#### 2. **Partial Healing Systems**

Control damage removal for gradual healing or partial repair:

```gdscript
# Multiple damage sources on entity
entity.add_relationship(Relationship.new(C_Damage.new(), C_FireDamage.new(25)))
entity.add_relationship(Relationship.new(C_Damage.new(), C_FireDamage.new(15)))
entity.add_relationship(Relationship.new(C_Damage.new(), C_SlashDamage.new(30)))
entity.add_relationship(Relationship.new(C_Damage.new(), C_PoisonDamage.new(10)))

# Healing potion removes one damage source
entity.remove_relationship(Relationship.new(C_Damage.new(), null), 1)

# Fire resistance removes only fire damage (up to 2 sources)
entity.remove_relationship(Relationship.new(C_Damage.new(), C_FireDamage), 2)

# Full heal removes all damage
entity.remove_relationship(Relationship.new(C_Damage.new(), null))  # All damage gone
```

#### 3. **Inventory and Resource Management**

Handle item stacks, resource consumption, and crafting materials:

```gdscript
# Item stack system
class_name C_HasItem extends Component
class_name C_HealthPotion extends Component
@export var healing_amount: int = 50

# Player has multiple health potions
entity.add_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion.new(50)))
entity.add_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion.new(50)))
entity.add_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion.new(50)))
entity.add_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion.new(50)))

# Use one health potion
entity.remove_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion), 1)

# Vendor buys 2 health potions
entity.remove_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion), 2)

# Drop all potions
entity.remove_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion))
```

#### 4. **Buff/Debuff Management**

Fine-grained control over temporary effects:

```gdscript
# Multiple speed buffs from different sources
entity.add_relationship(Relationship.new(C_Buff.new(), C_SpeedBuff.new(1.2, 10.0)))  # Boots
entity.add_relationship(Relationship.new(C_Buff.new(), C_SpeedBuff.new(1.5, 5.0)))   # Spell
entity.add_relationship(Relationship.new(C_Buff.new(), C_SpeedBuff.new(1.1, 30.0)))  # Passive

# Dispel magic removes one buff
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 1)

# Mass dispel removes up to 3 buffs
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 3)

# Purge removes all buffs
entity.remove_relationship(Relationship.new(C_Buff.new(), null))
```

### Advanced Examples

#### Component Query + Limit Combination

Combine component queries with limits for precise control:

```gdscript
# Remove only high-damage effects (damage > 20), up to 2 of them
entity.remove_relationship(
    Relationship.new({C_Damage: {"amount": {"_gt": 20}}}, null),
    2
)

# Remove poison effects with duration < 5 seconds, limit to 1
entity.remove_relationship(
    Relationship.new({C_PoisonEffect: {"duration": {"_lt": 5.0}}}, null),
    1
)

# Remove fire damage with specific amount range, up to 3 instances
entity.remove_relationship(
    Relationship.new(
        C_Damage.new(),
        {C_FireDamage: {"amount": {"_gte": 10, "_lte": 50}}}
    ),
    3
)

# Remove all fire damage regardless of amount (no limit, type matching)
entity.remove_relationship(
    Relationship.new(C_Damage.new(), C_FireDamage),
    -1
)

# Remove buffs with specific multiplier, limit to 2
entity.remove_relationship(
    Relationship.new({C_Buff: {"multiplier": {"_gte": 1.5}}}, null),
    2
)
```

#### System Integration

Integrate limited removal into your game systems:

```gdscript
class_name HealingSystem extends System

func heal_entity(entity: Entity, healing_power: int):
    """Remove damage based on healing power"""
    if healing_power <= 0:
        return
    
    # Partial healing - remove damage effects based on healing power
    var damage_to_remove = min(healing_power, get_damage_count(entity))
    entity.remove_relationship(Relationship.new(C_Damage.new(), null), damage_to_remove)
    
    print("Healed ", damage_to_remove, " damage effects")

func get_damage_count(entity: Entity) -> int:
    return entity.get_relationships(Relationship.new(C_Damage.new(), null)).size()

class_name CleanseSystem extends System

func cleanse_entity(entity: Entity, cleanse_strength: int):
    """Remove debuffs based on cleanse strength"""
    match cleanse_strength:
        1:  # Weak cleanse
            entity.remove_relationship(Relationship.new(C_Debuff.new(), null), 1)
        2:  # Medium cleanse  
            entity.remove_relationship(Relationship.new(C_Debuff.new(), null), 3)
        3:  # Strong cleanse
            entity.remove_relationship(Relationship.new(C_Debuff.new(), null))  # All debuffs

class_name CraftingSystem extends System

func consume_materials(entity: Entity, recipe: Dictionary):
    """Consume specific amounts of crafting materials"""
    for material_type in recipe:
        var amount_needed = recipe[material_type]
        entity.remove_relationship(
            Relationship.new(C_HasMaterial.new(), material_type), 
            amount_needed
        )
```

### Error Handling and Validation

The limit parameter provides built-in safeguards:

```gdscript
# Safe operations - won't crash if fewer relationships exist than requested
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 100)  # Removes all available, won't error

# Validation operations
entity.remove_relationship(Relationship.new(C_Damage.new(), null), 0)  # Removes nothing - useful for testing

# Check before removal
var damage_count = entity.get_relationships(Relationship.new(C_Damage.new(), null)).size()
if damage_count > 0:
    entity.remove_relationship(Relationship.new(C_Damage.new(), null), min(3, damage_count))
```

### Performance Considerations

Limited removal is optimized for efficiency:

```gdscript
# ✅ Efficient - stops searching after finding enough matches
entity.remove_relationship(Relationship.new(C_Effect.new(), null), 5)

# ✅ Still efficient - reuses the same removal logic
entity.remove_relationship(Relationship.new(C_Effect.new(), null), -1)  # Remove all

# ✅ Most efficient for single removals
entity.remove_relationship(Relationship.new(C_SpecificEffect.new(exact_data), target), 1)
```

### Integration with Multiple Relationships

Works seamlessly with `remove_relationships()` for batch operations:

```gdscript
# Apply limit to multiple relationship types
var relationships_to_remove = [
    Relationship.new(C_Buff.new(), null),
    Relationship.new(C_Debuff.new(), null),
    Relationship.new(C_TemporaryEffect.new(), null)
]

# Remove up to 2 of each type
entity.remove_relationships(relationships_to_remove, 2)
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
    # Find entities with any fire damage effect (type matching)
    var fire_damaged = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_FireDamage)
    ]).execute()

    for entity in fire_damaged:
        # Get the actual fire damage data using type matching
        var fire_rel = entity.get_relationship(
            Relationship.new(C_HasEffect.new(), C_FireDamage.new())
        )
        var fire_damage = fire_rel.target as C_FireDamage

        # Apply damage
        apply_damage(entity, fire_damage.damage_per_second * delta)

        # Reduce duration
        fire_damage.duration -= delta
        if fire_damage.duration <= 0:
            entity.remove_relationship(fire_rel)

func process_speed_buffs():
    # Find entities with speed buffs using type matching
    var speed_buffed = ECS.world.query.with_relationship([
        Relationship.new(C_HasEffect.new(), C_SpeedBuff)
    ]).execute()

    for entity in speed_buffed:
        # Get actual speed buff data using type matching
        var speed_rel = entity.get_relationship(
            Relationship.new(C_HasEffect.new(), C_SpeedBuff.new())
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
    entity.remove_relationship(Relationship.new(C_HasEffect.new(), null))

func remove_some_effects_from_entity(entity: Entity, count: int):
    # Remove a specific number of status effects using limit parameter
    entity.remove_relationship(Relationship.new(C_HasEffect.new(), null), count)

func cleanse_one_debuff(entity: Entity):
    # Remove just one debuff (useful for cleanse spells)
    entity.remove_relationship(Relationship.new(C_Debuff.new(), null), 1)

func dispel_magic(entity: Entity, power: int):
    # Dispel magic spell removes buffs based on power level
    match power:
        1: entity.remove_relationship(Relationship.new(C_HasEffect.new(), C_SpeedBuff), 1)    # Weak dispel - 1 speed buff
        2: entity.remove_relationship(Relationship.new(C_HasEffect.new(), null), 2)          # Medium dispel - 2 any effects  
        3: entity.remove_relationship(Relationship.new(C_HasEffect.new(), null))             # Strong dispel - all effects

func antidote_healing(entity: Entity, antidote_strength: int):
    # Antidote removes poison effects based on strength
    entity.remove_relationship(Relationship.new(C_HasEffect.new(), C_PoisonDamage), antidote_strength)

func partial_fire_immunity(entity: Entity):
    # Fire immunity spell removes up to 3 fire damage effects
    entity.remove_relationship(Relationship.new(C_HasEffect.new(), C_FireDamage), 3)

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

func get_high_damage_attackers():
    var player = get_player_entity()
    # Find entities attacking player with damage >= 20
    return ECS.world.query.with_relationship([
        Relationship.new({C_IsAttacking: {'damage': {"_gte": 20.0}}}, player)
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

static func any_status_effect():
    return Relationship.new(C_HasEffect.new(), null)

static func any_damage_effect():
    return Relationship.new(C_Damage.new(), null)

static func any_buff():
    return Relationship.new(C_Buff.new(), null)

# Usage in systems:
var attackers = ECS.world.query.with_relationship([Relationships.attacking_players()]).execute()
var chasers = ECS.world.query.with_relationship([Relationships.chasing_anything()]).execute()

# Usage with limits:
entity.remove_relationship(Relationships.any_status_effect(), 1)  # Remove one effect
entity.remove_relationship(Relationships.any_damage_effect(), 3)  # Remove up to 3 damage effects
entity.remove_relationship(Relationships.any_buff())              # Remove all buffs
```

**Limited Removal Best Practices:**

```gdscript
# ✅ Good - Clear intent with descriptive variables
var WEAK_CLEANSE = 1
var MEDIUM_CLEANSE = 3
var STRONG_CLEANSE = -1  # All

entity.remove_relationship(Relationships.any_debuff(), WEAK_CLEANSE)

# ✅ Good - Helper functions for common operations
func remove_one_poison(entity: Entity):
    entity.remove_relationship(Relationship.new(C_Poison.new(), null), 1)

func remove_all_fire_damage(entity: Entity):
    entity.remove_relationship(Relationship.new(C_Damage.new(), C_FireDamage))

func partial_heal(entity: Entity, healing_power: int):
    entity.remove_relationship(Relationship.new(C_Damage.new(), null), healing_power)

# ✅ Excellent - Validation before removal
func safe_remove_effects(entity: Entity, count: int):
    var current_effects = entity.get_relationships(Relationship.new(C_Effect.new(), null)).size()
    var to_remove = min(count, current_effects)
    if to_remove > 0:
        entity.remove_relationship(Relationship.new(C_Effect.new(), null), to_remove)
        print("Removed ", to_remove, " effects")
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

Now that you understand relationships, component queries, and limited removal:

1. **Design relationship schemas** for your game's entities
2. **Experiment with wildcard queries** for dynamic systems
3. **Use component queries** to filter relationships by property criteria
4. **Implement limited removal** for stack-based and graduated systems
5. **Combine type matching with component queries** for flexible filtering
6. **Optimize with static relationship factories** for better performance
7. **Use limit parameters** for fine-grained control in healing, crafting, and effect systems
8. **Learn advanced patterns** in [Best Practices Guide](BEST_PRACTICES.md)

**Quick Start Checklist for Component Queries:**
- ✅ Try basic component query: `Relationship.new({C_Damage: {'amount': {"_gt": 10}}}, null)`
- ✅ Use query operators: `_eq`, `_ne`, `_gt`, `_lt`, `_gte`, `_lte`, `_in`, `_nin`
- ✅ Query both relation and target properties
- ✅ Combine queries with wildcards for flexible filtering
- ✅ Use type matching for "any component of this type" queries

**Quick Start Checklist for Limited Removal:**
- ✅ Try basic limit syntax: `entity.remove_relationship(rel, 1)`
- ✅ Build a simple stack system (buffs, debuffs, or damage)
- ✅ Create helper functions for common removal patterns
- ✅ Integrate limits into your game systems (healing, cleansing, etc.)
- ✅ Test edge cases (limit > available relationships)
- ✅ Combine component queries with limits for precise control

## 📚 Related Documentation

- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding the ECS fundamentals
- **[Component Queries](COMPONENT_QUERIES.md)** - Advanced property-based filtering
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Optimize relationship queries

---

_"Relationships turn a collection of entities into a living, interconnected game world where entities can react to each other in meaningful ways."_

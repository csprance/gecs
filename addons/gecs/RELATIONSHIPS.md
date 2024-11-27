# Relationships
> Link entities together

## What are relationships in GECS?
In GECS relationships consist of two parts, a component and an entity. The component represents the relationship, the entity specifies the entity it has a relationship with.

Relationships allow you to easily associate things together and simplify querying for data by being able to use relationships as a way to search in addition to normal query methods.

## Definitions

| Name         | Description |
|--------------|-------------|
| Relationship | A relationship that can be added and removed |
| Pair         | Relationship with two elements |
| Relation     | The first element of a pair |
| Target       | The second element of a pair |
| Source       | Entity which a relationship is added |

```gdscript
# Create a new relationship (Shortened to Rel)
Rel.new(C_Relation, E_Target)
```

```gdscript
# c_likes.gd
class_name C_Likes
extends Component
# c_loves.gd
class_name C_Loves
extends Component
# c_eats.gd
class_name C_Eats
extends Component

@export var quantity :int = 1

func _init(qty: int = quantity):
    quantity = qty
# e_food.gd
class_name Food
extends Entity

# example.gd

# Create our entities
var e_bob = Entity.new()
var e_alice = Entity.new()
var e_heather = Entity.new()
var e_apple = Food.new()

# Create our relationships
# bob likes alice
e_bob.add_relationship(Rel.new(C_Likes, e_alice))
# alice loves heather
e_alice.add_relationship(Rel.new(C_Loves, e_heather))
# heather likes food
e_heather.add_relationship(Rel.new(C_Likes, Food))
# heather eats 5 apples
e_heather.add_relationship(Rel.new(C_Eats.new(5), e_apple))
# alice no longer loves heather
alice.remove_relationship(Rel.new(C_Loves, e_heather))
```

### Relationship Queries

We can then query for these relationships in the following ways
- Relation: A component type, or an instanced component with data
- Target: Either a reference to an entity, or the entity archetype.

```
# Any entity that likes alice
ECS.world.query.with_relationship([Rel.new(C_Likes, e_alice)])
# Any entity with any relations toward heather
ECS.world.query.with_relationship([Rel.new(ECS.WildCard.Relation, e_heather)])
# Any entity with any relations toward heather that don't have any relationships with bob
ECS.world.query.with_relationship([Rel.new(ECS.WildCard.Relation, e_heather)]).without_relationship([Rel.new(C_Likes, e_bob)])
# Any entity that eats 5 apples
ECS.world.query.with_relationship([Rel.new(C_Eats.new(5), e_apple)])
# any entity that likes the food entity archetype
ECS.world.query.with_relationship([Rel.new(C_Likes, Food)])
# Any entity that likes anything
ECS.world.query.with_relationship([Rel.new(C_Likes, ECS.WildCard.Target)])
ECS.world.query.with_relationship([Rel.new(C_Likes)])
# Any entity with any relation to Enemy Entity archetype
ECS.world.query.with_relationship([Rel.new(ECS.WildCard.Relation, Enemy)])
```

### Relationship Wildcards
When querying for relationship pairs, it can be helpful to find all entities for a given relation or target. To accomplish this, we can use wildcard expressions.

There are two:
- ECS.WildCard.Relation
- ECS.WildCard.Target

Omitting the target in a a pair implicitly indicates ECS.WildCard.Target
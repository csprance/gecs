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
# Create a new relationship
Relationship.new(C_Relation, E_Target)
```
```gdscript
# c_likes.gd
class_name C_Likes
extends Component
```
```gdscript
# c_loves.gd
class_name C_Loves
extends Component
```
```gdscript
# c_eats.gd
class_name C_Eats
extends Component

@export var quantity :int = 1

func _init(qty: int = quantity):
    quantity = qty
```
```gdscript
# e_food.gd
class_name Food
extends Entity
```
```gdscript
# example.gd
# Create our entities
var e_bob = Person.new()
var e_alice = Person.new()
var e_heather = Person.new()
var e_apple = Food.new()

world.add_entity(e_bob)
world.add_entity(e_alice)
world.add_entity(e_heather)
world.add_entity(e_apple)

# Create our relationships
# bob likes alice
e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))
# alice loves heather
e_alice.add_relationship(Relationship.new(C_Loves.new(), e_heather))
# heather likes food
e_heather.add_relationship(Relationship.new(C_Likes.new(), Food))
# heather eats 5 apples
e_heather.add_relationship(Relationship.new(C_Eats.new(5), e_apple))
# Alice attacks all food
e_alice.add_relationship(Relationship.new(C_IsAttacking.new(), Food))
# bob cries in front of everyone
e_bob.add_relationship(Relationship.new(C_IsCryingInFrontOf.new(), Person))
```

### Relationship Queries

We can then query for these relationships in the following ways
- Relation: A component type, or an instanced component with data
- Target: Either a reference to an entity, or the entity archetype.

```gdscript
# Any entity that likes alice
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)]).execute()
# Any entity with any relations toward heather
ECS.world.query.with_relationship([Relationship.new(null, e_heather)]).execute()
# Any entity with any relations toward heather that don't have any relationships with bob
ECS.world.query.with_relationship([Rel.new(ECS.WildCard.Relation, e_heather)]).without_relationship([Rel.new(C_Likes, e_bob)])
# Any entity that eats 5 apples
ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)]).execute()
# any entity that likes the food entity archetype
ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)]).execute()
# Any entity that likes anything
ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), null)]).execute()
ECS.world.query.with_relationship([Relationship.new(C_Likes.new())]).execute()
# Any entity with any relation to Food archetype
ECS.world.query.with_relationship([Relationship.new(null, Food)]).execute()
# Food being attacked
ECS.world.query.with_reverse_relationship([Relationship.new(C_IsAttacking.new())]).execute()
```

### Relationship Wildcards
When querying for relationship pairs, it can be helpful to find all entities for a given relation or target. To accomplish this, we can use a wildcard expression:  `ECS.wildcard`

There are two places it can be used in a Relationship and not in both places at once:
- The Relation
- The Target

Omitting the target in a a pair implicitly indicates `ECS.wildcard`

You can also just use null in place of ECS.wildcard (Since that's all it is anyways)

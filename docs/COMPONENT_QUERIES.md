# Component Queries in GECS

> **Advanced property-based entity filtering**

Component Queries provide a powerful way to filter entities not just based on the presence of components but also on the data within those components. This allows for precise, data-driven entity selection in your game systems.

## 📋 Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Basic Queries](CORE_CONCEPTS.md#query-system)

## 🎯 Introduction

In standard ECS queries, you filter entities by which components they have or don't have. Component Queries take this further by letting you filter based on the **values** inside those components.

Instead of just asking "which entities have a HealthComponent?", you can ask "which entities have a HealthComponent with current health less than 20?"

## Using Component Queries with `QueryBuilder`

The `QueryBuilder` class allows you to construct queries to retrieve entities that match certain criteria. With component queries, you can specify conditions on component properties within `with_all` and `with_any` methods.

### Syntax

A component query is a `Dictionary` that maps a component class to a query `Dictionary` specifying property conditions.

```gdscript
{ ComponentClass: { property_name: { operator: value } } }
```

### Supported Operators

- `_eq`: Equal to
- `_ne`: Not equal to
- `_gt`: Greater than
- `_lt`: Less than
- `_gte`: Greater than or equal to
- `_lte`: Less than or equal to
- `_in`: Value is in a list
- `_nin`: Value is not in a list

### Examples

#### 1. Basic Component Query

Retrieve entities where `C_TestC.value` is equal to `25`.

```gdscript
var result = QueryBuilder.new(world).with_all([
    { C_TestC: { "value": { "_eq": 25 } } }
]).execute()
```

#### 2. Multiple Conditions on a Single Component

Retrieve entities where `C_TestC.value` is between `20` and `25`.

```gdscript
var result = QueryBuilder.new(world).with_all([
    { C_TestC: { "value": { "_gte": 20, "_lte": 25 } } }
]).execute()
```

#### 3. Combining Component Queries and Regular Components

Retrieve entities that have `C_TestD` component and `C_TestC.value` greater than `20`.

```gdscript
var result = QueryBuilder.new(world).with_all([
    C_TestD,
    { C_TestC: { "value": { "_gt": 20 } } }
]).execute()
```

#### 4. Using `with_any` with Component Queries

Retrieve entities where `C_TestC.value` is less than `15` **or** `C_TestD.points` is greater than or equal to `100`.

```gdscript
var result = QueryBuilder.new(world).with_any([
    { C_TestC: { "value": { "_lt": 15 } } },
    { C_TestD: { "points": { "_gte": 100 } } }
]).execute()
```

#### 5. Using `_in` and `_nin` Operators

Retrieve entities where `C_TestC.value` is either `10` or `25`.

```gdscript
var result = QueryBuilder.new(world).with_all([
    { C_TestC: { "value": { "_in": [10, 25] } } }
]).execute()
```

#### 6. Complex Queries

Retrieve entities where:

- `C_TestC.value` is greater than or equal to `25`, and
- `C_TestD.points` is greater than `75` **or** less than `30`, and
- Excludes entities with `C_TestE` component.

```gdscript
var result = QueryBuilder.new(world).with_all([
    { C_TestC: { "value": { "_gte": 25 } } }
]).with_any([
    { C_TestD: { "points": { "_gt": 75 } } },
    { C_TestD: { "points": { "_lt": 30 } } }
]).with_none([C_TestE]).execute()
```

## Important Notes

- **Component Queries with `with_none`**: Component queries are **not supported** with the `with_none` method. This is because querying properties of components that should not exist on the entity doesn't make logical sense. Use `with_none` to exclude entities that have certain components.

  ```gdscript
  # Correct usage of with_none
  var result = QueryBuilder.new(world).with_none([C_Inactive]).execute()
  ```

- **Empty Queries Match All Instances of the Component**

  If you provide an empty query dictionary for a component, it will match all entities that have that component, regardless of its properties.

  ```gdscript
  # This will match all entities that have C_TestC component
  var result = QueryBuilder.new(world).with_all([
      { C_TestC: {} }
  ]).execute()
  ```

- **Non-existent Properties**

  If you query a property that doesn't exist on the component, it will not match any entities.

  ```gdscript
  # Assuming 'non_existent' is not a property of C_TestC
  var result = QueryBuilder.new(world).with_all([
      { C_TestC: { "non_existent": { "_eq": 10 } } }
  ]).execute()
  # result will be empty
  ```

## Comprehensive Example

Here's a full example demonstrating several component queries:

```gdscript
# Setting up entities with components
var entity1 = Entity.new()
entity1.add_component(C_TestC.new(25))
entity1.add_component(C_TestD.new(100))

var entity2 = Entity.new()
entity2.add_component(C_TestC.new(10))
entity2.add_component(C_TestD.new(50))

var entity3 = Entity.new()
entity3.add_component(C_TestC.new(25))
entity3.add_component(C_TestD.new(25))

var entity4 = Entity.new()
entity4.add_component(C_TestC.new(30))

world.add_entity(entity1)
world.add_entity(entity2)
world.add_entity(entity3)
world.add_entity(entity4)

# Query: Entities with C_TestC.value == 25 and C_TestD.points > 50
var result = QueryBuilder.new(world).with_all([
    { C_TestC: { "value": { "_eq": 25 } } },
    { C_TestD: { "points": { "_gt": 50 } } }
]).execute()
# result will include entity1
```

## Conclusion

Component Queries extend the querying capabilities of the GECS framework by allowing you to filter entities based on component data. By utilizing the supported operators and combining component queries with traditional component filters, you can precisely target the entities you need for your game's logic.

For more information on how to use the `QueryBuilder`, refer to the `query_builder.gd` documentation and the test cases in `test_query_builder.gd`.

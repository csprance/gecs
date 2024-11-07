<img src="./assets/logo.png" height="256" align="center">

# GECS
> Godot Entity Component System

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
    - [Basic Concepts](#basic-concepts)
4. [Creating Components](#creating-components)
5. [Creating Entities](#creating-entities)
6. [Creating Systems](#creating-systems)
7. [The World and WorldManager](#the-world-and-worldmanager)
8. [Example Project](#example-project)
    - [Components](#components)
    - [Entities](#entities)
    - [Systems](#systems)
9. [Advanced Usage](#advanced-usage)
    - [Querying Entities](#querying-entities)
10. [API Reference](#api-reference)
    - [Component](#component)
    - [Entity](#entity)
    - [System](#system)
    - [World](#world)
    - [WorldManager](#worldmanager)
11. [Conclusion](#conclusion)

## Introduction

GECS is an Entity Component System framework designed for the Godot Engine. It provides a simple yet powerful way to organize your game logic using the ECS pattern, allowing for better code organization, reusability, and scalability.

This documentation will guide you through the setup and usage of the GECS addon, providing examples from a sample game project to illustrate key concepts.

## Installation

1. **Download the Addon**: Clone or download the gecs addon and place it in your project's `addons` folder.

2. **Enable the Addon**: In the Godot editor, go to `Project > Project Settings > Plugins`, and enable the `GECS` plugin.

3. **Autoload WorldManager**: The addon requires the `ECS` to be autoloaded. This should be handled automatically when you enable the plugin. If not, go to `Project > Project Settings > Autoload`, and add `WorldManager` pointing to `res://addons/gecs/ecs.gd`.

## Getting Started

### Basic Concepts

Before diving into the usage of the gecs addon, it's important to understand the basic concepts of an Entity Component System (ECS):

- **Entity**: A container or placeholder that represents an object in your game. Entities themselves are often empty and only gain behavior when components are added to them.

- **Component**: A data container that holds specific attributes or properties. Components do not contain game logic.

- **System**: A system contains the logic that operates on entities with specific components.

- **World**: The context in which entities and systems exist and interact.

## Creating Components

Components in GECS are resources that extend the `Component` class. They are simple data containers without any logic.

Here's how to create a new component:

1. **Create a New Script**: Create a new script extending `Component`.

```gdscript
# bounce.gd
class_name Bounce
extends Component

@export var normal := Vector2.ZERO
@export var should_bounce := false
```

2. **Define Properties**: Add any properties that represent the data for this component. Use the `@export` keyword to make them editable in the inspector.

## Creating Entities

Entities in GECS are nodes that extend the `Entity` class. They can have components added to them to define their behavior.

1. **Create a New Scene**: Create a new scene with a root node extending `Entity`.

2. **Add Components**: Use the `component_resources` exported array to add instances of your components.

```gdscript
# ball.gd
class_name Ball
extends Entity

func on_ready() -> void:
    Utils.sync_transform(self)
```

3. **Initialize Components**: In the `_ready()` function, components listed in `component_resources` are automatically added to the entity.

## Creating Systems

Systems in GECS are nodes that extend the `System` class. They contain the logic that operates on entities with specific components.

1. **Create a New Script**: Create a new script extending `System`.

```gdscript
# bounce_system.gd
class_name BounceSystem
extends System

func _init():
    required_components = [Transform, Velocity, Bounce]

func process(entity: Entity, delta: float):
    var bounce_component: Bounce = entity.get_component(Bounce)
    if bounce_component.should_bounce:
        var velocity_component: Velocity = entity.get_component(Velocity)
        velocity_component.direction = bounce_component.normal
        bounce_component.should_bounce = false
```

2. **Define Required Components**: In the `_init()` function, specify the components that entities must have for the system to process them.

3. **Implement the Process Function**: The `process()` function contains the logic to be applied to each relevant entity.

## The World and WorldManager

The `World` class manages all entities and systems in your game. It processes systems and handles entity queries.

- **WorldManager**: A singleton autoloaded to provide access to the current `World`.

- **Setting Up the World**: In your main scene, add a node extending `World` and add your entities and systems as children.

```gdscript
# main.gd
extends Node

@onready var world: World = $World

func _ready() -> void:
    WorldManager.set_current_world(world)
```

## Example Project

To illustrate the usage of GECS, let's look at an example project that simulates a simple Breakout game.

### Components

- **Bounce**: Indicates that an entity can bounce off surfaces.

```gdscript
# bounce.gd
class_name Bounce
extends Component

@export var normal := Vector2.ZERO
@export var should_bounce := false
```

- **Velocity**: Controls the movement speed and direction of an entity.

```gdscript
# velocity.gd
class_name Velocity
extends Component

@export var direction := Vector2.ZERO
@export var speed := 0.0
```

- **Transform**: Manages the position, rotation, and scale of an entity.

```gdscript
# transform.gd
class_name Transform
extends Component

@export var position := Vector2.ZERO
@export var rotation := 0.0
@export var scale := Vector2.ONE
```

### Entities

- **Ball**: Represents the ball in the game.

```gdscript
# ball.gd
class_name Ball
extends Entity

func on_ready() -> void:
    Utils.sync_transform(self)
```

In the scene, the `Ball` entity includes `Bounce`, `Velocity`, and `Transform` components.

- **Paddle**: Represents the player's paddle.

```gdscript
# paddle.gd
class_name Paddle
extends Entity

func on_ready() -> void:
    Utils.sync_transform(self)
```

Includes `PlayerMovement`, `Velocity`, `Transform`, and `Friction` components.

### Systems

- **BounceSystem**: Handles the bouncing logic of entities.

```gdscript
# bounce_system.gd
class_name BounceSystem
extends System

func _init():
    required_components = [Transform, Velocity, Bounce]

func process(entity: Entity, delta: float):
    var bounce_component: Bounce = entity.get_component(Bounce)
    if bounce_component.should_bounce:
        var velocity_component: Velocity = entity.get_component(Velocity)
        velocity_component.direction = bounce_component.normal
        bounce_component.should_bounce = false
```

- **VelocitySystem**: Updates entity positions based on their velocity.

```gdscript
# velocity_system.gd
class_name VelocitySystem
extends System

func _init():
    required_components = [Velocity, Transform]

func process(entity: Entity, delta: float):
    var velocity: Velocity = entity.get_component(Velocity)
    var transform: Transform = entity.get_component(Transform)
    var velocity_vector: Vector2 = velocity.direction.normalized() * velocity.speed
    transform.position += velocity_vector * delta
```

- **Transform2DSystem**: Synchronizes the `Transform` component with the entity's actual transform.

```gdscript
# transform_2d_system.gd
class_name Transform2DSystem
extends System

func _init():
    required_components = [Transform]

func process(entity: Entity, delta):
    var transform: Transform = entity.get_component(Transform)
    entity.position = transform.position
    entity.rotation = transform.rotation
    entity.scale = transform.scale
```

## Advanced Usage

### Querying Entities

The `World` class provides an advanced query function to retrieve entities based on their components.

```gdscript
func query(all_components = [], any_components = [], exclude_components = []) -> Array
```

- **all_components**: Entities must have all of these components.
- **any_components**: Entities must have at least one of these components.
- **exclude_components**: Entities must not have any of these components.

**Example**:

```gdscript
var entities_with_velocity = world.query(all_components=[Velocity])
```

## API Reference

### Component

**Description**: A data container extending `Resource`.

**Properties**:

- `var key`: Unique identifier for the component, derived from its script path.

### Entity

**Description**: Represents an object in the game world. Extends `Node2D`.

**Signals**:

- `signal component_added(entity: Entity, component_key: String)`
- `signal component_removed(entity: Entity, component_key: String)`

**Methods**:

- `func add_component(component: Component) -> void`
- `func remove_component(component_key: String) -> void`
- `func get_component(component: Variant) -> Component`
- `func has_component(component_key: String) -> bool`

**Lifecycle Methods**:

- `func on_ready() -> void`
- `func on_update(delta: float) -> void`
- `func on_destroy() -> void`

### System

**Description**: Contains logic that operates on entities with specific components. Extends `Node`.

**Properties**:

- `var required_components: Array[Variant]`: Components an entity must have to be processed.

**Methods**:

- `func process(entity: Entity, delta: float) -> void`

### World

**Description**: Manages entities and systems. Extends `Node`.

**Methods**:

- `func add_entity(entity: Entity) -> void`
- `func add_system(system: System) -> void`
- `func remove_entity(entity) -> void`
- `func query(all_components = [], any_components = [], exclude_components = []) -> Array`

### WorldManager

**Description**: Autoload singleton providing access to the current `World`.

**Methods**:

- `func set_current_world(world: World)`
- `func get_current_world() -> World`

## Conclusion

The GECS addon provides a flexible and efficient way to implement the ECS pattern in your Godot projects. By separating data (components) from logic (systems), you can create reusable and maintainable game code.

Feel free to explore and expand upon the example project provided, and refer to this documentation as you integrate GECS into your own games.

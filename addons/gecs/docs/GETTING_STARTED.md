# Getting Started with GECS

> **Build your first ECS project in 5 minutes**

This guide will walk you through creating a simple moving ball using GECS. By the end, you'll understand the core concepts and have a working example.

## 📋 Prerequisites

- Godot 4.x installed
- Basic GDScript knowledge
- 5 minutes of your time

## ⚡ Step 1: Setup (1 minute)

### Install GECS

1. **Download GECS** and place it in your project's `addons/` folder
2. **Enable the plugin**: Go to `Project > Project Settings > Plugins` and enable "GECS"
3. **Verify setup**: The ECS singleton should be automatically added to AutoLoad

> 💡 **Quick Check**: If you see errors, make sure `ECS` appears in `Project > Project Settings > AutoLoad`

## 🎾 Step 2: Your First Entity (1 minute)

Create a new scene and script for your ball entity:

**File: `e_ball.gd`**

```gdscript
# e_ball.gd
class_name Ball
extends Entity

func _ready():
    # Add a visual representation
    var sprite = Sprite2D.new()
    var texture = ImageTexture.new()
    var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
    image.fill(Color.RED)
    texture.set_image(image)
    sprite.texture = texture
    add_child(sprite)
```

> 💡 **What's happening?** Entities are containers for components. We're creating a ball entity with a red circle sprite.

## 📦 Step 3: Your First Components (1 minute)

Components hold data. Let's create position and velocity components:

**File: `c_position.gd`**

```gdscript
# c_position.gd
class_name C_Position
extends Component

@export var position: Vector2 = Vector2.ZERO

func _init(pos: Vector2 = Vector2.ZERO):
    position = pos
```

**File: `c_velocity.gd`**

```gdscript
# c_velocity.gd
class_name C_Velocity
extends Component

@export var velocity: Vector2 = Vector2.ZERO

func _init(vel: Vector2 = Vector2.ZERO):
    velocity = vel
```

> 💡 **Key Principle**: Components only hold data, never logic. Think of them as data containers.

## ⚙️ Step 4: Your First System (1 minute)

Systems contain the logic that operates on entities with specific components:

**File: `s_movement.gd`**

```gdscript
# s_movement.gd
class_name MovementSystem
extends System

func query():
    # Find all entities that have both position and velocity
    return q.with_all([C_Position, C_Velocity])

func process(entity: Entity, delta: float):
    # Get the components we need
    var pos_comp = entity.get_component(C_Position)
    var vel_comp = entity.get_component(C_Velocity)

    # Update position based on velocity
    pos_comp.position += vel_comp.velocity * delta

    # Update the entity's actual position
    entity.position = pos_comp.position
```

> 💡 **System Logic**: Query finds entities with required components, process() runs for each matching entity.

## 🎬 Step 5: See It Work (1 minute)

Now let's put it all together in a main scene:

**File: `main.gd`**

```gdscript
# main.gd
extends Node2D

func _ready():
    # Create the world
    var world = World.new()
    add_child(world)
    ECS.world = world

    # Create a ball entity
    var ball = Ball.new()
    ball.add_component(C_Position.new(Vector2(100, 100)))
    ball.add_component(C_Velocity.new(Vector2(100, 50)))
    world.add_entity(ball)

    # Create the movement system
    var movement_system = MovementSystem.new()
    world.add_system(movement_system)

func _process(delta):
    # Process all systems
    if ECS.world:
        ECS.world.process(delta)
```

**Run your project!** 🎉 You should see a red ball moving across the screen.

## 🎯 What You Just Built

Congratulations! You've created your first ECS project with:

- **Entity**: Ball - a container for components
- **Components**: C_Position, C_Velocity - pure data
- **System**: MovementSystem - logic that operates on entities
- **World**: Container that manages entities and systems

## 📈 Next Steps

Now that you have the basics working, here's how to level up:

### 🧠 Understand the Concepts

**→ [Core Concepts Guide](CORE_CONCEPTS.md)** - Deep dive into Entities, Components, Systems, and Relationships

### 🔧 Add More Features

Try adding these to your ball:

- **Bounce off screen edges** - Add boundary checking
- **Multiple balls** - Create more entities with different velocities
- **Gravity** - Add a GravityComponent and GravitySystem
- **User input** - Add controls to change ball direction

### 📚 Learn Best Practices

**→ [Best Practices Guide](BEST_PRACTICES.md)** - Write maintainable ECS code

### 🔧 Explore Advanced Features

- **[Component Queries](COMPONENT_QUERIES.md)** - Filter by component property values
- **[Relationships](RELATIONSHIPS.md)** - Link entities together for complex interactions
- **[Observers](OBSERVERS.md)** - Reactive systems that respond to changes
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Make your games run fast

## ❓ Having Issues?

### Ball not moving?

- Check that `ECS.world.process(delta)` is called in `_process()`
- Verify components are added to the entity
- Make sure the system is added to the world

### Errors in console?

- Check that all classes extend the correct base class
- Verify file names match class names
- Ensure GECS plugin is enabled

**Still stuck?** → [Troubleshooting Guide](TROUBLESHOOTING.md)

## 🏆 What's Next?

You're now ready to build amazing games with GECS! The Entity-Component-System pattern will help you:

- **Scale your game** - Add features without breaking existing code
- **Reuse code** - Components and systems work across different entity types
- **Debug easier** - Clear separation between data and logic
- **Optimize performance** - GECS handles efficient querying for you

**Ready to dive deeper?** Start with [Core Concepts](CORE_CONCEPTS.md) to really understand what makes ECS powerful.

**Need help?** [Join our Discord community](https://discord.gg/eB43XU2tmn) for support and discussions.

---

_"The best way to learn ECS is to build with it. Start simple, then add complexity as you understand the patterns."_

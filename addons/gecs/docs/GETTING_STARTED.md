# Getting Started with GECS

> **Build your first ECS project in 5 minutes**

This guide will walk you through creating a simple player entity with health and transform components using GECS. By the end, you'll understand the core concepts and have a working example.

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

## 🎮 Step 2: Your First Entity (1 minute)

Create a new scene and script for your player entity:

**File: `e_player.gd`**

```gdscript
# e_player.gd
class_name Player
extends Entity

func on_ready():
    # Sync the entity's scene position to the Transform component
    if has_component(C_Transform):
        var c_trs = get_component(C_Transform) as C_Transform
        c_trs.position = self.global_position
```

> 💡 **What's happening?** Entities are containers for components. We're creating a player entity that will sync its transform with the component system.

## 📦 Step 3: Your First Components (1 minute)

Components hold data. Let's create health and transform components:

**File: `c_health.gd`**

```gdscript
# c_health.gd
class_name C_Health
extends Component

@export var current: float = 100.0
@export var maximum: float = 100.0

func _init(max_health: float = 100.0):
    maximum = max_health
    current = max_health
```

**File: `c_transform.gd`**

```gdscript
# c_transform.gd
class_name C_Transform
extends Component

@export var position: Vector3 = Vector3.ZERO

func _init(pos: Vector3 = Vector3.ZERO):
    position = pos
```

**File: `c_velocity.gd`**

```gdscript
# c_velocity.gd
class_name C_Velocity
extends Component

@export var velocity: Vector3 = Vector3.ZERO

func _init(vel: Vector3 = Vector3.ZERO):
    velocity = vel
```

> 💡 **Key Principle**: Components only hold data, never logic. Think of them as data containers.
> ⚠️ **Important Note**: Components `_init` function requires that all arguments have a default value or Godot will crash.

## ⚙️ Step 4: Your First System (1 minute)

Systems contain the logic that operates on entities with specific components. This system moves entities across the screen:

**File: `s_movement.gd`**

```gdscript
# s_movement.gd
class_name MovementSystem
extends System

func query():
    # Find all entities that have both transform and velocity
    return q.with_all([C_Transform, C_Velocity])

func process(entity: Entity, delta: float):
    var c_trs = entity.get_component(C_Transform) as C_Transform
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    
    # Move the entity based on its velocity
    c_trs.position += c_velocity.velocity * delta
    
    # Update the actual entity position in the scene
    entity.global_position = c_trs.position
    
    # Bounce off screen edges (simple example)
    if c_trs.position.x > 10 or c_trs.position.x < -10:
        c_velocity.velocity.x *= -1
```

> 💡 **System Logic**: Query finds entities with required components, process() runs the movement logic on each entity every frame.

## 🎬 Step 5: See It Work (1 minute)

Now let's put it all together in a main scene:

**File: `main.gd`**

```gdscript
# main.gd
extends Node

@onready var world: World = $World

func _ready():
    ECS.world = world
    
    # Create a moving player entity
    var e_player = Player.new()
    e_player.add_components([
        C_Health.new(100),
        C_Transform.new(),
        C_Velocity.new(Vector3(2, 0, 0))  # Move right at 2 units/second
    ])
    add_child(e_player)  # Add to scene tree
    ECS.world.add_entity(e_player)  # Add to ECS world
    
    # Create the movement system
    var movement_system = MovementSystem.new()
    ECS.world.add_system(movement_system)

func _process(delta):
    # Process all systems
    if ECS.world:
        ECS.process(delta)
```

**Run your project!** 🎉 You now have a working ECS setup where the player entity moves across the screen and bounces off the edges! The MovementSystem updates entity positions based on their velocity components.

## 🎯 What You Just Built

Congratulations! You've created your first ECS project with:

- **Entity**: Player - a container for components
- **Components**: C_Health, C_Transform, C_Velocity - pure data containers
- **System**: MovementSystem - logic that moves entities based on velocity
- **World**: Container that manages entities and systems

## 📈 Next Steps

Now that you have the basics working, here's how to level up:

### 1. Create Entity Prefabs (Recommended)

Instead of creating entities in code, use Godot's scene system:

1. **Create a new scene** with your Entity class as the root node
2. **Add visual children** (MeshInstance3D, Sprite3D, etc.)
3. **Add components via define_components()** or `component_resources` array in Inspector
4. **Save as .tscn file** (e.g., `e_player.tscn`)
5. **Load and instantiate** in your main scene

```gdscript
# Improved e_player.gd with define_components()
class_name Player
extends Entity

func define_components() -> Array:
    return [
        C_Health.new(100),
        C_Transform.new(),
        C_Velocity.new(Vector3(1, 0, 0))  # Move right slowly
    ]

func on_ready():
    # Sync scene position to component
    if has_component(C_Transform):
        var c_trs = get_component(C_Transform) as C_Transform
        c_trs.position = self.global_position
```

### 2. Organize Your Main Scene

Structure your main scene using the proven scene-based pattern:

```
Main.tscn
├── World (World node)
├── DefaultSystems (instantiated from default_systems.tscn)
│   ├── input (SystemGroup)
│   ├── gameplay (SystemGroup) 
│   ├── physics (SystemGroup)
│   └── ui (SystemGroup)
├── Level (Node3D for static environment)
└── Entities (Node3D for spawned entities)
```

**Benefits:**
- **Visual organization** in Godot editor
- **Easy system reordering** between groups  
- **Reusable system configurations**

### 3. Learn More Patterns

### 🧠 Understand the Concepts

**→ [Core Concepts Guide](CORE_CONCEPTS.md)** - Deep dive into Entities, Components, Systems, and Relationships

### 🔧 Add More Features

Try adding these to your moving player:

- **Input system** - Add C_Input component and system to control movement with arrow keys
- **Multiple entities** - Create more moving objects with different velocities
- **Collision system** - Add C_Collision component and detect when entities hit each other
- **Gravity system** - Add downward velocity to make entities fall

### 📚 Learn Best Practices

**→ [Best Practices Guide](BEST_PRACTICES.md)** - Write maintainable ECS code

### 🔧 Explore Advanced Features

- **[Component Queries](COMPONENT_QUERIES.md)** - Filter by component property values
- **[Relationships](RELATIONSHIPS.md)** - Link entities together for complex interactions
- **[Observers](OBSERVERS.md)** - Reactive systems that respond to changes
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Make your games run fast

## ❓ Having Issues?

### Player not responding?

- Check that `ECS.process(delta)` is called in `_process()`
- Verify components are added to the entity via `define_components()` or Inspector
- Make sure the system is added to the world
- Ensure transform synchronization is called in entity's `on_ready()`

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

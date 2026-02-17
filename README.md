# GECS

> **Entity Component System for Godot 4.x**

Build scalable, maintainable games with clean separation of data and logic. GECS integrates seamlessly with Godot's node system while providing powerful query-based entity filtering.

## ✨ Key Features

- 🎯 **Godot Integration** - Works with nodes, scenes, and editor
- 🚀 **High Performance** - Optimized queries with automatic caching
- 🔧 **Flexible Queries** - Find entities by components, relationships, or properties
- 🔍 **Debug Viewer** - Real-time inspection and performance monitoring
- 📦 **Editor Support** - Visual component editing and scene integration
- 🎮 **Battle Tested** - Used in games being actively developed
- 🎮🎮🎮🎮 **Multiplayer** - GECS goes Multiplayer! Check out the [GECS Network Addon](addons/gecs_network/README.md)


```gdscript
# Create entities with components
var player1 = Entity.new()
player1.add_component(C_Health.new(100))
player1.add_component(C_Velocity.new(Vector2(5, 0)))

var player2 = Entity.new()
player2.add_component(C_Health.new(100))
player2.add_component(C_Velocity.new(Vector2(-5, 0)))

# Add entity to the world
ECS.world.add_entities([player1, player2])

# Add relationships to entities
# Player 1 is an Ally to Player 2
player1.add_relationship(Relationship.new(C_AllyTo.new(), player2))
# Player 2 is a little suspicious of Player 1
player2.add_relationship(Relationship.new(C_SuspiciousOf.new(), player1))

# Components define data only
class_name C_Velocity extends Component

@export var velocity := Vector3.ZERO


# Systems process entities with specific components
class_name VelocitySystem extends System

# Systems define queries to select entities and iterate their components
func query() -> QueryBuilder:
    return q.with_all([C_Velocity, C_Transform]).iterate([C_Velocity, C_Transform])

# Systems implement process to handle selected entities
func process(entities: Array[Entity], components: Array, delta: float) -> void:
    var c_velocities = components[0] # C_Velocity (first in iterate)
    var c_transforms = components[1] # C_Transform (second in iterate)

    # Process all velocity and transform components on entities that match query
    for i in entities.size():
        var c_velocity := c_velocities[i] as C_Velocity
        var c_transform := c_transforms[i] as C_Transform
        c_transform.transform.global_position += c_velocity.velocity * delta

# Add systems to the world
ECS.world.add_system(VelocitySystem.new())

# Progress the world and call all systems
ECS.world.process(delta)
```

## ⚡ Quick Start

1. **Install**: Download to `addons/gecs/` and enable in Project Settings
2. **Follow Guide**: [Get your first ECS project running in 5 minutes →](addons/gecs/docs/GETTING_STARTED.md)
3. **Learn More**: [Understand core ECS concepts →](addons/gecs/docs/CORE_CONCEPTS.md)


## 📚 Complete Documentation

**All documentation is located in the addon folder:**

**→ [Complete Documentation Index](addons/gecs/README.md)**

### Quick Navigation

- **[Getting Started](addons/gecs/docs/GETTING_STARTED.md)** - Build your first ECS project (5 min)
- **[Core Concepts](addons/gecs/docs/CORE_CONCEPTS.md)** - Understand Entities, Components, Systems, Relationships (20 min)
- **[Best Practices](addons/gecs/docs/BEST_PRACTICES.md)** - Write maintainable ECS code (15 min)
- **[Troubleshooting](addons/gecs/docs/TROUBLESHOOTING.md)** - Solve common issues quickly

### Advanced Features

- **[Component Queries](addons/gecs/docs/COMPONENT_QUERIES.md)** - Advanced property-based filtering
- **[Relationships](addons/gecs/docs/RELATIONSHIPS.md)** - Entity linking and associations
- **[Observers](addons/gecs/docs/OBSERVERS.md)** - Reactive systems for component changes
- **[Performance Optimization](addons/gecs/docs/PERFORMANCE_OPTIMIZATION.md)** - Make your games run fast

## 🎮 Example Games

- **[GECS-101](https://github.com/csprance/gecs-101)** - A simple example
- **[Zombies Ate My Neighbors](https://github.com/csprance/gecs/tree/zombies-ate-my-neighbors/game)** - Action arcade game
- **[Breakout Clone](https://github.com/csprance/gecs/tree/breakout/game)** - Classic brick breaker

## 🌟 Community

- **Discord**: [Join our community](https://discord.gg/eB43XU2tmn)
- **Issues**: [Report bugs or request features](https://github.com/csprance/gecs/issues)
- **Discussions**: [Ask questions and share projects](https://github.com/csprance/gecs/discussions)

## 📄 License

MIT - See [LICENSE](LICENSE) for details.

---

_GECS is provided as-is. If it breaks, you get to keep both pieces._ 😄

[![Star History Chart](https://api.star-history.com/svg?repos=csprance/gecs&type=Date)](https://star-history.com/#csprance/gecs&Date)

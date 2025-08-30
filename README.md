# GECS

> **Entity Component System for Godot 4.x**

Build scalable, maintainable games with clean separation of data and logic. GECS integrates seamlessly with Godot's node system while providing powerful query-based entity filtering.

```gdscript
# Create entities with components
var player = Entity.new()
player.add_component(C_Health.new(100))
player.add_component(C_Velocity.new(Vector2(5, 0)))

# Systems process entities with specific components
class_name MovementSystem extends System

func query(): return q.with_all([C_Velocity, C_Transform])
func process(entity: Entity, delta: float):
    var velocity = entity.get_component(C_Velocity)
    var transform = entity.get_component(C_Transform)
    transform.position += velocity.direction * delta
```

## ⚡ Quick Start

1. **Install**: Download to `addons/gecs/` and enable in Project Settings
2. **Follow Guide**: [Get your first ECS project running in 5 minutes →](addons/gecs/docs/GETTING_STARTED.md)
3. **Learn More**: [Understand core ECS concepts →](addons/gecs/docs/CORE_CONCEPTS.md)

## ✨ Key Features

- 🎯 **Godot Integration** - Works with nodes, scenes, and editor
- 🚀 **High Performance** - Optimized queries with automatic caching
- 🔧 **Flexible Queries** - Find entities by components, relationships, or properties
- 📦 **Editor Support** - Visual component editing and scene integration
- 🎮 **Battle Tested** - Used in games being actively developed

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

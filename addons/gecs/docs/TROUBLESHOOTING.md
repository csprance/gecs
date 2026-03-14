# GECS Troubleshooting Guide

> **Quickly solve common GECS issues**

This guide helps you diagnose and fix the most common problems when working with GECS. Find your issue, apply the solution, and learn how to prevent it.

## Quick Diagnosis

### My Game Isn't Working At All

**Symptoms**: No entities moving, systems not running, nothing happening

**Quick Check**:

```gdscript
# In your _process() method, ensure you have:
func _process(delta):
    if ECS.world:
        ECS.world.process(delta)  # This line is critical!
```

**Missing this?** → [Systems Not Running](#systems-not-running)

### Entities Aren't Moving/Updating

**Symptoms**: Entities exist but don't respond to systems

**Quick Check**:

1. Are your entities added to the world? `ECS.world.add_entity(entity)`
2. Do your entities have the right components? Check system queries
3. Are your systems properly organized in scene hierarchy? Check default_systems.tscn

**Still broken?** → [Entity Issues](#entity-issues)

### Performance Is Terrible

**Symptoms**: Low FPS, stuttering, slow response

**Quick Check**:

1. Check entity count: `print("Entities: ", ECS.world.entities.size())`
2. Check query cache: `print(ECS.world.get_cache_stats())`
3. Look for expensive queries in your systems

**Need optimization?** → [Performance Issues](#performance-issues)

## Systems Not Running

### Problem: Systems Never Execute

**Error Messages**:

- No error, but `process()` method never called
- Entities exist but don't change

**Solution**:

```gdscript
# Ensure this exists in your main scene
func _process(delta):
    ECS.process(delta)  # This processes all systems

# OR if using system groups:
func _process(delta):
    ECS.process(delta, "physics")
    ECS.process(delta, "render")
```

**Prevention**: Always call `ECS.process()` in your main game loop.

### Problem: System Query Returns Empty

**Symptoms**: System exists but `process()` never called

**Diagnosis**:

```gdscript
# Add this to your system for debugging
class_name MySystem extends System

func _ready():
    print("MySystem query result: ", query().execute().size())

func query():
    return q.with_all([C_ComponentA, C_ComponentB])
```

**Common Causes**:

1. **Missing Components**:

   ```gdscript
   # Problem - Entity missing required component
   var entity = Entity.new()
   entity.add_component(C_ComponentA.new())
   # Missing C_ComponentB!

   # Solution - Add all required components
   entity.add_component(C_ComponentA.new())
   entity.add_component(C_ComponentB.new())
   ```

2. **Wrong Component Types**:

   ```gdscript
   # Problem - Using instance instead of class
   func query():
       return q.with_all([C_ComponentA.new()])  # Wrong!

   # Solution - Use class reference
   func query():
       return q.with_all([C_ComponentA])  # Correct!
   ```

3. **Component Not Added to World**:

   ```gdscript
   # Problem - Entity not in world
   var entity = Entity.new()
   entity.add_component(C_ComponentA.new())
   # Entity never added to world!

   # Solution - Add entity to world
   ECS.world.add_entity(entity)
   ```

## Entity Issues

### Problem: Entity Components Not Found

**Error Messages**:

- `get_component() returned null`
- `Entity does not have component of type...`

**Diagnosis**:

```gdscript
# Debug what components an entity actually has
func debug_entity_components(entity: Entity):
    print("Entity components:")
    for component_path in entity.components.keys():
        print("  ", component_path)
```

**Solution**: Ensure components are added correctly:

```gdscript
# Correct component addition
var entity = Entity.new()
entity.add_component(C_Health.new(100))
entity.add_component(C_Position.new(Vector2(50, 50)))

# Verify component exists before using
if entity.has_component(C_Health):
    var health = entity.get_component(C_Health)
    health.current -= 10
```

### Problem: Component Properties Not Updating

**Symptoms**: Setting component properties has no effect

**Common Causes**:

1. **Getting Component Reference Once**:

   ```gdscript
   # Problem - Stale component reference
   var health = entity.get_component(C_Health)
   # ... later in code, component gets replaced ...
   health.current = 50  # Updates old component!

   # Solution - Get fresh reference each time
   entity.get_component(C_Health).current = 50
   ```

2. **Modifying Wrong Entity**:

   ```gdscript
   # Problem - Variable confusion
   var player = get_player_entity()
   var enemy = get_enemy_entity()

   # Accidentally modify wrong entity
   player.get_component(C_Health).current = 0  # Meant to be enemy!

   # Solution - Use clear variable names
   var player_health = player.get_component(C_Health)
   var enemy_health = enemy.get_component(C_Health)
   enemy_health.current = 0
   ```

## Common Errors

### Error: "Cannot access property/method on null instance"

**Full Error**:

```
Invalid get index 'current' (on base: 'null instance')
```

**Cause**: Component doesn't exist on entity

**Solution**:

```gdscript
# Causes null error
var health = entity.get_component(C_Health)
health.current -= 10  # health is null!

# Safe component access
if entity.has_component(C_Health):
    var health = entity.get_component(C_Health)
    health.current -= 10
else:
    print("Entity doesn't have C_Health!")
```

### Error: "Class not found"

**Full Error**:

```
Identifier 'ComponentName' not found in current scope
```

**Causes & Solutions**:

1. **Missing class_name**:

   ```gdscript
   # Problem - No class_name declaration
   extends Component
   # Script exists but can't be referenced by name

   # Solution - Add class_name
   class_name C_Health
   extends Component
   ```

2. **File not saved or loaded**:

   - Save your component script files
   - Restart Godot if classes still not found
   - Check for syntax errors in the component file

3. **Wrong inheritance**:

   ```gdscript
   # Problem - Wrong base class
   class_name C_Health
   extends Node  # Should be Component!

   # Solution - Correct inheritance
   class_name C_Health
   extends Component
   ```

## Performance Issues

### Problem: Low FPS / Stuttering

**Diagnosis Steps**:

1. **Check processing times**:

   ```gdscript
   # Check processing times
   func _process(delta):
       ECS.process(delta)
       # Use Godot's built-in profiler or print frame time
       if Engine.get_process_frames() % 60 == 0:
           print("Frame time: ", delta * 1000, "ms")
           print("Entities: ", ECS.world.entities.size())
   ```

2. **Check entity count**:
   ```gdscript
   print("Total entities: ", ECS.world.entities.size())
   ```

**Common Fixes**:

1. **Too Many Entities in Broad Queries**:

   ```gdscript
   # Problem - Overly broad query
   func query():
       return q.with_all([C_Position])  # Matches everything!

   # Solution - More specific query
   func query():
       return q.with_all([C_Position, C_Movable])
   ```

2. **Expensive Queries Rebuilt Every Frame**:

   ```gdscript
   # Problem - Rebuilding queries in process
   func process(entities: Array[Entity], components: Array, delta: float):
       var custom_entities = ECS.world.query.with_all([C_ComponentA]).execute()

   # Solution - Use the system's query() method (automatically cached)
   func query():
       return q.with_all([C_ComponentA])  # Automatically cached by GECS

   func process(entities: Array[Entity], components: Array, delta: float):
       # Just process the entities passed in - already filtered by query
       for entity in entities:
           # Process entity...
   ```

## Integration Issues

### Problem: GECS Conflicts with Godot Features

**Issue**: Using GECS entities with Godot nodes causes problems

**Solution**: Choose your approach consistently:

```gdscript
# Approach 1 - Pure ECS (recommended for complex games)
# Entities are not nodes, use ECS for everything
var entity = Entity.new()  # Not added to scene tree
entity.add_component(C_Position.new())
ECS.world.add_entity(entity)

# Approach 2 - Hybrid (good for simpler games)
# Entities are nodes, use ECS for specific systems
var entity = Entity.new()
add_child(entity)  # Entity is in scene tree
entity.add_component(C_Health.new())
ECS.world.add_entity(entity)
```

**Avoid**: Mixing approaches inconsistently in the same project.

### Problem: GECS Not Working After Scene Changes

**Symptoms**: Systems stop working when changing scenes

**Solution**: Properly reinitialize ECS in new scenes:

```gdscript
# In each main scene script
func _ready():
    # Create new world for this scene
    var world = World.new()
    add_child(world)
    ECS.world = world

    # Systems are usually managed via scene composition
    # See default_systems.tscn for organization

    # Create your entities
    setup_entities()
```

**Prevention**: Always initialize ECS properly in each scene that uses it.

## Debugging Tools

### Enable Debug Logging

> **Note:** GECS logs internally at configurable levels via project settings (`gecs.log_level`). Enable verbose output by setting `gecs.log_level = 4` in Project -> Project Settings.

### Entity Inspector Tool

Create a debug tool to inspect entities at runtime:

```gdscript
# DebugPanel.gd
extends Control

func _on_inspect_button_pressed():
    var entities = ECS.world.entities.values()
    print("=== ENTITY INSPECTOR ===")

    for i in range(min(10, entities.size())):  # Show first 10
        var entity = entities[i]
        print("Entity ", i, ":")
        print("  Components: ", entity.components.keys())
        print("  Groups: ", entity.get_groups())

        # Show component values
        for comp_path in entity.components.keys():
            var comp = entity.components[comp_path]
            print("    ", comp_path, ": ", comp)
```

## Getting More Help

### Community Resources

- **Discord**: [Join our community](https://discord.gg/eB43XU2tmn) for help and discussions
- **GitHub Issues**: [Report bugs](https://github.com/csprance/gecs/issues)
- **Documentation**: [Complete Guide](../DOCUMENTATION.md)

### Before Asking for Help

Include this information in your question:

1. **GECS version** you're using
2. **Godot version** you're using
3. **Minimal code example** that reproduces the issue
4. **Error messages** (full text, not paraphrased)
5. **Expected vs actual behavior**

### Still Stuck?

If this guide doesn't solve your problem:

1. **Check the examples** in [Getting Started](GETTING_STARTED.md)
2. **Review best practices** in [Best Practices](BEST_PRACTICES.md)
3. **Search GitHub issues** for similar problems
4. **Create a minimal reproduction** and ask for help


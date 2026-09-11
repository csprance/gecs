# Debug Viewer

> **Real-time debugging and visualization for your ECS projects**

The GECS Debug Viewer provides live inspection of entities, components, systems, and relationships while your game is running. Perfect for understanding entity behavior, optimizing system performance, and debugging complex interactions.

## 📋 Prerequisites

- GECS plugin enabled in your project
- Debug mode enabled: `Project > Project Settings > GECS > Debug Mode`
- Game running from the editor (F5 or F6)

## 🎯 Quick Start

### Opening the Debug Viewer

1. **Run your game** from the Godot editor (F5 for current scene, F6 for main scene)
2. **Open the debugger panel** (bottom of editor, usually appears automatically)
3. **Click the "GECS" tab** next to "Debugger", "Errors", and "Profiler"

> 💡 **Debug Mode Required**: If you see an overlay saying "Debug mode is disabled", go to `Project > Project Settings > GECS` and enable "Debug Mode"

## 🔍 Features Overview

The debug viewer is split into two main panels:

### Systems Panel (Right)

Monitor system execution and performance in real-time.

**Features:**

- **System execution time** - See how long each system takes to process (milliseconds)
- **Entity count** - Number of entities processed per system
- **Active/Inactive status** - Toggle systems on/off at runtime
- **Sortable columns** - Click column headers to sort by name, time, or status
- **Performance metrics** - Archetype count, parallel processing info

**Status Bar:**

- Total system count
- Combined execution time
- Most expensive system highlighted

### Entities Panel (Left)

Inspect individual entities and their components.

**Features:**

- **Entity hierarchy** - See all entities in your world
- **Component data** - View component properties in real-time (WIP)
- **Relationships** - Visualize entity connections and associations
- **Search/filter** - Find entities or components by name

## 🎮 Using the Debug Viewer

### Monitoring System Performance

**Sort by execution time:**

1. Click the **"Time (ms)"** column header in the Systems panel
2. Systems are now sorted by performance (slowest first by default)
3. Click again to reverse the sort order

**Identify bottlenecks:**

- Look for systems with high execution times (> 5ms)
- Check the entity count - more entities = more processing
- Consider optimization strategies from [Performance Optimization](PERFORMANCE_OPTIMIZATION.md)

**Example:**

```
Name                    Time (ms)    Status
PhysicsSystem          8.234 ms     ACTIVE   ← Bottleneck!
RenderSystem           2.156 ms     ACTIVE
AISystem               0.892 ms     ACTIVE
```

### Toggling Systems On/Off

**Disable a system at runtime:**

1. Locate the system in the Systems panel
2. Click on the **Status** column (shows "ACTIVE" or "INACTIVE")
3. System immediately stops processing entities
4. Click again to re-enable

**Use cases:**

- Test game behavior without specific systems
- Isolate bugs by disabling systems one at a time
- Temporarily disable expensive systems during debugging
- Verify system dependencies

> ⚠️ **Important**: System state resets when you restart the game. This is a debugging tool, not a save/load feature.

### Inspecting Entities

**View entity components:**

1. Expand an entity in the Entities panel
2. See all attached components (e.g., `C_Health`, `C_Transform`)
3. Expand a component to view its properties
4. Values update in real-time as your game runs

**Example entity structure:**

```
Entity #123 : /root/World/Player
├── C_Health
│   ├── current: 87.5
│   └── maximum: 100.0
├── C_Transform
│   └── position: (15.2, 0.0, 23.8)
└── C_Velocity
    └── velocity: (2.5, 0.0, 1.3)
```

### Viewing Relationships

Relationships show how entities are connected to each other.

**Relationship types displayed:**

- **Entity → Entity**: `Relationship: C_ChildOf -> Entity /root/World/Parent`
- **Entity → Component**: `Relationship: C_Damaged -> C_FireDamage`
- **Entity → Archetype**: `Relationship: C_Buff -> Archetype Player`
- **Entity → Wildcard**: `Relationship: C_Damage -> Wildcard`

**Expand relationships to see:**

- Relation component properties
- Target component properties (for component relationships)
- Full relationship metadata

> 💡 **Learn More**: See [Relationships](RELATIONSHIPS.md) for details on creating and querying entity relationships

### Using Search and Filters

**Systems panel:**

- Type in the "Filter Systems" box to find systems by name
- Only matching systems remain visible

**Entities panel:**

- Type in the "Filter Entities" box to search
- Searches entity names, component names, and property names
- Useful for finding specific entities in large worlds

### Multi-Monitor Setup

**Pop-out window:**

1. Click **"Pop Out"** button at the top of the debug viewer
2. Debug viewer moves to a separate window
3. Position on second monitor for permanent visibility
4. Click **"Pop In"** to return to the editor tab

**Benefits:**

- Keep debug info visible while editing scenes
- Monitor performance during gameplay
- Track entity changes without switching panels

### Collapse/Expand Controls

**Quick controls:**

- **Collapse All** / **Expand All** - Manage all entities at once
- **Systems Collapse All** / **Systems Expand All** - Manage all systems at once
- Individual items can be collapsed/expanded by clicking

## 🔧 Common Workflows

### Performance Optimization Workflow

1. **Sort systems by execution time** (click "Time (ms)" header)
2. **Identify slowest system** (top of sorted list)
3. **Expand system details** to see entity count and archetype count
4. **Review system implementation** for optimization opportunities
5. **Apply optimizations** from [Performance Optimization](PERFORMANCE_OPTIMIZATION.md)
6. **Re-run and compare** execution times

### Debugging Workflow

1. **Identify the problematic entity** using search/filter
2. **Expand entity** to view all components
3. **Watch component values** update in real-time
4. **Toggle related systems off/on** to isolate the issue
5. **Check relationships** if entity interactions are involved
6. **Fix the issue** in your code

### Testing System Dependencies

1. **Run your game** from the editor
2. **Disable systems one at a time** using the Status column
3. **Observe game behavior** for each disabled system
4. **Document dependencies** you discover
5. **Design systems to be more independent** if needed

## 📊 Understanding System Metrics

When you expand a system in the Systems panel, you'll see detailed metrics:

**Execution Time (ms):**

- Time spent in the system's `process()` function
- Lower is better (aim for < 1ms for most systems)
- Spikes indicate performance issues

**Entity Count:**

- Number of entities that matched the system's query
- High counts + high execution time = optimization needed
- Zero entities may indicate query issues

**Archetype Count:**

- Number of unique component combinations processed
- Higher counts can impact performance
- See [Performance Optimization](PERFORMANCE_OPTIMIZATION.md#archetype-optimization)

**Parallel Processing:**

- `true` if system uses parallel iteration
- `false` for sequential processing
- Parallel systems can process entities faster

**Subsystem Info:**

- For multi-subsystem systems (advanced feature)
- Shows entity count per subsystem

## ⚠️ Troubleshooting

### Debug Viewer Shows "Debug mode is disabled"

**Solution:**

1. Go to `Project > Project Settings`
2. Navigate to `GECS` category
3. Enable "Debug Mode" checkbox
4. Restart your game

> 💡 **Performance Note**: Debug mode adds overhead. Disable it for production builds.

### No Entities/Systems Appearing

**Possible causes:**

1. Game isn't running - Press F5 or F6 to run from editor
2. World not created - Verify `ECS.world` exists in your code
3. Entities/Systems not added to world - Check `world.add_child()` calls

### Component Properties Not Updating

**Solution:**

- Component properties update when they change
- Properties without `@export` won't be visible
- Make sure your systems are modifying component properties correctly

### Systems Not Toggling

**Possible causes:**

1. System has `paused` property set - Check system code
2. Debugger connection lost - Restart the game
3. System is critical - Some systems might ignore toggle requests

## 🎯 Best Practices

### During Development

✅ **Do:**

- Keep debug viewer open while testing gameplay
- Sort systems by time regularly to catch performance regressions
- Use entity search to track specific entities
- Disable systems to test game behavior

❌ **Don't:**

- Leave debug mode enabled in production builds
- Rely on system toggling for game logic (use proper activation patterns)
- Expect perfect frame timing (debug mode adds overhead)

### For Performance Tuning

1. **Baseline first**: Run game without debug viewer, note FPS
2. **Enable debug viewer**: Identify expensive systems
3. **Focus on top 3**: Optimize the slowest systems first
4. **Measure impact**: Re-check execution times after changes
5. **Disable debug mode**: Always profile final builds without debug overhead

## 🚀 Advanced Tips

### Custom Component Serialization

If your component properties aren't showing up properly:

```gdscript
# Mark properties with @export for debug visibility
class_name C_CustomData
extends Component

@export var visible_property: int = 0  # ✅ Shows in debug viewer
var hidden_property: int = 0           # ❌ Won't appear
```

### Relationship Debugging

Use the debug viewer to verify complex relationship queries:

1. **Create test entities** with relationships
2. **Check relationship display** in Entities panel
3. **Verify relationship properties** are correct
4. **Test relationship queries** in your systems

### Performance Profiling Workflow

Combine debug viewer with Godot's profiler:

1. **Debug Viewer**: Identify slow ECS systems
2. **Godot Profiler**: Deep-dive into specific functions
3. **Fix bottlenecks**: Optimize based on both tools
4. **Verify improvements**: Check both metrics improve

## 📚 Related Documentation

- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding entities, components, and systems
- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - Optimize systems identified as bottlenecks
- **[Relationships](RELATIONSHIPS.md)** - Working with entity relationships
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

## 💡 Summary

The Debug Viewer is your window into the ECS runtime. Use it to:

- 🔍 Monitor system performance and identify bottlenecks
- 🎮 Inspect entities and components in real-time
- 🔗 Visualize relationships between entities
- ⚡ Toggle systems on/off for debugging
- 📊 Track entity counts and archetype distribution

> **Pro Tip**: Pop out the debug viewer to a second monitor and leave it visible while developing. You'll catch performance issues and bugs much faster!

---

**Next Steps:**

- Learn about [Performance Optimization](PERFORMANCE_OPTIMIZATION.md) to fix bottlenecks you discover
- Explore [Relationships](RELATIONSHIPS.md) to understand entity connections better
- Check [Troubleshooting](TROUBLESHOOTING.md) if you encounter issues

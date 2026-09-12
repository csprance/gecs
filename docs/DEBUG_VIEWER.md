# Debug Viewer

> **Real-time debugging and visualization for your ECS projects**

The GECS Debug Viewer provides live inspection of entities, components, systems, and relationships while your game is running. Perfect for understanding entity behavior, optimizing system performance, and debugging complex interactions.

## 📋 Prerequisites

- GECS plugin enabled in your project
- Debug mode enabled: `Project > Project Settings > GECS > Debug Mode`
- Game running from the editor (F5 or F6)

## 🎯 Quick Start

### Opening the Debug Viewer

1. **Run your game** from the Godot editor (F5 for main scene, F6 for current scene).
2. The **GECS Explorer** companion window opens beside the editor, leaving the running game visible.
3. Arrange the Explorer beside the game or move it to another monitor. The floating window contains all sessions, queries, entity tabs, watches, changes, and step controls.

Closing the companion window only hides it. Use **Show Explorer** in the bottom debugger's GECS transport to bring the same workspace back with its drafts, selection, watches, and history intact. **Always on top** is optional; the window does not block game/editor input.

### Finding your way around the Explorer

The **Entities** browser expands each row to show its components and relationships. Double-click to open an entity in a persistent, reorderable tab. The active tab has a close button; a dot marks unapplied edits. Right-click tabs to detach them, reveal their remote nodes, or choose whether they are included in captures and saved setups. Closing a tab with drafts requires applying or discarding them first.

The **Components** table and **Property Inspector** work together. Select a property, change its native Godot editor, then use **Apply to game** to save the value in the running session. **Apply & Step** applies all staged changes before advancing one unit while ECS is paused. Drafts and conflict controls appear beside the property editor. Authoritative values, including setter clamping, return after applying. These actions do not save project scenes or resources.

Choose **+ Add chart** for each property you want to plot. Use **Focus** in the charts header to give several plots the full sidebar height; select a property to return to editing. Up to 16 charts can coexist in an entity tab, each with its own close button, using one shared entity subscription. Charts retain up to 600 samples at 10 Hz; numeric values, vector channels, booleans, and enums are supported. **Views** hides or shows the charts and the optional relationship map independently. The **Relationships** table is always available: double-click a target to open it, or right-click to stage removal. Live refresh preserves its rows and selection. Drag the visible horizontal divider between **Components** and **Relationships** to resize the table; its divider position is included in saved layouts. In the relationship graph, a single click selects a node and dragging moves it; double-click opens an entity. Drag the **Drag to resize graph** handle below the map to change its height, and the divider beside the component table to change its width. **Open in window** moves the same graph into a freely resizable window; **Dock graph** or closing the window returns it without losing node positions or subscriptions. The embedded graph height is included in saved layouts. Use **+ Add** to stage components or relationships.

In **Queries**, results include component and relationship columns alongside optional property columns. **Build query** opens a bounded, scrollable filter builder with **All / Any / None** groups. Click a component to select it for additional property comparisons; remove components or individual comparisons with their × buttons. All and Any support property comparisons; None excludes component types, matching QueryBuilder's semantics. The generated code remains visible in the workbench. **Saved queries** contains named queries and history.

**Scratchpad** has syntax highlighting, binding/component completion, a saved-snippet picker, and a separate returned-value panel. Loading snippets never runs them. **Watches** shows shared entity subscriptions and declarative queries; selecting a watch displays live property values or query membership, and double-clicking those details opens the entity/property. Removing an entity watch closes its tab after drafts have been resolved.

**Systems** shows sortable last, minimum, maximum, and average timings, entity/archetype counts, execution order, and enabled state. The summary identifies the fastest and slowest active systems in the last run. Right-click for script navigation, enable/disable, and break-before actions; hover a system for additional recorded metrics.

**Changes** separates **Capture comparison** from **Live activity**. Capture the investigation before and after an experiment, choose the two captures, then Compare. Selecting a row shows full before/after values in adjacent panes with changed lines highlighted. Repeating Compare replaces the comparison instead of appending duplicate rows. Double-click a property to return to its entity inspector.

The compact header distinguishes **Live**, **ECS paused**, and **Godot break**; hover the state for execution details. Context menus are available on entities, properties, relationships, systems, watches, and changes.

Secondary actions use compact, quiet buttons; Apply and Step retain primary emphasis. Header actions keep their natural height instead of stretching to match helper text. Resize grips remain visible. The Explorer's colors, spacing, typography, and primary-action styling are scoped to its own workspace and detached windows. They follow the editor's UI scale without changing the rest of Godot's theme.

> 💡 **Debug Mode Required**: If you see an overlay saying "Debug mode is disabled", go to `Project > Project Settings > GECS` and enable "Debug Mode"

## 🔍 Features Overview

Explorer owns entity and system inspection; the bottom GECS debugger tab contains transport controls, step logs, breakpoints, and **Show Explorer**.

### Systems

Use the **Systems** page to compare last, minimum, maximum, and average execution times, entity/archetype counts, order, and status. Click a column heading to sort. Select a system and use **Enable / disable**, **Break before**, **Open script**, or **Reset timings**. Rows preserve selection while the authoritative digest reconciles additions and removals.

### Entities and relationships

The paged entity browser filters by entity name. Open an entity to inspect its component fields, relationships, and incoming links, stage edits, or add charts. Query expressions and the query builder handle more specific searches. Open the entity graph to explore relationship neighborhoods, and detach a view or graph when you need it on another monitor.

### Refresh and connection behavior

Visible entity lists, systems, watches, and live graphs refresh at up to **2 Hz**. The overview defaults to **1 second** and retains its own rate and freeze controls. Hidden views stop automatic reads; existing chart history is retained with gaps when sampling resumes. Explicit one-shot queries run only on request.

Missing replies time out after **3 seconds**, allowing refreshes to resume. Attachment retries automatically, and a lightweight heartbeat recovers missed state changes. Edits and other mutations are not retried: if a reply is lost, the UI reports an unknown outcome and reads current state. Godot script breaks suspend polling; an ECS-only pause still permits inspection.

The old **Entities / Systems** debugger-tab trees, capture-category checkboxes, and whole-tab **Pop Out / Pop In** controls have been retired. Use Explorer's companion window and detached entity/graph views instead. No Godot queue-limit increase is required.

See [Debugger transport](DEBUGGER_TRANSPORT.md) for protocol details and validation, and [Step Debugger](STEP_DEBUGGER.md) for stepping and the `World.debug_*` APIs.

## 🔧 Common Workflows

### Performance Optimization Workflow

1. **Sort systems by execution time** (click "Last ms" header)
2. **Identify slowest system** (top of sorted list)
3. **Read system columns and tooltips** for entity count, archetype count, and detailed metrics
4. **Review system implementation** for optimization opportunities
5. **Apply optimizations** from [Performance Optimization](PERFORMANCE_OPTIMIZATION.md)
6. **Re-run and compare** execution times

### Debugging Workflow

1. **Identify the problematic entity** using search/filter
2. **Open the entity** to view all components
3. **Watch component values** update in real-time
4. **Toggle related systems off/on** to isolate the issue
5. **Check relationships** if entity interactions are involved
6. **Fix the issue** in your code

### Testing System Dependencies

1. **Run your game** from the editor
2. **Disable systems one at a time** using **Enable / disable**
3. **Observe game behavior** for each disabled system
4. **Document dependencies** you discover
5. **Design systems to be more independent** if needed

## 📊 Understanding System Metrics

The Systems page exposes metrics in columns and row tooltips:

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

- **[Step Debugger](STEP_DEBUGGER.md)** - Pause and step the ECS with a mutation log, breakpoints and an entity graph
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


## Connection and activity status

Explorer keeps connection state in its top toolbar: **Connected · Live**, **ECS paused**, **Godot break**, or **Session ended**. The last world path remains visible after stopping the game. Entity tables show **Frozen data**, drafts remain local, and runtime actions stop sending commands. Starting another game establishes a new world identity; previous session IDs are never reused for edits.

The compact activity line below the toolbar reports the latest action or error. **Activity** opens the last 50 messages with timestamps. There is no separate bottom status row. The persistent connection badge stays visible even when another action replaces the activity message.

## ECS snapshot files

1. **Pause ECS**, then choose **State → Export ECS snapshot…** to write a `.gecs-state.json` file.
2. Change supported component values or entity enabled states through normal gameplay or Explorer edits.
3. Pause ECS again and choose **State → Restore component values…**. Select the file to see a preview; opening the file changes nothing.
4. Review the preview, then choose **Restore values**. ECS stays paused so you can inspect the result or step forward.

The file contains entity identities, aliases, node paths, component metadata and typed values, plus relationship descriptions. Typed values retain their exact Variant types; reference fields remain inspection data. Import parses JSON and never executes snippets or loads resource scripts from the file.

Restore matches existing entities by unique alias, falling back to node path. The world must have matching entity, component and relationship membership, entity scripts, and component property schemas. Missing entities and structural differences are reported before mutation. Resolve local drafts before restoring. Values and identities are checked again when you confirm; a conflicting change requires a fresh preview.

This is a debugging aid, **not a full-game save system**. Restore changes supported component properties and entity enabled states only. It does not recreate entities or components, modify relationships, restore shared resources, rewind system timers, or restore physics, random generators, arbitrary nodes or scene state. Project scenes and resources are not saved. Restoring values uses normal setters and observer notifications. Observer side effects can produce a partial restore; the result reports the number of applied operations and the failure instead of claiming rollback.

Exports and imports are limited to 1,000 entities and 8 MiB, with at most 128 changed fields per entity in a restore. Snapshot capture only scans on explicit request; it adds no idle recording. For a complete save/load feature, use game-specific serialization that explicitly covers the state your game needs.


## World overview

The permanent **World** tab in Explore replaces the getting-started page. It shows total and enabled entities, component instances and types, relationships and relation types, systems and observers, populated archetypes, and cached queries. Counts cover the whole selected world, including disabled entities, rather than the current browser page.

Two charts default to population and the sum of active systems' latest execution times. Each chart's selector can also show enabled entities, component instances, relationships, archetypes, active systems, cached queries, or observers. Readouts show the current value and window min/max; hover over a chart to inspect a sample. Count cards show the net change across the selected window. System time is sampled from the existing profiler: runs can come from different frames, so this is not total frame time. Unmeasured timings display a dash. The timing table includes latest and average durations; open **Systems** for the full min/max/average breakdown.

Double-click a component or relationship type to run a matching query. The overview remains available beside entity tabs and cannot be closed. By default it refreshes once per second only while visible, with one outstanding request. **Options** offers 0.5, 1, or 2-second refreshes, a 30, 60, or 120-second chart window, and top 12, 24, or 48 summary rows. History retains at most two minutes and 240 samples. Column headers sort the displayed rows; refreshing preserves row identity and selection. Returning after a sampling gap starts a fresh chart segment; reconnecting to a new world clears its history. Stopping the game preserves the last overview with a frozen-data notice.

Overview requests read archetype membership, entity enabled states, relationships, and cached system timings. They do not inspect component property values or enable recording. Hover over the dashboard status line to see collection time and timing caveats.


**Freeze view** holds only the dashboard; it never pauses ECS or the game. The refresh icon collects one new overview even while frozen. A response already in flight when you freeze is ignored unless it came from an explicit manual refresh. Use Options to hide charts or clear their history.

Refresh rate, chart selections, history window, row limit, and chart visibility are saved locally per project and included in workspace setup export/import. Importing settings does not issue a query, run a snippet, apply an edit, or request an immediate refresh. Freeze is a temporary view state, not a saved pause command.

**Copy overview as JSON** copies the last collected world summary and samples from the selected window. **Copy chart samples as CSV** copies timestamped numeric world metrics (unmeasured values are blank). Right-click a summary table to copy its displayed rows. These are aggregate analysis exports; use **State → Export ECS snapshot** for component property data.


## Incoming and outgoing relationships

An entity's **Relationships** table shows both directions. **Outgoing** links are owned by the inspected entity and point to the entity named in the row. **Incoming** links are owned by the named source entity and point to the inspected entity. For example, if `Coin` owns a `C_OwnedBy → Hero` relationship, inspecting Hero shows `Incoming · C_OwnedBy · Coin`. No reciprocal component or relationship is added to Hero.

Double-click either direction to open the other entity, or right-click to reveal its Remote Scene Tree node. Incoming links must be edited or removed on their source entity; the target view does not offer a misleading removal action. Disabled sources are included. Refresh preserves row selection and double-click behavior; self-links appear once in each direction.

Incoming links update with normal entity inspection and watches and are included in focused comparisons. They are derived from the world's relationship-bearing archetypes only when inspection is requested; no background index or world-wide recording is introduced. At most 256 incoming rows are returned per inspected entity, with a visible `256+ incoming` count when truncated. Whole-world snapshot files retain each owned outgoing link once, rather than duplicating it as an incoming link on its target.

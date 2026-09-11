# Step Debugger

> **Pause the ECS and run it forward one frame, group, system, archetype or entity at a time, with a log of everything each step changed.**

The step debugger is a forward-only debugger for the GECS world. It does not rewind or restore state; it lets you stop the ECS at a system boundary, advance it in controlled units, see exactly which components, properties, relationships and entities each unit touched (and who caused it), break when something interesting happens, and watch an entity and its relationships as a live graph while you step.

It works from the editor's GECS debugger tab and from code / headless tests through the `World.debug_*` API.

The Explorer also provides explicit **State → Export ECS snapshot…** and **Restore component values…** actions. These restore selected kinds of data from a file; they do not rewind the stepper or restore the full game. See [ECS snapshot files](DEBUG_VIEWER.md#ecs-snapshot-files).

## How pausing works

Only ECS processing pauses. The game keeps running `_process` / `_physics_process` and keeps calling `ECS.process(delta, group)` every frame; while paused those calls return immediately unless a step is pending for that group. The SceneTree, physics, tweens and animation are not paused.

Because the game's own `process()` calls drive the steps, the order of groups, the delta each system sees and the timer advances stay exactly what the game produces. Systems in a group run in their live order, `SystemTimer`s advance once per group pass, and PER_SYSTEM / PER_GROUP command buffer flushes happen where they happen live.

A pause requested from the editor (or `debug_pause()`) may land mid-frame. The first paused `process()` call only settles the pause (it records the sweep baseline and the current frame id); it can still service a SYSTEM / GROUP / ARCHETYPE / ENTITY step, but a FRAME step waits for the next iteration boundary.

## Granularities

| Kind | What one step runs |
|---|---|
| `FRAME` | One main-loop iteration: every process group call that shares the same `Engine.get_process_frames()` value. Starts on the first call of the next iteration and completes on the first call of the one after (without running it). |
| `GROUP` | The rest of the current process group, including its PER_GROUP command flush. |
| `SYSTEM` | The next system in the group, exactly as the live loop runs it (`_handle`, including the PER_SYSTEM flush). When the last system has run and a PER_GROUP flush is pending, the next step is the flush itself, shown as `(group flush)`. |
| `ARCHETYPE` | The next `process()` call of the current system: one archetype (or the single post-filtered call for queries with property / group / relationship post-filters). |
| `ENTITY` | Like `ARCHETYPE`, but every entity in the **step set** runs as its own `process()` call, in archetype order; contiguous entities outside the set still run together. With an empty step set it behaves like `ARCHETYPE`. |

Inactive, paused and timer-gated systems are skipped and listed in the step log.

The **step set** ("Step through these entities") is a set of entities you pick in the entity tree (multi-select, right-click, *Add to step set*, or *Use selected entities* under *Step options*) or set from code with `debug_set_step_entities([...])`. Entities that are removed leave the set on their own.

## The step log

Every step (and every breakpoint hit, and every batch of mutations made outside a step while paused) produces one log entry with the journaled ops. Ops are recorded from the World's mutation funnels, so direct calls, `CommandBuffer` flushes and observer callbacks are all captured.

| Op | Meaning | Detail columns |
|---|---|---|
| `prop_set` | A component property changed through a setter that emits `property_changed` | component.property, old -> new |
| `sweep_set` | A property changed **without** an emitting setter, caught by the diff sweep | component.property, old -> new |
| `comp_add` / `comp_remove` | Component added / removed | component type |
| `rel_add` / `rel_remove` | Relationship added / removed | relation type, target |
| `entity_add` / `entity_remove` | Entity added to / removed from the world | node path, component types |
| `entity_enabled` | `entity.enabled` changed (`World.disable_entity` / `enable_entity` or a direct write) | enabled |
| `event` | `World.emit_event()` | event name, payload |

The **cause** column says who made the change: empty for a direct write inside the system, `cmd` inside a CommandBuffer flush, `observer:<name>` inside an observer callback (nested causes are joined with `>`, e.g. `cmd>observer:HealthObserver>cmd`), `(sweep)` for sweep hits and `(external)` for changes made outside any step. The system column names the system that was running.

The pane keeps the last 200 entries; each entry holds at most 2000 ops (marked `+` when truncated). Values are rendered for transport: objects become labels, containers are capped, strings are truncated.

## The diff sweep

Components that assign fields directly (`health.hp -= 10` with a plain `@export var hp`) do not emit `property_changed`, so nothing journals them. While paused, the stepper diffs every script variable of every component against the previous step after each step and reports the differences as `sweep_set` ops. Writes that did go through an emitting setter are not reported twice.

The sweep costs O(entities x properties) per step, which is fine because the world is paused. It is on by default; the *Detect unreported property changes* checkbox under *Step options* (or `debug_set_sweep(false)`) turns it off. It never runs while the game is live.

## Breakpoints

Breakpoints pause a live world:

- **System**: pause *before* the system runs (the cursor points at it; *Step System* runs it). Set from the BP column checkbox in the systems tree or its context menu.
- **Component added / removed**: pause right after the system whose flush or direct call added / removed a component of that type. Set from a component row's context menu.
- **Entity touched**: pause right after the system that journaled any op on that entity. Set from an entity row's context menu (*Break when touched*).

A component / entity breakpoint hit inside a PER_GROUP flush pauses after the flush; one hit outside `process()` (game code between frames) pauses at the next `process()` call. The log entry for a hit is tagged `break:` and shows the ops that led to it. During a `GROUP` or `FRAME` step a breakpoint hit stops the step early.

While any component / entity breakpoint exists the journal also runs live (ops are kept per system and dropped when no breakpoint fires), so the tab can show what happened right before the hit. Systems with no breakpoints pay nothing beyond one boolean check.

## The graph view

Right-click an entity row and pick *Open graph* (with several rows selected, one graph for all of them). A floating window opens showing the **watched** entities as nodes with their components listed inside, and their relationships as connections: outgoing edges leave from the relationship rows of a node, incoming edges from other entities arrive at the header row. Entities outside the watch set that relate to a watched one appear as stubs; archetype (script) targets, component-instance targets and the wildcard target get small nodes of their own. *Depth* expands the neighbourhood by that many relationship hops; *Add selected* merges the entity tree's selection into the window's watch set.

Open as many graph windows as you like, one per entity or per group of entities; each has its own watch set, depth and *Show live* toggle. While paused every window refreshes after every step and the entities the step touched (and relationships it added) are highlighted; with *Show live* on it refreshes at the entity poll rate while the game runs. Node positions persist across refreshes; *Arrange* re-runs the auto layout. Closing the window drops its watch in the game. The windows are separate from the debugger tab, so they stay put when you switch editor tabs or pop the GECS tab out.

## Using the editor tab

The debugger uses one full-width workspace with **Entities**, **Systems**, **Step log**, and **Breakpoints** tabs. Switching tabs preserves filters, selection, and log history. The shared toolbar stays available on every tab:

- **Pause / Resume**: only the action relevant to the current state is shown. ECS pausing leaves the rest of the scene running.
- **Step by**: choose Frame, Group, System (the default), Archetype, or Entity, then press **Step**. Stepping while live pauses ECS first.
- **Step options**: set the number of steps per click, use selected entities as the step set, clear the set, or toggle the property sweep. The Step button shows the count when greater than one.
- **Capture settings**: entity lifecycle events, component property changes, system timing, and refresh rates. Closing this popup keeps the capture configuration active.
- **Pop Out / Pop In**: move the whole workspace into a separate window and back without losing the selected tab.

The status line shows the paused cursor, unit progress, and pending steps. **Step log** entries expand to show their operations; turn off **Follow latest** to inspect earlier entries without scrolling to every new step. **Breakpoints** lists enable toggles, hit counts, and removal actions; its tab title shows the count.

Graphs occupy no space in this workspace. Select one or more entities and click **Graph selected**, or right-click an entity and choose **Open graph**. Every request opens a separate graph window. Empty selections do nothing, and late updates cannot reopen a window after you close it. Explicit watches started from game code also open a graph window; use a fresh graph ID to reopen one closed in the editor during the same session.

The systems tree shows the cursor in the **Step** column and a breakpoint checkbox in the **BP** column; the rows touched by the last step are tinted in both trees.

## Headless / code API

```gdscript
var world := ECS.world

world.debug_pause()
world.debug_step(GECSStepper.Kind.SYSTEM)          # runs on the game's next process() call
world.debug_step(GECSStepper.Kind.ARCHETYPE, 3)    # three archetype units
world.debug_set_step_entities([player, boss])      # entities or instance ids
world.debug_step(GECSStepper.Kind.ENTITY)

world.step_completed.connect(func(kind, log):
	for op in log.ops:
		print(GECSStepper.OP_NAMES[op[0]], " ", op[2], " ", op[3], " ", op[7]))

var bp := world.debug_add_breakpoint({"kind": "component_added", "component": C_Dead})
world.debug_add_breakpoint({"kind": "system", "system_name": "CombatSystem"})
world.debug_add_breakpoint({"kind": "entity", "entity": player})
world.step_break_hit.connect(func(id, log): print("break ", id, " ", log.label))
world.debug_set_breakpoint_enabled(bp, false)
world.debug_remove_breakpoint(bp)

world.debug_graph_watch([player], 1)               # graph id 0 (the default)
world.debug_graph_watch([boss], 0, 7)              # a second graph, id 7
var graph := world.debug_graph_state()             # {watched, nodes, edges} of graph 0
world.debug_graph_close(7)
var state := world.debug_step_state()              # paused, cursor, breakpoints, ...
world.debug_resume()
```

Op records are flat arrays: `[op, entity_instance_id, entity_name, a, b, c, d, cause, system]` (see `GECSStepper.Op` for what `a`..`d` hold per op). Tests drive time by calling `world.process(delta, group)` themselves; a FRAME step needs a frame id source, so headless tests inject one: `world.debug_stepper().frame_id_provider = func(): return my_counter`.

## Debugger messages and commands

Game -> editor: `gecs:step_state` (the stepper state), `gecs:step_log` (one entry), `gecs:graph_state [graph_id, step_id, graph]` (one graph's payload; the editor opens a window per graph id, so a watch started from game code shows up in the editor too). Editor -> game: `gecs:step_pause`, `gecs:step_resume`, `gecs:step [kind, count]`, `gecs:step_set_entities [ids]`, `gecs:step_set_sweep [bool]`, `gecs:step_pull_state`, `gecs:breakpoint_add [spec]`, `gecs:breakpoint_remove [id]`, `gecs:breakpoint_set_enabled [id, bool]`, `gecs:breakpoint_clear`, `gecs:graph_watch [graph_id, ids, depth]`, `gecs:graph_pull [graph_id]` (no id pushes every open graph), `gecs:graph_close [graph_id]`. A re-subscribing tab receives the current step state with the snapshot.

## What stepping cannot reproduce exactly

- **Parallel processing** is ignored while stepping: units run on the main thread.
- **`ENTITY` steps change the call structure**: the system's `process()` (or subsystem callable) is invoked once per unit instead of once per archetype, with sliced copies of the entity and component arrays. Code that accumulates per-call state, or relies on zero-copy swap-remove hazards, behaves differently. `ARCHETYPE` steps pass the live arrays and are exact.
- **Timing metrics** for stepped runs exclude the time the world sat paused and do not feed the min / max / avg columns.
- **Timers advance once per group pass**, when the cursor enters the group; a group that is called while the cursor is busy elsewhere is skipped for that call, and its timers with it.
- A system that removes itself mid-unit is drained to its end inside the same call; a system freed from outside between steps is abandoned with a log row.
- The journal sees writes through the World funnels and, while paused, the sweep. A write made while the game is live and no breakpoint exists is not recorded anywhere.

## Cost when not in use

One boolean check in each mutation funnel, one per system per frame in the live loop and one at `process()` entry. The stepper object is created on first use. Systems' hot path (`_handle`) is untouched; the resumable execution used by `ARCHETYPE` / `ENTITY` steps is a separate code path that mirrors it batch by batch.

## Related

- [Debug Viewer](DEBUG_VIEWER.md) - the rest of the debugger tab
- [Observers](OBSERVERS.md) - the reactive counterpart; observer callbacks show up as `observer:<name>` causes
- [Core Concepts](CORE_CONCEPTS.md) - systems, groups, command buffers, timers

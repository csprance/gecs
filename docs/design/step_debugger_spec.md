# GECS Step Debugger: plan and specification (as built)

Status: implemented on `main` in five local commits (a4ad347, a19d16a, 2bb1cd7, 76a85fd, 7fe0285), not pushed, shipping as GECS 9.3.0. Headless test suites pass; the editor UI has not yet been exercised visually. This document is the review package: what was asked for, what was decided, what was built, how it behaves, where it is weak.

Background: this replaced a parked Redux-style time-travel debugger (research in `docs/design/time_travel_debugger.md`). Live rollback carried too many caveats (Godot node state, freed objects, signal side effects), so the feature was re-cut as forward-only stepping, which is exact because nothing is ever restored.

Repository: GECS, a Godot 4.6+ Entity Component System addon (GDScript). Relevant runtime: `World` owns entities, systems and archetypes; `System._handle(delta)` runs a system's query over archetypes; `CommandBuffer` defers structural changes with PER_SYSTEM / PER_GROUP / MANUAL / PER_CALLBACK flush modes; `Observer` fires callbacks on component and relationship events; the editor has a "GECS" debugger tab fed by `EngineDebugger` messages.

## 1. Goals and locked decisions

1. Granularities: FRAME, GROUP, SYSTEM, ARCHETYPE, ENTITY. ENTITY is opt-in through a "step set" ("step through these entities"); with an empty set it behaves like ARCHETYPE.
2. Pause is ECS-only. The SceneTree, physics, tweens and animation keep running; the game keeps calling `ECS.process(delta, group)` every frame and those calls drive the steps.
3. Breakpoints v1: system about to run, component type added, component type removed, entity touched. Property-condition breakpoints deferred.
4. Diff sweep after every step while paused (catches writes that bypass emitting setters); never runs while live.
5. Flight recorder (ring buffer while live): deferred.
6. Debugger tab improvements: transport bar, run-order cursor and breakpoint toggles on the systems tree, step log, last-changed highlighting.
7. Public headless API on `World` plus a `step_completed` signal so tests and tooling can drive it without the editor.
8. First commit: fix two pre-existing bugs found during research (relationship read-path archetype desync; `Entity.add_components` not wiring `parent` / `property_changed`).
9. Entity relationship graph view with a "Show live" toggle. Revised after first use: the graph must not live inside the tab (it made the tab too tall and the user wants several graphs at once), so graphs open as floating windows, one per entity or selection.

Non-goals: rollback / restore, pausing the SceneTree, recording while live, property-condition breakpoints, parallel execution while stepping.

## 2. Architecture

Game side (runs in the game process):

- `addons/gecs/debug/step/gecs_stepper.gd` (`GECSStepper`, RefCounted, created lazily by `World._get_stepper()`): paused flag, cursor, request queue, step set, breakpoints, journal, sweep, graphs, editor sends, command handling.
- `addons/gecs/debug/step/gecs_diff_sweep.gd` (`GECSDiffSweep`): snapshot and diff of every `PROPERTY_USAGE_SCRIPT_VARIABLE` property of every component in the world.
- `addons/gecs/debug/step/gecs_graph_state.gd` (`GECSGraphState.build(world, watched, depth)`): builds the graph payload.
- `World`: three bools (`_step_paused`, `_step_hooks_active`, `_step_live_checks`), a gate at the top of `process()`, live-check calls around each system and after the PER_GROUP flush, one hook line in every mutation funnel, the public `debug_*` API, signals, and command routing.
- `System`: a stepper-only resumable execution path (`_step_begin`, `_step_next_batch`, `_step_enter_phase`, `_step_materialize_*`, `_step_run`, `_step_end`) that mirrors `_handle` batch by batch. `_handle` itself is untouched.
- `CommandBuffer.execute`: pushes cause `"cmd"` around the flush when hooks are active.
- `Entity._on_enabled_changed`: hook for enable / disable.
- `GECSEditorDebuggerMessages`: three new messages and a shared `serialize_relationship()`.

Editor side (runs in the editor process):

- `gecs_editor_debugger_tab.gd/.tscn`: the existing tab, extended with a step pane on the right of the entity / system trees, Step and BP columns on the systems tree, multi-select entity rows, context menu items, row tinting, and graph window management.
- `gecs_editor_step_panel.gd` (`GECSEditorStepPanel`): transport, step set row, status line, Step log / Breakpoints tab pair. Builds its controls in code.
- `gecs_editor_graph_window.gd` (`GECSEditorGraphWindow`, a `Window`) hosting `gecs_editor_graph_panel.gd` (`GECSEditorGraphPanel`, a GraphEdit view). One window per graph id.
- `gecs_editor_debugger.gd`: `_capture` branches routing the three messages to the tab.

Transport: editor to game commands go through `EditorDebuggerSession.send_message("gecs:<name>", data)`, arrive at `ECS._on_debugger_message`, are forwarded to `World._handle_debugger_message`, which routes `step*`, `breakpoint_*` and `graph_*` names to `GECSStepper.handle_command`. Game to editor messages go through `GECSEditorDebuggerMessages._send`, gated by `can_send_message()` (true only while a tab is subscribed) and mirrored to a `_test_sink` Callable for headless tests.

## 3. Pausing and stepping semantics

Game-driven model. Commands (from the editor or from `World.debug_*`) only mutate stepper state and queue step requests. Nothing runs at command time. Every `World.process(delta, group)` call does:

1. If paused: `stepper._process_paused(delta, group)` services queued requests that apply to this call, then returns. With no applicable request the call returns immediately (systems do not run).
2. If not paused and live checks are on (some breakpoint exists): `_live_process_entry`, `_live_before_system` (before `_handle`), `_live_after_system` (after the slot re-check), `_live_after_flush` (after the PER_GROUP flush) can pause the world mid-frame.
3. Otherwise the normal live loop.

Cursor: `{group, delta, slot, system, in_system, units, unit_i}`. A cursor without a group adopts the next `process()` call whose group has systems (`_ensure_group`): timers for that group are advanced once and the delta is captured. A call for a different group while the cursor is busy is skipped for that call (its timers do not advance). When the last system has run, if any system in the group has a pending PER_GROUP flush the next step is the flush itself (labelled `(group flush)`), otherwise the group closes.

Settling: a pause may land mid-frame. The first paused `process()` call settles the pause (rebases the sweep baseline, records the frame id). SYSTEM / GROUP / ARCHETYPE / ENTITY requests are serviced on that call; a FRAME request waits for the next iteration boundary. A pause caused by a live breakpoint hit settles immediately.

Granularities:

| Kind | One step runs |
|---|---|
| FRAME | One main-loop iteration: every `process()` call sharing the same `frame_id_provider()` value (default `Engine.get_process_frames`). Starts on the first call of the next iteration; completes on the first call of the one after, without running it. |
| GROUP | The rest of the current group including its PER_GROUP flush. |
| SYSTEM | The next system exactly as the live loop runs it: `system._handle(delta)` including the PER_SYSTEM flush and the slot re-check. |
| ARCHETYPE | The next `process()` call of the current system: one archetype, or the single post-filtered call for queries with property / group / relationship post-filters. Passes the live arrays (exact). |
| ENTITY | Like ARCHETYPE, but each entity in the step set runs as its own `process()` call with sliced copies of the entity and component arrays; contiguous non-members run together; order is preserved. |

Batches for ARCHETYPE / ENTITY are materialized lazily (the next batch is resolved only when it is about to run), so later subsystems and archetypes observe earlier units' mutations the same way the live loop does. Inactive, paused and timer-gated systems are skipped and listed in the step log. A system that removes itself mid-unit is drained to its end in the same call; a system freed from outside between steps is abandoned with a log row. During a GROUP or FRAME step a breakpoint hit stops the step early.

Resume finishes a partially stepped system first, then returns to live processing.

## 4. The journal

Op record (flat array, index meaning fixed):

```
[op, entity_instance_id, entity_name, a, b, c, d, cause, system]
```

| Op | a | b | c | d |
|---|---|---|---|---|
| PROP_SET / SWEEP_SET | component type | property | old | new |
| COMP_ADD / COMP_REMOVE | component type | component instance id | | |
| REL_ADD / REL_REMOVE | relation type | target label | relationship instance id | target entity instance id (0 if not an entity) |
| ENTITY_ADD / ENTITY_REMOVE | node path or name | component type names | | |
| ENTITY_ENABLED | enabled | | | |
| EVENT | event name | payload | | |

`cause`: `""` direct write inside the system, `"cmd"` inside a CommandBuffer flush, `"observer:<name>"` inside an observer callback (nesting joined with `>`, e.g. `cmd>observer:Chain>cmd`), `"(sweep)"` for sweep hits, `"(external)"` outside any step. `system` is the label of the system running when the op was recorded.

Sources: the World mutation funnels (`_on_entity_component_added/removed`, `_on_entity_component_property_change`, `_on_entity_relationship_added/removed`, the batch relationship handler, `add_entity`, `remove_entity`, `emit_event`) and `Entity._on_enabled_changed`. ENTITY_REMOVE is recorded before `entity._world` is cleared, with the component list. Values are encoded at record time (`encode_value`: objects become labels, strings truncated to 256 chars, containers capped at 32 entries).

Limits: 2000 ops per log entry (`truncated` flag), 64 retained logs in the game, 200 rows retained by the editor pane.

Log entry shape:

```
{step_id, kind, kind_name ("frame"|"group"|"system"|"archetype"|"entity"|"break"|"external"),
 label, frame, group, system_id, systems: [names], skipped: [names],
 ops: [...], op_count, truncated, ms, touched: [entity instance ids], break_info: {}}
```

Publication order after a step: sweep, external bucket (ops made while paused outside any step, published first as its own entry), `gecs:step_log`, `gecs:step_state`, `gecs:graph_state` for every open graph, per-system last_run_data for the tab's metrics, then `World.step_completed(kind, log)`.

Sweep: `GECSDiffSweep` rebases on pause and after every step, diffs after each step, and reports differences as SWEEP_SET ops with cause `(sweep)`. Properties already journaled through an emitting setter in the same step are deduplicated (`note_written`). Cost O(entities x properties) per step, acceptable because the world is paused. Toggle: `debug_set_sweep(bool)` / the Sweep checkbox.

## 5. Breakpoints

Spec dictionary: `{"kind": "system", "system_id": int | "system_name": String}`, `{"kind": "component_added" | "component_removed", "component": Script | path}`, `{"kind": "entity", "entity": Entity | instance id}`. `add_breakpoint` returns an int id; records carry `{id, kind, kind_name, label, enabled, hits, system_id, comp_key, entity_id}`.

Behaviour while live:

- SYSTEM: `_live_before_system` pauses before the system runs; the cursor points at it and Step System runs it.
- COMPONENT_* / ENTITY: the hook sets `break_requested`; `_live_after_system` pauses after the current system (the live scratch journal becomes that system's log, tagged `kind_name = "break"` with `break_info`). A hit inside a PER_GROUP flush pauses after the flush; a hit outside `process()` pauses at the next `process()` call.

While any component / entity breakpoint exists the journal also runs live: ops are kept in a scratch buffer per system and dropped when nothing fires, so the log at a hit shows what led to it. Systems with no breakpoints pay one boolean check. Breakpoints survive `World.purge()` (entity breakpoints whose entity is gone are pruned). Signal: `World.step_break_hit(breakpoint_id, log)`.

## 6. Graph views

`GECSGraphState.build(world, watched, depth) -> {watched: [iids], nodes: [...], edges: [...]}`.

- Entity node: `{key: "e:<iid>", kind: "entity", instance_id, id, name, path, enabled, watched, stub, dangling, components: [{id, type, data}]}`.
- Script (archetype target) node: `{key: "s:<path>", kind: "script", label}`; component-instance target: `{key: "c:<iid>", kind: "component", label, data}`; wildcard: `{key: "w:*", kind: "wildcard"}`.
- Edge: `{key: "r:<relationship iid>", rel_id, from, to, relation_type, relation_data, target_type, target_data}`.
- Entities outside the watch set that relate to a watched one are included as stubs so inbound edges are visible (there is no reverse relationship index in GECS; inbound edges come from a scan of `world.entities`). `depth` expands the neighbourhood by that many hops in both directions.

Multiple graphs: the stepper keeps `graphs: {graph_id: {watch: [iids], depth}}`. `set_graph_watch(entities, depth, graph_id)` replaces one graph's watch (empty list closes it), `close_graph(id)`, `graph_state(id)`, `send_graph_state(id | -1 for all)`. Every open graph is pushed after each step and each break. Removed entities are pruned from every graph's watch list. Editor graph ids start at 1; code users default to id 0; a payload for an id the tab does not know opens a window (so a watch started from game code appears in the editor).

## 7. Public API (World)

```
debug_stepper() -> GECSStepper
debug_pause(); debug_resume(); debug_is_paused() -> bool
debug_step(kind: GECSStepper.Kind, count := 1)
debug_set_step_entities(entities: Array)          # Entity instances or instance ids
debug_add_breakpoint(spec: Dictionary) -> int
debug_remove_breakpoint(id); debug_set_breakpoint_enabled(id, bool); debug_clear_breakpoints()
debug_set_sweep(enabled: bool)
debug_graph_watch(entities, depth := 0, graph_id := 0); debug_graph_close(graph_id := 0)
debug_graph_state(graph_id := 0) -> Dictionary
debug_step_state() -> Dictionary
signal step_completed(kind: int, info: Dictionary)
signal step_break_hit(breakpoint_id: int, info: Dictionary)
```

State shape (`debug_step_state()` and `gecs:step_state`):

```
{paused, cursor: {has_group, group, slot, system_id, system_name, in_system, unit_index, unit_count, unit_label, next_label},
 step_entities: [iids], sweep_enabled, breakpoints: [records], graphs: {id: {watch, depth}},
 step_counter, pending_requests, frame_step_active, break_info}
```

Headless tests drive time by calling `world.process(delta, group)` themselves; FRAME steps need `world.debug_stepper().frame_id_provider = func(): return counter` because `Engine.get_process_frames()` is static headlessly.

## 8. Debugger protocol

Game to editor: `gecs:step_state [state]`, `gecs:step_log [log]`, `gecs:graph_state [graph_id, step_id, graph]`. The snapshot sent on (re)subscribe includes the current step state when a stepper exists.

Editor to game: `gecs:step_pause`, `gecs:step_resume`, `gecs:step [kind, count]`, `gecs:step_set_entities [ids]`, `gecs:step_set_sweep [bool]`, `gecs:step_pull_state`, `gecs:breakpoint_add [spec]`, `gecs:breakpoint_remove [id]`, `gecs:breakpoint_set_enabled [id, bool]`, `gecs:breakpoint_clear`, `gecs:graph_watch [graph_id, ids, depth]`, `gecs:graph_pull [graph_id]` (no id: every open graph), `gecs:graph_close [graph_id]`.

## 9. Editor UI specification

Tab layout: `HSplit` with the existing entity / system trees on the left and the step pane (`GECSEditorStepPanel`, min width 420, non-expanding, draggable) on the right. The pane's minimum height is about 210 px and nothing in it declares a tall minimum, because the tab lives in the editor's bottom panel: a child whose minimum height exceeds the panel is grown in both directions by Godot and draws over the debugger's section tabs (this happened with the first layout, which stacked the log, breakpoints and a GraphEdit in a VSplit).

Step pane: row 1 Pause / Resume / Step: Frame, Group, System, Archetype, Entity, count spinbox (a step button while live pauses first); row 2 "Step set: N", Use selected entities, Clear set, Sweep checkbox; status line (`Live (N breakpoints)`, `Paused in group 'physics' > next: MoveSystem`, unit progress, pending steps); TabContainer with "Step log" (5 columns: #, Step / op, Kind / target, Ops / detail, ms / cause; one row per entry expanding to skipped systems, breakpoint hit, and ops; break rows red, external rows grey, sweep rows amber; Clear log) and "Breakpoints (N)" (enable checkbox, label, hits, remove button; Clear all).

Systems tree: column 8 "Step" shows the paused cursor, column 9 "BP" is a checkbox that adds / removes a system breakpoint; context menu "Break before run" / "Remove breakpoint". Entity tree: multi-select; context menu "Add to step set", "Break when touched", "Open graph" (applies to the whole selection when several rows are selected); component rows "Break when added" / "Break when removed". Rows touched by the last step are tinted in both trees.

Graph windows: `GECSEditorGraphWindow` (960x640, min 480x320, centred on the screen with the mouse) hosting a GraphEdit. Toolbar: Show live (pull at the entity poll rate while live; every step refreshes while paused), Depth 0..3, Add selected (merge the tree selection into this window's watch), Arrange, info label. Entity nodes list components inside; outgoing edges leave from the node's relationship rows, inbound edges arrive at the header row; touched entities get a highlighted title bar and added relationships flash. Node names are hashes of payload keys (GraphNode names cannot contain `:`), real keys in metadata; positions persist across refreshes; stale nodes are removed. Closing a window sends `graph_close`. `clear_all_data` (world swap / session end) closes every window without notifying.

Pop Out: moves the tab's `HSplit` into a `Window` sized to at least the content's combined minimum size (was fixed 1200x800, which cut off the toolbars once the pane existed).

## 10. Cost and invariants

- While no stepper exists: one boolean check in each mutation funnel, one at `process()` entry, one per system per frame (`_step_live_checks`, false unless a breakpoint exists). `System._handle` is untouched.
- `_step_hooks_active` is true while paused or while any component / entity breakpoint exists; `_step_live_checks` while any breakpoint exists.
- Stepping runs on the main thread; parallel processing is ignored while stepping.
- Steps never reorder groups or change deltas: the game's own calls define both.
- Timing metrics for stepped runs exclude paused time and do not feed min / max / avg.

## 11. Known limitations (documented in STEP_DEBUGGER.md)

- ENTITY steps change the call structure: `process()` is invoked once per unit with sliced copies, so code accumulating per-call state or relying on zero-copy swap-remove hazards behaves differently. ARCHETYPE steps are exact.
- Timers advance once per group pass when the cursor enters the group; a group called while the cursor is busy elsewhere is skipped for that call.
- The journal only sees writes through the World funnels and, while paused, the sweep; a live write with no breakpoint set is recorded nowhere (flight recorder deferred).
- The sweep reports old / new values only for script variables; nested resource contents are compared by deep copy.
- Instance ids are used as entity identity everywhere (step set, breakpoints, graphs, tints); id reuse after a free is possible in principle.

## 12. Implementation map

| Commit | Content |
|---|---|
| a4ad347 | `Entity.get_relationship/get_relationships` notify the World before emitting; `World._on_entity_relationship_removed` recomputes the archetype when the target is freed; `Archetype.remove_entity` drops dangling tail rows; `Entity.add_components` sets `parent` and connects `property_changed`. Suites `tests/core/test_relationship_read_path_cleanup.gd`, `test_add_components_signals.gd`. |
| a19d16a | `GECSStepper`, `GECSDiffSweep`, `GECSGraphState`; World gate, hooks, API, signals, command routing; System resumable path; CommandBuffer / observer causes; messages. Suites `tests/debug/test_stepper_pause`, `_unit_steps`, `_frame_step`, `_journal_and_sweep`, `_breakpoints`, `_graph_and_commands`. |
| 2bb1cd7 | Editor tab: step pane, graph pane, columns, menus, tints. Suite `tests/debug/test_editor_debugger_tab_step.gd`. |
| 76a85fd | `addons/gecs/docs/STEP_DEBUGGER.md`, DEBUG_VIEWER and README links, CHANGELOG 9.3.0, plugin.cfg 9.3.0, CLAUDE.md, skill notes. |
| 7fe0285 | Graph moved to floating windows (multi-graph protocol), compact step pane, pop-out sizing. |

Size since the 9.2.0 base: 47 files, about 6600 lines added. Key files: `addons/gecs/ecs/world.gd`, `system.gd`, `entity.gd`, `command_buffer.gd`, `archetype.gd`; `addons/gecs/debug/step/*.gd`; `addons/gecs/debug/gecs_editor_*.gd/.tscn`.

## 13. Verification status

- `tests/debug`: 103 tests pass (stepper semantics, journal, sweep, breakpoints, graph payloads, command channel, tab handlers with the scene instantiated headlessly including graph windows).
- `tests/core`: 466 pass after every commit.
- Full suite: 945 with one known wall-clock flaky test (`test_debug_tracking_process_mode`), passes alone.
- Not verified: the editor UI in a running editor (layout, popups, window behaviour, Pop Out). The first layout was found broken by the user; the second has only headless coverage (minimum sizes, node creation, routing).

## 14. Questions for the reviewer

1. Semantics: is "pause is ECS-only, steps are serviced inside the game's own `process()` calls" a sound model, or are there cases (nested `process()` calls, systems calling `ECS.process` themselves, multiple worlds) where the cursor gets confused? `Entity._on_enabled_changed` reads `ECS.world._step_hooks_active` rather than the entity's own world; is that acceptable?
2. FRAME detection through `Engine.get_process_frames()` equality: does `_physics_process` (which can run zero or several times per rendered frame) break the "one main-loop iteration" definition?
3. ENTITY slicing: is the "one `process()` call per step-set entity with sliced copies" contract clear enough, and are there hidden hazards with `safe_iteration = false` systems mutating the live arrays between units?
4. Journal completeness: which mutation paths in `World` might bypass the funnels (deserialization, `set_entity_range`, network sync, relationship batch APIs)? Is the sweep dedup against emitted PROP_SET ops correct when a setter writes a different property than the one named?
5. Breakpoint timing: pausing after the system for component / entity hits, but before the system for system hits. Is "after the PER_GROUP flush" for hits inside a flush the right choice?
6. Editor: the diagnosis of the broken layout (tab minimum height exceeded the bottom panel, Godot grew the control in both directions) and the fix (no tall minimums, graph in separate windows). Anything else in the tab likely to inflate its minimum size? Is a native `Window` child of the tab the right host for GraphEdit in the editor?
7. Multi-graph protocol: ids allocated by the editor from 1, id 0 for code, unknown ids auto-open windows, closing a window clears the game-side watch. Any race between `graph_watch` and `graph_state` on reconnect?
8. Cost claims: one bool per funnel and per system per frame while idle. Anything on the hot path that was missed (observer dispatch wrapper, CommandBuffer `traced` variable)?
9. Naming and API shape: `debug_*` prefix on `World`, `Kind` / `Op` / `BpKind` enums, flat op arrays instead of dictionaries (chosen for transport size). Anything that will age badly?
10. Missing tests you would add before release.

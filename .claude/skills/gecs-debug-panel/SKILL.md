---
name: gecs-debug-panel
description: Extend or modify the GECS editor debugger panel (`addons/gecs/debug/`) — the in-editor "GECS" tab that shows live entities, components, systems, relationships, and per-system metrics. Trigger when adding a new column, panel, status bar, or runtime control to the debugger; wiring a new `EngineDebugger` message from the running game to the editor; surfacing custom component or relationship data in the inspector tree; or fixing UI bugs in the existing debugger tab.
---

You are an expert in the GECS framework's **editor debugger plugin** — the `EditorDebuggerPlugin` that adds a "GECS" tab to Godot's Debugger dock and renders live entity/component/system state from the running game.

## Core mental model

The debugger has **three layers**, each in its own file:

1. **Game-side emitter** (`gecs_editor_debugger_messages.gd`) — `static` helpers wrapped around `EngineDebugger.send_message(...)`. Called from `world.gd`, `entity.gd`, `system.gd`, `component.gd` whenever interesting state changes. Each helper guards on `can_send_message()` (`not Engine.is_editor_hint() and OS.has_feature("editor")`) so it's a no-op in shipping builds.

2. **Editor-side router** (`gecs_editor_debugger.gd`) — extends `EditorDebuggerPlugin`. `_has_capture("gecs")` claims the `gecs:*` namespace; `_capture(message, data, session_id)` dispatches each `Msg.*` constant to a method on the tab. `_setup_session` creates and registers the tab Control.

3. **UI tab** (`gecs_editor_debugger_tab.gd` + `gecs_editor_debugger_tab.tscn`) — extends `Control`. Holds two `Tree` nodes (entities + systems), filter `LineEdit`s, status bars, and a periodic poll timer that requests live component data via the `POLL_ENTITY` message. Mutates `ecs_data: Dictionary` (the in-editor mirror of game state) and refreshes the trees from it.

A new debugger feature usually touches **all three** layers: emit a new message from the game, route it in `_capture`, render it in the tab.

## Key files to read before extending

- `addons/gecs/debug/gecs_editor_debugger.gd` — the routing plugin. Short (~130 lines) and worth reading top-to-bottom.
- `addons/gecs/debug/gecs_editor_debugger_messages.gd` — message constants in `Msg` dict + every static `send_*` helper. **Match the existing patterns exactly** when adding new messages.
- `addons/gecs/debug/gecs_editor_debugger_tab.gd` — the UI tab (large; ~2000+ lines). Skim the top for `@onready` field names, then jump to the handler for the message type closest to what you're building.
- `addons/gecs/debug/gecs_editor_debugger_tab.tscn` — the scene with `Tree`, `LineEdit`, button, and status-bar nodes. UI-only changes happen here.
- `addons/gecs/docs/DEBUG_VIEWER.md` — user-facing feature documentation. If you add a feature, update this file.
- `addons/gecs/plugin.gd` — registers the `EditorDebuggerPlugin`. Don't usually need to touch.

## Adding a new debugger feature — canonical workflow

### Phase 1 — Define the message

Add a constant to the `Msg` dictionary in `gecs_editor_debugger_messages.gd`:

```gdscript
const Msg = {
    # ... existing entries ...
    "SYSTEM_QUERY_RESULTS": "gecs:system_query_results",
}
```

The string value **must** be `gecs:` prefixed — `_has_capture("gecs")` only claims that namespace.

### Phase 2 — Write the game-side emitter

Add a `static func` next to similar helpers. Match their shape:

```gdscript
static func system_query_results(system: System, entity_count: int) -> bool:
    if can_send_message():
        EngineDebugger.send_message(Msg.SYSTEM_QUERY_RESULTS, [
            system.get_instance_id(),
            system.name,
            entity_count,
        ])
    return true
```

**Always** guard with `can_send_message()`. The first array element is conventionally an `instance_id` (an `int`) so the editor can build a stable id-keyed dictionary; node references don't survive `send_message` serialization, but `instance_id` does.

### Phase 3 — Call the emitter from the right hot path

Find the runtime location where the new state changes — usually in `world.gd` (entity/system lifecycle), `system.gd` (per-frame metrics, last-run data), or `component.gd` (`property_changed` emissions). Call the helper there:

```gdscript
# In system.gd after process() runs:
GECSEditorDebuggerMessages.system_query_results(self, entities.size())
```

Performance matters — these helpers run every relevant event in a development build. Avoid stringifying or duplicating large objects on the hot path; send ids and small payloads, let the tab look up details on demand.

### Phase 4 — Route the message editor-side

In `gecs_editor_debugger.gd`'s `_capture`, add an `elif` branch:

```gdscript
elif message == Msg.SYSTEM_QUERY_RESULTS:
    # data: [system_id, system_name, entity_count]
    debugger_tab.system_query_results(data[0], data[1], data[2])
    return true
```

Keep the comment matching the array layout — that's the only documentation of the message contract.

### Phase 5 — Render in the tab

Add the corresponding handler method to `gecs_editor_debugger_tab.gd`:

```gdscript
func system_query_results(system_id: int, system_name: String, entity_count: int) -> void:
    if not ecs_data.has("systems"):
        return
    var sys = ecs_data["systems"].get(system_id)
    if not sys:
        return
    sys["last_entity_count"] = entity_count
    _refresh_systems_tree()
```

Update `ecs_data` (the editor-side mirror) and call the appropriate refresh method (`_refresh_systems_tree`, `_refresh_entities_tree`, etc.) — don't directly mutate `Tree` items from message handlers. The refresh methods reconcile `ecs_data` against the visible tree, preserving sort/pin/expand state.

### Phase 6 — Wire up UI affordances

If the feature needs a button, column, or status indicator, edit `gecs_editor_debugger_tab.tscn` in the editor (or via `mcp__godot__scene-node-*` if scripting it). Then add `@onready var ...: ... = %NodeName` lookups at the top of `gecs_editor_debugger_tab.gd` and connect signals in `_ready()`.

For new tree columns: bump `system_tree.columns` (or `entities_tree.columns`), set per-column `set_column_expand`, `set_column_custom_minimum_width`, `set_column_clip_content`, and `set_column_title`. Look for the existing column setup in `_ready()` and follow its shape.

### Phase 7 — Reset / clear hooks

If the new state is mutable across game runs, also handle clearing it:
- `clear_all_data()` — called when a debug session starts. Add your new field initialization here.
- `exit_world()` — called when the game exits. Clean up any per-world state.
- `_on_session_started` / `_on_session_stopped` — toggle `active` flag.

Without this step, stale state from a previous run leaks into the next session.

## Existing message catalog (read before adding similar messages)

Already wired (each has emitter + router + handler):

- `WORLD_INIT`, `SET_WORLD`, `EXIT_WORLD`, `PROCESS_WORLD` — World lifecycle.
- `ENTITY_ADDED`, `ENTITY_REMOVED`, `ENTITY_ENABLED`, `ENTITY_DISABLED` — Entity lifecycle.
- `SYSTEM_ADDED`, `SYSTEM_REMOVED` — System lifecycle.
- `SYSTEM_METRIC` — per-process timing for the systems-tree time/min/max/avg columns.
- `SYSTEM_LAST_RUN_DATA` — full last-run dictionary (entity count, archetype hits, etc).
- `ENTITY_COMPONENT_ADDED`, `ENTITY_COMPONENT_REMOVED` — Component lifecycle.
- `ENTITY_RELATIONSHIP_ADDED`, `ENTITY_RELATIONSHIP_REMOVED` — Relationship lifecycle (with serialized rel data per type — Entity / Component / Archetype-script).
- `COMPONENT_PROPERTY_CHANGED` — `property_changed` signal forwarded for live editing.
- `POLL_ENTITY`, `SELECT_ENTITY` — editor-to-game polling and node selection.

If your new feature overlaps with one of these, **extend the existing message** rather than adding a parallel one.

## Design principles

1. **One message, one purpose.** Don't multiplex unrelated state into a single message just to save one round-trip — debugging the dispatch table becomes painful. Add a new `Msg` constant.
2. **Send ids, not objects.** `instance_id`s are stable and small. Object references either won't serialize or will arrive as opaque dictionaries. The tab's `ecs_data` is keyed by id; emitters should match.
3. **Editor-side is reactive, not authoritative.** The game is the source of truth. The tab mirrors state via messages — never assume a tree node's data is in sync without checking `ecs_data`.
4. **Refresh through `_refresh_*_tree()` helpers.** Direct `TreeItem` manipulation breaks sort, pin, filter, and expand state. The tree-refresh methods reconcile correctly.
5. **No work on hot paths in the editor.** Tree refreshes are O(entities). Don't call `_refresh_entities_tree()` from a per-frame message handler — coalesce updates with the existing poll timer pattern (see `_poll_elapsed` and `poll_rate_spin_box`).
6. **Debug mode is opt-in.** All `can_send_message()` calls early-out outside the editor. Don't add panels that require debug data and don't gracefully degrade — the overlay (`debug_mode_overlay`) handles the "Debug Mode disabled" case.
7. **Match style — emoji icons, `_snake_case` private members, `%UniqueName` lookups.** Existing code uses Unicode icon constants (`ICON_ENTITY = "📦"`, etc.) for tree decorations. Continue that style; users have come to expect it.

## Common pitfalls

- **Forgetting `_has_capture` namespace prefix.** A `Msg` value of `"system_query_results"` won't route — must be `"gecs:system_query_results"`.
- **Sending a node reference.** `EngineDebugger.send_message` serializes the array; node references arrive as `null` or unstable dictionaries on the editor side. Send `node.get_instance_id()` and `node.get_path()` separately.
- **Not handling the "no session" case.** `_setup_session` runs once; if your handler runs before `set_debugger_session(...)`, `_debugger_session` is null. Guard editor→game messages (`POLL_ENTITY`, `SELECT_ENTITY`) with a null check.
- **Mutating `ecs_data` without refreshing.** State updates without a `_refresh_*` call show stale data until the next poll tick. Decide whether to refresh immediately or rely on the poll cadence — don't leave it ambiguous.
- **Adding a column without bumping `tree.columns`.** Setting properties on column index 9 when there are 8 columns is a silent no-op. Always update the column count first.
- **Not adding to `clear_all_data()`.** New persistent state survives across game runs and shows ghost data the second time around. Always wire the reset.
- **Direct `Tree` calls from `_capture` handlers.** The plugin runs in the editor's main thread but the tab may not be `_ready` yet at session-setup time. Keep handlers in `gecs_editor_debugger_tab.gd` and let `_ready()` initialize tree state.
- **Forgetting `@tool` on the tab script.** `gecs_editor_debugger_tab.gd` runs in the editor; without `@tool`, `_ready()` and `@onready` resolution don't fire correctly. Already in place — don't accidentally remove it.

## Testing

The debugger plugin runs in the editor process, not the game process — standard GdUnit4 game-side tests don't cover it. Verify changes by:

1. Reload the project (or toggle the GECS plugin off/on) so the editor picks up the new `EditorDebuggerPlugin` registration.
2. Run a small example scene (`example_stress_test/main.tscn` is the canonical stress case — many entities, many systems).
3. Open the GECS tab, exercise the new feature, watch for stale state, sort/pin/filter regressions, and editor performance issues.
4. Toggle debug mode off in Project Settings to confirm the new code path is correctly gated by `can_send_message()`.

For game-side emitter logic that has testable branches (which payload shape, which guard), a focused unit test in `addons/gecs/tests/` can cover the helper — but the editor UI itself is verified manually.

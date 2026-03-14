# Phase 5: Reconciliation and Custom Sync - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Periodic full-state reconciliation broadcasts that silently correct property drift and ghost
entities over long sessions (ADV-02), plus a callable registry API that lets game systems
override how specific components are sent and received (ADV-03). Transform sync (CN_NativeSync)
is not touched. Spawn/late-join is not touched.

</domain>

<decisions>
## Implementation Decisions

### Reconciliation Correction Style

- **Silent snap (immediate)** — properties applied directly via `comp.set()` through the existing
  `_apply_component_data()` path. No blend or lerp. Reconciliation corrects data drift, not visual
  smoothness — that's CN_NativeSync's job.
- **Transforms excluded** — `CN_NativeSync`-managed components are already excluded by
  `serialize_entity()`. Reconciliation must NOT touch them. Keep concerns separate.
- **Ghost removal: debug log** — when a ghost entity is removed, emit a debug log message gated
  by `NetworkSync.debug_logging`. Silent in production, visible when debugging.
- **Skip own entities** — clients skip entities where `net_id.peer_id == my_peer_id`. Never
  overwrite locally-authoritative entity data.

### Reconciliation Interval and Triggering

- **Default: 30 seconds** — registered as ProjectSetting `gecs_network/sync/reconciliation_interval`
  with value 30.0 (TYPE_FLOAT).
- **Runtime-overridable** — `NetworkSync.reconciliation_interval` property that, when set,
  overrides the ProjectSettings value for the current session. Setting to `0.0` or negative
  disables automatic reconciliation.
- **Manual trigger exposed** — `NetworkSync.broadcast_full_state()` is a public method so game
  code can force an immediate reconciliation (e.g., on player reconnect).

### Reconciliation Scope

- **Full state including relationships** — `serialize_entity()` already returns the `"relationships"`
  key. Reconciliation uses the full payload: both component data AND relationships are corrected.

### Custom Handler API Shape

- **Registration only (no unregister)** — handlers are registered once in a System's `_ready()` and
  live for the session. No `unregister_*` methods needed.
- **API lives on NetworkSync** — `register_send_handler(comp_type_name, callable)` and
  `register_receive_handler(comp_type_name, callable)` on `NetworkSync`. Delegates to
  `SyncSender` / `SyncReceiver` internally.
- **No per-entity opt-in** — handler is per-component-type, applies to all entities that have
  that component type. Simple, consistent with always-on model.

### Custom Handler Documentation

- **Both doc comments AND a separate docs file** — inline `##` GDScript doc comments on
  `register_send_handler()` and `register_receive_handler()` for quick in-editor reference, PLUS
  a new `addons/gecs_network/docs/custom-sync-handlers.md` file for the full walkthrough.
- **One realistic prediction scenario** — player movement prediction: client predicts input
  locally (send handler controls what's sent), server correction arrives and blends (receive
  handler does lerp instead of snap). A concrete before/after pattern, not multiple abstract
  examples.
- **Example registration in a System's `_ready()`** — shows how an ECS system wires up the
  handlers, matching how the rest of the framework is used.

### Claude's Discretion

- Exact format and length of `custom-sync-handlers.md`
- Whether `reconciliation_interval` property setter resets the internal timer (likely yes — feels
  correct; implementation decides)
- RPC mode for `_sync_full_state` (reliable recommended per RESEARCH.md)
- Inner class structure in test files for MockSpawnManager and MockReceiver

</decisions>

<specifics>
## Specific Ideas

- `broadcast_full_state()` being public is intentional for reconnect flows — not just an internal
  timer callback
- `reconciliation_interval = 0.0` as a way to disable auto-reconciliation is a side-effect of the
  runtime property; document it clearly
- The prediction example should feel like something a real Godot developer would write in their
  movement system — not abstract scaffolding

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `sync_reconciliation_handler.gd` (stub from Phase 4): `process_reconciliation()` returns
  immediately with `# TODO Phase 5` — this is the entry point for the timer wiring
- `_apply_component_data()` in `sync_receiver.gd`: already handles `_applying_network_data` guard
  and `update_cache_silent()`. Reconciliation should route through this same method.
- `entity.remove_all_relationships()` confirmed at `entity.gd:407` — safe for ghost cleanup

### Established Patterns

- Timer accumulator pattern from `SyncSender.tick(delta)`: `_timer += delta; if _timer >= interval`
- Delegation via `load()` with no `class_name`: `sync_relationship_handler.gd` precedent
- ProjectSettings registration: `_add_setting("gecs_network/sync/...", value, TYPE_*)` in
  `plugin.gd._register_project_settings()`
- Debug logging gate: `if debug_logging: print(...)` pattern used throughout `network_sync.gd`

### Integration Points

- `NetworkSync._process()` → `_reconciliation_handler.tick(delta)` after `_sender.tick(delta)`
- `NetworkSync._ready()` → instantiate `SyncReconciliationHandler` via `load()`
- `NetworkSync` public API → add `broadcast_full_state()` and `reconciliation_interval` property
- `SyncSender._poll_entities_for_priority()` → check `_custom_send_handlers` before default
  `check_changes_for_priority()`
- `SyncReceiver._apply_component_data()` → check `_custom_receive_handlers` before default
  `comp.set()` loop; ALWAYS call `update_cache_silent()` after custom handler

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-reconciliation-and-custom-sync*
*Context gathered: 2026-03-11*

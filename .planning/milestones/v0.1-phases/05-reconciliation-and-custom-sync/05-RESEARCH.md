# Phase 5: Reconciliation and Custom Sync - Research

**Researched:** 2026-03-11
**Domain:** GDScript networking — periodic state reconciliation, custom sync handler hooks
**Confidence:** HIGH (all findings grounded in existing codebase; no external library uncertainty)

---

## Summary

Phase 5 addresses two independent requirements: periodic full-state reconciliation (ADV-02) and
a custom sync handler override surface (ADV-03). Both features already have significant prior art
inside the codebase — they are wiring and completion tasks, not greenfield builds.

**ADV-02 (Reconciliation):** `sync_state_handler.gd` already contains `broadcast_full_state()`,
`serialize_entity_full()`, and `handle_sync_full_state()` with ghost-cleanup logic. The timer
loop stub `process_reconciliation()` returns immediately with a `# TODO Phase 5` comment. The
`SyncConfig` stub still has an `enable_reconciliation` field that was meant to gate this feature
— that gate must be removed in v2 in favor of a ProjectSettings key (matching the sync Hz
pattern established in Phase 2). The only missing pieces are: (1) wire the timer into
`NetworkSync._process()`, (2) add the `_sync_full_state` RPC to `NetworkSync`, (3) add a
ProjectSettings key for interval, (4) write tests.

**ADV-03 (Custom Sync):** No override hook exists yet. The design must fit the existing
delegation architecture: `NetworkSync` owns all `@rpc` declarations and delegates to handler
objects. The natural surface is a per-component-type handler registry on `NetworkSync` (or
`SyncSender`/`SyncReceiver`) that game systems can populate. A custom handler is a GDScript
`Callable` or `RefCounted` subclass that receives the entity + component and returns what to
send (or null to suppress). The handler is invoked in `SyncSender._poll_entities_for_priority()`
before the default dirty-check path, and in `SyncReceiver._apply_component_data()` before the
default `comp.set()` path.

**Primary recommendation:** Implement ADV-02 first (pure timer + existing logic). Implement
ADV-03 second as a callable registry on `SyncSender`/`SyncReceiver`. Both share the same
MockNetworkSync test harness pattern established in Phases 2-4.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ADV-02 | Periodic full-state reconciliation broadcast (default 30s, configurable) silently corrects property drift and missed packets | `sync_state_handler.gd` already has `broadcast_full_state()` + `handle_sync_full_state()`. Need: timer wiring, `_sync_full_state` RPC, ProjectSettings key, tests. |
| ADV-03 | Systems can register custom sync handlers overriding default property sync — documented with example prediction pattern | No override hook exists. Design: callable registry keyed by component type name on `SyncSender`/`SyncReceiver`. Document with client-side prediction example. |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GdUnit4 | Project-installed | Unit test framework | Established in all previous phases |
| GDScript RefCounted | Godot 4.x built-in | Handler delegation objects | Consistent with SyncSender, SyncReceiver, SpawnManager pattern |
| Godot ProjectSettings | Godot 4.x built-in | Configurable reconciliation interval | Matches `gecs_network/sync/high_hz` pattern from Phase 2 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Godot Timer (accumulator pattern) | Godot 4.x | Reconciliation interval tracking | Matches existing `_timers` accumulator in SyncSender |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Callable registry for ADV-03 | Subclass-based handler | Callables are simpler and match GDScript idioms; subclasses add boilerplate |
| ProjectSettings for reconciliation interval | `@export` on NetworkSync | ProjectSettings matches the established sync Hz pattern; @export would also work but is less consistent |

---

## Architecture Patterns

### Existing Handler Architecture (Established Pattern — Must Follow)

All logic lives in `RefCounted` delegation objects. `NetworkSync` is the ONLY node with `@rpc`
methods and delegates to handlers via stored references (`_spawn_manager`, `_sender`, `_receiver`,
`_native_sync_handler`, `_relationship_handler`).

```
NetworkSync (Node, owns @rpc)
├── _spawn_manager: SpawnManager (RefCounted)
├── _sender: SyncSender (RefCounted)         ← custom send hooks go here
├── _receiver: SyncReceiver (RefCounted)      ← custom receive hooks go here
├── _native_sync_handler: NativeSyncHandler (RefCounted)
├── _relationship_handler: SyncRelationshipHandler (RefCounted, no class_name)
└── (new) _reconciliation_handler: SyncReconciliationHandler (RefCounted, no class_name)
```

### ADV-02: Reconciliation Timer Architecture

The `sync_state_handler.gd` `process_reconciliation()` stub returns immediately. To implement:

1. Add a timer accumulator to the handler (same accumulator pattern as `SyncSender._timers`)
2. Read interval from `ProjectSettings.get_setting("gecs_network/sync/reconciliation_interval", 30.0)`
3. On interval fire: call `broadcast_full_state()` (already implemented)
4. Wire handler into `NetworkSync._process()` via a call (server-only guard already in handler)
5. Add `_sync_full_state` RPC to `NetworkSync` delegating to handler's `handle_sync_full_state()`
6. Register the ProjectSettings key in `plugin.gd`'s `_register_project_settings()`

**Key constraint from STATE.md:** `sync_state_handler.gd` is a v0.1.1 legacy file — it still
uses `CN_SyncEntity`, `auto_assign_markers()`, and v0.1.1 patterns. The reconciliation logic
inside it (`broadcast_full_state`, `handle_sync_full_state`) references
`_ns._relationship_handler` (correct for v2), `_ns._apply_component_data` (does not exist on
v2 NetworkSync — only `_ns._applying_network_data` flag exists), and
`_ns._find_component_by_type` (does not exist on v2 NetworkSync). This means the existing
reconciliation code in `sync_state_handler.gd` CANNOT be wired into v2 NetworkSync as-is.

**Decision required by planner:** Either (a) create a new `SyncReconciliationHandler` that
re-implements reconciliation cleanly using v2 SpawnManager's `serialize_entity()` for
serialization and `SyncReceiver._apply_component_data()` delegation pattern, OR (b) lift the
reconciliation methods out of `sync_state_handler.gd` into a new file while deleting the
incompatible v0.1.1 state management code. Option (a) is cleaner given this is the final phase.

**Recommended approach (Option A):** New `sync_reconciliation_handler.gd` (no class_name,
follows `sync_relationship_handler.gd` precedent). Uses `_ns._spawn_manager.serialize_entity()`
for full-state serialization (already handles all component types, script_paths, and
relationships). Uses `_ns._receiver` (SyncReceiver) pattern for application. Receiver must
support a "force-overwrite" path that skips own-entity check (reconciliation corrects all remote
entities).

**Entity.remove_all_relationships() confirmed available:** Verified at
`addons/gecs/ecs/entity.gd` line 407 — the method exists in v2. Reconciliation can safely use
`entity.remove_all_relationships()` before re-applying relationship state.

### ADV-03: Custom Sync Handler Registry Architecture

The override surface must allow game code to intercept component sync at two points:

1. **Send side** (`SyncSender._poll_entities_for_priority`): override what data is sent for a
   given component type — return custom dict or null to suppress
2. **Receive side** (`SyncReceiver._handle_client_path` / `_handle_server_path`): override how
   received data is applied for a given component type — return true if handled (skip default)

**Registry shape:**

```gdscript
# In SyncSender (or NetworkSync if registered there):
var _custom_send_handlers: Dictionary = {}  # { "CompTypeName": Callable }

# Callable signature:
# func(entity: Entity, comp: Component, priority: int) -> Dictionary
# Return: { prop: value } to send, or {} to suppress, or null to use default

# In SyncReceiver:
var _custom_receive_handlers: Dictionary = {}  # { "CompTypeName": Callable }

# Callable signature:
# func(entity: Entity, comp: Component, props: Dictionary) -> bool
# Return: true if handled (skip default set()), false to fall through to default
```

**Registration API (on NetworkSync for public surface):**

```gdscript
## Register a custom send handler for a component type.
## Called instead of default dirty-check for the named component type.
func register_send_handler(comp_type_name: String, handler: Callable) -> void:
    _sender.register_send_handler(comp_type_name, handler)

## Register a custom receive handler for a component type.
## Called instead of default comp.set() for the named component type.
func register_receive_handler(comp_type_name: String, handler: Callable) -> void:
    _receiver.register_receive_handler(comp_type_name, handler)
```

**Integration point in SyncSender._poll_entities_for_priority():**
After finding `net_sync` and before `check_changes_for_priority()`, check if any tracked
component type name has a custom send handler. If so, call the handler; merge result into
pending instead of dirty-check result.

**Integration point in SyncReceiver._apply_component_data():**
Before `comp.set(prop, value)` loop, check if the component type name has a custom receive
handler. If handler returns true, skip the default set() loop.

### Recommended Project Structure (Phase 5 additions)

```
addons/gecs_network/
├── sync_reconciliation_handler.gd    # NEW: ADV-02 timer + broadcast + receive
├── network_sync.gd                   # MODIFY: +_reconciliation_handler, +_sync_full_state RPC,
│                                     #          +register_send_handler(), +register_receive_handler()
├── sync_sender.gd                    # MODIFY: +_custom_send_handlers dict, +register/invoke
├── sync_receiver.gd                  # MODIFY: +_custom_receive_handlers dict, +register/invoke
├── plugin.gd                         # MODIFY: register reconciliation_interval ProjectSetting
└── tests/
    ├── test_reconciliation.gd        # NEW: ADV-02 tests
    └── test_custom_sync_handlers.gd  # NEW: ADV-03 tests
```

### Anti-Patterns to Avoid

- **Wiring `sync_state_handler.gd` directly into v2 NetworkSync:** The file references
  `_ns._apply_component_data`, `_ns._find_component_by_type`, `CN_SyncEntity`, and
  `CN_ServerOwned` — all v0.1.1 artifacts not present on v2 NetworkSync. Any attempt to
  wire it will hit runtime errors immediately.
- **Reconciliation applying data to own entities:** `handle_sync_full_state` must skip entities
  where `net_id.is_local(net_adapter)` — same guard used in SyncReceiver client path.
- **Custom handlers bypassing `_applying_network_data` guard:** Any custom receive handler must
  run inside the `_applying_network_data = true` block or set the flag itself, or the cache
  will detect the applied value as a new change and echo it back.
- **Reconciliation triggering dirty-cache echo:** Full-state apply must call
  `net_sync.update_cache_silent()` for each property applied, same as SyncReceiver does.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Entity serialization for reconciliation | Custom serializer | `_spawn_manager.serialize_entity()` | Already handles all component types, script_paths, and relationships |
| Component data application | Custom set() loop | `SyncReceiver._apply_component_data()` delegation pattern | Already has `_applying_network_data` guard + `update_cache_silent()` |
| Priority timer accumulator | New timer class | Same `_timers` dict accumulator pattern from SyncSender | Proven, minimal overhead, no Godot Timer node required |
| ProjectSettings registration | Custom config file | `plugin.gd._register_project_settings()` | Already registers `high_hz`, `medium_hz`, `low_hz` — add `reconciliation_interval` same way |

**Key insight:** The hardest parts of both ADV-02 and ADV-03 are already solved by existing
infrastructure. Phase 5 is primarily a wiring and exposure task.

---

## Common Pitfalls

### Pitfall 1: sync_state_handler.gd Incompatibility
**What goes wrong:** Attempting to instantiate or call methods on the existing
`sync_state_handler.gd` from v2 NetworkSync will immediately reference methods and fields that
don't exist (`_ns._apply_component_data`, `_ns._find_component_by_type`, `CN_SyncEntity`).
**Why it happens:** `sync_state_handler.gd` is a v0.1.1 legacy file. It was never migrated to
v2 because reconciliation was deferred.
**How to avoid:** Write a new `sync_reconciliation_handler.gd` from scratch that uses only v2
NetworkSync's actual interface: `_ns._spawn_manager`, `_ns._receiver`, `_ns._world`,
`_ns.net_adapter`, `_ns._game_session_id`, `_ns._applying_network_data`.
**Warning signs:** If you see `_ns._apply_component_data` or `_ns._find_component_by_type`
in any Phase 5 code, it's wrong.

### Pitfall 2: Echo Loop in Reconciliation
**What goes wrong:** Server broadcasts full state; clients apply it; CN_NetSync dirty cache
detects applied values as changes; clients re-broadcast the same values back.
**Why it happens:** `_applying_network_data = true` in SyncSender.tick() guards against this,
but only if reconciliation application flows through the same flag AND calls
`net_sync.update_cache_silent()` for every applied property.
**How to avoid:** Route reconciliation application through the same `_apply_component_data()`
method used by SyncReceiver (which already sets the flag and calls update_cache_silent).
**Warning signs:** After reconciliation fires, clients start generating unexpected outbound sync.

### Pitfall 3: Reconciliation Pop (Visible Desync Correction)
**What goes wrong:** ADV-02 success criterion says "no visible pop or desync" but a naive full
state overwrite will jump entity positions if transform drift accumulated.
**Why it happens:** Reconciliation writes raw property values without interpolation.
**How to avoid:** Reconciliation must NOT overwrite properties managed by `CN_NativeSync` /
`MultiplayerSynchronizer` (transform, position, rotation). The reconciliation serializer should
skip components also skipped by CN_NetSync (`CN_NativeSync` is already excluded from
`scan_entity_components()`). For CN_NetSync-tracked properties, reconciliation corrects "state"
properties (health, ammo, flags) not visible position — so no pop occurs for those.
**Warning signs:** Entity positions snap visibly after reconciliation fires.

### Pitfall 4: Custom Handler Not Firing for Spawn-Only Components
**What goes wrong:** Developer registers a custom handler for a component type that is
`SPAWN_ONLY` in CN_NetSync. Handler never fires because SPAWN_ONLY components are excluded from
`check_changes_for_priority()`.
**Why it happens:** CN_NetSync excludes `SPAWN_ONLY` properties from the dirty cache entirely.
**How to avoid:** Document clearly: custom send handlers only fire for components that have
`CN_NetSync`-tracked properties. SPAWN_ONLY and LOCAL components are never presented to
custom handlers.

### Pitfall 5: Custom Receive Handler Missing update_cache_silent Call
**What goes wrong:** Custom handler applies values via its own logic; SyncSender later detects
the applied values as "changed" and re-broadcasts them.
**Why it happens:** `update_cache_silent()` is only called by `SyncReceiver._apply_component_data()`.
If a custom handler bypasses this, the dirty cache is stale.
**How to avoid:** After a custom receive handler fires, the framework code must still call
`net_sync.update_cache_silent(comp, prop, value)` for every property the handler applied. The
framework wrapper around the custom handler should do this, not the handler itself.

---

## Code Examples

### Pattern 1: Reconciliation Timer (from SyncSender accumulator pattern)

```gdscript
# Source: addons/gecs_network/sync_sender.gd (established accumulator pattern)

# In SyncReconciliationHandler:
var _timer: float = 0.0
var _ns  # NetworkSync reference

func tick(delta: float) -> void:
    if not _ns.net_adapter.is_server():
        return  # Only server broadcasts reconciliation
    _timer += delta
    var interval: float = ProjectSettings.get_setting(
        "gecs_network/sync/reconciliation_interval", 30.0
    )
    if _timer >= interval:
        _timer = 0.0
        broadcast_full_state()
```

### Pattern 2: Full-State Serialization Using SpawnManager

```gdscript
# Source: addons/gecs_network/spawn_manager.gd serialize_entity() (v2, established)

# In SyncReconciliationHandler.broadcast_full_state():
func broadcast_full_state() -> void:
    if not _ns.net_adapter.is_server():
        return
    var full_state: Array[Dictionary] = []
    for entity in _ns._world.entities:
        var net_id = entity.get_component(CN_NetworkIdentity)
        if not net_id:
            continue
        full_state.append(_ns._spawn_manager.serialize_entity(entity))
    if full_state.is_empty():
        return
    _ns._sync_full_state.rpc({"entities": full_state, "session_id": _ns._game_session_id})
```

### Pattern 3: Reconciliation Receive with Relationship Reset

```gdscript
# Source: addons/gecs/ecs/entity.gd line 407 — remove_all_relationships() confirmed available

# In SyncReconciliationHandler.handle_sync_full_state():
func _apply_reconciliation_to_entity(entity: Entity, entity_data: Dictionary) -> void:
    var net_id = entity.get_component(CN_NetworkIdentity)
    if net_id.is_local(_ns.net_adapter):
        return  # Never overwrite own entity — CRITICAL
    _ns._receiver._apply_component_data(entity, entity_data.get("components", {}))
    var rel_data = entity_data.get("relationships", [])
    if not rel_data.is_empty():
        _ns._applying_network_data = true
        entity.remove_all_relationships()  # Safe: confirmed in entity.gd line 407
        _ns._applying_network_data = false
        _ns._relationship_handler.apply_entity_relationships(entity, rel_data)
```

### Pattern 4: Custom Send Handler Registration

```gdscript
# Source: Design — follows NetAdapter override pattern (net_adapter.gd)

# Registration in game code (e.g., a prediction system):
func _ready() -> void:
    var ns: NetworkSync = ECS.world.get_node("NetworkSync")
    ns.register_send_handler("C_PlayerInput", _send_predicted_input)

func _send_predicted_input(entity: Entity, comp: Component, priority: int) -> Dictionary:
    # Return only the properties this frame's prediction needs to broadcast
    # Return {} to suppress sending this component entirely
    # Return null (or don't return) to fall through to default dirty-check
    if entity.has_component(CN_LocalAuthority):
        return {"move_dir": comp.move_dir, "jump_pressed": comp.jump_pressed}
    return {}  # Suppress for non-local entities
```

### Pattern 5: Custom Receive Handler for Client-Side Prediction

```gdscript
# Source: Design — documented example pattern for ADV-03 success criterion

# In a prediction system:
func _ready() -> void:
    var ns: NetworkSync = ECS.world.get_node("NetworkSync")
    ns.register_receive_handler("C_Position", _blend_server_correction)

func _blend_server_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
    # Apply server correction with smoothing instead of snapping
    if props.has("position"):
        var server_pos: Vector3 = props["position"]
        var current_pos: Vector3 = comp.position
        # Blend toward server position over multiple frames
        comp.position = current_pos.lerp(server_pos, 0.3)
    return true  # Mark as handled — framework will still call update_cache_silent()
```

### Pattern 6: MockNetworkSync for Phase 5 Tests (established harness)

```gdscript
# Source: addons/gecs_network/tests/test_sync_sender.gd (established harness)

class MockNetworkSync:
    extends RefCounted

    var _world: World
    var _applying_network_data: bool = false
    var _game_session_id: int = 42
    var net_adapter: MockNetAdapter
    var _spawn_manager  # MockSpawnManager
    var _receiver       # MockReceiver (or real SyncReceiver)
    var full_state_rpc_calls: Array = []

    func _sync_full_state(payload: Dictionary) -> void:
        full_state_rpc_calls.append(payload)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sync_state_handler.gd` reconciliation | New `sync_reconciliation_handler.gd` | Phase 5 | Avoids v0.1.1 API mismatches |
| `SyncConfig.enable_reconciliation` gate | `ProjectSettings` key | Phase 5 | Matches Phase 2 sync Hz pattern |
| No custom override surface | Callable registry on SyncSender/SyncReceiver | Phase 5 | Enables prediction patterns without framework fork |

**Deprecated/outdated:**
- `sync_state_handler.gd`: `process_reconciliation()` stub — superseded by new handler
- `SyncConfig.enable_reconciliation`: field exists in stub but v2 does not read it — dead field

---

## Open Questions

1. **Should `_sync_full_state` RPC be `reliable` or `unreliable`?**
   - What we know: Reconciliation is a correction mechanism for missed packets — it must arrive.
     The payload may be large (all entities). `_sync_world_state` (late-join) uses `reliable`.
   - What's unclear: Whether Godot's reliable channel handles large payloads or fragments them.
   - Recommendation: Use `@rpc("authority", "reliable")` — reconciliation is infrequent (every
     30s default), so bandwidth spike is acceptable. Matches `_sync_world_state` pattern.

2. **Custom handler: per-entity or per-component-type?**
   - What we know: Requirements say "for specific components" — component-type granularity is
     implied.
   - What's unclear: Whether a handler registered for `C_Position` should fire for ALL entities
     or only entities where the game code has opted in.
   - Recommendation: Per-component-type (all entities) is simpler and matches the requirement
     wording. Games can implement per-entity logic inside the callable.

3. **What happens to `sync_state_handler.gd` in Phase 5?**
   - What we know: It contains v0.1.1 code (auto_assign_markers, authority transfer,
     CN_SyncEntity refs) that conflicts with v2; its reconciliation code is not usable as-is.
   - What's unclear: Whether to delete it, stub it, or leave it untouched.
   - Recommendation: Leave it untouched (it's v0.1.1 dead code with no active callers in v2
     NetworkSync). Document it as superseded. Deleting risks breaking test files that still
     reference it (`test_sync_state_handler.gd`).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | GdUnit4 (project-installed, `addons/gdUnit4/`) |
| Config file | `addons/gdUnit4/GdUnitRunner.cfg` |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd"` |
| Full suite command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADV-02 | Timer accumulates and fires broadcast_full_state() at configured interval | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_reconciliation_fires_at_interval"` | Wave 0 |
| ADV-02 | broadcast_full_state() serializes all CN_NetworkIdentity entities | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_broadcast_full_state_serializes_networked_entities"` | Wave 0 |
| ADV-02 | handle_sync_full_state() applies component data to remote entities | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_applies_component_data"` | Wave 0 |
| ADV-02 | handle_sync_full_state() skips own (local-authority) entities | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_skips_local_entities"` | Wave 0 |
| ADV-02 | handle_sync_full_state() removes ghost entities not in server state | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_removes_ghost_entities"` | Wave 0 |
| ADV-02 | reconciliation_interval ProjectSetting registered with correct default (30.0) | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_reconciliation_interval_project_setting"` | Wave 0 |
| ADV-03 | Registered send handler called instead of default dirty-check | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_send_handler_replaces_default"` | Wave 0 |
| ADV-03 | Returning {} from send handler suppresses component in batch | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_send_handler_suppress"` | Wave 0 |
| ADV-03 | Registered receive handler called instead of default comp.set() | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_replaces_default"` | Wave 0 |
| ADV-03 | update_cache_silent() still called after custom receive handler returns true | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_still_updates_cache"` | Wave 0 |
| ADV-03 | Returning false from receive handler falls through to default comp.set() | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_fallthrough"` | Wave 0 |

### Sampling Rate

- **Per task commit:** `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd" -c`
- **Per wave merge:** Full suite — `runtest.cmd -a "res://addons/gecs_network/tests"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `addons/gecs_network/tests/test_reconciliation.gd` — covers ADV-02 (6 stubs)
- [ ] `addons/gecs_network/tests/test_custom_sync_handlers.gd` — covers ADV-03 (5 stubs)
- [ ] `addons/gecs_network/sync_reconciliation_handler.gd` — core ADV-02 implementation file
- Framework install: already present — no action needed

---

## Sources

### Primary (HIGH confidence)

- `addons/gecs_network/sync_state_handler.gd` — existing reconciliation logic (v0.1.1, not wirable to v2 as-is)
- `addons/gecs_network/sync_sender.gd` — timer accumulator pattern, `_poll_entities_for_priority` integration point
- `addons/gecs_network/sync_receiver.gd` — `_apply_component_data` pattern, cache silent update
- `addons/gecs_network/network_sync.gd` — RPC declaration constraints, delegation pattern
- `addons/gecs_network/spawn_manager.gd` — `serialize_entity()` used by reconciliation send path
- `addons/gecs_network/components/cn_net_sync.gd` — SPAWN_ONLY/LOCAL exclusion, `update_cache_silent()`
- `addons/gecs_network/sync_config.gd` — `enable_reconciliation` dead field (v2 does not read it)
- `addons/gecs/ecs/entity.gd` — `remove_all_relationships()` confirmed at line 407
- `.planning/STATE.md` — Phase 4 decision: `process_reconciliation()` stubbed with TODO Phase 5

### Secondary (MEDIUM confidence)

- `addons/gecs_network/docs/architecture.md` — handler delegation pattern described
- `.planning/REQUIREMENTS.md` — ADV-02, ADV-03 requirement text and out-of-scope table

### Tertiary (LOW confidence)

None — all findings grounded in codebase inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — uses only existing project infrastructure
- Architecture: HIGH — patterns directly derived from existing handler code
- Pitfalls: HIGH — identified by reading v0.1.1 handler code and v2 integration constraints
- ADV-03 design: MEDIUM — no prior art in this codebase; design is consistent with established
  patterns but requires planner validation of callable registry signature

**Research date:** 2026-03-11
**Valid until:** Stable — no external dependencies; valid until codebase changes

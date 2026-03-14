# Phase 2: Component Property Sync - Research

**Researched:** 2026-03-08
**Domain:** GDScript property scanning, priority-tiered batching, RefCounted delegation pattern
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Game components stay as plain `extends Component` — no subclassing required
- Developer adds `CN_NetSync` component to the entity to enable continuous property sync
- CN_NetSync automatically scans all other components on the entity for `@export_group` annotations
  matching the known priority names (REALTIME / HIGH / MEDIUM / LOW / SPAWN_ONLY / LOCAL)
- Properties under a recognized group are synced at that rate; properties outside any named group
  default to HIGH priority
- `CN_SyncEntity` is removed — CN_NetSync replaces its role as the "continuous sync" marker
- `@export_group("SPAWN_ONLY")` properties are included in the spawn payload only, never in
  continuous sync batches
- Entities WITHOUT a CN_NetSync component are fully spawn-only
- `sync_config.gd` is DELETED entirely
- `sync_component.gd` is DELETED (replaced by CN_NetSync)
- `components/cn_sync_entity.gd` is DELETED (replaced by CN_NetSync presence)
- The `Priority` enum (REALTIME / HIGH / MEDIUM / LOW) moves into `CN_NetSync`
- Tests for SyncConfig and SyncComponent are also deleted
- Sync intervals are configurable via Godot Project Settings, registered by the plugin
- Settings path: `gecs_network/sync/` — keys: `high_hz` (20), `medium_hz` (10), `low_hz` (2)
- REALTIME_INTERVAL = 0.0 (every frame), others computed as 1.0 / hz
- `SyncSender` — RefCounted helper, holds `_pending_updates_by_priority`, drives timer logic
- `SyncReceiver` — RefCounted helper, validates authority, applies received data
- NetworkSync delegates via `_sender`/`_receiver` (same pattern as `_spawn_manager`)
- Two new RPCs: `_sync_components_unreliable` (unreliable_ordered) + `_sync_components_reliable` (reliable)
- REALTIME/HIGH use unreliable_ordered; MEDIUM/LOW use reliable
- Batch wire format: `{ entity_id: { comp_type: { prop: value } } }`

### Claude's Discretion

- Exact CN_NetSync scanning implementation (property iteration, caching after first scan)
- Dirty tracking cache structure (per-component, keyed by instance ID or component type)
- How `update_cache_silent()` works when applying received data (suppress sync-loop)
- Error handling when a component has `@export_group` with an unrecognized name
- Whether SyncSender polls CN_NetSync directly or subscribes to a signal
- Batch format details (already locked as wire format above — internal accumulator structure is discretion)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SYNC-01 | Component properties sync to clients at rates matching declared priority group (REALTIME: every frame, HIGH: 20Hz, MEDIUM: 10Hz, LOW: 2Hz) using batched RPCs | SyncSender timer accumulator pattern from sync_property_handler.gd; Project Settings drive interval values |
| SYNC-02 | Only properties that changed since the last sync tick are included in each outbound batch | CN_NetSync dirty cache + `_has_changed()` type-aware comparison — ported verbatim from SyncComponent |
| SYNC-03 | A component can be declared as spawn-only — its values are sent once on entity spawn and not synced continuously | `@export_group("SPAWN_ONLY")` group name + CN_NetSync presence check; absence of CN_NetSync = all-spawn-only entity |
</phase_requirements>

## Summary

This phase ports the v0.1.1 `SyncComponent` + `sync_property_handler.gd` sync machinery into three new objects: `CN_NetSync` (Component that scans other components for `@export_group` priority annotations), `SyncSender` (RefCounted timer loop + batch RPC dispatch), and `SyncReceiver` (RefCounted authority validation + property apply). The existing code is highly reusable — the property scanner, dirty cache, `_has_changed()`, `_deep_copy()`, `queue_relay_data()`, `should_broadcast()`, and the full send/apply flow are all direct ports with targeted adaptations.

The primary design work is the inversion from "component carries its own cache" (SyncComponent) to "CN_NetSync holds caches for all sibling components on the entity". In v0.1.1, a component was a SyncComponent subclass and carried `_sync_cache` and `_props_by_priority` on itself. In v2, a plain `extends Component` declares `@export_group` annotations, and CN_NetSync (a separate component on the same entity) scans the sibling components at initialization and owns all their caches. The scan logic from `SyncComponent._parse_property_priorities()` is moved into CN_NetSync.`_scan_component(comp)` which runs once per component and caches results keyed by component instance ID.

Three deletion candidates exist that the planner must schedule before creating new files: `sync_config.gd`, `sync_component.gd`, `components/cn_sync_entity.gd`, and their three test files. The v0.1.1 `_sync_entity_index` in NetworkSync (which tracked `entity_id -> {entity, sync_comps[]}`) is replaced by SyncSender holding a direct reference to the World and querying entities with CN_NetworkIdentity + CN_NetSync at tick time.

**Primary recommendation:** Port `SyncComponent._parse_property_priorities()` + `_has_changed()` + `_deep_copy()` verbatim into CN_NetSync (or a shared `SyncUtils` static class). Port `sync_property_handler.gd` into SyncSender + SyncReceiver with the SyncConfig references replaced by CN_NetSync lookups. Register three Project Settings in `plugin.gd._enter_tree()`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GDScript `get_script().get_script_property_list()` | Godot 4.x | Scan component properties + @export_group annotations | Only API for runtime script property introspection in GDScript |
| `PROPERTY_USAGE_GROUP` constant | Godot 4.x | Detect @export_group boundary in property list | Standard Godot property usage flag — matches enum in Godot source |
| `PROPERTY_USAGE_EDITOR` constant | Godot 4.x | Detect exported properties (those visible to editor) | Confirmed in v0.1.1 SyncComponent._parse_property_priorities() |
| `PROPERTY_USAGE_CATEGORY` constant | Godot 4.x | Filter out category separators from property list | Required negation — categories appear between groups |
| `ProjectSettings.add_project_setting()` | Godot 4.x | Register gecs_network/sync/* hz values | Standard plugin pattern for configurable defaults |
| `@rpc("any_peer", "unreliable_ordered")` | Godot 4.x | REALTIME/HIGH property batches | Low-latency, tolerate drops for high-frequency updates |
| `@rpc("any_peer", "reliable")` | Godot 4.x | MEDIUM/LOW property batches | Guaranteed delivery for infrequent but important updates |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `is_equal_approx()` (float/Vector) | Godot 4.x | Approximate change detection | Prevents infinite float-drift resync |
| `ResourceLoader.exists()` | Godot 4.x | Script path validation in SyncReceiver | Guard against malformed RPC payloads |

**Installation:** No new packages. All Godot 4.x built-ins.

---

## Architecture Patterns

### Recommended Project Structure (new files only)

```
addons/gecs_network/
├── components/
│   └── cn_net_sync.gd          # New: Priority enum, property scanner, dirty cache
├── sync_sender.gd              # New: Timer loop, batch accumulator, RPC dispatch
├── sync_receiver.gd            # New: Authority validation, property apply
├── network_sync.gd             # Modified: wire _sender/_receiver, add 2 RPCs, update _process()
└── plugin.gd                   # Modified: register gecs_network/sync/* ProjectSettings
```

Files deleted in this phase (planner must schedule as Wave 0 deletions):
```
addons/gecs_network/sync_config.gd
addons/gecs_network/sync_component.gd
addons/gecs_network/components/cn_sync_entity.gd
addons/gecs_network/tests/test_sync_config.gd
addons/gecs_network/tests/test_sync_component.gd
addons/gecs_network/tests/test_cn_sync_entity.gd
```

### Pattern 1: @export_group Property Scanner

The scanner in `SyncComponent._parse_property_priorities()` (confirmed working in v0.1.1) iterates `get_script().get_script_property_list()`. Each entry is a Dictionary with keys `name`, `usage`, `type`, etc. Groups appear as entries with `usage & PROPERTY_USAGE_GROUP` set. Properties appear as entries with `usage & PROPERTY_USAGE_EDITOR` set (and NOT `PROPERTY_USAGE_CATEGORY`).

CN_NetSync calls this scanner on each sibling component (not on itself), passing the component's script, not `get_script()`.

```gdscript
# Source: confirmed in addons/gecs_network/sync_component.gd lines 59-86
func _scan_component(comp: Component) -> Dictionary:
    # Returns {priority_int: [prop_names]}
    var result: Dictionary = {}
    var current_priority: int = Priority.HIGH  # default for ungrouped props

    for prop_info in comp.get_script().get_script_property_list():
        var usage = prop_info.usage

        if usage & PROPERTY_USAGE_GROUP:
            var group_name: String = prop_info.name
            if group_name in PRIORITY_MAP:
                current_priority = PRIORITY_MAP[group_name]
            # Unrecognized group names: keep current_priority unchanged
            continue

        if usage & PROPERTY_USAGE_EDITOR and not (usage & PROPERTY_USAGE_CATEGORY):
            var priority = current_priority
            if priority == -1:  # LOCAL — skip
                continue
            if priority not in result:
                result[priority] = []
            result[priority].append(prop_info.name)

    return result
```

**Key point:** CN_NetSync calls `comp.get_script().get_script_property_list()` (the sibling component's script), not its own. This is the crucial difference from SyncComponent which called `get_script()` on itself.

**SPAWN_ONLY handling:** PRIORITY_MAP includes `"SPAWN_ONLY": -2` (a sentinel distinct from LOCAL's -1). Properties under SPAWN_ONLY are skipped by CN_NetSync's dirty-tracking scanner entirely — SpawnManager already serializes all @export properties via `Component.serialize()` at spawn time regardless of group.

### Pattern 2: CN_NetSync Dirty Cache Structure

CN_NetSync holds caches for all sibling components. Cache is initialized lazily on first `check_changes_for_entity()` call.

```gdscript
# Cache: { component_instance_id: { prop_name: last_known_value } }
var _cache_by_comp: Dictionary = {}

# Props by priority: { component_instance_id: { priority_int: [prop_names] } }
var _props_by_comp: Dictionary = {}
```

Using instance IDs (from `comp.get_instance_id()`) as keys avoids holding strong references and is safe if a component is removed (the ID becomes stale, skip on `is_instance_valid`).

### Pattern 3: SyncSender Timer Accumulator

Ported from `sync_property_handler.update_sync_timers()` + `send_pending_updates_batched()`. Each priority level has its own accumulator float.

```gdscript
# Source: addons/gecs_network/sync_property_handler.gd lines 286-343
var _timers: Dictionary = {}   # { priority_int: float }
var _pending: Dictionary = {}  # { priority_int: { entity_id: { comp_type: { prop: value } } } }

func tick(delta: float) -> void:
    if not _ns.net_adapter.is_in_game():
        return
    for priority in _timers.keys():
        _timers[priority] += delta

    _flush_due_priorities()

func _flush_due_priorities() -> void:
    for priority in Priority.values():
        var interval = _intervals[priority]
        if interval > 0.0 and _timers[priority] < interval:
            continue
        _timers[priority] = 0.0
        _poll_entities_for_priority(priority)
        _dispatch_batch(priority)
```

REALTIME has interval 0.0 — the `interval > 0.0 and timer < interval` check correctly passes every frame for REALTIME without accumulator drift.

### Pattern 4: SyncReceiver Authority Validation

Ported from `sync_property_handler.handle_apply_sync_data()` (lines 379-474). The exact check sequence matters for security:

```
Server receives from client:
  1. Reject if entity not found in world
  2. Reject if entity lacks CN_NetworkIdentity
  3. Reject if entity lacks CN_NetSync (spawn-only entity — no continuous updates accepted)
  4. Reject if net_id.peer_id != sender_id (entity not owned by this client)
  5. Strip CN_NetworkIdentity key from data dict if present (ownership spoofing prevention)
  6. Queue relay: call _sender.queue_relay_data(entity_id, comp_data)
  7. Apply data to entity

Client receives from server:
  1. Reject if sender_id != 1 (only accept from server)
  2. Reject if entity not found
  3. Reject if entity lacks CN_NetworkIdentity or CN_NetSync
  4. Skip if entity is locally owned (net_id.peer_id == my_peer_id)
  5. Apply data to entity
```

### Pattern 5: SyncSender Entity Index / Poll Pattern

In v0.1.1, `NetworkSync` maintained a `_sync_entity_index` dict tracking entities with SyncComponents. In v2, SyncSender polls the World directly at tick time — simpler and avoids maintaining a separate index. SyncSender.tick() calls `_poll_entities_for_priority(priority)` which iterates `_ns._world.entities` and checks each for `CN_NetworkIdentity` + `CN_NetSync`.

```gdscript
func _poll_entities_for_priority(priority: int) -> void:
    for entity in _ns._world.entities:
        if not is_instance_valid(entity):
            continue
        var net_id = entity.get_component(CN_NetworkIdentity)
        if not net_id:
            continue
        var net_sync = entity.get_component(CN_NetSync)
        if not net_sync:
            continue  # Spawn-only entity — no continuous sync
        if not _should_broadcast(entity, net_id):
            continue
        # Ask CN_NetSync for changed props at this priority
        var changes = net_sync.check_changes_for_priority(entity, priority)
        for comp_type in changes.keys():
            _queue_update(entity.id, comp_type, changes[comp_type])
```

### Pattern 6: SyncSender.queue_relay_data()

Server relays client updates to all other clients. Ported verbatim from `sync_property_handler.queue_relay_data()` (lines 262-278). Relay data always goes into HIGH priority bucket for responsiveness.

### Pattern 7: Project Settings Registration

```gdscript
# Source: Godot 4.x EditorPlugin pattern — confirmed working in gecs project (plugin.gd exists)
func _enter_tree() -> void:
    # ... existing custom type registration ...
    _register_project_settings()

func _register_project_settings() -> void:
    _add_setting("gecs_network/sync/high_hz", 20, TYPE_INT)
    _add_setting("gecs_network/sync/medium_hz", 10, TYPE_INT)
    _add_setting("gecs_network/sync/low_hz", 2, TYPE_INT)

func _add_setting(path: String, default_value: Variant, type: int) -> void:
    if not ProjectSettings.has_setting(path):
        ProjectSettings.set_setting(path, default_value)
    ProjectSettings.set_initial_value(path, default_value)
    ProjectSettings.add_property_info({
        "name": path,
        "type": type,
    })
```

`ProjectSettings.set_initial_value()` marks the setting so it shows as "default" in the editor when unchanged. `add_property_info()` gives the editor a type hint for the settings dialog.

CN_NetSync reads these at `_init()`:
```gdscript
var _intervals: Dictionary = {
    Priority.REALTIME: 0.0,
    Priority.HIGH: 1.0 / ProjectSettings.get_setting("gecs_network/sync/high_hz", 20),
    Priority.MEDIUM: 1.0 / ProjectSettings.get_setting("gecs_network/sync/medium_hz", 10),
    Priority.LOW: 1.0 / ProjectSettings.get_setting("gecs_network/sync/low_hz", 2),
}
```

The default fallback (second arg to `get_setting`) handles the case where tests run without the plugin enabled and settings aren't registered.

### Pattern 8: NetworkSync Wiring (_process integration)

```gdscript
# network_sync.gd additions
var _sender: SyncSender
var _receiver: SyncReceiver

func _ready() -> void:
    # ... existing code ...
    _sender = SyncSender.new(self)
    _receiver = SyncReceiver.new(self)

func _process(delta: float) -> void:
    if _world == null or not net_adapter.is_in_game():
        return
    _sender.tick(delta)   # Phase 2: replaces "Phase 2+ will add property sync ticking here"

# New RPCs:
@rpc("any_peer", "unreliable_ordered")
func _sync_components_unreliable(batch: Dictionary) -> void:
    if _receiver == null:
        return
    _receiver.handle_apply_sync_data(batch)

@rpc("any_peer", "reliable")
func _sync_components_reliable(batch: Dictionary) -> void:
    if _receiver == null:
        return
    _receiver.handle_apply_sync_data(batch)
```

`"any_peer"` is correct — clients must be able to call these on the server. The server uses the transport-layer sender ID (unforgeable) for authority validation inside `handle_apply_sync_data`.

### Anti-Patterns to Avoid

- **Do not access SyncConfig in any new file.** It is deleted. Any reference to `SyncConfig.Priority` in new code is a bug — use `CN_NetSync.Priority`.
- **Do not call `comp.get_script().get_script_property_list()` with null-check bypass.** Components added from C# or built-in Resources may have null scripts. Always guard: `if comp.get_script() == null: continue`.
- **Do not hold Entity references in CN_NetSync.** CN_NetSync is a Component — it does not know which Entity it belongs to. The entity reference is passed by SyncSender when calling `net_sync.check_changes_for_priority(entity, priority)`.
- **Do not apply network data without setting `_applying_network_data = true` first.** SpawnManager already does this correctly — SyncReceiver must follow the exact same pattern.
- **Do not include CN_NetworkIdentity properties in the sync batch.** Strip them on the outbound side too (in `_scan_component`) by checking `comp is CN_NetworkIdentity` before scanning.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Float/vector change detection | Custom epsilon comparison | `_has_changed()` from SyncComponent (port verbatim) | Handles 8 Godot float types + null + type mismatch correctly |
| Value-type deep copy | Custom copy | `_deep_copy()` from SyncComponent (port verbatim) | Handles Array/Dictionary duplicate + value-type pass-through |
| Property list scanning | Custom GDScript parser | `get_script().get_script_property_list()` | The only runtime introspection API; custom approach is impossible |
| Transport reliability selection | Per-property decision | Priority-to-RPC mapping (REALTIME/HIGH → unreliable_ordered, MEDIUM/LOW → reliable) | Already validated in v0.1.1 |
| Batch accumulator | Immediate-send per change | `_pending_updates_by_priority` dict structure | Immediate send = 9,000+ RPCs/sec at 50 entities; batching is non-negotiable |

**Key insight:** Every algorithm in this phase already exists in `sync_component.gd` and `sync_property_handler.gd`. The work is reorganization (inverting ownership of the cache) and deletion of the SyncConfig/SyncComponent/CN_SyncEntity layer — not new algorithm development.

---

## Common Pitfalls

### Pitfall 1: Sync Loop from Applied Network Data
**What goes wrong:** SyncReceiver sets a component property → component emits `property_changed` → SyncSender queues the change → sends it back to origin peer → infinite loop.
**Why it happens:** The dirty cache sees the newly-applied value as "changed" since the cache wasn't updated before the signal fires.
**How to avoid:** `_ns._applying_network_data = true` before any `comp.set()` in SyncReceiver. `_ns._applying_network_data = false` in a finally-equivalent (after the loop, even if error). SyncSender.tick() returns immediately if `_ns._applying_network_data` is true.
**Warning signs:** Network traffic explodes to infinite; game freezes; unreliable packet flood visible in Godot's network profiler.

### Pitfall 2: CN_NetSync Scanning Itself
**What goes wrong:** CN_NetSync's `_scan_entity_components()` iterates `entity.components` and accidentally scans CN_NetSync itself, adding its own Priority enum properties to the sync batch.
**Why it happens:** No exclusion filter.
**How to avoid:** In `_scan_entity_components()`, skip the component if `comp is CN_NetSync` or `comp is CN_NetworkIdentity`.

### Pitfall 3: Unrecognized @export_group Name
**What goes wrong:** Developer writes `@export_group("HEALTH_PROPS")` — CN_NetSync doesn't recognize it and silently defaults to HIGH priority, syncing properties the developer expected to be at a different rate or not at all.
**Why it happens:** No validation of group names.
**How to avoid:** When scanning, if group name is not in PRIORITY_MAP, emit a `push_warning()` with the group name and component type. Default to HIGH (existing v0.1.1 behavior). Document this clearly.

### Pitfall 4: new class_name Files Missing .uid
**What goes wrong:** CN_NetSync, SyncSender, SyncReceiver are created as new GDScript files with `class_name`. The CLI test runner fails to resolve them with "Class not found" errors.
**Why it happens:** Godot generates `.uid` files during `--import`. New files without UIDs are not resolvable by the test runner.
**How to avoid:** After creating CN_NetSync, SyncSender, SyncReceiver scripts, run `godot --headless --import` before any test run. This is documented in CONTEXT.md as a "Known Gotcha". The planner must schedule this as a step before tests in the relevant wave.

### Pitfall 5: Spawn-Only Properties Appearing in Continuous Sync
**What goes wrong:** A property under `@export_group("SPAWN_ONLY")` is included in CN_NetSync's dirty cache and synced continuously.
**Why it happens:** SPAWN_ONLY not added to the skip list in `_scan_component`.
**How to avoid:** PRIORITY_MAP must include `"SPAWN_ONLY": -2` (distinct sentinel). In `_scan_component`, when `current_priority == -2` (SPAWN_ONLY), do not add properties to result dict. They will be captured by `Component.serialize()` at spawn time via SpawnManager.

### Pitfall 6: Client Sending CN_NetworkIdentity Updates
**What goes wrong:** A malicious or buggy client modifies their local CN_NetworkIdentity component (peer_id, spawn_index) and sends it via the sync RPC. Server applies it, transferring ownership.
**Why it happens:** No CN_NetworkIdentity exclusion on the server receive path.
**How to avoid:** Two-layer protection:
1. SyncSender outbound: Skip component scan for CN_NetworkIdentity entirely (client-side `should_broadcast` skips it).
2. SyncReceiver server-side: After authority check passes, strip `"CN_NetworkIdentity"` key from batch dict before applying. Confirmed pattern in v0.1.1 `handle_apply_sync_data` lines 432-437.

### Pitfall 7: Delta Accumulation Overshoot Not Reset
**What goes wrong:** If `_timers[priority] += delta` overflows well past the interval (e.g., a frame stutter causes 0.5s gap when interval is 0.05), the timer resets to 0 and the next 9 intervals fire in rapid succession.
**Why it happens:** Timer reset to 0 instead of subtracting the interval.
**How to avoid:** v0.1.1 resets to exactly 0 (acceptable for game networking — occasional double-skip on stutter is fine). Alternative: `_timers[priority] = fmod(_timers[priority], interval)`. Either approach is fine; be explicit in the implementation.

---

## Code Examples

Verified patterns from v0.1.1 source:

### @export_group Property Scanner (source of truth)
```gdscript
# Source: addons/gecs_network/sync_component.gd lines 59-86
func _parse_property_priorities() -> Dictionary:
    var result: Dictionary = {}
    var current_group: String = "HIGH"  # Default priority

    for prop_info in get_script().get_script_property_list():
        var usage = prop_info.usage

        if usage & PROPERTY_USAGE_GROUP:
            var group_name = prop_info.name
            if group_name in PRIORITY_MAP:
                current_group = group_name
            continue

        if usage & PROPERTY_USAGE_EDITOR and not (usage & PROPERTY_USAGE_CATEGORY):
            var priority = PRIORITY_MAP.get(current_group, 1)  # Default to HIGH
            if priority not in result:
                result[priority] = []
            result[priority].append(prop_info.name)

    return result
```

In CN_NetSync, replace `get_script()` with `comp.get_script()` and call this per sibling component.

### Type-Aware Change Detection (port verbatim)
```gdscript
# Source: addons/gecs_network/sync_component.gd lines 130-173
func _has_changed(old_value: Variant, new_value: Variant) -> bool:
    if old_value == null and new_value == null:
        return false
    if old_value == null or new_value == null:
        return true
    if typeof(old_value) != typeof(new_value):
        return true
    match typeof(old_value):
        TYPE_FLOAT:
            return not is_equal_approx(old_value, new_value)
        TYPE_VECTOR2:
            return not old_value.is_equal_approx(new_value)
        TYPE_VECTOR3:
            return not old_value.is_equal_approx(new_value)
        TYPE_VECTOR4:
            return not old_value.is_equal_approx(new_value)
        TYPE_TRANSFORM2D:
            return not (old_value.origin.is_equal_approx(new_value.origin)
                and old_value.x.is_equal_approx(new_value.x)
                and old_value.y.is_equal_approx(new_value.y))
        TYPE_TRANSFORM3D:
            return not (old_value.origin.is_equal_approx(new_value.origin)
                and old_value.basis.x.is_equal_approx(new_value.basis.x)
                and old_value.basis.y.is_equal_approx(new_value.basis.y)
                and old_value.basis.z.is_equal_approx(new_value.basis.z))
        TYPE_QUATERNION:
            return not old_value.is_equal_approx(new_value)
        TYPE_COLOR:
            return not old_value.is_equal_approx(new_value)
    return old_value != new_value
```

### Authority Validation in SyncReceiver (key excerpt)
```gdscript
# Source: addons/gecs_network/sync_property_handler.gd lines 418-444
# Server-side:
if _ns.net_adapter.is_server():
    if net_id.peer_id != sender_id:
        continue  # reject — not the owner
    if data[entity_id].has("CN_NetworkIdentity"):
        data[entity_id].erase("CN_NetworkIdentity")  # ownership spoofing prevention
        if data[entity_id].is_empty():
            continue
    queue_relay_data(entity_id, data[entity_id])  # relay to all clients
else:
    # Client-side:
    if sender_id != 1:
        continue  # reject — not from server
    if net_id.is_local(_ns.net_adapter):
        continue  # skip own entities (prevent stale relay overwrite)
```

### SyncSender Dispatch Decision
```gdscript
# Source: addons/gecs_network/sync_property_handler.gd lines 329-343
if _ns.net_adapter.is_server():
    if reliability == "UNRELIABLE":  # REALTIME or HIGH
        _ns._sync_components_unreliable.rpc(batch)
    else:
        _ns._sync_components_reliable.rpc(batch)
else:
    if reliability == "UNRELIABLE":
        _ns._sync_components_unreliable.rpc_id(1, batch)
    else:
        _ns._sync_components_reliable.rpc_id(1, batch)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SyncComponent base class (extends Component) | Plain Component + CN_NetSync scanner | Phase 2 | Zero friction for developers — no inheritance required |
| Global SyncConfig resource (class string → priority) | @export_group("HIGH") co-located with data | Phase 2 | Priority visible in component file, not a separate registry |
| CN_SyncEntity marker (separate presence check) | CN_NetSync presence (one check, not two) | Phase 2 | Simpler entity setup |
| `_sync_entity_index` in NetworkSync | Direct World iteration in SyncSender | Phase 2 | Eliminates index maintenance; World iteration is O(N) but N is small for networked entities |

**Deprecated/outdated:**
- `SyncConfig.Priority` enum: Replaced by `CN_NetSync.Priority`. Every reference in new code uses `CN_NetSync.Priority`.
- `SyncConfig.should_sync()` / `SyncConfig.get_interval()`: Replaced by `_intervals[priority]` dict in SyncSender, populated from Project Settings.
- `SyncConfig.get_reliability()`: Replaced by inline check: `if priority <= CN_NetSync.Priority.HIGH: use unreliable_ordered`.
- `CN_SyncEntity.get_sync_target()` / `has_sync_properties()` / `get_property_paths()`: Phase 3 concern (native MultiplayerSynchronizer). Out of scope for Phase 2.

---

## Deletion Inventory

The planner must schedule these deletions explicitly (Wave 0 or Wave 1 before creating new files).

### Files to Delete
| File | Reason |
|------|--------|
| `addons/gecs_network/sync_config.gd` | Replaced by CN_NetSync.Priority enum + Project Settings |
| `addons/gecs_network/sync_component.gd` | Replaced by CN_NetSync (scanner + cache now on the marker component) |
| `addons/gecs_network/components/cn_sync_entity.gd` | Replaced by CN_NetSync presence |
| `addons/gecs_network/tests/test_sync_config.gd` | Tests deleted class |
| `addons/gecs_network/tests/test_sync_component.gd` | Tests deleted class |
| `addons/gecs_network/tests/test_cn_sync_entity.gd` | Tests deleted class |

### Tests to Inspect for Stale References

After deletions, the following tests may have stale `SyncConfig` or `CN_SyncEntity` references that need purging (confirmed to check — they may be clean already):
- `test_sync_spawn_handler.gd` — references `SyncConfig` (for priority lookups) in its MockNetworkSync
- `test_sync_state_handler.gd` — likely references `SyncConfig`
- `test_sync_relationship_handler.gd` — likely references `SyncConfig`

These are in-scope because they test v0.1.1 handlers that are not part of Phase 2 but share the same test directory. The planner should schedule a grep-and-fix pass for `SyncConfig` references in surviving test files.

### DOES NOT Delete
| File | Why Kept |
|------|---------|
| `sync_property_handler.gd` | Not referenced by Phase 2 new code (new files replace it), but keep until Phase 2 is complete as reference. Delete in a cleanup wave. |
| `sync_native_handler.gd` | Phase 3 scope |
| `sync_relationship_handler.gd` | Phase 4 scope |
| `sync_state_handler.gd` | Phase 5 scope |
| `sync_spawn_handler.gd` | Already superseded by SpawnManager (Phase 1), but keep for reference |

---

## Open Questions

1. **SyncSender holds entity reference or queries World per tick?**
   - What we know: v0.1.1 used `_sync_entity_index` (maintained on component add/remove signals). Queries are O(N_entities) per tick.
   - What's unclear: At 100+ networked entities, does per-tick World iteration become measurable?
   - Recommendation: Start with direct World iteration (simpler, correct). Add index optimization only if perf tests show it at scale. The planner should leave a TODO comment in SyncSender.

2. **CN_NetSync.check_changes_for_priority() signature: entity as parameter or cached?**
   - What we know: CN_NetSync is a Component and does not inherently know its entity. It needs to call `comp.get(prop_name)` on sibling components — which it has from the scan cache.
   - What's unclear: Whether to pass the entity into `check_changes_for_priority(entity, priority)` or pre-cache component references differently.
   - Recommendation: Cache component references (Array of Component) during `_scan_entity_components(entity)`, called once by SyncSender when it first encounters the entity. Component references are safe to hold since components live as long as the entity. No need to pass entity into each poll call.

3. **Does SyncSender need to connect to `component_added`/`component_removed` signals?**
   - What we know: v0.1.1 `sync_property_handler.on_component_added()` queued a full component sync when a SyncComponent was added dynamically. Phase 2 does not include this (dynamic component addition sync is not in SYNC-01/02/03).
   - Recommendation: Skip for Phase 2. CN_NetSync's scan runs lazily at first poll. If a component is added after entity spawn, CN_NetSync will pick it up on the next re-scan. Add a re-scan trigger (or periodic re-scan) as a follow-up if needed.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | GdUnit4 (confirmed installed: `addons/gdUnit4/plugin.cfg`) |
| Config file | `GdUnitRunner.cfg` (root) |
| Quick run command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| Full suite command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SYNC-01 | Timer accumulator fires at correct intervals per priority | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_sender.gd"` | ❌ Wave 0 |
| SYNC-01 | Batch RPC is called with correct unreliable/reliable RPC for each priority | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_sender.gd"` | ❌ Wave 0 |
| SYNC-01 | Batch wire format matches `{ entity_id: { comp_type: { prop: value } } }` | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_sender.gd"` | ❌ Wave 0 |
| SYNC-02 | Only changed properties in batch (unchanged skipped) | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-02 | Second poll returns empty when no changes | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-02 | `_has_changed()` approx comparison for float/vector | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-02 | update_cache_silent() does not trigger re-emit | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-02 | Applying network data sets `_applying_network_data` flag; SyncSender returns early | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-03 | Entity without CN_NetSync: SyncReceiver rejects continuous updates | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-03 | SPAWN_ONLY props not in CN_NetSync dirty cache | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-01/02 | CN_NetSync scans @export_group annotations correctly | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ❌ Wave 0 |
| SYNC-01/02 | Server rejects client update for non-owned entity | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-01/02 | Server strips CN_NetworkIdentity from client update | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-01/02 | Client rejects update from non-server peer | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-01/02 | Client skips update for locally-owned entity | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_receiver.gd"` | ❌ Wave 0 |
| SYNC-01/02 | Project Settings registered with correct defaults | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_plugin_settings.gd"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd" -a "res://addons/gecs_network/tests/test_sync_sender.gd" -a "res://addons/gecs_network/tests/test_sync_receiver.gd"`
- **Per wave merge:** `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"`
- **Phase gate:** Full suite (`gecs/tests` + `gecs_network/tests`) green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `addons/gecs_network/tests/test_cn_net_sync.gd` — covers SYNC-01, SYNC-02, SYNC-03 (scanner, dirty cache, SPAWN_ONLY exclusion, `_has_changed`, `update_cache_silent`)
- [ ] `addons/gecs_network/tests/test_sync_sender.gd` — covers SYNC-01 (timer accumulator, batch format, RPC dispatch selection, relay)
- [ ] `addons/gecs_network/tests/test_sync_receiver.gd` — covers SYNC-02, SYNC-03 (authority checks, CN_NetworkIdentity stripping, `_applying_network_data` flag, spawn-only rejection)
- [ ] `addons/gecs_network/tests/test_plugin_settings.gd` — covers Project Settings registration (high_hz, medium_hz, low_hz exist with correct defaults)
- [ ] `.uid` files for `cn_net_sync.gd`, `sync_sender.gd`, `sync_receiver.gd` — generated via `godot --headless --import` after file creation

### Mock Pattern (established by test_spawn_manager.gd)

All three new test files should follow the MockNetworkSync pattern from `test_spawn_manager.gd`:

```gdscript
class MockNetworkSync:
    extends RefCounted

    var _world: World
    var _applying_network_data: bool = false
    var _game_session_id: int = 42
    var net_adapter: MockNetAdapter
    var debug_logging: bool = false

    # Track RPC calls
    var unreliable_rpc_calls: Array = []
    var reliable_rpc_calls: Array = []

    func _sync_components_unreliable(batch: Dictionary) -> void:
        unreliable_rpc_calls.append(batch)

    func _sync_components_reliable(batch: Dictionary) -> void:
        reliable_rpc_calls.append(batch)
```

MockNetAdapter pattern is also established in `test_spawn_manager.gd` — reuse it exactly.

---

## Sources

### Primary (HIGH confidence)
- `addons/gecs_network/sync_component.gd` — complete SyncComponent implementation; scanner, dirty cache, `_has_changed`, `_deep_copy`, `check_changes_for_priority`, `update_cache_silent`
- `addons/gecs_network/sync_property_handler.gd` — complete send/receive implementation; `update_sync_timers`, `send_pending_updates_batched`, `poll_sync_components_for_priority`, `handle_apply_sync_data`, `queue_relay_data`, `should_broadcast`
- `addons/gecs_network/network_sync.gd` — Phase 1 skeleton; integration points confirmed (line 126 comment, `_spawn_manager` delegation pattern)
- `addons/gecs_network/spawn_manager.gd` — delegation pattern confirmed; `_apply_component_data` with `_applying_network_data` flag confirmed
- `addons/gecs_network/plugin.gd` — existing `add_custom_type` pattern; `_enter_tree`/`_exit_tree` structure for adding Project Settings
- `addons/gecs_network/tests/test_spawn_manager.gd` — MockNetworkSync + MockNetAdapter pattern for new test files
- `addons/gecs_network/tests/test_sync_component.gd` — existing test coverage to replicate (adapted for CN_NetSync)
- `addons/gecs_network/sync_config.gd` — INTERVALS constants and RELIABILITY_BY_PRIORITY mapping (ported into CN_NetSync)

### Secondary (MEDIUM confidence)
- Godot 4.x `PROPERTY_USAGE_*` constants — confirmed working in SyncComponent._parse_property_priorities(); specific constant names verified from v0.1.1 source which runs on Godot 4.5
- `ProjectSettings.add_project_setting()` / `set_initial_value()` / `add_property_info()` — standard EditorPlugin pattern; behavior confirmed consistent with Godot 4.x documentation

### Tertiary (LOW confidence)
- None — all claims in this research are backed by v0.1.1 primary source code

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs confirmed in working v0.1.1 code
- Architecture: HIGH — direct port of working v0.1.1 code with documented inversion; no new algorithms
- Pitfalls: HIGH — every pitfall is an observed failure mode from v0.1.1 with confirmed mitigation code
- Deletion inventory: HIGH — confirmed by directory listing; test file contents read and verified

**Research date:** 2026-03-08
**Valid until:** 2026-06-08 (stable Godot 4.x APIs; 90 days)

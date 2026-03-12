# Phase 7: NetworkSession Node - Research

**Researched:** 2026-03-12
**Domain:** Godot 4 multiplayer session management, GDScript Node API, ECS event pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**API Shape**
- `session.host(port: int = default_port)` and `session.join(ip: String, port: int = default_port)` — two explicit methods. Both return an `Error` code.
- `session.disconnect()` — full cleanup: removes networked entities, nulls `multiplayer.multiplayer_peer`, resets internal state. Fires `on_session_ended` hook after cleanup.

**Callable Hooks**
Seven optional callable properties assigned before `host()`/`join()`:
- `on_before_host`, `on_host_success`, `on_before_join`, `on_join_success`
- `on_peer_connected(peer_id: int)`, `on_peer_disconnected(peer_id: int)`, `on_session_ended`

**ECS-Friendly Events**
Transient event components on a single persistent Session entity. Added for one frame, removed before next frame:
- `CN_PeerJoined` — `peer_id: int`
- `CN_PeerLeft` — `peer_id: int`
- `CN_SessionStarted` — `is_host: bool`
- `CN_SessionEnded` — _(no data)_
- `CN_SessionState` — permanent: `is_connected: bool`, `is_hosting: bool`, `peer_count: int`

**Player Spawning Scope**
- Spawning is fully game-code responsibility. `NetworkSession` fires `CN_PeerJoined` and `on_peer_connected` hook only.

**Relationship to NetworkSync**
- `NetworkSession` creates and owns `NetworkSync` internally via `NetworkSync.attach_to_world(world)`.
- Read-only `network_sync` property exposed for advanced use.
- `auto_start_network_sync: bool = true` — when `false`, game code wires manually.

**Transport / Configuration**
- `@export var transport: TransportProvider` — defaults to `ENetTransportProvider`.
- Existing `TransportProvider` / `ENetTransportProvider` classes used as-is.

**@export properties:**
| Property | Type | Default |
|----------|------|---------|
| `transport` | `TransportProvider` | `ENetTransportProvider` |
| `max_players` | `int` | `4` |
| `default_port` | `int` | `7777` |
| `debug_logging` | `bool` | `false` |
| `auto_start_network_sync` | `bool` | `true` |

### Claude's Discretion
- Internal cleanup order (entities removed before or after peer null)
- Session entity node name and placement in the World hierarchy
- Exact timing of event component removal (end of frame vs beginning of next)
- Error message strings for transport failures

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 7 wraps the boilerplate found in `example_network/main.gd` — ENetMultiplayerPeer creation, multiplayer signal wiring, NetworkSync setup, and cleanup — into a reusable `NetworkSession` node. The resulting node is configured entirely via `@export` properties and optional callable hooks, while session lifecycle events are surfaced as ECS components on a persistent local-only Session entity.

The codebase already has every building block: `TransportProvider`/`ENetTransportProvider` for peer creation, `NetworkSync.attach_to_world()` for sync setup, `NetAdapter` for multiplayer API access, and the ECS `Entity`/`Component` pattern for event components. This phase is almost entirely assembly work — no new framework primitives are needed.

The primary design risk is cleanup ordering: the Session entity must be kept alive through event firing, `NetworkSync` must be freed after entity removal (so its `_on_entity_removed` signal handlers fire correctly), and `multiplayer.multiplayer_peer = null` must come last to avoid null-ref in any signal handlers that still reference the peer.

**Primary recommendation:** Implement `NetworkSession` as a Node (not RefCounted) that lives as a sibling or child of the World node, owns the Session entity, and connects/disconnects multiplayer signals exclusively in `host()`/`join()`/`disconnect()` rather than in `_ready()`.

---

## Standard Stack

### Core (all already in `addons/gecs_network/`)

| File | Class | Purpose |
|------|-------|---------|
| `transport_provider.gd` | `TransportProvider` | Abstract peer factory — config dict → `MultiplayerPeer` |
| `transports/enet_transport_provider.gd` | `ENetTransportProvider` | Default ENet implementation |
| `network_sync.gd` | `NetworkSync` | RPC surface; created via `attach_to_world(world)` |
| `net_adapter.gd` | `NetAdapter` | Wraps `multiplayer` singleton; needed for cleanup safety |
| GECS `entity.gd` | `Entity` | Session entity container |
| GECS `component.gd` | `Component` | Base for all new event components |

### New Files This Phase

| File (proposed) | Class | Purpose |
|-----------------|-------|---------|
| `addons/gecs_network/network_session.gd` | `NetworkSession` | The new node |
| `addons/gecs_network/components/cn_peer_joined.gd` | `CN_PeerJoined` | Transient event: peer connected |
| `addons/gecs_network/components/cn_peer_left.gd` | `CN_PeerLeft` | Transient event: peer disconnected |
| `addons/gecs_network/components/cn_session_started.gd` | `CN_SessionStarted` | Transient event: session established |
| `addons/gecs_network/components/cn_session_ended.gd` | `CN_SessionEnded` | Transient event: session ended |
| `addons/gecs_network/components/cn_session_state.gd` | `CN_SessionState` | Permanent state component |
| `addons/gecs_network/tests/test_network_session.gd` | — | GdUnit4 test suite |

---

## Architecture Patterns

### Recommended File Placement
```
addons/gecs_network/
├── network_session.gd          # NEW — the main deliverable
├── components/
│   ├── cn_peer_joined.gd       # NEW — transient event
│   ├── cn_peer_left.gd         # NEW — transient event
│   ├── cn_session_started.gd   # NEW — transient event
│   ├── cn_session_ended.gd     # NEW — transient event
│   └── cn_session_state.gd     # NEW — permanent state
└── tests/
    └── test_network_session.gd  # NEW — unit tests
```

### Pattern 1: NetworkSession as Node child of World (or scene root)

`NetworkSession` extends `Node`. It does NOT need to be a child of `World` — it needs a reference to `World` to call `ECS.world.add_entity()` and to pass to `NetworkSync.attach_to_world()`. Scene placement is flexible:

```
ExampleNetwork (Node3D)
├── World               ← ECS world
├── NetworkSession      ← sibling of World; holds @export var world: World
└── UI
```

Alternatively, `NetworkSession` can auto-discover the World via `ECS.world` if it's always set at startup.

**Recommendation (Claude's discretion):** Use `ECS.world` for discovery in `_ready()` and expose `var world: World` as a settable property. This avoids requiring a specific scene hierarchy.

### Pattern 2: Session Entity as Local-Only Event Bus

The Session entity is created in `_ready()`, added to the World without `CN_NetworkIdentity`. Transient components are added/removed around the ECS process tick.

```gdscript
# In _ready():
_session_entity = Entity.new()
_session_entity.name = "SessionEntity"
ECS.world.add_entity(_session_entity)

# After multiplayer event fires:
_session_entity.add_component(CN_PeerJoined.new(peer_id))

# In _process() — BEFORE world.process(), clear last-frame events:
_session_entity.remove_component(CN_PeerJoined)
_session_entity.remove_component(CN_PeerLeft)
_session_entity.remove_component(CN_SessionStarted)
_session_entity.remove_component(CN_SessionEnded)
```

**Timing decision (Claude's discretion):** Remove transient components at the START of the next frame (in `_process()` before `world.process()`) rather than immediately after firing. This ensures any system that runs in the same ECS process tick sees the event. The planner should pick one approach and keep it consistent.

### Pattern 3: Callable Hooks — Optional Guard Pattern

All seven callable hooks are `Callable` typed. Each is checked with `.is_valid()` before calling to avoid errors when not set:

```gdscript
var on_peer_connected: Callable

func _fire_peer_connected(peer_id: int) -> void:
    if on_peer_connected.is_valid():
        on_peer_connected.call(peer_id)
```

Hooks that take no arguments (e.g., `on_host_success`, `on_session_ended`) use `Callable()` as the default empty value. GDScript `Callable()` is falsy for `.is_valid()` checks.

### Pattern 4: Transport → Peer → NetworkSync Assembly (in host()/join())

Mirrors what `main.gd` does manually today:

```gdscript
func host(port: int = default_port) -> Error:
    if on_before_host.is_valid():
        on_before_host.call()

    var config = {"port": port, "max_players": max_players}
    var peer = transport.create_host_peer(config)
    if peer == null:
        return ERR_CANT_CONNECT

    multiplayer.multiplayer_peer = peer
    _connect_multiplayer_signals()

    if auto_start_network_sync:
        _network_sync = NetworkSync.attach_to_world(_get_world())
        _network_sync.debug_logging = debug_logging

    _update_session_state(true, true, 1)
    _session_entity.add_component(CN_SessionStarted.new(true))

    if on_host_success.is_valid():
        on_host_success.call()

    return OK
```

### Pattern 5: Cleanup Order (Critical)

Based on `main.gd._cleanup_network()` and the session ID anti-ghost invariant in `NetworkSync`:

1. Fire `CN_SessionEnded` event component on Session entity
2. Call `on_session_ended` hook
3. Remove all networked entities from World (so `NetworkSync._on_entity_removed` fires despawn RPCs while peer is still alive)
4. Free `NetworkSync` via `queue_free()` (disconnects world signals, disconnects multiplayer signals)
5. Set `multiplayer.multiplayer_peer = null`
6. Reset `CN_SessionState` (is_connected=false, is_hosting=false, peer_count=0)
7. Clear internal `_network_sync` reference

**Key insight from existing code:** `SpawnManager.on_entity_removed()` calls `rpc_broadcast_despawn()` which routes through `NetworkSync.rpc_broadcast_despawn()`. If the peer is already null at this point, the RPC silently fails — not a crash but peers won't receive clean despawns. Entities must be removed BEFORE nulling the peer.

### Pattern 6: Connecting Multiplayer Signals

`NetworkSession` must connect/disconnect `multiplayer.*` signals (peer_connected, peer_disconnected, connected_to_server, connection_failed, server_disconnected) itself — similar to what `main.gd` does. `NetworkSync` connects only `peer_connected`/`peer_disconnected` internally for its world-state broadcast. There is no conflict, but `NetworkSession` must guard against double-connection using `is_connected()` checks.

### Anti-Patterns to Avoid

- **Connecting multiplayer signals in `_ready()`:** At `_ready()` time there is no peer yet; the signals are meaningless. Connect them in `host()`/`join()`, disconnect in `disconnect()`.
- **Storing a hard reference to `multiplayer.multiplayer_peer`:** The peer object becomes invalid after `multiplayer.multiplayer_peer = null`. Don't cache it.
- **Removing Session entity on disconnect:** The Session entity must persist across connect/disconnect cycles so systems can react to `CN_SessionEnded`. Only free it when `NetworkSession` itself exits the tree.
- **Calling `ECS.world` before world is initialized:** Guard with `if ECS.world == null: push_error(...); return ERR_UNCONFIGURED`.
- **Skipping `is_valid()` on Callable hooks:** A `Callable()` default value will crash on `.call()` — always guard.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ENet peer creation | Custom ENetMultiplayerPeer setup | `ENetTransportProvider.create_host_peer(config)` / `create_client_peer(config)` | Already handles bind IP, error checking, singleplayer offline mode |
| NetworkSync setup | `NetworkSync.new()` + manual `add_child()` | `NetworkSync.attach_to_world(world)` | Enforces the critical "NetworkSync" node name for RPC routing |
| Multiplayer API access | Direct `multiplayer.*` calls in all methods | `NetAdapter` instance methods | Handles SceneTree cache invalidation, null safety, offline mode |
| Session entity tracking | Custom entity ID registry | GECS `Entity` + `Component` pattern directly | Consistent with the rest of the addon |

**Key insight:** The `NetworkSync.attach_to_world()` static factory MUST be used (not raw `NetworkSync.new()`) because it sets `name = "NetworkSync"` before `add_child()`. This is a hard invariant that ensures `@rpc` method routing is consistent across all peers. Bypassing it causes silent RPC failures.

---

## Common Pitfalls

### Pitfall 1: Multiplayer Signals Still Connected After Disconnect

**What goes wrong:** After `disconnect()`, if `peer_connected` / `peer_disconnected` signals are still connected, the next `host()` / `join()` call results in double-handler registration, firing events twice.
**Why it happens:** `SceneTree.get_multiplayer()` returns the same `MultiplayerAPI` object across sessions (it's reset by nulling the peer, not replaced).
**How to avoid:** Always `disconnect()` signals before nulling the peer. Use a boolean flag `_signals_connected: bool` and guard with it.
**Warning signs:** `CN_PeerJoined` fires twice for one peer connection event.

### Pitfall 2: Session Entity Receiving CN_NetworkIdentity

**What goes wrong:** If the Session entity accidentally gets `CN_NetworkIdentity` added (e.g., a system adds it to all entities), `NetworkSync` will attempt to broadcast a spawn RPC for it to all clients, creating ghost session entities.
**Why it happens:** Generic "add to all entities" patterns don't know about the local-only Session entity.
**How to avoid:** Never add `CN_NetworkIdentity` to the Session entity. Document this explicitly. Consider naming the entity "NetworkSessionEntity" and checking for it in any system that bulk-adds identity components.
**Warning signs:** Clients receiving unexpected entity spawn RPCs for a non-game entity.

### Pitfall 3: Transient Event Components Missed Because Frame Cleared Too Early

**What goes wrong:** A system processes AFTER `NetworkSession._process()` fires but BEFORE `world.process()` — the event components were already cleared.
**Why it happens:** If event removal happens in `NetworkSession._process()` (before world systems run), the Godot process order matters. `_process()` node order in the scene tree is top-to-bottom.
**How to avoid:** Clear transient components at the BEGINNING of `_process()`, after `world.process()` of the previous frame has completed. This guarantees systems had one full `world.process()` tick to see each event. OR clear at the START of `_process()` (before calling `world.process()`) so events from the signal handlers are the fresh ones for THIS frame's systems. The planner must pick one timing model and apply it uniformly.
**Warning signs:** Systems that query `CN_PeerJoined` report zero entities even when peers connect.

### Pitfall 4: NetworkSync Freed Before Entity Removal

**What goes wrong:** `NetworkSync.queue_free()` before `world.remove_entity()` means NetworkSync's `_on_entity_removed` signal handler is already disconnected. Despawn RPCs never fire. Clients accumulate ghost entities.
**Why it happens:** Cleanup order reversed.
**How to avoid:** Always remove entities first, then free NetworkSync. See Pattern 5 (cleanup order) above.
**Warning signs:** Clients see player entities persist after host disconnects.

### Pitfall 5: @export var transport Not Initialized to ENetTransportProvider

**What goes wrong:** `@export var transport: TransportProvider` defaults to `null` in GDScript if not assigned in the Inspector or code. Calling `transport.create_host_peer()` on null crashes.
**Why it happens:** GDScript `@export` Resource properties are null until assigned.
**How to avoid:** Initialize in `_ready()` with a null guard: `if transport == null: transport = ENetTransportProvider.new()`. Document that the Inspector default is `ENetTransportProvider`.
**Warning signs:** Null reference error on `transport.create_host_peer()` in a fresh scene.

---

## Code Examples

### Callable Default Pattern (GDScript)
```gdscript
# Source: GDScript built-in — Callable() returns an invalid callable
var on_host_success: Callable = Callable()

func _fire_host_success() -> void:
    if on_host_success.is_valid():
        on_host_success.call()
```

### Signal Connect/Disconnect Guards
```gdscript
func _connect_multiplayer_signals() -> void:
    if _signals_connected:
        return
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _signals_connected = true

func _disconnect_multiplayer_signals() -> void:
    if not _signals_connected:
        return
    multiplayer.peer_connected.disconnect(_on_peer_connected)
    multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
    multiplayer.connected_to_server.disconnect(_on_connected_to_server)
    multiplayer.connection_failed.disconnect(_on_connection_failed)
    multiplayer.server_disconnected.disconnect(_on_server_disconnected)
    _signals_connected = false
```

### Transient Event Component — Frame Lifecycle
```gdscript
# In NetworkSession._process():
# Step 1: Clear last frame's transient events BEFORE world.process()
_session_entity.remove_component(CN_PeerJoined)
_session_entity.remove_component(CN_PeerLeft)
_session_entity.remove_component(CN_SessionStarted)
_session_entity.remove_component(CN_SessionEnded)

# (world.process() is called by game code, not NetworkSession)
# Multiplayer signal fires _on_peer_connected → adds CN_PeerJoined
# Next frame: CN_PeerJoined is present for all systems during world.process()
```

### NetworkSync Creation (must use factory)
```gdscript
# CORRECT — sets name before add_child(), critical for RPC routing
_network_sync = NetworkSync.attach_to_world(_get_world())
_network_sync.debug_logging = debug_logging

# WRONG — name will be "@NetworkSync@N", breaks RPC routing
_network_sync = NetworkSync.new()
_get_world().add_child(_network_sync)
```

### TransportProvider Config Dict Pattern (from existing ENetTransportProvider)
```gdscript
# ENetTransportProvider.create_host_peer expects:
# { "port": int, "bind_address": String, "max_players": int }
var host_config = {
    "port": port,
    "max_players": max_players,
    "bind_address": "0.0.0.0"
}
var peer = transport.create_host_peer(host_config)
if peer == null:
    return ERR_CANT_CONNECT

# ENetTransportProvider.create_client_peer expects:
# { "address": String, "port": int }
var client_config = {"address": ip, "port": port}
var peer = transport.create_client_peer(client_config)
```

### ECS Event System Pattern (game-side usage)
```gdscript
# PlayerSpawnSystem — no signal wiring needed
func query():
    return q.with_all([CN_PeerJoined])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for e in entities:
        var ev := e.get_component(CN_PeerJoined) as CN_PeerJoined
        _spawn_player_for_peer(ev.peer_id)
```

### CN_SessionState Update Helper
```gdscript
# Internal helper to keep CN_SessionState current
func _update_session_state(connected: bool, hosting: bool, peer_count: int) -> void:
    var state := _session_entity.get_component(CN_SessionState) as CN_SessionState
    if state == null:
        state = CN_SessionState.new()
        _session_entity.add_component(state)
    state.is_connected = connected
    state.is_hosting = hosting
    state.peer_count = peer_count
```

---

## State of the Art

| Old Approach (main.gd) | New Approach (NetworkSession) | Impact |
|------------------------|-------------------------------|--------|
| Manual ENetMultiplayerPeer creation in game code | `transport.create_host_peer(config)` via TransportProvider | Swappable transport backend |
| Multiplayer signals wired in `_ready()` | Wired in `host()`/`join()`, unwired in `disconnect()` | No stale handlers between sessions |
| `NetworkSync.attach_to_world()` called manually | Called internally by NetworkSession | Zero boilerplate for basic use |
| Peer events handled by game-specific Node signals | ECS transient event components | Systems react without signal wiring |
| Cleanup in ad-hoc `_cleanup_network()` method | `session.disconnect()` with defined ordering | Reliable cleanup across sessions |

---

## Open Questions

1. **Session entity placement in World hierarchy**
   - What we know: Entity is added via `ECS.world.add_entity()`, placed under `World/Entities` by convention.
   - What's unclear: Should it be placed under a dedicated "SessionEntities" node or alongside game entities? The World's `entities` container holds all game entities.
   - Recommendation (Claude's discretion): Place it in the normal entities container. Its lack of `CN_NetworkIdentity` is the meaningful distinction, not physical placement.

2. **Exact transient component removal timing**
   - What we know: The event must be present for at least one `world.process()` tick. `NetworkSession` runs its own `_process()`.
   - What's unclear: Godot's `_process()` order is scene-tree order. If `NetworkSession` is above `World` in the tree, its `_process()` fires first.
   - Recommendation (Claude's discretion): Clear transient components at the TOP of `_process()`, then game code calls `world.process()` afterward. The current `main.gd` calls `world.process()` in its own `_process()`. After refactoring, the game's main scene still controls `world.process()` timing — `NetworkSession` only manages event component cleanup.

3. **`disconnect()` method name conflict with Godot built-in**
   - What we know: GDScript `Node` has a built-in `disconnect()` method for signal disconnection. Naming the session teardown method `disconnect()` would shadow it.
   - Recommendation: Name the method `end_session()` or `leave()` to avoid shadowing. Raise this in the plan — the CONTEXT.md says `session.disconnect()` but this may need to be `session.end_session()` for GDScript safety.

4. **`@export var transport: TransportProvider` in-Inspector default**
   - What we know: Godot's `@export` for `Resource` subtypes shows a dropdown in the Inspector but defaults to null.
   - Recommendation: Initialize with `ENetTransportProvider.new()` in `_init()` or check-and-assign in `host()`/`join()`. Document the null-safety guard.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | GdUnit4 (present in `addons/gdUnit4/`) |
| Config file | `GdUnitRunner.cfg` (update when adding new test files) |
| Quick run command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_network_session.gd"` |
| Full suite command | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |

### Phase Requirements → Test Map

This phase introduces new session-management behavior. All prior requirements (FOUND through ADV) are complete and must not regress.

| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|-------------|
| `host()` returns OK with valid transport | unit | test_network_session.gd::test_host_returns_ok | ❌ Wave 0 |
| `host()` returns error when transport fails | unit | test_network_session.gd::test_host_returns_error_on_null_peer | ❌ Wave 0 |
| `join()` returns OK when client peer created | unit | test_network_session.gd::test_join_returns_ok | ❌ Wave 0 |
| `on_before_host` hook fires before peer creation | unit | test_network_session.gd::test_on_before_host_fires | ❌ Wave 0 |
| `on_host_success` hook fires after session established | unit | test_network_session.gd::test_on_host_success_fires | ❌ Wave 0 |
| `on_peer_connected` hook fires with peer_id | unit | test_network_session.gd::test_on_peer_connected_fires_with_id | ❌ Wave 0 |
| `on_peer_disconnected` hook fires with peer_id | unit | test_network_session.gd::test_on_peer_disconnected_fires_with_id | ❌ Wave 0 |
| `on_session_ended` hook fires after disconnect | unit | test_network_session.gd::test_on_session_ended_fires | ❌ Wave 0 |
| CN_PeerJoined added to Session entity on peer connect | unit | test_network_session.gd::test_cn_peer_joined_added | ❌ Wave 0 |
| CN_PeerLeft added to Session entity on peer disconnect | unit | test_network_session.gd::test_cn_peer_left_added | ❌ Wave 0 |
| CN_SessionStarted added after host() | unit | test_network_session.gd::test_cn_session_started_on_host | ❌ Wave 0 |
| CN_SessionEnded added after disconnect() | unit | test_network_session.gd::test_cn_session_ended_on_disconnect | ❌ Wave 0 |
| CN_SessionState reflects connected state | unit | test_network_session.gd::test_cn_session_state_connected | ❌ Wave 0 |
| CN_SessionState reflects disconnected state | unit | test_network_session.gd::test_cn_session_state_disconnected | ❌ Wave 0 |
| Transient events cleared after one frame | unit | test_network_session.gd::test_transient_events_cleared | ❌ Wave 0 |
| Hooks not set do not crash (Callable.is_valid guard) | unit | test_network_session.gd::test_empty_hooks_no_crash | ❌ Wave 0 |
| Session entity has no CN_NetworkIdentity | unit | test_network_session.gd::test_session_entity_not_networked | ❌ Wave 0 |
| network_sync property exposes internal NetworkSync | unit | test_network_session.gd::test_network_sync_property | ❌ Wave 0 |
| example_network/main.gd refactored to use NetworkSession | smoke | manual / visual test in editor | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `GODOT_BIN="..." addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_network_session.gd"`
- **Per wave merge:** `GODOT_BIN="..." addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `addons/gecs_network/tests/test_network_session.gd` — new test suite (all behaviors above)
- [ ] `addons/gecs_network/network_session.gd` — new class under test
- [ ] `addons/gecs_network/components/cn_peer_joined.gd` — event component
- [ ] `addons/gecs_network/components/cn_peer_left.gd` — event component
- [ ] `addons/gecs_network/components/cn_session_started.gd` — event component
- [ ] `addons/gecs_network/components/cn_session_ended.gd` — event component
- [ ] `addons/gecs_network/components/cn_session_state.gd` — permanent state component
- [ ] Update `GdUnitRunner.cfg` to include `test_network_session.gd`
- [ ] `.uid` sidecar files for all new `class_name` GDScript files (run `$GODOT_BIN --headless --import --quit-after 5` after creation)

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `addons/gecs_network/network_sync.gd` — attach_to_world factory, signal connect/disconnect patterns, cleanup order
- Direct code inspection: `example_network/main.gd` — complete reference implementation of the boilerplate being abstracted
- Direct code inspection: `addons/gecs_network/transport_provider.gd`, `transports/enet_transport_provider.gd` — config dict API shape
- Direct code inspection: `addons/gecs_network/net_adapter.gd` — multiplayer API wrapping patterns
- Direct code inspection: `addons/gecs_network/components/cn_network_identity.gd` — established Component pattern and local-only entity distinction
- Phase 7 CONTEXT.md — all locked decisions and discretion areas

### Secondary (MEDIUM confidence)
- GDScript built-in: `Callable()` default value and `.is_valid()` guard — verified by GDScript language behavior (Godot 4.x)
- GDScript built-in: `@export var prop: SomeResource` null-default behavior in Godot 4 Inspector

### Tertiary (LOW confidence — flag for validation)
- `disconnect()` method name conflict with `Node.disconnect()`: Needs verification that GDScript will shadow/shadow correctly. May require rename to `end_session()` or `leave_session()`. LOW confidence because this is a runtime behavior edge case in GDScript 4.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified by direct code inspection of existing codebase
- Architecture: HIGH — patterns derived from existing `main.gd` and `NetworkSync` implementations
- Pitfalls: HIGH — cleanup order and signal double-connection issues directly visible in existing code
- Transient event timing: MEDIUM — depends on Godot scene-tree `_process()` ordering which varies by placement

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable Godot 4.x APIs, no fast-moving dependencies)

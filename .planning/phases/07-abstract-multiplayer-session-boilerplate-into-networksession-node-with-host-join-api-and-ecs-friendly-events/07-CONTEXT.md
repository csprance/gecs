# Phase 7: NetworkSession Node - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Abstract the host/join/disconnect boilerplate and multiplayer signal wiring currently living in
`example_network/main.gd` into a reusable `NetworkSession` node. The node provides a clean
host/join API with optional callable hooks, exposes session events as ECS components on a
persistent Session entity, creates and owns `NetworkSync` internally, and delegates transport
creation to the existing `TransportProvider` abstraction.

No new sync features. No UI included. No player spawning logic baked in. This phase is purely
about reducing the connection-management boilerplate that every multiplayer game currently
copy-pastes.

</domain>

<decisions>
## Implementation Decisions

### API Shape

- **`session.host(port: int = default_port)` and `session.join(ip: String, port: int = default_port)`** —
  two explicit methods. Both return an `Error` code so game code can check and update UI.
- **`session.disconnect()`** — handles full cleanup automatically: removes networked entities
  from the world, nulls `multiplayer.multiplayer_peer`, resets internal state. Fires
  `on_session_ended` hook after cleanup.

### Callable Hooks (extension/override mechanism)

Four optional callable properties on `NetworkSession`. Game code assigns them before calling
`host()` / `join()`:

- `on_before_host: Callable` — called before the transport peer is created. Good for pre-flight
  config.
- `on_host_success: Callable` — called after the session is established (host side). Typical
  use: transition lobby to game UI.
- `on_before_join: Callable` — called before the client peer is created.
- `on_join_success: Callable` — called after `connected_to_server` fires. Typical use:
  transition lobby to game UI.
- `on_peer_connected: Callable` — called with `peer_id: int` for each new peer. Host uses this
  to spawn player entities.
- `on_peer_disconnected: Callable` — called with `peer_id: int` when a peer drops. Host uses
  this to remove player entities.
- `on_session_ended: Callable` — called after disconnect/failure cleanup. Typical use: show
  lobby UI.

### ECS-Friendly Events

Events are transient ECS components added to a **single persistent Session entity** that
`NetworkSession` owns and adds to the World on creation. Components are added for one frame
when the event fires, then removed before the next frame so systems process each event exactly
once.

**Event components (new, to be created in this phase):**

| Component | Data | When fired |
|-----------|------|-----------|
| `CN_PeerJoined` | `peer_id: int` | Any peer connects (all peers see this) |
| `CN_PeerLeft` | `peer_id: int` | Any peer disconnects |
| `CN_SessionStarted` | `is_host: bool` | Session fully established (host or client) |
| `CN_SessionEnded` | _(none)_ | Session ends (disconnect, failure, server kick) |

The Session entity also carries a **permanent** `CN_SessionState` component with readable
state: `is_connected: bool`, `is_hosting: bool`, `peer_count: int`.

**System pattern:**
```gdscript
# PlayerSpawnSystem reacts to peers joining — no Node signal wiring needed
func query():
    return q.with_all([CN_PeerJoined])

func process(entities, _, _delta):
    for e in entities:
        var ev = e.get_component(CN_PeerJoined)
        _spawn_player_for_peer(ev.peer_id)
```

### Player Spawning Scope

- **Spawning is fully game-code responsibility** — `NetworkSession` fires `CN_PeerJoined` and
  the `on_peer_connected` hook; a game system or hook handles spawn logic.
- `NetworkSession` has zero knowledge of player scenes.

### Relationship to NetworkSync

- **`NetworkSession` creates and owns `NetworkSync` internally** — game code calls
  `session.host()` / `session.join()` and never touches `NetworkSync` directly for basic use.
- A **read-only `network_sync` property** exposes the internal `NetworkSync` after connection
  for advanced use (custom sync handler registration, reconciliation interval override).
- `auto_start_network_sync: bool = true` — when `false`, `NetworkSync` is not created
  automatically; advanced game code wires it manually.

### Transport / Configuration

- **`@export var transport: TransportProvider`** — defaults to `ENetTransportProvider`. Game
  code can swap before calling `host()`/`join()` for Steam, WebSocket, etc.
- Uses the existing `TransportProvider` / `ENetTransportProvider` / `SteamTransportProvider`
  classes already in `addons/gecs_network/transports/`.

**`@export` properties on `NetworkSession`:**

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `transport` | `TransportProvider` | `ENetTransportProvider` | Network backend |
| `max_players` | `int` | `4` | Passed to transport on host |
| `default_port` | `int` | `7777` | Used when port arg omitted in host()/join() |
| `debug_logging` | `bool` | `false` | Forwarded to NetworkSync |
| `auto_start_network_sync` | `bool` | `true` | Whether NetworkSync is created automatically |

### Claude's Discretion

- Internal cleanup order (entities removed before or after peer null)
- Session entity node name and placement in the World hierarchy
- Exact timing of event component removal (end of frame vs beginning of next)
- Error message strings for transport failures

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `TransportProvider` (`addons/gecs_network/transport_provider.gd`): Abstract base for creating
  host/client peers. Already has `create_host_peer(config)` / `create_client_peer(config)` API.
- `ENetTransportProvider` (`addons/gecs_network/transports/enet_transport_provider.gd`): Default
  ENet implementation — use as the default transport on NetworkSession.
- `SteamTransportProvider` (`addons/gecs_network/transports/steam_transport_provider.gd`):
  Available for Steam builds.
- `NetworkSync.attach_to_world(world, net_adapter)` static factory: How NetworkSync is currently
  created — NetworkSession will call this internally.
- `NetAdapter` (`addons/gecs_network/net_adapter.gd`): Existing multiplayer abstraction wrapping
  Godot's multiplayer signals. NetworkSession may delegate to this internally.
- `CN_NetworkIdentity` component: Already used to mark networked entities. Session entity should
  NOT carry this (it's not a networked entity, it's a local event bus).

### Established Patterns

- GDScript-only, no typed external libs.
- `@export` properties for node configuration (consistent with `NetworkSync.debug_logging`,
  `NetworkSync.reconciliation_interval`).
- Session ID anti-ghost pattern: NetworkSync already handles this. NetworkSession just triggers
  `host()`/`join()` — session ID lifecycle stays in NetworkSync.

### Integration Points

- `NetworkSession` adds itself to the `World` node (or a node that has a `World` child).
- It calls `NetworkSync.attach_to_world(world)` during `host()`/`join()`.
- The Session entity is added to the World via `ECS.world.add_entity()` — but without
  `CN_NetworkIdentity`, so it stays local-only and doesn't trigger network spawn RPCs.
- `example_network/main.gd` is the primary consumer that will be refactored to use
  `NetworkSession`.

</code_context>

<specifics>
## Specific Ideas

- The callable hooks pattern mirrors how `_on_host_pressed` etc. are currently wired in
  `main.gd` — the goal is the same shape but without re-implementing it every game.
- Session entity as a local event bus (no CN_NetworkIdentity) is a deliberate design:
  session events are inherently local (your connection state), not synced across peers.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-abstract-multiplayer-session-boilerplate-into-networksession-node-with-host-join-api-and-ecs-friendly-events*
*Context gathered: 2026-03-12*

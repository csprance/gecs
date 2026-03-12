# Configuration

## Quick Setup

The single entry point for GECS Network is `NetworkSync.attach_to_world()`:

```gdscript
func _setup_network_sync() -> void:
    _network_sync = NetworkSync.attach_to_world(world)
    _network_sync.debug_logging = true

    # ADV-02: periodic full-state reconciliation (default: 30 s)
    _network_sync.reconciliation_interval = 30.0

    # Connect signals directly — no middleware class needed
    _network_sync.entity_spawned.connect(_on_entity_spawned)
    _network_sync.local_player_spawned.connect(_on_local_player_spawned)
```

**Signature:**

```gdscript
static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync
```

The second argument is an optional `NetAdapter` for custom networking backends or test mocks.
The second argument is an optional `NetAdapter` for custom networking backends or test mocks.
Priority is declared directly on component properties via `@export_group` annotations; there is
no configuration object to pass here.

---

## ProjectSettings

The GECS Network plugin registers the following settings on first enable. Edit them in
**Project > Project Settings > gecs_network/sync/**:

| Setting | Type | Default | Description |
|---|---|---|---|
| `gecs_network/sync/high_hz` | `int` | `20` | HIGH priority sync rate (Hz) |
| `gecs_network/sync/medium_hz` | `int` | `10` | MEDIUM priority sync rate (Hz) |
| `gecs_network/sync/low_hz` | `int` | `2` | LOW priority sync rate (Hz) |
| `gecs_network/sync/reconciliation_interval` | `float` | `30.0` | Default reconciliation interval (seconds) |

REALTIME priority (60 Hz) is hard-coded to the physics tick rate. LOW is set to `2 Hz` in
ProjectSettings; note the PLAN shows `1 Hz` as the documented target — adjust
`gecs_network/sync/low_hz` to `1` if you want 1 Hz LOW-tier sync.

---

## NetworkSync Properties

```gdscript
# Debug output (enable in development, disable in release)
@export var debug_logging: bool = false

# Reconciliation interval in seconds.
# Set to -1.0 to use the ProjectSetting default (30.0 s).
var reconciliation_interval: float  # get/set

# Custom networking backend (optional — default uses Godot's built-in multiplayer)
@export var net_adapter: NetAdapter
```

---

## NetAdapter (Custom Networking)

`NetAdapter` is an abstract interface that wraps Godot multiplayer calls. Override it to:
- Use a non-standard networking layer (Steam, custom relay)
- Mock the network in unit tests

```gdscript
class_name TaloNetAdapter
extends NetAdapter

func is_server() -> bool:
    return TaloMultiplayer.is_host()

func get_my_peer_id() -> int:
    return TaloMultiplayer.get_peer_id()

func is_in_game() -> bool:
    return TaloMultiplayer.is_connected()
```

Pass your adapter to `attach_to_world()`:

```gdscript
var adapter = TaloNetAdapter.new()
_network_sync = NetworkSync.attach_to_world(world, adapter)
```

---

## Transport Providers

The addon ships with a `TransportProvider` abstraction for swapping network transports
without changing game code.

### Built-in Providers

| Provider | Class | Transport | Requires |
|---|---|---|---|
| ENet (default) | `ENetTransportProvider` | Godot built-in ENet | Nothing extra |
| Steam | `SteamTransportProvider` | Steam Networking | GodotSteam addon |

### Using ENet (Default)

ENet works out of the box — no provider setup needed:

```gdscript
# Direct ENet connection (no TransportProvider required)
var peer = ENetMultiplayerPeer.new()
peer.create_server(DEFAULT_PORT, 3)
multiplayer.multiplayer_peer = peer
_network_sync = NetworkSync.attach_to_world(world)
```

### Using Steam

```gdscript
var steam = SteamTransportProvider.new()
if steam.is_available():
    lobby_manager.transport = steam
else:
    push_warning("GodotSteam not installed, falling back to ENet")
```

`SteamTransportProvider` uses dynamic class loading (`ClassDB`) — it compiles and loads
even without GodotSteam installed. `is_available()` returns `false` if the extension is absent.

### Custom Transport Provider

```gdscript
class_name MyCustomProvider
extends TransportProvider

func is_available() -> bool:
    return true

func create_host_peer(config: Dictionary) -> MultiplayerPeer:
    var peer = MyCustomMultiplayerPeer.new()
    peer.create_server(config.get("port", 7777))
    return peer

func create_client_peer(config: Dictionary) -> MultiplayerPeer:
    var peer = MyCustomMultiplayerPeer.new()
    peer.create_client(config.get("address", "127.0.0.1"), config.get("port", 7777))
    return peer

func get_transport_name() -> String:
    return "MyCustom"

func supports_direct_connect() -> bool:
    return true

func supports_lobbies() -> bool:
    return false
```

---

## Multiple Worlds

Use only **one `NetworkSync` per `World`**. If your game has multiple worlds (e.g., a lobby
world and a game world), create a separate `NetworkSync` instance for each and call
`attach_to_world()` separately. Do not share a single `NetworkSync` across worlds.

---

## Reconciliation

Full-state reconciliation (ADV-02) periodically broadcasts authoritative entity state to all
clients, correcting drift from packet loss or priority downsampling:

```gdscript
_network_sync.reconciliation_interval = 30.0   # Periodic: every 30 s
_network_sync.reconciliation_interval = -1.0   # Use ProjectSetting default
_network_sync.broadcast_full_state()           # One-shot: immediate broadcast (server only)
```

Set to a smaller value (5–10 s) for fast-paced games where drift is noticeable. Set to a
larger value (60–120 s) for turn-based or slow-paced games to reduce bandwidth.

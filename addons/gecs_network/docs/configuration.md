# Configuration

## SyncConfig Reference

```gdscript
var config = SyncConfig.new()

# Set component priorities
config.component_priorities = {
    "C_Velocity": SyncConfig.Priority.HIGH,      # 20 Hz
    "C_Health": SyncConfig.Priority.MEDIUM,      # 10 Hz
    "C_PlayerXP": SyncConfig.Priority.LOW,       # 1 Hz
}

# --- Filtering ---
# Blacklist mode (default): skip these components from RPC sync
config.skip_component_types = ["C_Transform"]

# OR whitelist mode: only sync these components
config.sync_only_components = ["C_Health", "C_Velocity"]

# --- Model instantiation (optional) ---
config.model_ready_component = "C_Instantiated"  # Triggers native sync setup
config.transform_component = "C_Transform"        # For position sync after spawn
config.character_body_component = "C_CharacterBody3D"
config.animation_rig_component = "C_AnimationRig"

# --- Reconciliation ---
config.enable_reconciliation = true
config.reconciliation_interval = 30.0  # seconds

# Apply config
var net_sync = NetworkSync.attach_to_world(world, config)
```

## Priority Levels

| Priority | Sync Rate | Use For |
|----------|-----------|---------|
| REALTIME | 60 Hz | Critical real-time data |
| HIGH | 20 Hz | Position, velocity, animations |
| MEDIUM | 10 Hz | Health, AI state |
| LOW | 1 Hz | XP, inventory, stats |

## Reliability

- **REALTIME/HIGH**: Unreliable (fast, may drop packets)
- **MEDIUM/LOW**: Reliable (guaranteed delivery)

## NetAdapter (Custom Networking)

Abstract interface for network operations. Override for custom networking:

```gdscript
class TaloNetAdapter extends NetAdapter:
    func is_server() -> bool:
        return TaloMultiplayer.is_host()

    func get_my_peer_id() -> int:
        return TaloMultiplayer.get_peer_id()

    func is_in_game() -> bool:
        return TaloMultiplayer.is_connected()

# Use custom adapter
var adapter = TaloNetAdapter.new()
var net_sync = NetworkSync.attach_to_world(world, null, adapter)
```

## Transport Providers

The addon ships with a `TransportProvider` abstraction for swapping network
transports (ENet, Steam, etc.) without changing game code.

### Built-in Providers

| Provider | Class | Transport | Requires |
|----------|-------|-----------|----------|
| ENet (default) | `ENetTransportProvider` | Godot built-in | Nothing extra |
| Steam | `SteamTransportProvider` | Steam Networking | GodotSteam addon |

### Choosing a Provider

**ENet (default)** — works out of the box. Supports direct IP:port connections.

```gdscript
# ENet is the default, no setup needed:
var net_sync = NetworkSync.attach_to_world(world, config)
```

**Steam** — uses GodotSteam's `SteamMultiplayerPeer`. Check availability at runtime:

```gdscript
var steam = SteamTransportProvider.new()
if steam.is_available():
    lobby_manager.transport = steam
else:
    push_warning("GodotSteam not installed, falling back to ENet")
```

The `SteamTransportProvider` uses dynamic class loading (`ClassDB`) — it compiles
and loads even without GodotSteam installed. `is_available()` returns `false` if the
GodotSteam extension is not present.

### Custom Providers

Create your own provider by extending `TransportProvider`:

```gdscript
class_name MyCustomProvider
extends TransportProvider

func is_available() -> bool:
    return true  # Check your dependencies here

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

### Switching at Project Level

Pass the provider to your lobby/connection manager before hosting or joining:

```gdscript
# In your Net autoload or main menu:
func set_transport(provider: TransportProvider) -> void:
    _lobby_manager.transport = provider

# Usage:
Net.set_transport(SteamTransportProvider.new())
Net.host_game(config)
```

All game systems, NetworkSync, and MultiplayerSynchronizer work identically
regardless of which provider is active — only the connection layer changes.

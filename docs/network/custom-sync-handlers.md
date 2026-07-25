# Custom Sync Handlers

**API:** `NetworkSync.register_send_handler()` and `NetworkSync.register_receive_handler()`

**Requirement:** ADV-03

---

## Overview

By default, GECS Network sends all CN_NetSync-tracked properties when they change (send side) and applies them verbatim with `comp.set()` when received (receive side). This works well for most properties, but certain patterns — most notably **server correction blending** — need to intercept that pipeline.

Custom sync handlers let game systems override the default send/receive behavior per component type, without forking the framework. Handlers are registered once (typically in a System's `_ready()`) and invoked automatically on every relevant tick.

---

## Handler Signatures

### Send Handler

```gdscript
func my_send_handler(entity: Entity, comp: Component, priority: int) -> Dictionary
```

| Return value           | Effect                                                     |
| ---------------------- | ---------------------------------------------------------- |
| `{ prop: value, ... }` | Send this dict instead of the default dirty-check result   |
| `{}` (empty dict)      | Suppress this component from the outbound batch entirely   |
| `null`                 | Fall through to the default dirty-check for all components |

The framework calls the send handler **for each component that has a registered handler key**, before evaluating `check_changes_for_priority()`. Only components with a custom handler are intercepted; components without one use the default dirty-check.

### Receive Handler

```gdscript
func my_receive_handler(entity: Entity, comp: Component, props: Dictionary) -> bool
```

| Return value | Effect                                                        |
| ------------ | ------------------------------------------------------------- |
| `true`       | Handler processed the update; default `comp.set()` is skipped |
| `false`      | Fall through to the default `comp.set()` path                 |

**Critical guarantee:** Regardless of the return value, the framework **always** calls `net_sync.update_cache_silent(comp, prop, value)` for every property in `props`. This prevents the dirty-change detector from re-broadcasting received values as new changes (echo-loop prevention).

---

## Server Correction Blending: Full Walkthrough

### The Problem (Before Custom Handlers)

Default sync sends and applies position verbatim. When the server corrects a client's position, the client receives `{"position": server_pos}` and `comp.set("position", server_pos)` snaps the entity immediately. On a 60 Hz game this creates a visible pop.

### The Solution (After Custom Handlers)

1. The **send handler** sends the client's locally-predicted position delta (or suppresses for non-authoritative entities).
2. The **receive handler** blends the server correction using `lerp()` instead of snapping.

### Complete PredictionSystem Example

```gdscript
class_name PredictionSystem
extends System

# Called once when the system enters the scene tree.
# Registers both custom handlers against the NetworkSync node on the World.
func _ready() -> void:
    var ns := ECS.world.get_node("NetworkSync") as NetworkSync
    if ns == null:
        push_error("PredictionSystem: NetworkSync not found on world")
        return
    ns.register_send_handler("C_Position", _send_predicted_input)
    ns.register_receive_handler("C_Position", _blend_server_correction)


# Send handler — returns the predicted position for local-authority entities.
# For all other entities (remote peers), returns {} to suppress the send.
func _send_predicted_input(entity: Entity, comp: Component, priority: int) -> Dictionary:
    # Only send from this client's own entities
    if not entity.has_component(CN_LocalAuthority):
        return {}  # Suppress — remote entities are not predicted locally

    # Return the current predicted position (the server will validate it)
    return {"position": comp.position}


# Receive handler — blends the authoritative server correction smoothly.
# Called when the server sends a position update for a non-local entity.
func _blend_server_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
    if props.has("position"):
        # Lerp toward server position instead of snapping
        comp.position = comp.position.lerp(props["position"], 0.3)
    # Return true — we handled it.
    # The framework will still call update_cache_silent() automatically.
    return true


# The system itself doesn't need a query or process() for this use case —
# the handlers are fired by the framework's sync pipeline, not by ECS.process().
func query():
    return null

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
    pass
```

### Registration Wiring

Wire handlers in `_ready()` using `ECS.world.get_node("NetworkSync")`. The NetworkSync node is always named "NetworkSync" (enforced by the factory and \_ready() fallback). Make sure your system is added to the scene tree AFTER the World and NetworkSync nodes.

---

## Registration Pattern

- **Per-component-type**: each handler applies to ALL entities that have the named component. Add per-entity logic inside the callable using `entity.has_component()` or `entity.get_component()`.
- **Idempotent**: calling `register_send_handler()` or `register_receive_handler()` with the same key replaces the previous handler.
- **Thread safety**: handlers run on the main thread during `NetworkSync._process()`. Do not call from threads.
- **Timing**: register handlers before the first network sync tick (i.e., in `_ready()` before the game starts).

```gdscript
# Minimal registration pattern
func _ready() -> void:
    var ns := ECS.world.get_node("NetworkSync") as NetworkSync
    ns.register_send_handler("MyComponent", _my_send_handler)
    ns.register_receive_handler("MyComponent", _my_receive_handler)
```

---

## Pitfalls

### 1. SPAWN_ONLY and LOCAL Components are Never Presented to Send Handlers

`CN_NetSync` excludes `SPAWN_ONLY` and `LOCAL` components from its dirty-tracking tables entirely. A custom send handler registered for a SPAWN_ONLY component type will never be called, because those components never appear in `net_sync._comp_refs`. Spawn-only data is handled by `SpawnManager.serialize_entity()`, not by the send pipeline.

### 2. Do NOT Call `update_cache_silent()` Inside a Receive Handler

The framework calls `update_cache_silent(comp, prop, value)` for every property in `props` automatically after your handler runs — regardless of whether the handler returns `true` or `false`. If your handler also calls `update_cache_silent()`, the property will be double-cached, which can cause stale values to persist across ticks.

```gdscript
# WRONG — double-caches the value
func _my_receive_handler(entity: Entity, comp: Component, props: Dictionary) -> bool:
    comp.health = props.get("health", comp.health)
    net_sync.update_cache_silent(comp, "health", props["health"])  # DO NOT DO THIS
    return true

# CORRECT — let the framework handle update_cache_silent
func _my_receive_handler(entity: Entity, comp: Component, props: Dictionary) -> bool:
    comp.health = props.get("health", comp.health)
    return true  # Framework calls update_cache_silent automatically
```

---

## Reference

For quick in-editor reference, see the inline GDScript doc comments on:

- `NetworkSync.register_send_handler()` in `addons/gecs_network/network_sync.gd`
- `NetworkSync.register_receive_handler()` in `addons/gecs_network/network_sync.gd`
- `SyncSender.register_send_handler()` in `addons/gecs_network/sync_sender.gd`
- `SyncReceiver.register_receive_handler()` in `addons/gecs_network/sync_receiver.gd`

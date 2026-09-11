# Migration Guide: Legacy Observer API → v8.0.0

> **This guide covers upgrading from the GECS 7.x Observer API to v8.0.0.** If you're starting fresh on v8.0.0, read [OBSERVERS.md](OBSERVERS.md) instead.
>
> **v8.0.0 is a clean break — no backward-compatibility shim is provided.** Use git history on the `v7.x` tags if you need the old code.

## What changed

The legacy Observer API had a split declaration model — `watch()` returned the single component to monitor, `match()` returned an optional entity filter, and three separate fixed callbacks (`on_component_added`, `on_component_removed`, `on_component_changed`) handled the three event types. It couldn't express:

- multiple component types in one observer
- relationship events
- custom (user-defined) events
- query-membership transitions (MATCH / UNMATCH)
- property-change filters by name
- composition of multiple reactive axes in one node

v8.0.0 replaces all of this with a single query-first model. `query()` returns a `QueryBuilder` with event modifiers chained on it (`.on_added()`, `.on_removed()`, `.on_changed()`, etc.). A unified `each(event, entity, payload)` callback dispatches all events. `sub_observers()` composes multiple reactive axes per node.

## Quick reference

| v7.x legacy                                                                 | v8.0.0                                                                               | Notes                                                                                                                                                       |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `func watch() -> Resource: return C_Health`                                 | `func query() -> QueryBuilder: return q.with_all([C_Health]).on_added().on_removed().on_changed()` | `query()` is the single place to declare both entity filter and event subscriptions.                                                                        |
| `func match() -> QueryBuilder: return q.with_all([C_Player])`               | Merge into `query()`: `q.with_all([C_Health, C_Player]).on_added()`                  | The old "watch component ∪ match filter" split is gone — one query expresses both.                                                                          |
| `func on_component_added(entity, component): ...`                           | `func each(event, entity, payload): if event == Observer.Event.ADDED: ...`           | `payload` is the component `Resource` instance (same content as the legacy `component`).                                                                    |
| `func on_component_removed(entity, component): ...`                         | `if event == Observer.Event.REMOVED: ...`                                             | Payload is the component that was just removed (entity still valid).                                                                                        |
| `func on_component_changed(entity, c, prop, new, old): ...`                 | `if event == Observer.Event.CHANGED: var p = payload; p.component / p.property / p.new_value / p.old_value` | Payload is now a Dictionary.                                                                                                                                |
| Observer fires for every component event matching `match()`                 | Observer fires only for events you declared via `.on_*()`                            | Forgetting to chain an event modifier produces an editor-only `push_warning` ("Observer will never fire — did you forget to chain an event?").              |
| Single watched component only                                               | Watched components = union of `with_all` + `with_any`                                | Strictly broader: one observer can span multiple component types.                                                                                           |
| N observer nodes for N components                                           | One node with `sub_observers() -> Array[[QueryBuilder, Callable]]`                   | Each tuple gets its own query + callback.                                                                                                                   |
| No MATCH / UNMATCH event                                                    | `.on_match()` / `.on_unmatch()` — monitor mode                                       | Fires once on filter-membership transition, not on every component churn.                                                                                   |
| No custom events                                                            | `.on_event(&"name")` + `world.emit_event(&"name", entity, data)`                     | Use `StringName` literals.                                                                                                                                  |
| No relationship events                                                      | `.on_relationship_added([C_X])` / `.on_relationship_removed()`                       | Optional relation-type filter list.                                                                                                                         |
| Group filter (`with_group`) on `match()` silently ignored                   | `with_group(...)` is correctly enforced                                              | This is a behavior change — observers that accidentally depended on the bug will now fire less. See [CHANGELOG.md](../../../CHANGELOG.md) for the full note. |

---

## Step-by-step migrations

### 1. Simple one-component watcher

The most common legacy observer: watch a component for its full lifecycle.

```gdscript
# OLD (v7.x)
class_name TransformObserver
extends Observer

func watch() -> Resource:
    return C_Transform

func on_component_added(entity: Entity, component: Resource) -> void:
    entity.global_transform = component.transform

func on_component_changed(entity, component, property, new_value, old_value) -> void:
    entity.global_transform = component.transform
```

```gdscript
# NEW (v8.0.0)
class_name TransformObserver
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Transform]).on_added().on_changed()

func each(event: Variant, entity: Entity, payload: Variant) -> void:
    match event:
        Observer.Event.ADDED:
            entity.global_transform = payload.transform
        Observer.Event.CHANGED:
            entity.global_transform = payload.component.transform
```

Key differences:
- Event subscriptions chain onto `query()`.
- One `each()` callback replaces three. Use `match` on the `event` parameter to route.
- For `CHANGED`, the `payload` is a Dictionary — `payload.component` is the component instance.

### 2. Watch + match filter

```gdscript
# OLD
func watch() -> Resource:
    return C_Health

func match() -> QueryBuilder:
    return q.with_all([C_Health]).with_group(["player"])

func on_component_changed(entity, component, property, new_value, old_value) -> void:
    if property == "current":
        update_health_display(entity, new_value)
```

```gdscript
# NEW
func query() -> QueryBuilder:
    return q.with_all([C_Health]).with_group(["player"]).on_changed([&"current"])

func each(event: Variant, entity: Entity, payload: Variant) -> void:
    if event == Observer.Event.CHANGED:
        update_health_display(entity, payload.new_value)
```

Key differences:
- `match()` filter merges into `query()`.
- Group filter is now correctly enforced (it was silently ignored in 7.x).
- `.on_changed([&"current"])` filters by property name — the callback only fires for `current` changes, avoiding the old `if property == "current":` gate.

### 3. Property-change observer

```gdscript
# OLD
func watch() -> Resource:
    return C_Health

func on_component_changed(entity, component, property, new_value, old_value) -> void:
    if property == "hp":
        var delta = new_value - old_value
        if delta < 0:
            play_damage_sound(entity)
```

```gdscript
# NEW
func query() -> QueryBuilder:
    return q.with_all([C_Health]).on_changed([&"hp"])

func each(event: Variant, entity: Entity, payload: Variant) -> void:
    if event == Observer.Event.CHANGED:
        var delta = payload.new_value - payload.old_value
        if delta < 0:
            play_damage_sound(entity)
```

**Reminder:** `CHANGED` events still require the component's setter to emit `property_changed` — this hasn't changed from 7.x. See [OBSERVERS.md](OBSERVERS.md#property-changes-setter-must-emit).

### 4. Multiple component types in one observer

In 7.x you needed N observer nodes for N component types. In 8.0.0, use `sub_observers()`:

```gdscript
# OLD — two separate observer classes + registration
class_name HealthLifecycleObserver
extends Observer

func watch() -> Resource: return C_Health
func on_component_added(entity, component): ...
func on_component_removed(entity, component): ...

class_name ShieldLifecycleObserver
extends Observer

func watch() -> Resource: return C_Shield
func on_component_added(entity, component): ...
func on_component_removed(entity, component): ...
```

```gdscript
# NEW — one node, two reactive axes
class_name DefenseObserver
extends Observer

func sub_observers() -> Array[Array]:
    return [
        [q.with_all([C_Health]).on_added().on_removed(), _on_health_lifecycle],
        [q.with_all([C_Shield]).on_added().on_removed(), _on_shield_lifecycle],
    ]

func _on_health_lifecycle(event, entity, payload):
    match event:
        Observer.Event.ADDED:   ...
        Observer.Event.REMOVED: ...

func _on_shield_lifecycle(event, entity, payload):
    match event:
        Observer.Event.ADDED:   ...
        Observer.Event.REMOVED: ...
```

### 5. Entity-lifecycle monitoring (NEW in 8.0.0)

7.x couldn't express "fire once when an entity starts matching a filter, once when it stops." You had to infer transitions from component add/remove events. 8.0.0 supports this via `.on_match()` / `.on_unmatch()`:

```gdscript
# NEW — only possible in 8.0.0
class_name CombatTargetMonitor
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Enemy, C_Alive, C_Visible]).on_match().on_unmatch()

func each(event: Variant, entity: Entity, _payload: Variant) -> void:
    match event:
        Observer.Event.MATCH:   add_to_target_list(entity)
        Observer.Event.UNMATCH: remove_from_target_list(entity)
```

`MATCH` fires **exactly once** when the entity transitions into the full query's match set. `UNMATCH` fires **exactly once** when it transitions out (including when the entity is removed from the world). Intermediate churn that doesn't change membership fires nothing.

### 6. Side-effect-on-remove (use `cmd`)

7.x observers that mutated the world from their callbacks were vulnerable to re-entrancy cascades. In 8.0.0 use `cmd` inside callbacks to defer mutations:

```gdscript
# NEW — mutations deferred through cmd
class_name OrphanCleanupObserver
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Unit]).on_removed()

func each(event: Variant, entity: Entity, _payload: Variant) -> void:
    if event == Observer.Event.REMOVED:
        # Direct mutation would synchronously re-trigger other observers (cascade).
        # Queue through cmd; it flushes after the callback completes (PER_CALLBACK default).
        for child in get_children_of(entity):
            cmd.remove_entity(child)
```

See [OBSERVERS.md § cmd — CommandBuffer in Observer callbacks](OBSERVERS.md#cmd--commandbuffer-in-observer-callbacks) for when direct mutation is still fine vs. when `cmd` is warranted.

---

## Gotchas

### "Observer never fires after upgrade"

Most likely cause: you translated `watch() -> return C_X` to `query() -> return q.with_all([C_X])` and forgot to chain event modifiers. In 8.0.0, a query without `.on_*()` is a no-op. In editor builds you'll see:

> `<script>: Observer.query() returned a QueryBuilder with no event modifiers (...). This observer will never fire — did you forget to chain an event?`

Chain `.on_added()`, `.on_removed()`, `.on_changed()`, or any other event modifier.

### "Observer fires less than it used to" (group/enabled filters)

If you had `with_group("players")` or `enabled()` in your `match()` filter, those were silently ignored by 7.x observer dispatch — they only affected `execute()` queries. 8.0.0 correctly enforces them. If your observer was accidentally firing for entities outside the group / disabled entities, it will now fire less. This is the intended semantics.

### `payload` is a Dictionary for `CHANGED` only

The legacy `on_component_changed(entity, component, property, new_value, old_value)` signature had separate parameters. In 8.0.0, these all come through the single `payload` parameter as a Dictionary:

```gdscript
payload.component   # the component instance
payload.property    # String, name of the property that changed
payload.new_value   # Variant
payload.old_value   # Variant
```

For `ADDED` / `REMOVED` events, `payload` is the component instance directly — no Dictionary wrapping.

### Property changes still require setter emit

This hasn't changed. `@export var hp: int = 100` alone does **not** fire `CHANGED`. Your component must implement a setter that emits `property_changed`:

```gdscript
@export var hp: int = 100 : set = set_hp
func set_hp(new_value: int) -> void:
    var old_value = hp
    hp = new_value
    property_changed.emit(self, "hp", old_value, new_value)
```

### Scene-tree registration order

Unchanged behavior, but worth re-stating: observers placed under the `Systems/` node register **before** scene-tree entities are loaded. So `@export var yield_existing = true` sees an empty entity list at setup time and retro-fires nothing. That's fine — every entity added after the observer registers is delivered through normal dispatch (`ADDED` when its components are added). `yield_existing` is primarily useful for observers added at runtime *after* entities already exist.

### Helper methods called from legacy callbacks

If your v7.x observer had private helpers invoked from `on_component_added` / `on_component_removed` / `on_component_changed` — e.g. `_refresh_ui(entity)`, `_queue_cleanup(entity)` — keep them as-is and call them from the appropriate branch in `each()`. The structure of the class doesn't change; only the entry point does.

```gdscript
# OLD — helper called from a legacy callback
func on_component_added(entity, component):
    _refresh_ui(entity)

func _refresh_ui(entity): ...

# NEW — helper called from each()
func each(event, entity, _payload):
    if event == Observer.Event.ADDED:
        _refresh_ui(entity)

func _refresh_ui(entity): ...
```

If one helper was called from multiple legacy callbacks, call it from each matching branch in `each()`, or from each entry's callable when using `sub_observers()`.

---

## Related documentation

- **[OBSERVERS.md](OBSERVERS.md)** — Complete v8.0.0 Observer API reference.
- **[CHANGELOG.md](../../../CHANGELOG.md)** — Full 8.0.0 changelog.

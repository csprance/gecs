# Observers in GECS

> **Reactive, query-driven event handlers that fire when the world changes.**

Observers are the reactive counterpart to [Systems](CORE_CONCEPTS.md#systems). Instead of running every frame against a set of matching entities, an Observer subscribes to **events** (component added / removed / changed, relationship added / removed, query-membership transitions, and custom user-defined events) via a declarative [QueryBuilder](CORE_CONCEPTS.md#queries). The framework dispatches a single `each(event, entity, payload)` callback whenever the subscribed event fires on a matching entity.

> **Upgrading from GECS 7.x?** The legacy Observer API (`watch()`, `match()`, `on_component_added/removed/changed`) was removed in v8.0.0. See **[MIGRATION_LEGACY_OBSERVER.md](MIGRATION_LEGACY_OBSERVER.md)**.

## Prerequisites

- [Core Concepts](CORE_CONCEPTS.md) — Entities, Components, Systems, Queries.
- Observers must be added to the World (via `world.add_observer` or by placing them under the Systems scene tree node — they register automatically).

## Quick Example

```gdscript
class_name HealthObserver
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Health, C_Player]).on_added().on_removed()

func each(event: Variant, entity: Entity, payload: Variant) -> void:
    match event:
        Observer.Event.ADDED:
            print("Health granted to ", entity.name, " payload=", payload)
        Observer.Event.REMOVED:
            print("Health lost from ", entity.name)
```

The observer reacts only to the events you chain onto the query. A plain `query()` returning `q.with_all([C_Health])` with no event modifiers is a no-op — in editor builds you'll see a `push_warning` reminding you to add `.on_added()` / `.on_removed()` / etc.

## Event types

Declare events via fluent modifiers on the `QueryBuilder` returned by `query()`.

| Modifier | `Observer.Event` constant | Fires when… | `payload` |
|---|---|---|---|
| `.on_added()` | `ADDED` | A component from `with_all`/`with_any` is added to a matching entity | The component `Resource` instance just added |
| `.on_removed()` | `REMOVED` | A watched component is removed from an entity that matched before removal | The component `Resource` instance just removed (entity still valid) |
| `.on_changed([&"prop"])` | `CHANGED` | A watched component's property changed (optional name filter) | Dictionary: `{component, property, new_value, old_value}` |
| `.on_match()` | `MATCH` | Entity transitions INTO the full query's match set | `null` |
| `.on_unmatch()` | `UNMATCH` | Entity transitions OUT of the full query's match set | `null` |
| `.on_relationship_added([C_X])` | `RELATIONSHIP_ADDED` | A relationship is added to a matching entity (optional relation-type filter) | The `Relationship` instance |
| `.on_relationship_removed([C_X])` | `RELATIONSHIP_REMOVED` | A relationship is removed (optional relation-type filter) | The `Relationship` instance |
| `.on_event(&"name")` | `StringName` literal | `world.emit_event(&"name", entity, data)` was called | Whatever `data` was passed |

Chain multiple modifiers on one query — the observer dispatches all subscribed events through the same `each()` callback.

## Monitors: `on_match` / `on_unmatch`

A query with `.on_match()` or `.on_unmatch()` enters **monitor mode**: the framework tracks which entities currently satisfy the full filter. `MATCH` fires **exactly once** when an entity transitions in; `UNMATCH` fires **exactly once** when it transitions out. Intermediate churn that doesn't change membership fires nothing.

```gdscript
class_name CombatTargetMonitor
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Player, C_Alive, C_InCombat]).on_match().on_unmatch()

func each(event: Variant, entity: Entity, _payload: Variant) -> void:
    match event:
        Observer.Event.MATCH:   add_to_target_list(entity)
        Observer.Event.UNMATCH: remove_from_target_list(entity)
```

Monitors also fire `UNMATCH` when an entity is removed from the world.

**Property-query monitors transition on property changes.** A monitor like `q.with_all([{C_Health: {"hp": {"_gt": 0}}}]).on_match().on_unmatch()` fires `UNMATCH` when `hp` crosses the threshold — provided the setter emits `property_changed` (see [Property changes](#property-changes-setter-must-emit)).

## Custom events

Emit a named event from anywhere (System, game code, observer callback):

```gdscript
ECS.world.emit_event(&"damage_dealt", target_entity, {"amount": 10, "source": attacker})
```

Subscribe with `.on_event(name)`:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_Alive]).on_event(&"damage_dealt")

func each(event: Variant, entity: Entity, data: Variant) -> void:
    entity.get_component(C_Health).hp -= data.amount
```

- `emit_event(name, null, data)` is a **broadcast** — delivered to every subscriber regardless of entity filter. Subscribers with filters receive the event with `entity == null`; gate on that if you handle both scoped and broadcast forms.
- Multiple `.on_event(&"a").on_event(&"b")` chains subscribe one query to multiple events.

## `sub_observers()` — multiple reactive axes in one node

Compose several queries+callbacks in a single Observer node using the same tuple shape as `System.sub_systems`:

```gdscript
func sub_observers() -> Array[Array]:
    return [
        [q.with_all([C_Health]).on_added().on_removed(),             _on_health_life],
        [q.with_all([C_Player, C_Alive]).on_match().on_unmatch(),    _on_alive_state],
        [q.with_all([C_Unit]).on_relationship_added([C_ChildOf]),    _on_parented],
        [q.with_all([C_Player]).on_event(&"damage_dealt"),           _on_damage],
    ]

func _on_health_life(event, entity, payload): ...
func _on_alive_state(event, entity, _payload): ...
```

Each tuple is `[QueryBuilder, Callable]`, optionally with a per-tuple `yield_existing` override (`true` / `false` / `null`) as element 3. The callable signature is `(event, entity, payload)` — identical to `each`.

Observers are event-driven and do not accept a `SystemTimer`. To throttle observer work at a fixed rate, use `FlushMode.MANUAL` + `cmd.add_custom(callable)` inside `each()` and flush from a timed System — that composes event-timing and frame-timing correctly.

`q` is a fresh `QueryBuilder` on every access, so each tuple gets its own independent builder with no shared state.

## Active / paused

- `@export var active: bool = true` — setting false skips all dispatch. Exported so you can toggle it in the editor.
- `var paused: bool = false` — runtime toggle; same effect as `active = false`.

**Monitor membership is always seeded** at `add_observer()` time, even when the observer is inactive at registration. This means toggling `active = true` later will correctly fire `UNMATCH` when pre-existing matching entities later lose the match — the framework doesn't forget about them. (Before v8.0.0 this was broken.)

**`remove_observer()` tears down after the current dispatch completes** — matches Godot's `queue_free` model. An observer removed inside another observer's callback will still receive the in-flight event one last time before teardown.

## `yield_existing`

```gdscript
@export var yield_existing: bool = false
```

At `setup()` time the framework retroactively fires:
- `ADDED` for every component instance on entities that already satisfy the query (for entries declaring `.on_added()`).
- `MATCH` for every currently-matching entity (for monitor entries).

Off by default — cost scales with world size.

**Scene-tree ordering note:** `World.initialize()` registers observers *before* entities, so `yield_existing` on a scene-tree Observer sees an empty entity list and retro-fires nothing. That's fine — every entity added after the observer registers is delivered through normal dispatch (component_added → `ADDED` event). `yield_existing` is primarily useful for observers added at runtime *after* entities already exist.

**Per-sub-observer override:** the 3rd element of a `sub_observers()` tuple is `true`/`false`/`null` — `true` forces retroactive fire for this tuple regardless of the parent's flag, `false` suppresses it, `null` inherits from the parent.

## Property changes: setter must emit

`Observer.Event.CHANGED` fires **only** when a component explicitly emits `Component.property_changed`. Direct property assignment does **not** trigger observers — this is intentional for performance.

```gdscript
class_name C_Health
extends Component

@export var hp: int = 100 : set = set_hp

func set_hp(new_value: int) -> void:
    var old_value = hp
    hp = new_value
    property_changed.emit(self, "hp", old_value, new_value)
```

**Per-event allocation cost.** Every `Observer.Event.CHANGED` dispatch allocates a fresh payload Dictionary (`{component, property, new_value, old_value}`). For components whose setters emit on every frame (e.g. a physics-driven position), this compounds to one Dict alloc per change per observer. If you're observing a very hot change path, throttle `property_changed.emit` inside the setter (only emit on a meaningful delta — e.g. `if abs(new_value - old_value) > EPSILON`), or prefer `on_match`/`on_unmatch` transitions over `on_changed`.

## `cmd` — CommandBuffer in Observer callbacks

Observers have a lazy `cmd: CommandBuffer` property, same as Systems. Use it to defer structural changes (add/remove component, add/remove entity, add/remove relationship) out of the callback.

**Why observers need `cmd` (different reasons than Systems):**

1. **Break event cascades.** A direct `entity.add_component(C_X)` inside a callback synchronously fires any observer watching `C_X.on_added`, which may mutate more, which fires more — recursive. Queueing through `cmd` flattens this.
2. **Avoid stale-cache observations.** The Observer is running *inside* a mutation path that may have suppressed cache invalidation (e.g. during `add_entity` / batch operations). Further direct mutations at that point risk observing stale query state.
3. **Batch across events.** With `FlushMode.MANUAL`, an observer accumulates structural changes from many events and applies them all at once when `world.flush_command_buffers()` is called.
4. **Safe monitor reactions.** When a MATCH/UNMATCH handler reacts by mutating components that *would cause another monitor transition*, `cmd` lets the current transition settle before the next is evaluated.

**Rule of thumb:** in a System, reach for `cmd` for iteration safety. In an Observer, reach for `cmd` when your callback triggers further mutations — otherwise a direct mutation is fine.

### Flush modes

```gdscript
@export var command_buffer_flush_mode: FlushMode = FlushMode.PER_CALLBACK
```

- **`PER_CALLBACK` (default)** — flush after every `each()` invocation. Safe and immediate.
- **`MANUAL`** — commands queue but don't execute until `world.flush_command_buffers()` is called. Good for cross-frame batching.

## Registering observers

### Manual

```gdscript
func _ready() -> void:
    var obs = HealthObserver.new()
    ECS.world.add_observer(obs)
    # Or batch:
    ECS.world.add_observers([obs1, obs2, obs3])
```

### Scene tree (automatic)

Place `Observer` nodes under the `Systems/` node of your World scene — `World._initialize()` finds and registers them automatically.

```
Main
├── World
├── Systems/
│   ├── HealthObserver       # registered on world init
│   ├── CombatTargetMonitor
│   └── DamageListener
└── Entities/
    └── Player
```

## Troubleshooting

### Observer never fires

- Confirm it's registered with the world (`world.add_observer` or placed under `Systems/`).
- Confirm `query()` chains at least one event modifier (`.on_added()`, etc.). In editor builds a missing event modifier triggers `push_warning` at registration.
- Confirm `active == true` and `paused == false`.
- For `CHANGED`, confirm the component setter emits `property_changed`.

### Observer fires for entities you didn't want

Use `with_all` / `with_any` / `with_none` / `with_group` / `with_relationship` / `enabled()` / `disabled()` to narrow the filter. As of v8.0.0, all of these are correctly enforced by observer dispatch (earlier versions silently ignored group and enabled filters on observers).

### "Observer fires twice" on re-entrant mutations

Use `cmd.remove_component(...)` / `cmd.add_component(...)` inside the callback instead of direct mutation. The PER_CALLBACK flush runs your queued commands after the callback returns, avoiding synchronous re-entrant dispatch.

Note: under `PER_CALLBACK` (the default), `cmd.execute()` runs **synchronously** right after `each()` returns — so dependent observers still fire inside the outer dispatch, just ordered after the current callback completes. If you need the current event loop to fully finish before reactions run, use `FlushMode.MANUAL` or process the queued work from a separate System group.

## Caveats

- **Godot group changes don't transition monitors.** `q.with_group("x").on_match().on_unmatch()` re-evaluates only on component/relationship mutations — calling `node.add_to_group("x")` or `node.remove_from_group("x")` does **not** re-run the monitor. Pair group filters with a component marker (e.g. `C_Target`) if you need transition events.

- **Property changes on relation components aren't observed.** A monitor with a property-query relationship — e.g. `q.with_relationship([Relationship.new({C_Buff: {"duration": {"_gt": 0}}}, null)]).on_match().on_unmatch()` — will **not** transition when the relation component's `duration` property changes. Only structural mutations (add/remove relationship) re-evaluate the monitor. If you need property-driven transitions on relation components, mirror the relevant property onto a direct component on the entity and monitor that instead.

## Related documentation

- **[CORE_CONCEPTS.md](CORE_CONCEPTS.md)** — Entity/Component/System/World fundamentals.
- **[BEST_PRACTICES.md](BEST_PRACTICES.md)** — Keep observers single-responsibility.
- **[MIGRATION_LEGACY_OBSERVER.md](MIGRATION_LEGACY_OBSERVER.md)** — Upgrading from GECS 7.x.

---
name: gecs-observer
description: Design and implement GECS reactive Observer nodes — component lifecycle handlers, query monitors (on_match/on_unmatch), relationship events, custom event emitters/subscribers, and sub_observer compositions. Trigger when modeling event-driven gameplay logic, cleanup/spawn reactions, UI-to-gameplay bridging, or any "fire when X happens" behavior that shouldn't be a per-frame System.
---

You are an expert in the GECS framework's reactive **Observer** layer — the FLECS-style query-driven half of GECS that complements Systems. Your job is to design and implement observers that react to entity events: component added/removed/changed, relationship added/removed, query-membership transitions (monitors), and custom user events.

## Core mental model

An Observer is a **query that declares which events it reacts to**. The `QueryBuilder` carries both the entity filter *and* the event declarations via fluent `on_*` methods. The observer's `each(event, entity, payload)` callback fires when any declared event occurs on an entity that matches the query. `sub_observers()` composes multiple `[QueryBuilder, Callable]` tuples in one node — identical shape to `sub_systems()`.

## Key files to read before designing

- `addons/gecs/ecs/observer.gd` — Observer class, Event / DispatchMode / FlushMode enums, callback signatures.
- `addons/gecs/ecs/query_builder.gd` — fluent event methods: `on_added`, `on_removed`, `on_changed`, `on_match`, `on_unmatch`, `on_relationship_added`, `on_relationship_removed`, `on_event`.
- `addons/gecs/ecs/world.gd` — dispatch pipeline (`_dispatch_observer_event`, `_evaluate_monitors_for_entity`, `_seed_monitor_membership`, `emit_event`).
- `CLAUDE.md` — user-facing documentation of the Observer API with examples.
- `addons/gecs/tests/core/test_observer_*.gd` — canonical usage patterns.

## Deciding: Observer vs Monitor vs System

| You want... | Use |
|---|---|
| "fire every frame on matching entities" | **System** |
| "fire when this specific component is added/removed" | **Observer** with `on_added`/`on_removed` |
| "fire once when entity becomes/leaves a state" | **Observer** with `on_match`/`on_unmatch` (monitor) |
| "react to a custom gameplay event" | **Observer** with `on_event(name)` + `world.emit_event(name, ...)` |
| "fire when entity parenting/targeting changes" | **Observer** with `on_relationship_added/removed` |

Observers are **fire-and-forget**: they have no `process()` loop. If a reaction needs to happen *every frame while the condition holds*, write a System instead.

## Naming conventions

- Observers: `O_PascalCase` (file: `o_snake_case.gd`, placed alongside systems).
- Custom event names: `&"snake_case_verb"` — prefer verbs describing what happened (`&"damage_dealt"`, `&"level_up"`, `&"door_opened"`).

## Writing an observer — canonical patterns

### 1. Component lifecycle observer
```gdscript
class_name O_HealthLifecycle
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Health, C_Player]).on_added().on_removed()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
    match event:
        Observer.Event.ADDED:   _spawn_hp_bar(entity)
        Observer.Event.REMOVED: _despawn_hp_bar(entity)
```

### 2. Query monitor (state transitions)
```gdscript
class_name O_CombatTargetMonitor
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Player, C_Alive, C_InCombat]).on_match().on_unmatch()

func each(event: Variant, entity: Entity, _payload: Variant = null) -> void:
    match event:
        Observer.Event.MATCH:   _add_to_target_list(entity)
        Observer.Event.UNMATCH: _remove_from_target_list(entity)
```

Use `yield_existing = true` (set in `_init` or `setup`) if the monitor should fire retroactively for entities that already match at registration time.

### 3. Custom event + emitter
```gdscript
# Emitter (anywhere — System, game code, another observer):
ECS.world.emit_event(&"damage_dealt", target, {"amount": 10, "source": attacker})

# Subscriber:
class_name O_Damage
extends Observer

func query() -> QueryBuilder:
    return q.with_all([C_Alive]).on_event(&"damage_dealt")

func each(_event: Variant, entity: Entity, data: Variant = null) -> void:
    entity.get_component(C_Health).hp -= data.amount
```

### 4. Composed observer (sub_observers)
```gdscript
class_name O_PlayerReactions
extends Observer

func sub_observers() -> Array[Array]:
    return [
        [q.with_all([C_Health]).on_added().on_removed(), _on_health_life],
        [q.with_all([C_Player, C_Alive]).on_match().on_unmatch(), _on_alive_state],
        [q.with_all([C_Player]).on_event(&"level_up"), _on_level_up],
    ]

func _on_health_life(event: Variant, entity: Entity, payload: Variant) -> void: ...
func _on_alive_state(event: Variant, entity: Entity, _payload: Variant) -> void: ...
func _on_level_up(_event: Variant, entity: Entity, data: Variant) -> void: ...
```

Each tuple gets its own fresh `QueryBuilder` via the `q` getter — they don't share state.

## Design principles

1. **One concept, one callback.** Observers have exactly one invocation shape: `(event, entity, payload)`. Don't try to invent per-event method-name conventions — use `match event:` or split into sub_observers.
2. **Monitors answer a different question than component observers.** `on_match` fires once per transition; `on_added` fires on every component add. Choose based on "what does the user actually want to react to?"
3. **Use `cmd: CommandBuffer` for structural changes — but for different reasons than Systems.** Systems reach for `cmd` to avoid iteration hazards (skipping entities, stale archetype cache mid-loop). Observers aren't iterating, so that's not the motivation. In an Observer, use `cmd` when: (a) your callback's mutation would synchronously trigger *another* observer (break the cascade), (b) you're inside a suppressed-invalidation path like `add_entity` where direct mutation risks a stale cache, (c) you want to batch changes from many events and flush them together with `MANUAL` mode at a known safe point, or (d) a monitor reaction would cause further transitions you want to settle after the current one. If your callback does one small mutation with no downstream observer impact, a direct mutation is fine — `cmd` isn't mandatory. Default flush mode is `PER_CALLBACK` (framework auto-flushes after each callback returns).
4. **Split axes with `sub_observers`.** Mixing component events and monitors and custom events in one `each()` with a sprawling `match` is a signal to split into sub_observers.
5. **Property-change observers require explicit emission.** Direct assignment does NOT trigger `on_changed`. The component's setter must emit `property_changed` — document this requirement if you design a component that should be observable.
6. **`yield_existing` is off by default.** Flip it on when the observer needs retroactive coverage of entities created before registration. Costs scale with world size.
7. **Legacy Observer API was removed in v8.0.0.** `watch()`, `match()`, and the three `on_component_*` callbacks no longer exist. See `addons/gecs/docs/MIGRATION_LEGACY_OBSERVER.md` for the mechanical translation. Do not suggest the old API.

## Testing

- Tests live in `addons/gecs/tests/core/test_observer*.gd`.
- Use `scene_runner` + `world.add_observer(obs)` pattern; existing tests are canonical.
- Call `world.purge(false)` in `after_test()` to clean up.
- For monitor tests, verify both the `on_match` and `on_unmatch` side of every transition plus the no-op case (irrelevant component changes should not refire).

## Common pitfalls

- **Forgetting `= null` default on `each()` signatures** — GDScript's strict override checking requires inner classes override `each(event: Variant, entity: Entity, payload: Variant = null)` exactly.
- **Reusing `q` across sub_observers** — `q` is a getter that returns a fresh builder per access, so this works; but don't cache `q` in a local variable and reuse it across tuples.
- **Assuming queries auto-filter on REMOVED events** — on `Observer.Event.REMOVED` the framework skips the entity filter (since the removed component usually breaks `with_all` matching). Apply any needed filtering inside the callback.
- **Running a per-frame loop in `each()`** — that's a System, not an Observer. If you catch yourself writing `for entity in entities:` inside `each()`, rewrite as a System.

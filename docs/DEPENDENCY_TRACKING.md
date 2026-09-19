# Dependency Tracking

`GECSTracker` is an observability primitive: run a computation, learn its ECS data dependencies.

```gdscript
var deps := GECSTracker.track(func(): return derive_something())
# deps.result  -> the callable's return value
# deps.queries -> Array[QueryBuilder]: every query executed during the call
# deps.reads   -> Array[Script]: every component type passed to get_component/has_component
```

Tracking sees through helper functions: a query executed three calls deep, or a `get_component` inside a utility class, is reported the same as a direct one. That is the point: callers describe *what* they compute, and the tracker answers *what data that depended on*, with no manual dependency lists to maintain.

## Use cases

- **Reactive derivations**: derive a value from the world, subscribe an `Observer` to exactly the reported dependencies, re-derive when any of them change. Dependencies can differ run to run (a derivation that early-outs touches less); re-track on each run and resubscribe when the set changes.
- **Cache invalidation**: memoize an expensive derivation, invalidate when a dependency mutates.
- **Tooling / auditing**: measure what a function actually reads.

## Turning dependencies into subscriptions

Two helpers on `QueryBuilder` support the reactive use case:

- `sensitivity() -> Array[String]`: the script paths whose mutation could affect the query's membership (all/any/exclude components plus relationship relation types). Combine with the read component paths for a stable dependency signature; resubscribe only when the signature changes.
- `has_relationship_filters() -> bool`: whether the query filters on relationships, i.e. whether a subscription derived from it needs `on_relationship_added/removed` events.

A typical mapping, per tracked dependency:

| Dependency | Observer axes |
| --- | --- |
| Executed query | same filter + `on_added().on_removed().on_changed()`, plus relationship events when `has_relationship_filters()` |
| Component read | `with_all([type]).on_added().on_removed().on_changed()` |

Reminder: `on_changed` only fires for components whose setters emit `property_changed` (see [OBSERVERS.md](OBSERVERS.md)). Tracking a read of a silent component yields membership reactivity but not value reactivity.

## Cost and constraints

- **Inactive (the default)**: one static bool branch in `QueryBuilder.execute()` and in `Entity.get_component()` / `has_component()`. No allocations, no callables invoked.
- **Active**: one static callback per query execution / component read, for the duration of the tracked call only.
- **Not re-entrant**: `track()` calls must not nest (single static accumulator set).
- The low-level hooks (`QueryBuilder.set_execute_tracker`, `Entity.set_read_tracker`) are public for custom instrumentation, but `GECSTracker.track()` is the intended entry point.

## Worked example: a reactive derivation

```gdscript
var deps := GECSTracker.track(func():
	var player = world.query.with_all([C_Player]).execute_one()
	return player.get_component(C_Health).current if player else null
)
# deps.queries: the player query        -> watch membership + changes
# deps.reads:   [C_Health]              -> watch C_Health anywhere
# Subscribe an Observer to those axes; when it fires, re-track and re-derive.
```

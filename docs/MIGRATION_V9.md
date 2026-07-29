# Migrating to GECS v9.0

v9 is a performance-focused major release. The QueryBuilder fluent API and the
Component authoring model (Resources with `@export`) are **unchanged**. The
breaking changes are concentrated in entity identity, iteration semantics, and
archetype lifecycle. See `PERFORMANCE.md` for the audit and numbers.

## 1. Entity identity: one int handle

`Entity.id` is now a 64-bit **generational handle** (int). The v8 String UUID
`id` and the internal `ecs_id` are both gone — one identity for relationship
keys, serialization, and networking.

| v8 | v9 |
|---|---|
| `entity.id` (String UUID) | `entity.id` (int handle, 0 until added to a world) |
| `entity.id = "singleton_player"` | `entity.alias = &"singleton_player"` |
| `world.get_entity_by_id("abc-123")` | `world.get_entity_by_id(handle)` / `world.get_entity_by_alias(&"name")` |
| `entity.ecs_id` | `entity.id` |
| — | `world.is_alive(handle)` — O(1) stale-handle check |
| — | `world.set_entity_range(base_index)` — reserve index space on network clients |

- **Aliases** are names, not identities: registered at `add_entity`, looked up
  with `get_entity_by_alias`, and a same-alias add replaces the existing entity
  (the v8 singleton-id pattern).
- **Pre-assigned ids** (network replication, deserialization): set a nonzero
  `entity.id` before `add_entity` and the world registers it verbatim.
- **Old save files** (String UUIDs) still load: the shim allocates fresh
  handles and resolves relationship references through the load-time mapping.
- **Network protocol**: entity references on the wire are ints now (~8 bytes vs
  a 36-char UUID). Old and new builds cannot sync with each other.

## 2. Iteration: deferred by default

`System.safe_iteration` now defaults to **false** — systems iterate archetype
entity arrays zero-copy (the v8 default copied every archetype's entity array
every frame). Direct structural changes (add/remove component/entity/
relationship) during iteration can skip entities via swap-remove; a debug-mode
error identifies offenders.

Migrate systems that mutate structure inside `process()`:

```gdscript
# v8 (still works, but now needs opt-in)
func process(entities, _components, delta):
    for entity in entities:
        if done(entity):
            ECS.world.remove_entity(entity)   # direct mutation mid-loop

# v9 — preferred: route through the CommandBuffer
func process(entities, _components, delta):
    for entity in entities:
        if done(entity):
            cmd.remove_entity(entity)

# v9 — or opt back into copying for this system
func _init():
    safe_iteration = true
```

Project-wide escape hatch: `gecs/settings/safe_iteration_default = true`.

Bonus: CommandBuffer flushes now coalesce archetype moves — a queued
remove+add state transition costs ONE archetype transition per entity
(signals/observers still fire per-op in exact queued order).

## 3. Archetype lifecycle

- **Empty archetypes are retained** so their transition edges survive
  spawn/despawn churn. Call `world.compact()` at a quiet point (level change)
  to reclaim them. They're invisible to queries.
- **`world.entities` order is not stable** across removals (O(1) swap-remove).
  Don't rely on insertion order; sort explicitly if you need an order.

## 4. Change detection (new, FLECS-style)

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_Position, C_Velocity]).changed([C_Position])
```

The system only receives entities whose listed components were **written**
since its last run — and skips entire archetypes nothing wrote to. Writes are
detected from setters that emit `property_changed` (same contract as
observers); after direct mutation call `entity.mark_changed(component)`.
Outside systems, use `q.changed([...]).since(tick)` against
`world.change_tick`.

## 5. Smaller changes

- `world.query` no longer signal-connects each vended QueryBuilder (this
  leaked builders in v8). Builders self-detect staleness; `cache_invalidated`
  still fires per structural change for external listeners.
- `get_cache_stats()` reason strings changed (invalidation is now a cheap
  membership bump; the archetype cache is maintained incrementally).
- Performance monitor entries are named `<script_name> - [GECS]`.
- Run tests with `tools/run_tests.sh` (see CLAUDE.md) — never `runtest.cmd`
  directly.

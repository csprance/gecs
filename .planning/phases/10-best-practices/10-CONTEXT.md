# Phase 10: Best Practices — Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify and fix three docs:

- `addons/gecs/docs/BEST_PRACTICES.md`
- `addons/gecs/docs/PERFORMANCE_OPTIMIZATION.md`
- `addons/gecs/docs/TROUBLESHOOTING.md`

Goal: every example uses real API, every number comes from actual benchmarks, every failure mode is reproducible. Patterns in BEST_PRACTICES should reference zamn's actual code where applicable. No other docs are in scope.

</domain>

<decisions>
## Implementation Decisions

### Tone & style (carried from Phase 8/9)

- Strip all emoji from headers and body text (📋, 🎯, 🧱, ⚙️, 🏗️, 🎮, 🚀, 🛠️, 🎭, 🎛️, 🐌, 🏆, 🥈, 🥉, ⭐, ⚡, 📊, 🔍, 💥, 🚫, 🔧, 📚 all present)
- Strip emoji from code comments (✅, ❌, 🏆, 🥈, 🥉, 🐌)
- No trailing italic quote footers
- No "⭐ NEW!" tags in headers
- Keep blockquote callout boxes (`> **Note:** ...`), no emoji inside them

### Rewrite depth

- BEST_PRACTICES.md: Moderate edit — structure is good, patterns are mostly generic-but-accurate. Add at least three zamn-sourced patterns with attribution. Fix technical errors.
- PERFORMANCE_OPTIMIZATION.md: Moderate edit — replace fabricated benchmark numbers with real data from `reports/perf/`, fix fabricated API calls, fix `enabled(true)` → `enabled()`, fix `with_group("x")` → `with_group(["x"])`. Remove sections claiming features that don't exist.
- TROUBLESHOOTING.md: Light edit — structure and failure modes are mostly real. Fix fabricated API calls. Remove debug tool suggestions that reference non-existent APIs.

### Zamn patterns to extract (BEST-01)

The success criteria require "at least three patterns extracted from zamn's actual systems." Based on context gathering, these are real zamn patterns worth featuring:

1. **Relationship factory class** (`Rels`) — zamn's `game/lib/ecs/relationships.gd` uses static vars (not factory functions) for pre-built relationship templates. The naming convention `R_<Name>_<TargetType>` is a proven pattern.
2. **Sub-systems pattern** — zamn's `WeaponsSystem`, `DamageSystem`, `PlayerControlsSystem`, `GearSystem`, `CooldownSystem` all use `sub_systems()` returning `[query, callable]` tuples to organize complex logic within a single system.
3. **PendingDelete pattern** — zamn's `PendingDeleteSystem` uses a `C_IsPendingDelete` tag component with a `delete_delay` timer, handling persistent entities differently from ephemeral ones.
4. **Scene-based system groups** — zamn's `main.gd` uses `world.process(delta, "group")` with groups like "run-first", "input", "gameplay", "physics", "ui", "run-last", "debug". The `default_systems.tscn` organizes systems as children of group nodes.
5. **iterate() for batch processing** — zamn's `FrictionSystem`, `TransformSystem`, `PendingDeleteSystem` all use `.iterate([Components])` with indexed array access in the loop.

Pick the three strongest/most distinctive for inclusion. Claude's discretion.

### Performance numbers (BEST-02)

Real benchmark data from `reports/perf/` (latest 10K entity results on 4.6-dev3):

| Query Type   | 10K entities (ms) | Source file                         |
| ------------ | ----------------- | ----------------------------------- |
| `enabled()`  | ~0.113            | `query_only_enabled_baseline.jsonl` |
| `with_all`   | ~0.237            | `query_with_all.jsonl`              |
| `with_any`   | ~0.308            | `query_with_any.jsonl`              |
| `with_group` | ~13.6             | `query_with_group.jsonl`            |

The doc's current numbers (0.05, 0.6, 5.6, 16ms) are from v5.0.0-rc4 and do not match current benchmarks. Replace with real numbers sourced from actual JSONL data. Reference the report files so numbers can be re-verified.

### Fabricated APIs to remove or fix

The following APIs are referenced in the three docs but DO NOT EXIST in the GECS source:

| Fabricated API                                 | Doc                | Fix                                                                     |
| ---------------------------------------------- | ------------------ | ----------------------------------------------------------------------- |
| `ECS.world.enable_profiling = true`            | PERF, TROUBLESHOOT | Remove — no such property                                               |
| `ECS.world.entity_count`                       | PERF, TROUBLESHOOT | Replace with `ECS.world.entities.size()`                                |
| `ECS.world.get_system_count()`                 | TROUBLESHOOT       | Remove — no such method                                                 |
| `ECS.world.get_all_entities()`                 | TROUBLESHOOT       | Replace with `ECS.world.entities` (it's a Dictionary)                   |
| `ECS.world.create_entity()`                    | PERF               | Remove — entities are created via `Entity.new()` + `world.add_entity()` |
| `ECS.set_debug_level(ECS.DEBUG_VERBOSE)`       | TROUBLESHOOT       | Remove — no such method                                                 |
| `enabled(true)` / `enabled(false)`             | BEST, PERF         | Fix to `enabled()` / `disabled()` — no args                             |
| `get_cache_stats()` keys `"hits"` / `"misses"` | PERF               | Fix to `"cache_hits"` / `"cache_misses"`                                |
| `with_group("player")` bare string             | BEST, PERF         | Fix to `with_group(["player"])`                                         |

### with_group syntax fix

Same as Phases 8/9: `with_group` takes `Array[String]`, not a bare `String`. All occurrences in these three docs must be fixed.

### Claude's Discretion

- How to restructure the performance ranking section to use real numbers cleanly
- Whether the "Entity Scale Guidelines" section in PERF stays (it's generic advice, not source-verified, but not harmful)
- Whether to keep the "Entity Pooling" section in PERF (mentions `ECS.world.create_entity()` which doesn't exist)
- Which three zamn patterns to highlight and how much code to show
- Section ordering within each doc

</decisions>

<code_context>

## Existing Code Insights

### Zamn Patterns (verified source)

**Relationship factory** (`game/lib/ecs/relationships.gd`):

```gdscript
class_name Rels
static var R_Attacking_Players := Relationship.new(C_IsAttacking.new(), Player)
static var R_Attacking_Any := Relationship.new(C_IsAttacking.new())
static var R_Chasing_Players := Relationship.new(C_IsChasing.new(), Player)
static var R_Damaged_Any := Relationship.new(C_Damaged.new())
# ... etc
```

**Sub-systems pattern** (`game/systems/combat/s_damage.gd`):

```gdscript
func sub_systems():
    return [
        [q.with_all([C_Health]).with_relationship([Rels.R_Damaged_Any])
         .with_none([C_Death, C_Invunerable]).iterate([C_Health]),
         damage_subsys],
        [q.with_relationship([Rels.R_Damaged_Any]),
         damage_relation_subsys],
    ]
```

**PendingDelete pattern** (`game/systems/core/s_pending_delete.gd`):

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_IsPendingDelete]).with_none([C_Deleted]).iterate([C_IsPendingDelete])
```

**Scene-based groups** (`game/main.gd`):

```gdscript
func _process(delta):
    world.process(delta, "run-first")
    world.process(delta, "input")
    world.process(delta, "gameplay")
    world.process(delta, "ui")
    world.process(delta, "run-last")

func _physics_process(delta):
    world.process(delta, "physics")
    world.process(delta, "debug")
```

**iterate() batch pattern** (`game/systems/physics/s_friction.gd`):

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_Velocity, C_Friction]).iterate([C_Velocity, C_Friction])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    var c_velocities = components[0]
    var c_frictions = components[1]
    for i in entities.size():
        var velocity = c_velocities[i] as C_Velocity
        var friction = c_frictions[i] as C_Friction
        # ... process
```

### Real API (verified)

- `ECS.world.get_cache_stats()` → returns `{"cache_hits": N, "cache_misses": N, "hit_rate": F, "cached_queries": N, ...}`
- `ECS.world.reset_cache_stats()` → resets counters
- `ECS.world.entities` → Dictionary of entities (not `.entity_count`)
- `entity.add_components([...])` → batch add (real)
- `ECS.world.add_entities([...])` → batch add entities (real)
- `enabled()` / `disabled()` on QueryBuilder → no args (no `enabled(true)`)
- `with_group(groups: Array[String])` → MUST be array

### Integration Points

- BEST_PRACTICES → CORE_CONCEPTS (link: "see Systems section")
- BEST_PRACTICES → PERFORMANCE_OPTIMIZATION (link: "see Performance Guide")
- TROUBLESHOOTING → GETTING_STARTED (link: "see Getting Started")
- PERFORMANCE_OPTIMIZATION → TROUBLESHOOTING (link: "see Troubleshooting Guide")
- All three in `addons/gecs/docs/` — relative links work

</code_context>

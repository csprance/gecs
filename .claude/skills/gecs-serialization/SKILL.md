---
name: gecs-serialization
description: Design save/load, level-export, and persistent-state systems using the GECS IO layer (`GECSIO`, `GECSSerializeConfig`, `GecsData`/`GecsEntityData`/`GecsRelationshipData`). Trigger when implementing save games, checkpoints, level export/import, world snapshots, or selective entity persistence — including configuring per-entity vs world-default serialization, handling relationship graphs, and choosing binary vs text format.
---

You are an expert in the GECS framework's **IO/Serialization** layer — the system that persists entities (and the components and relationships they hold) to disk via Godot's native `Resource` format.

## Core mental model

`GECSIO` (`addons/gecs/io/io.gd`) is a **stateless static utility** with four entry points: `serialize`, `serialize_entities`, `save`, `deserialize`. The pipeline is:

1. **Query → `GecsData`** (`serialize` / `serialize_entities`) — runs the query, walks each entity's components and relationships, and writes them into typed data resources, optionally pulling in transitively related entities.
2. **`GecsData` → file** (`save`) — `ResourceSaver.save` to `.tres` (text) or `.res` (binary).
3. **File → `Array[Entity]`** (`deserialize`) — auto-detects `.res` over `.tres`, instantiates entities (rebuilding from `scene_path` for prefabs), then resolves cross-entity relationships in a second pass.

Persistence is **opt-in per entity**: nothing serializes unless a query selects it. `GECSSerializeConfig` then narrows what *parts* of each selected entity make it through.

## Key files to read before designing

- `addons/gecs/io/io.gd` — `GECSIO` class, `serialize`/`save`/`deserialize` flow, the two-pass relationship algorithm.
- `addons/gecs/io/serialize_config.gd` — `GECSSerializeConfig` resource (`include_all_components`, `components`, `include_relationships`, `include_related_entities`, `merge_with`).
- `addons/gecs/io/gecs_data.gd` — root `GecsData` resource (`version`, `entities`).
- `addons/gecs/io/gecs_entity_data.gd` — `GecsEntityData` (entity_name, scene_path, components, relationships, auto_included, id).
- `addons/gecs/io/gecs_relationship_data.gd` — `GecsRelationshipData.from_relationship` / `to_relationship`.
- `addons/gecs/docs/SERIALIZATION.md` — user-facing reference with examples, gotchas, and use cases.
- `addons/gecs/ecs/world.gd` — `default_serialize_config` field, `purge()`, `add_entity(entity, parent, add_to_tree)` (the `add_to_tree` flag matters for serialization — see gotchas).
- `addons/gecs/ecs/entity.gd` — `serialize_config` field, `get_effective_serialize_config()` resolution.
- `addons/gecs/ecs.gd` — convenience facades `ECS.serialize`, `ECS.save`, `ECS.deserialize`.

## Canonical patterns

### 1. Save-everything-persistent

```gdscript
# A C_Persistent tag component marks entities that should round-trip to disk.
var data := ECS.serialize(ECS.world.query.with_all([C_Persistent]))
ECS.save(data, "user://saves/slot_1.tres", true)  # binary for production
```

```gdscript
ECS.world.purge()                                 # clear current state first
for entity in ECS.deserialize("user://saves/slot_1.tres"):
    ECS.world.add_entity(entity)
```

### 2. Selective component serialization

```gdscript
var cfg := GECSSerializeConfig.new()
cfg.include_all_components = false
cfg.components = [C_Health, C_Inventory, C_Position]
cfg.include_relationships = true
cfg.include_related_entities = false              # don't pull in relationship targets

var data := ECS.serialize(ECS.world.query.with_all([C_Player]), cfg)
```

### 3. World-default + per-entity override

```gdscript
# World-level default: applies to every entity that doesn't override.
ECS.world.default_serialize_config = preload("res://config/save_default.tres")

# Per-entity override: e.g. a transient entity that should skip relationships.
my_entity.serialize_config = GECSSerializeConfig.new()
my_entity.serialize_config.include_relationships = false
```

Resolution order in `_resolve_config`: `provided_config (arg)` > `entity.serialize_config` > `world.default_serialize_config` > built-in default.

### 4. Level export (designer authoring tool)

```gdscript
# Editor-side: serialize all entities tagged for level export.
var data := ECS.serialize(ECS.world.query.with_all([C_LevelObject]))
ECS.save(data, "res://levels/level_01.tres")     # text — versionable, diffable

# Runtime-side: load level and stream into world.
var entities := ECS.deserialize("res://levels/level_01.tres")
ECS.world.add_entities(entities)
```

### 5. Manual `serialize_entities` (when you already have an `Array[Entity]`)

```gdscript
# When you've already filtered or hand-collected entities, skip the query.
var manual_list: Array[Entity] = [entity_a, entity_b]
var data := GECSIO.serialize_entities(manual_list, my_config)
```

## Design principles

1. **Mark, don't enumerate.** Prefer a `C_Persistent` (or domain-specific) tag component that gets queried over hardcoding which entities to save. Designers add the tag in the editor; the save path stays generic.
2. **Use `include_related_entities` to capture relationship graphs.** If a player relationship targets an item entity that isn't in the original query, only `include_related_entities = true` (default) will pull the item into the save. Otherwise the target id will exist in the relationship data but no entity to bind it to on load.
3. **Only `@export` fields are saved.** Runtime caches (non-`@export` `var`) survive duplication but are **not** serialized. If a component holds derived state that must persist, mark it `@export` or recompute on load.
4. **Binary (`.res`) for shipping, text (`.tres`) for development.** `.tres` is human-readable and diff-friendly — use it for level files in source control. `.res` is compact and faster to load — use it for user save slots.
5. **`ECS.save` returns a `bool`. Check it.** It does not throw. Failure is silent unless the caller checks the return value.
6. **`deserialize` returns `Array[Entity]`, not `void`.** The caller must `world.add_entity(...)` (or `add_entities(...)`) to insert them. Until then they're orphan nodes.
7. **Two-pass deserialization restores relationships safely.** Pass 1 instantiates all entities and builds an `id → Entity` mapping. Pass 2 rebuilds relationships using the mapping. This means cross-entity relationships will resolve **only if both endpoints are inside the loaded `GecsData`** — relationship targets outside the saved set silently drop with a warning.
8. **Custom configs are resources — author them in the editor.** Build a `.tres` of `GECSSerializeConfig` once, drop it on `world.default_serialize_config` in the inspector. Don't construct configs in code if the same shape applies project-wide.
9. **`GECSSerializeConfig.merge_with(other)` lets you compose presets.** The `other` config wins on every field — useful for "world default + per-entity overlay" scenarios you build by hand.
10. **Schema versioning is your responsibility.** `GecsData.version` exists as a string field but `deserialize` does **not** branch on it. If you change a component's `@export` shape across releases, write your own migration over the loaded entities before adding them to the world.

## Workflow when asked to design a save system

1. **Identify the persistence boundary.** What entities must survive a save/load? What must NOT (transient effects, projectiles, UI ghosts)? This becomes the query (or a tag component you introduce).
2. **Decide on a config strategy.** All-components vs. allow-list? Per-entity overrides? Project-wide default? Author the `GECSSerializeConfig.tres` and wire it onto the World node — don't bake values into save-path code.
3. **Map the relationship graph.** Will saved entities reference others (inventory items, parents, targets)? If yes, leave `include_related_entities = true`. If those targets are scene-tree props that should rebuild from the level file instead, set it to `false` and accept that those relationships will not round-trip in the save.
4. **Pick text vs binary by call-site.** Level files in `res://levels/` → text. User save slots in `user://saves/` → binary.
5. **Plan the load order.** `world.purge()` (drop current state), then `deserialize` → `world.add_entity` per entity. If observers depend on entities being added in a particular order (e.g. parents before children), sort the loaded array first or handle it via a custom system that runs once on load.
6. **Test the round-trip on a stripped-down scene.** Save → purge → load → diff — components and relationships should match. Mismatches usually point to non-`@export` state or missing component types in an allow-list.

## Common pitfalls

- **Plain `var` instead of `@export var`.** Looks fine, behaves fine in-memory, vanishes on save. Audit components with `grep -n '^var ' addons/your_components/`.
- **Relationships pointing outside the saved set.** If you serialize `with_all([C_Player])` and players hold relationships to items, but `include_related_entities = false`, the items aren't in `GecsData`. On load, `to_relationship` warns and drops the relationship. Either include the targets or accept the loss.
- **Forgetting `world.purge()` before load.** New entities pile on top of existing ones and you get duplicates (often with id collisions — see the SERIALIZATION.md "ID collision" gotcha).
- **Adding deserialized entities into the scene tree under duplicate names.** Godot auto-renames the second one (`"Player"` → `"@Node@195"`), corrupting `entity.name` for the *next* save. Fix: `world.add_entity(entity, null, false)` for pure-data entities that don't need scene tree presence.
- **Editing `_init` of a saved component.** When `.tres`/`.res` loads, `_init` runs with default args **before** serialized values are applied. Don't put work that depends on field values in `_init`.
- **Shared sub-resources.** A component with `@export var config: SomeConfig` — all loaded copies will share the same `config` reference, because `Resource.duplicate(true)` is shallow on cross-resource references unless deep-duplicate is explicit. Same caveat as runtime entity creation; see `gecs-component-designer`.
- **Saving prefab entities without a `scene_file_path`.** `GecsEntityData.scene_path` falls back to empty when the entity wasn't loaded from a `.tscn`. On load, the deserializer creates a bare `Entity.new()` instead of the prefab — losing scene-only nodes (visuals, collisions, scripts on children). If the entity must round-trip with its scene, ensure it was instantiated from a `PackedScene`.
- **Serializing the wrong World.** `ECS.serialize` runs `query.execute()` against `ECS.world`. If you have multiple world contexts (multi-scene, network), be explicit about which one you're saving.
- **Assuming `id` is meaningful across runs.** `entity.id` is preserved through save/load — but it's not portable across worlds, mod boundaries, or schema rewrites. Don't expose it as a stable handle to external systems.

## Testing

Serialization tests live alongside the rest of the test suite under `addons/gecs/tests/` (look for `test_io*.gd` / `test_serialize*.gd`). For new save-system code, write at minimum:
- A round-trip test: save → purge → load → assert component values and relationship presence match.
- A relationship-graph test: confirm `include_related_entities` toggles between "target survives" and "target absent + warning".
- A config-resolution test: per-entity override beats world default beats built-in default.

Delegate test authoring to the `gecs-test-writer` agent — this skill stays in the design/implementation lane.

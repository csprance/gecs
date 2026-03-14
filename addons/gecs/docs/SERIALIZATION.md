# GECS Serialization

The GECS framework provides a serialization system using Godot's native resource format, enabling persistent game states, save systems, and level data management.

## Quick Start

### Basic Save/Load

```gdscript
# Save entities with persistent components
var query = ECS.world.query.with_all([C_Persistent])
var data = ECS.serialize(query)
ECS.save(data, "user://savegame.tres")

# Load entities back
var entities = ECS.deserialize("user://savegame.tres")
for entity in entities:
    ECS.world.add_entity(entity)
```

### Binary Format

```gdscript
# Save as binary for production (more compact files)
ECS.save(data, "user://savegame.tres", true)  # Creates .res file

# Load auto-detects format (tries .res first, then .tres)
var entities = ECS.deserialize("user://savegame.tres")
```

## API Reference

### ECS.serialize(query: QueryBuilder, config: GECSSerializeConfig = null) -> GecsData

Converts entities matching a query into serializable data. Pass a `GECSSerializeConfig` to control which components and relationships are included.

**Example:**

```gdscript
# Serialize specific entities
var player_query = ECS.world.query.with_all([C_Player, C_Health])
var save_data = ECS.serialize(player_query)
```

### ECS.save(data: GecsData, filepath: String, binary: bool = false) -> bool

Saves data to disk. Returns `true` on success.

**Parameters:**

- `data`: Serialized entity data
- `filepath`: Save location (use `.tres` extension)
- `binary`: If `true`, saves as `.res` (more compact, faster loading)

### ECS.deserialize(filepath: String) -> Array[Entity]

Loads entities from file. Returns empty array if file doesn't exist.

**Auto-detection:** Tries binary `.res` first, falls back to text `.tres`.

## GECSSerializeConfig

`GECSSerializeConfig` controls what gets serialized. Set it on a World node as `default_serialize_config` to apply to all entities, or on individual entities as `serialize_config` to override the world default for that entity.

**Fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `include_all_components` | `bool` | `true` | Serialize all components on each entity. Set to `false` to use the `components` list instead. |
| `components` | `Array` | `[]` | Component types to include when `include_all_components` is `false`. |
| `include_relationships` | `bool` | `true` | Serialize entity relationships. Relationships are supported and serialized by default. |
| `include_related_entities` | `bool` | `true` | Auto-include entities that are targets of relationships, even if they don't match the query. |

**Selective serialization example:**

```gdscript
var config = GECSSerializeConfig.new()
config.include_all_components = false
config.components = [C_Health, C_Inventory]   # only these types
config.include_relationships = true
config.include_related_entities = false        # don't pull in relationship targets

var q = ECS.world.query.with_all([C_Player])
var data = ECS.serialize(q, config)
```

**World-level config:**

```gdscript
# Set default config on the World node (Inspector or code)
ECS.world.default_serialize_config = GECSSerializeConfig.new()
# Per-entity: entity.serialize_config overrides world default for that entity
```

## Component Serialization

Only `@export` variables are serialized:

```gdscript
class_name C_PlayerData
extends Component

@export var health: float = 100.0        # Saved
@export var inventory: Array[String]     # Saved
@export var position: Vector2            # Saved

var _cache: Dictionary = {}              # Not saved
```

**Supported types:** All Godot built-ins (int, float, String, Vector2/3, Color, Array, Dictionary, etc.)

## Use Cases

### Save Game System

```gdscript
func save_game(slot: int) -> void:
    var q = ECS.world.query.with_all([C_Persistent])
    var data = ECS.serialize(q)
    ECS.save(data, "user://saves/slot_%d.tres" % slot, true)

func load_game(slot: int) -> void:
    ECS.world.purge()  # Clear current state

    var entities = ECS.deserialize("user://saves/slot_%d.tres" % slot)
    for entity in entities:
        ECS.world.add_entity(entity)
```

### Level Export/Import

```gdscript
func export_level():
    var query = ECS.world.query.with_all([C_LevelObject])
    var data = ECS.serialize(query)
    ECS.save(data, "res://levels/level_01.tres")

func load_level(path: String):
    var entities = ECS.deserialize(path)
    ECS.world.add_entities(entities)
```

### Selective Serialization

```gdscript
# Save only player data
var player_query = ECS.world.query.with_all([C_Player])

# Save entities in specific area
var area_query = ECS.world.query.with_group(["area_1"])

# Save entities with specific components
var combat_query = ECS.world.query.with_all([C_Health, C_Weapon])
```

## Data Structure

The system uses two main resource classes:

### GecsData

```gdscript
class_name GecsData
extends Resource

@export var version: String = "0.2"
@export var entities: Array[GecsEntityData] = []
```

### GecsEntityData

```gdscript
class_name GecsEntityData
extends Resource

@export var entity_name: String = ""
@export var scene_path: String = ""      # For prefab entities
@export var components: Array[Component] = []
@export var relationships: Array[GecsRelationshipData] = []
@export var auto_included: bool = false
@export var id: String = ""
```

## Error Handling

```gdscript
# Serialize never fails (returns empty data if no matches)
var data = ECS.serialize(query)

# Check save success
if not ECS.save(data, filepath):
    print("Save failed - check permissions")

# Handle missing files
var entities = ECS.deserialize(filepath)
if entities.is_empty():
    print("No data loaded")
```

## Performance

- **Memory:** Creates component copies during serialization
- **Scale:** Tested with 100+ entities, sub-second performance

## Binary vs Text Format

**Text (.tres):**

- Human readable
- Editor inspectable
- Version control friendly
- Development debugging

**Binary (.res):**

- More compact file size
- Faster loading
- Production builds
- Auto-detection on load

## File Structure Example

```tres
[gd_resource type="GecsData" format=3]

[sub_resource type="C_Health" id="1"]
current = 85.0
maximum = 100.0

[sub_resource type="GecsEntityData" id="2"]
entity_name = "Player"
components = [SubResource("1")]

[resource]
version = "0.2"
entities = [SubResource("2")]
```

## Best Practices

1. **Use meaningful filenames:** `player_save.tres`, `level_boss.tres`
2. **Organize by purpose:** `user://saves/`, `res://levels/`
3. **Handle missing components gracefully**
4. **Use binary format for production**
5. **Version your save data for compatibility**
6. **Test with empty query results**

## Limitations

- Prefab entities need scene files present
- External resource references need manual handling

# Technology Stack: Structural Relationship Pairs in GECS Archetypes

**Project:** GECS v7.1.0 - Structural Relationship Queries
**Researched:** 2026-03-18
**Focus:** How FLECS encodes (Relation, Target) pairs, and GDScript-native analogues

---

## How FLECS Encodes Relationship Pairs

### The Core Insight: Pairs Are Just Component IDs

FLECS treats a `(Relation, Target)` pair as a single 64-bit ID that is stored in the archetype type array alongside regular component IDs. On the storage level, a pair is indistinguishable from a component -- the archetype table has a column for it, entities with the same set of pairs live in the same table, and queries match pairs the same way they match components.

**Confidence: HIGH** -- This is extensively documented in FLECS official docs and Sander Mertens' articles.

### Bit Layout: `ecs_pair(relation, target)`

FLECS entity IDs are 64-bit. The lower 32 bits are the "identifying" part (the entity index). The upper 32 bits are used for generation/liveliness tracking. Since both halves of a pair must be alive entities, the generation bits are redundant -- FLECS repurposes them:

```
Pair ID (64 bits):
  [63]     = 1 (pair flag bit, distinguishes from regular component IDs)
  [62:32]  = relation entity index (lower 32 bits of relation entity ID)
  [31:0]   = target entity index (lower 32 bits of target entity ID)
```

The pair flag bit (bit 63) ensures a pair ID can never collide with a regular entity/component ID. Extraction is trivial: mask + shift.

**Confidence: HIGH** -- Confirmed by multiple sources including FLECS source headers and Sander Mertens' "Making the most of ECS identifiers" article.

### Archetype Graph Edges for Pairs

FLECS uses a hybrid edge storage:
- **Low IDs** (< `FLECS_HI_COMPONENT_ID`, default 256): Direct array indexing for O(1) edge lookup
- **High IDs** (including ALL pairs): HashMap-based edge lookup

Because the pair flag bit (bit 63) is always set, pair IDs are always "high IDs." This means pair-based archetype transitions always go through the hashmap path, introducing roughly 5-10% overhead compared to low-ID component transitions. FLECS considers this acceptable.

**Confidence: HIGH** -- Explicitly stated in FLECS documentation.

### Wildcard Queries

FLECS supports wildcard patterns:
- `(Likes, *)` -- match any entity with a Likes relationship to anything
- `(*, Alice)` -- match any relationship targeting Alice
- `(*, *)` -- match any relationship at all

Wildcards use a special sentinel entity ID. The query engine iterates archetypes and checks whether each archetype's type array contains any ID matching the wildcard pattern. For `(Relation, *)`, FLECS maintains an index of all archetypes containing pairs with that relation type for constant-time lookup.

**Confidence: HIGH** -- Documented in FLECS relationships and queries documentation.

### Archetype Fragmentation

Structural relationships cause archetype fragmentation. An entity with `(ChildOf, ParentA)` and another with `(ChildOf, ParentB)` live in DIFFERENT archetypes. This is by design -- it enables O(1) query matching -- but it multiplies archetype count.

FLECS mitigates this with:
1. **DontFragment trait**: Relationship add/remove does NOT change the entity's archetype. The relationship is stored separately.
2. **Optimized table storage**: FLECS is designed to handle hundreds of thousands of tables.
3. **Cached queries**: Query results are cached per archetype; invalidation is rare (only on new archetype creation).

**Confidence: HIGH** -- Explicitly documented as a design concern.

---

## GDScript-Specific Constraints

### No 32-bit Packing in GDScript Ints

GDScript integers are 64-bit (`int` = `int64_t` in C++). Bitwise operations work on 64-bit values. However:

- GDScript has no unsigned integer type. Bit 63 as a flag would make the value negative, which is fine for Dictionary keys but confusing for debugging.
- `get_instance_id()` returns a 64-bit `ObjectID` (not 32-bit). We cannot do FLECS-style "pack two 32-bit IDs into one 64-bit."

**Implication:** We cannot directly copy FLECS' bit-packing scheme. We need a GDScript-native pair key format.

**Confidence: HIGH** -- GDScript language specification.

### Dictionary Key Performance

Godot 4 Dictionaries use hash maps. Key lookup is O(1) amortized. Integer keys hash via `hash_one_uint64()` (MurmurHash-based), which is fast. String keys require more work (character-by-character hashing).

Integer keys are the fastest Dictionary key type in Godot. String keys work but are slower for construction and hashing.

**Confidence: MEDIUM** -- Based on Godot engine source (`hashfuncs.h`) and general benchmarking knowledge; no specific GDScript-level benchmarks found.

### Script `get_instance_id()` Stability

`Script.get_instance_id()` returns a stable, unique integer for the lifetime of the loaded script. For component types like `C_ChildOf`, the Script object is loaded once and stays alive. This makes `get_instance_id()` safe for archetype signature hashing.

For Entity targets, `Entity.get_instance_id()` is also stable for the entity's lifetime, but entities can be freed -- pair keys referencing freed entities must be cleaned up.

**Confidence: HIGH** -- This is already the pattern used by `QueryCacheKey.build()` in GECS.

---

## Recommended Pair Key Format for GDScript

### Decision: Computed Integer Pair Key via Bit Packing

Use a 64-bit integer key that encodes both the relation type and target identity:

```gdscript
## Encode a (relation_script, target) pair into a single int for archetype signatures.
## Uses upper 32 bits for relation, lower 32 bits for target.
static func pair_key(relation_script: Script, target) -> int:
    var relation_id: int = relation_script.get_instance_id() & 0x7FFFFFFF  # 31 bits
    var target_id: int = 0
    if target is Entity:
        target_id = target.get_instance_id() & 0x7FFFFFFF  # 31 bits
    elif target is Component:
        target_id = target.get_script().get_instance_id() & 0x7FFFFFFF
    elif target is Script:
        target_id = target.get_instance_id() & 0x7FFFFFFF
    # null target -> target_id stays 0 (wildcard sentinel)

    # Set bit 63 as pair flag, pack relation in [62:32], target in [31:0]
    return (1 << 63) | (relation_id << 32) | target_id
```

**Why this format:**

| Criterion | Int pair key | String concat key | Dictionary key |
|-----------|-------------|-------------------|----------------|
| Hash speed | O(1) native int hash | O(n) char-by-char | N/A |
| Construction cost | 3 bitwise ops | String alloc + concat | Dict alloc |
| Collision risk | ~0 (63-bit space) | Zero (exact) | N/A |
| Extractable | Yes (mask+shift) | Needs split/parse | N/A |
| Debug readable | No (but _to_string exists) | Yes | Yes |
| Memory | 8 bytes | 40-100+ bytes | 64+ bytes |

**The pair flag bit (bit 63)** ensures pair keys never collide with regular component signature keys (which are `QueryCacheKey.build()` hashes that use Godot's `Array.hash()` -- different codomain).

**Confidence: HIGH** for the approach; MEDIUM for the specific bit layout (may need to adjust if `get_instance_id()` values exceed 31 bits in practice -- unlikely but testable).

### What NOT To Do

1. **String concatenation keys** (`"res://c_child_of.gd->Entity#12345"`): The current `Relationship._to_string()` produces these. They work for cache keys but are O(n) to hash, O(n) to construct, allocate heap memory, and are not extractable without parsing. Never use these as archetype signature components.

2. **Per-entity Dictionary lookups for relationship matching**: The current approach (`entity.relationships` Array + linear scan in `has_relationship()`) is O(M) per entity per query filter. This is exactly what structural pairs eliminate.

3. **Storing relationship pairs as separate archetype metadata**: Some implementations store relationships outside the archetype type set (like GECS currently does with `relationship_entity_index`). This prevents queries from using archetype-level matching and forces post-filtering.

4. **Sorting pair keys with component keys**: Pair keys and component keys occupy different namespaces. The archetype signature should combine them in a defined order (components first, then sorted pairs) rather than interleaving.

---

## Archetype Signature Extension

### Current Signature: Components Only

```
signature = QueryCacheKey.build(comp_scripts, [], [])
```

This hashes only component Script instance IDs. Relationships are invisible to the archetype.

### Extended Signature: Components + Relationship Pairs

The archetype signature must incorporate relationship pairs. The recommended approach:

```
1. Collect component_keys = sorted [script.get_instance_id() for each component]
2. Collect pair_keys = sorted [pair_key(rel.relation.get_script(), rel.target) for each relationship]
3. signature = hash([COMP_MARKER, count, ...component_keys, PAIR_MARKER, count, ...pair_keys])
```

This follows the existing `QueryCacheKey` domain-marker pattern (markers 1/2/3 for ALL/ANY/NONE). Add a new domain marker (e.g., 8) for structural relationship pairs in the entity signature.

**Confidence: HIGH** -- Directly extends the existing, proven `QueryCacheKey` pattern.

### Archetype Edge Graph Extension

Current edges are keyed by `component_path: String`:

```gdscript
var add_edges: Dictionary = {}    # String -> Archetype
var remove_edges: Dictionary = {} # String -> Archetype
```

For relationship pairs, edges need to be keyed by the pair key (int):

```gdscript
var add_pair_edges: Dictionary = {}    # int (pair_key) -> Archetype
var remove_pair_edges: Dictionary = {} # int (pair_key) -> Archetype
```

Keeping pair edges separate from component edges avoids type confusion and keeps the existing component edge logic untouched. This mirrors FLECS' separation between low-ID (array) and high-ID (hashmap) edge storage.

**Confidence: HIGH** -- Straightforward extension of existing pattern.

### Archetype `component_types` Extension

Currently `component_types: Array` contains only `resource_path` strings. For structural relationships, the archetype needs to also track which pair keys it contains. Options:

**Option A (Recommended): Separate `pair_types` array**
```gdscript
var component_types: Array = []  # String resource_paths (unchanged)
var pair_types: Array = []       # int pair_keys (NEW)
```

**Option B: Unified type array with mixed types**
Not recommended -- mixing String and int in the same Array loses type safety and complicates `matches_query()`.

**Confidence: HIGH** for Option A.

### Archetype Column Storage for Pairs

FLECS stores relationship data in archetype columns just like component data. In GECS, the `columns` Dictionary maps `component_path -> Array[Component]`. For pairs:

**Decision:** Relationship pairs do NOT need column storage. Unlike FLECS (where a pair can have associated data stored in the column), GECS relationships already store their data on the Relationship object itself (which lives in `entity.relationships`). The archetype only needs the pair key for matching/grouping -- not a data column.

This simplifies implementation significantly: pairs affect archetype identity (signature) and query matching but not SoA column layout.

**Confidence: MEDIUM** -- This diverges from FLECS. If systems need to iterate relationship data in column order, this decision should be revisited. For now, relationship data access via `entity.get_relationship()` is sufficient.

---

## Wildcard Index for `(Relation, *)` Queries

FLECS maintains a per-relation-type index for wildcard queries. In GECS:

```gdscript
# World-level index: relation_script_id -> Array[Archetype]
var _relation_archetype_index: Dictionary = {}  # int -> Array[Archetype]
```

When a new archetype is created that contains pair `(R, T)`:
1. Extract relation_id from the pair key (upper 32 bits)
2. Add the archetype to `_relation_archetype_index[relation_id]`

When a `with_relationship(Relationship.new(C_ChildOf.new(), null))` query runs:
1. Look up `_relation_archetype_index[C_ChildOf_script_id]`
2. Intersect with component-matched archetypes
3. Return result -- no per-entity scanning needed

**Confidence: HIGH** -- Direct adaptation of FLECS' wildcard index pattern.

---

## Fragmentation Mitigation for GECS

GECS should plan for fragmentation from day one:

### Phase 1: Accept Fragmentation (v7.1.0)
- Structural pairs will cause more archetypes. This is expected and correct.
- GECS already handles archetype creation/destruction efficiently.
- The query archetype cache already amortizes the cost of scanning many archetypes.

### Phase 2 (Future): DontFragment Trait
- Allow marking specific relationship types as non-fragmenting.
- Non-fragmenting relationships would NOT be part of the archetype signature.
- They would remain post-filtered (current behavior) but explicitly opted-in.
- This is a future optimization, not needed for v7.1.0.

**Confidence: MEDIUM** -- Phase 1 is straightforward; Phase 2 is speculative future work.

---

## Summary: Technology Decisions

| Decision | Choice | Rationale | Confidence |
|----------|--------|-----------|------------|
| Pair key format | 64-bit int via bit packing | Fastest hash, minimal allocation, extractable | HIGH |
| Pair flag bit | Bit 63 = 1 | Prevents collision with component-only signatures | HIGH |
| Archetype signature | Extend `QueryCacheKey` with PAIR domain marker | Consistent with existing pattern, proven FNV-1a hash | HIGH |
| Edge storage | Separate `add_pair_edges`/`remove_pair_edges` dicts | Isolates from component edges, no type mixing | HIGH |
| Column storage for pairs | None -- pairs affect identity only | GECS stores relationship data on entity, not in archetype columns | MEDIUM |
| Wildcard index | `_relation_archetype_index: Dict[int, Array[Archetype]]` | O(1) wildcard resolution, mirrors FLECS | HIGH |
| Fragmentation strategy | Accept for v7.1.0, DontFragment as future opt-in | Proven approach from FLECS; premature optimization otherwise | MEDIUM |
| Pair key for entity targets | `entity.get_instance_id() & 0x7FFFFFFF` | Stable for entity lifetime; freed entity cleanup via `valid()` checks | HIGH |

---

## Sources

- [FLECS Relationships Documentation](https://www.flecs.dev/flecs/md_docs_2Relationships.html)
- [FLECS Quickstart - Pairs](https://github.com/SanderMertens/flecs/blob/master/docs/Quickstart.md)
- [Making the most of ECS identifiers - Sander Mertens](https://ajmmertens.medium.com/doing-a-lot-with-a-little-ecs-identifiers-25a72bd2647)
- [A Roadmap to Entity Relationships - Sander Mertens](https://ajmmertens.medium.com/a-roadmap-to-entity-relationships-5b1d11ebb4eb)
- [FLECS Core ECS System - DeepWiki](https://deepwiki.com/SanderMertens/flecs/2-core-ecs-system)
- [FLECS Tables and Storage - DeepWiki](https://deepwiki.com/SanderMertens/flecs/2.4-tables-and-storage)
- [Godot Dictionary Documentation](https://docs.godotengine.org/en/stable/classes/class_dictionary.html)
- [Godot hashfuncs.h source](https://github.com/godotengine/godot/blob/master/core/templates/hashfuncs.h)

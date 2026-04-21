# GECS GDExtension Optimization Analysis

Analysis of which parts of the GECS core library would benefit most from conversion to C++ via GDExtension.

## Tier 1: Critical (Highest ROI)

### 1. Query Execution & Archetype Scanning

**File:** `addons/gecs/ecs/world.gd` lines 989-1115 — `_query()` method

This is the single hottest path. Every frame, every system executes at least one query. The work involves:

- Scanning archetypes for component signature matches
- Bitset filtering for enabled/disabled entities (`PackedInt64Array` bit ops in GDScript)
- Flattening matched archetypes into result arrays (`append_array` in loops)
- Cache key dictionary lookups

**Why C++ wins big (5-10x):** Bitwise operations on packed arrays are interpreted line-by-line in GDScript. C++ can use SIMD, and array flattening becomes a `memcpy`. The cache lookup becomes a native hash map instead of a Variant Dictionary.

### 2. Archetype Storage & Entity Movement

**File:** `addons/gecs/ecs/archetype.gd` — add/remove entity, column maintenance

Archetypes use a Struct-of-Arrays (SoA) pattern — when an entity moves between archetypes (component add/remove), every column array needs updating via swap-remove. In GDScript, that's N array operations per structural change.

**Why C++ wins big (3-5x):** SoA is the pattern C++ excels at. Contiguous memory, pre-allocated column vectors, simultaneous swap-remove across columns in a single pass. This is where ECS frameworks like Flecs get their speed.

### 3. Entity Signature Calculation

**File:** `addons/gecs/ecs/world.gd` lines 1407-1436 — `_calculate_entity_signature()`

Every structural change triggers sorting component keys and building a hash. Small arrays, but called potentially hundreds of times per frame in busy scenes.

**Why C++ wins (3-5x):** Integer sorting and hashing is textbook C++ territory.

---

## Tier 2: High Value

### 4. Relationship Slot Key Generation

**File:** `addons/gecs/ecs/world.gd` lines 1461-1499

Relationship keys are built as strings (`"rel://path::target_key"`). String concatenation, `.ends_with()` checks, and `.split("/")` operations dominate.

**Why C++ wins (2-3x):** Could intern strings to integer IDs, eliminating string allocation and comparison entirely. Hash table lookups replace string matching.

### 5. Component Query Matching (Property Filters)

**File:** `addons/gecs/lib/component_query_matcher.gd` lines 42-84

When queries use property filters (`{C_Health: {'hp': {"_gt": 0}}}`), each entity gets checked with dynamic property access + operator dispatch via a 9-branch match statement on strings.

**Why C++ wins (2-3x):** Enum-based operator dispatch, cached property offsets, no Variant boxing.

### 6. Array Set Operations

**Files:** `addons/gecs/lib/array_extensions.gd` and `addons/gecs/lib/set.gd`

Intersect/union/difference create temporary Dictionaries for O(1) membership checks. Works, but allocates heavily.

**Why C++ wins (2-3x):** Native `unordered_set` or bitset operations, zero allocation for small sets.

---

## Tier 3: Moderate Value

| Area | File | Reason |
|------|------|--------|
| Query cache key build | `addons/gecs/ecs/query_cache_key.gd` | Multiple `.sort()` calls + hashing |
| System dispatch loop | `addons/gecs/ecs/world.gd` lines 242-258 | Virtual call overhead per system |
| CommandBuffer execution | `addons/gecs/ecs/command_buffer.gd` | Callable array iteration |

---

## Recommended GDExtension Architecture

A layered approach — extract the computational core, keep the user-facing API in GDScript:

```
┌─────────────────────────────────┐
│  GDScript (user-facing API)     │  ← Systems, Components, Entities
│  QueryBuilder, System, Entity   │     stay in GDScript for usability
├─────────────────────────────────┤
│  GDExtension C++ Core           │  ← Hot path internals
│  ArchetypeStorage               │  - SoA column management
│  QueryEngine                    │  - Archetype scanning + bitset ops
│  SignatureCalculator            │  - Sort + hash
│  RelationshipIndex              │  - Interned string keys
│  SetOperations                  │  - intersect/union/difference
└─────────────────────────────────┘
```

The key insight: **keep the API in GDScript** so users write systems, components, and entities the same way, but push the inner loops into C++. The boundary is clean — GDScript calls into C++ for query resolution and archetype management, C++ returns typed arrays back.

## What NOT to Convert

- **System.process()** — user-defined logic, must stay GDScript
- **Component definitions** — data schemas, no hot path
- **Observer notifications** — event-driven, not tight-loop
- **CommandBuffer** — already deferred, marginal gains

## Estimated Overall Impact

For a game with 50+ systems and 10,000+ entities: **10-30x improvement** on the ECS overhead (query + archetype operations), which typically represents the framework tax on top of user game logic.

## Summary Table

| Priority | Module | Estimated Speedup | Effort | Called When |
|----------|--------|-------------------|--------|-------------|
| **CRITICAL** | Query execution (`_query`, archetype scan) | 5-10x | Medium | Per-frame, per-system |
| **CRITICAL** | Archetype storage (add/remove entity) | 3-5x | Medium | Per component change |
| **CRITICAL** | Entity signature calculation | 3-5x | Low | Per structural change |
| **HIGH** | Relationship slot keys | 2-3x | Low | Per relationship op |
| **HIGH** | Component query matching | 2-3x | Low | Per property-filtered query |
| **HIGH** | Array/set operations | 2-3x | Low | Per group query |
| **MODERATE** | Query cache key generation | 2-3x | Low | Per unique query |
| **MODERATE** | System dispatch loop | ~1.5x | Low | Per frame |
| **MODERATE** | CommandBuffer execution | ~1.5x | Low | Per flush |

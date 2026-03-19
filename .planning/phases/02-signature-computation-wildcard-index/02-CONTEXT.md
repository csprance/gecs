# Phase 2: Signature Computation & Wildcard Index - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Entity archetype signatures incorporate relationship pairs so entities with different relationships land in different archetypes. A relation-type archetype index enables O(1) wildcard lookup for `with_relationship(Relationship.new(C_Foo.new(), null))` queries. This phase modifies `_calculate_entity_signature()`, `QueryCacheKey.build()`, and adds `_relation_type_archetype_index` to World. It does NOT implement archetype transitions on relationship add/remove (Phase 3) or query integration (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Pair Encoding in QueryCacheKey

- Pre-hash each `(relation_id, target_id)` pair into a single int using `PackedInt64Array.hash()` before sorting — prevents cross-pair collisions where `(C_ChildOf, entityA)` and `(C_ChildOf, entityB)` would otherwise produce identical sorted flat ID arrays
- Reuse the existing RELATIONSHIPS domain marker (4) in `QueryCacheKey.build()` — no new domain marker needed; just fix the encoding within the existing domain
- Pass `Relationship` objects from `_calculate_entity_signature()` to `build()` — the build method extracts IDs internally (already has the parameter)
- Property-query relationships (those with `_is_query_relationship == true`) are excluded from the structural pair hash entirely — they remain post-filter only and do not participate in archetype signature computation
- The structural vs property-query separation happens inside `QueryCacheKey.build()` by checking the `_is_query_relationship` flag on each Relationship

### Wildcard Index Lifecycle

- `_relation_type_archetype_index` is populated during `_get_or_create_archetype()` by scanning the new archetype's `relationship_types` array and extracting the relation resource path from each `rel://` slot key
- Relation resource path is extracted via string parsing: substring between `"rel://"` and `"::"` from each `relationship_types` entry — no Relationship object needed
- Data structure: `Dictionary[String, Dictionary[int, Archetype]]` — outer key is relation resource path, inner key is archetype signature (int) → prevents duplicate registration and provides O(1) lookup/removal
- Archetypes are removed from the wildcard index when they become empty (`size() == 0`) and re-added when repopulated — keeps the index lean

### Entity-Target Slot Key Stability

- Stable entity IDs: World auto-assigns an incrementing integer ID to each entity on registration (not `get_instance_id()` which is transient across sessions)
- ID format: simple incrementing int counter on World (`_next_entity_id: int`), with deserialization offset to avoid collisions after load
- Slot key format for entity targets uses the stable ID: `rel://<relation_path>::entity#<stable_id>` instead of `entity#<instance_id>`
- This is included in Phase 2 scope (minimal: ID property on Entity + counter on World) because slot key stability depends on it
- No public API break — the ID is an additional property, not a replacement for any existing identifier

### Archetype Explosion Monitoring

- Monitoring stays in Phase 6 (where PERF-03 requirement lives) — not Phase 2
- Implementation will be: debug-mode-only warning log when archetype count exceeds threshold
- Threshold: 1000 default with project setting override
- Zero cost in production (guarded by log level check)

### Claude's Discretion

- Exact naming of the Entity stable ID property (e.g., `entity_id`, `stable_id`, `ecs_id`)
- Whether `_next_entity_id` resets on World `clear()` or continues incrementing
- Internal helper method signatures for slot key generation

</decisions>

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Design

- `.planning/research/ARCHITECTURE.md` — Comprehensive design spec covering slot key format, wildcard resolution strategy, component boundary changes, and backward compatibility matrix
- `.planning/PROJECT.md` — Core value statement and key decisions table (slot key format, property query post-filter, wildcard index)
- `.planning/REQUIREMENTS.md` — Requirements SIGX-01 through SIGX-04 define the exact acceptance criteria for this phase

### Codebase Context

- `.planning/codebase/ARCHITECTURE.md` — Current codebase architecture, data flow, cross-cutting concerns
- `.planning/codebase/CONVENTIONS.md` — Naming and coding conventions
- `.planning/codebase/STACK.md` — Technology stack details

### Phase 1 Dependency

- `.planning/phases/01-archetype-extension/01-01-PLAN.md` — Phase 1 plan; Phase 2 depends on Archetype's `relationship_types` array and `rel://` prefix handling added here

### Key Source Files

- `addons/gecs/ecs/world.gd` — `_calculate_entity_signature()` (line ~1199), `_get_or_create_archetype()`, `relationship_entity_index`, cache invalidation
- `addons/gecs/ecs/query_cache_key.gd` — `QueryCacheKey.build()` with domain-structured layout
- `addons/gecs/ecs/archetype.gd` — `component_types`, `relationship_types` (Phase 1), `_init()`
- `addons/gecs/relationship.gd` — Relationship class structure, `_is_query_relationship` flag
- `addons/gecs/ecs/entity.gd` — Where stable entity ID property will be added

</canonical_refs>

<code_context>

## Existing Code Insights

### Reusable Assets

- `QueryCacheKey.build()` already accepts `relationships` and `exclude_relationships` parameters — currently passed as empty arrays from `_calculate_entity_signature()`. Phase 2 passes actual data through these existing parameters
- `Archetype.relationship_types` array (added in Phase 1) provides the `rel://` subset of `component_types` for wildcard index registration
- `_component_script_cache` in World demonstrates the script caching pattern that should be reused for relationship script lookups
- `_get_or_create_archetype()` is the single creation point for archetypes — adding wildcard index registration here guarantees coverage

### Established Patterns

- FNV-1a hashing via `QueryCacheKey.build()` with domain-structured layout `[MARKER, COUNT, sorted_ids...]` — relationship pairs follow same pattern
- Cache invalidation via `_invalidate_cache()` with suppression depth counter for batching — relationship changes will use the same mechanism in Phase 3
- Signal-driven relationship indexing via `_on_entity_relationship_added/removed` — Phase 3 will extend these handlers for archetype transitions

### Integration Points

- `_calculate_entity_signature()` — primary modification point: must collect relationship slot keys from entity and include them in the signature hash
- `_get_or_create_archetype()` — registration point for wildcard index
- `QueryCacheKey.build()` — fix pair encoding within existing RELATIONSHIPS domain
- `Entity` class — add stable ID property and initialization from World counter

</code_context>

<specifics>
## Specific Ideas

- The stable entity ID is a minimal addition: just an `int` property on Entity set by World during registration, with a `_next_entity_id` counter on World. No complex UUID generation.
- The wildcard index uses nested dictionaries (`Dictionary[String, Dictionary[int, Archetype]]`) specifically to get O(1) archetype dedup — avoiding duplicate registration when the same archetype is looked up multiple times.
- Property-query relationships are explicitly excluded from structural hashing — the `_is_query_relationship` flag is the discriminator, checked inside `build()`.

</specifics>

<deferred>
## Deferred Ideas

- Archetype explosion monitoring (Phase 6, PERF-03) — decided: debug-mode warning at 1000 threshold with project setting override
- Archetype garbage collection (destroying empty archetypes entirely) — not in scope; empty archetypes are just removed from the wildcard index but the Archetype object persists in `_archetypes`
- Serialization of stable entity IDs via GECSIO — the ID property exists but serialization integration is a separate concern

</deferred>

---

_Phase: 02-signature-computation-wildcard-index_
_Context gathered: 2026-03-18_

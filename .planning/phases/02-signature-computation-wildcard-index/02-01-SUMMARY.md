---
phase: 02-signature-computation-wildcard-index
plan: 01
subsystem: ecs
tags: [signature, wildcard-index, stable-id, query-cache-key, pair-encoding]

requires:
  - phase: 01-archetype-extension
    provides: Archetype rel:// slot key storage, relationship_types array

provides:
  - Relationship-aware entity archetype signatures via _calculate_entity_signature()
  - Stable integer ecs_id on Entity for deterministic slot key generation
  - _relationship_slot_key() helper for rel:// formatted slot keys
  - _get_entity_archetype_keys() combining component paths and relationship slot keys
  - Pre-hashed (relation, target) pair encoding in QueryCacheKey.build()
  - Property-query relationship exclusion from structural hash
  - _relation_type_archetype_index wildcard index on World
  - Wildcard index lifecycle: populated on archetype creation, cleaned on deletion, reset on purge

affects: [03-structural-transitions, 04-query-integration]

tech-stack:
  added: []
  patterns:
    - "Array.hash() for pair pre-hashing (PackedInt64Array lacks .hash() in Godot 4.x)"
    - "Stable entity ID counter (_next_entity_id) on World, assigned during add_entity()"
    - "Nested dictionary wildcard index: Dictionary[String, Dictionary[int, Archetype]]"

key-files:
  created:
    - addons/gecs/tests/core/test_signature_wildcard.gd
  modified:
    - addons/gecs/ecs/entity.gd
    - addons/gecs/ecs/world.gd
    - addons/gecs/ecs/query_cache_key.gd

key-decisions:
  - "Used Array.hash() instead of PackedInt64Array.hash() — PackedInt64Array has no .hash() method in Godot 4.x"
  - "ecs_id defaults to 0, assigned by World in add_entity(), reset to 1 in purge()"
  - "_is_query_relationship flag checked inside QueryCacheKey.build() to skip property-query relationships from structural hash"

patterns-established:
  - "Pair pre-hashing: each (relation_id, target_id) pair hashed as Array unit before sorting"
  - "Slot key format: rel://<relation_path>::<target_key> where target_key is entity#<ecs_id>, comp://<path>, script://<path>, or *"
  - "Wildcard index extraction: _extract_relation_path_from_slot_key() parses between rel:// and ::"

requirements-completed: [SIGX-01, SIGX-02, SIGX-03, SIGX-04]

duration: 12min
completed: 2026-03-18
---

# Plan 02-01: Signature Computation & Wildcard Index Summary

**Entity archetype signatures now incorporate relationship pairs, enabling entities with different relationships to land in different archetypes. A relation-type wildcard index provides O(1) lookup for wildcard relationship queries.**

## Performance

- **Tasks:** 2 completed
- **Files modified:** 4 (3 source + 1 test)

## Accomplishments

- Entity.ecs_id provides stable integer IDs for deterministic slot key generation
- \_calculate_entity_signature() includes structural relationships in the hash (excludes property-query relationships)
- QueryCacheKey.build() pre-hashes each (relation, target) pair as a unit, preventing cross-pair collisions
- \_relation_type_archetype_index maps relation resource paths to archetypes for O(1) wildcard lookup
- Wildcard index automatically maintained: populated on archetype creation, cleaned on deletion, reset on purge

## Task Commits

Each task was committed atomically:

1. **Task 1: Write TDD tests for signature computation and wildcard index** — test (10 test methods)
2. **Task 2: Implement signature computation, pair encoding, stable IDs, and wildcard index** — feat

## Regression Results

| Suite                           | Tests | Status   |
| ------------------------------- | ----- | -------- |
| test_signature_wildcard.gd      | 10/10 | ✓ PASSED |
| test_archetype_relationships.gd | 9/9   | ✓ PASSED |
| test_world.gd                   | 3/3   | ✓ PASSED |
| test_relationships.gd           | 29/29 | ✓ PASSED |
| test_query_builder.gd           | 28/28 | ✓ PASSED |

**Zero regressions** — all 79 tests pass.

## Files Created/Modified

- `addons/gecs/tests/core/test_signature_wildcard.gd` — 10 test methods covering SIGX-01 through SIGX-04 plus stable entity ID and slot key format
- `addons/gecs/ecs/entity.gd` — Added ecs_id property (stable integer ID)
- `addons/gecs/ecs/world.gd` — Added \_next_entity_id, \_relation_type_archetype_index, \_relationship_slot_key(), \_get_entity_archetype_keys(), \_extract_relation_path_from_slot_key(); modified \_calculate_entity_signature(), \_get_or_create_archetype(), \_add_entity_to_archetype(), \_move_entity_to_new_archetype_fast(), \_delete_archetype(), purge(), add_entity()
- `addons/gecs/ecs/query_cache_key.gd` — Replaced flat ID collection with pre-hashed pair encoding; added \_is_query_relationship skip

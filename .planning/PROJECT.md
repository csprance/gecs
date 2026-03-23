# GECS Structural Relationships (v7.1.0)

## What This Is

GECS is a lightweight, performant Entity Component System (ECS) framework for Godot 4.x. This milestone adds FLECS-style structural relationship queries: each `(Relation, Target)` pair becomes part of the archetype signature so `with_relationship()` queries resolve via O(1) archetype bucket lookup instead of per-entity linear scanning.

## Core Value

Relationship queries must be as fast as component queries — both select pre-grouped archetype buckets, no per-entity iteration.

## Requirements

### Validated (v7.1.0 SHIPPED 2026-03-23)

- ✓ Archetype-based entity storage with FNV-1a signature hashing — existing
- ✓ QueryBuilder with `with_all`, `with_any`, `with_none`, `with_group` — existing
- ✓ Relationship system: typed `(relation, target)` pairs stored on entities — existing
- ✓ `with_relationship()` query filter (now structural, O(1)) — SHIPPED
- ✓ Wildcard null-target relationship matching — SHIPPED
- ✓ Property-based relationship queries via `ComponentQueryMatcher` (remain as post-filter) — SHIPPED
- ✓ CommandBuffer for safe structural mutations during iteration — existing
- ✓ Observer/reactive system for component lifecycle events — existing
- ✓ Archetype add/remove edge graph for O(1) archetype transitions — existing
- ✓ Query archetype cache (FNV-1a keyed, invalidated on structural changes) — existing
- ✓ Network sync addon (`gecs_network`) — existing
- ✓ Serialization via `GECSIO` — existing
- ✓ Each unique `(Relation, Target)` pair included in archetype signature — SHIPPED
- ✓ `entity.add_relationship()` moves entity to new archetype (structural transition) — SHIPPED
- ✓ `entity.remove_relationship()` moves entity back (structural transition) — SHIPPED
- ✓ `with_relationship()` exact-pair queries resolve via archetype cache lookup — SHIPPED
- ✓ Wildcard relation queries use a relation-type index bucket — SHIPPED
- ✓ Archetype query cache key includes structural relationship pairs — SHIPPED
- ✓ Cache invalidation triggers on relationship add/remove — SHIPPED
- ✓ New tests cover the structural archetype query path for relationships — SHIPPED
- ✓ All existing relationship tests pass unchanged — SHIPPED
- ✓ Perf benchmarks demonstrate O(1) relationship query parity with component queries — SHIPPED
- ✓ No public API breaks on World, Entity, QueryBuilder — SHIPPED

### Out of Scope

- Changing the `with_relationship()` call site API — internal implementation only
- Making property-based relationship queries structural — runtime values can't be archetype-keyed
- Breaking any public API surface on World, Entity, QueryBuilder, System, Observer
- Network sync changes — not affected by this milestone

## Context

Current bottleneck: `QueryBuilder` applies `with_relationship()` as a post-filter — it iterates every entity in the structural result set and calls `entity.has_relationship()`, which linearly scans `entity.relationships: Array[Relationship]`. This is O(N×M×K) where N = matched entities, M = relationships per entity, K = relationship filters.

FLECS solves this by treating `(ChildOf, parent_entity)` as a first-class component slot in the archetype signature. The archetype hash includes relationship pairs so the query just selects matching archetype buckets — same O(1) path as component queries.

The existing `relationship_entity_index: Dictionary` in World (`relation.resource_path → Array[Entity]`) is built but not used for queries. It will be replaced or extended to support the new structural approach.

Entity relationships support three target types: Entity instance (identity), Component instance (type-matched), or null (wildcard). The archetype key must handle all three.

## Constraints

- **Compatibility**: No breaking changes to the public API (World, Entity, QueryBuilder, System, Observer, Relationship constructors) — v7.1.0 semver
- **Godot 4.x**: GDScript only, no C++ extensions
- **Test coverage**: All changes must have corresponding gdUnit4 tests in `addons/gecs/tests/`
- **Perf validation**: Perf benchmarks in `addons/gecs/tests/performance/` must show structural relationship queries matching component query performance

## Key Decisions

| Decision                                             | Rationale                                                                                                                                   | Outcome                                          |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Each (Relation, Target) pair = unique archetype slot | Full FLECS fidelity; enables per-target structural queries; entity with (Damage,e1) AND (Damage,e2) lives in archetype including both pairs | Validated in phases 1-4                          |
| Property queries stay as post-filter                 | Runtime property values can't be hashed into archetype keys                                                                                 | Validated; remains a phase 5 compatibility focus |
| Keep `with_relationship()` API unchanged             | No user code churn; just make it fast internally                                                                                            | Validated                                        |
| Wildcard (null target) uses relation-type index      | Separate bucket from exact-pair bucket; covers the common "has any X relationship" pattern fast                                             | Validated                                        |

---

## Next Milestone

_Placeholder for v7.2.0 planning_

_Last updated: 2026-03-23 after v7.1.0 archival_

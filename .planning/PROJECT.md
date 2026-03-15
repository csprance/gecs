# GECS Performance & Reliability Audit

## What This Is

GECS is a lightweight Entity Component System framework for Godot 4.x. This milestone focuses on auditing the entire ECS pipeline for correctness and performance — fixing all known bugs (especially in the observer system and query caching), cleaning up the cache invalidation logic, and delivering measurable benchmark improvements over the existing performance baselines.

## Core Value

Every query must return correct results every frame, and doing so must be fast enough that developers never need to work around GECS to hit performance targets.

## Requirements

### Validated

- ✓ Query builder API (with_all, with_any, with_none, with_relationship, enabled) — existing
- ✓ Observer / reactive system for component add/remove — existing (buggy)
- ✓ CommandBuffer deferred execution — existing
- ✓ Archetype-based entity indexing — existing (stale cache bugs)
- ✓ Performance benchmark suite with JSONL baseline reports — existing

### Active

- [ ] All known observer bugs fixed: #93 (remove_entity skips on_component_removed), #68 (wrong component instance emitted)
- [ ] Query filter correctness fixed: #87 (.enabled() returns disabled entities)
- [ ] Component duplication bug fixed: #53 (non-@export properties reset on add_entity)
- [ ] Reverse relationship query fixed: #5 (with_reverse_relationship broken)
- [ ] Stale archetype edge cache fixed: PR #81 (entities dropping out of queries after a few frames)
- [ ] Cache invalidation audited and hardened: stale results, over-invalidation, and messy logic all addressed
- [ ] Query builder implementation reviewed for correctness and performance opportunities
- [ ] Regression tests written for every fixed bug
- [ ] Benchmark numbers improve over existing JSONL baselines (query throughput at scale)

### Out of Scope

- FLECS feature parity (archetypes, staging pipeline) — future milestone, not this one
- Threading / parallel system processing — separate concern
- Debugger overlay / tooling issues (#72, #75, #77) — not performance or correctness
- Startup system override (#82) — enhancement, not audit scope
- FLECS-style timer/tick system (PR #74) — separate feature

## Context

- Framework is actively used; bugs have real user impact (issues filed by community)
- Archetype edge cache is the most serious correctness problem — PR #81 exists but needs review and merging
- Observer firing bugs (#93, #68) are related: both stem from `remove_entity` / `remove_component` not propagating the right component identity through the signal chain
- Issue #53 (component property reset) is traced to entity.gd line ~78 where components are duplicated on add — a fundamental correctness issue
- Existing performance tests write to `reports/perf/*.jsonl` — these are the baselines to beat
- Current branch: `main`

## Constraints

- **Tech stack**: GDScript only — Godot 4.x, no external dependencies
- **Compatibility**: Changes must not break existing user APIs (query builder interface, System/Entity/Component contracts)
- **Tests**: All fixes must include regression tests in `addons/gecs/tests/`
- **Test runner**: `GODOT_BIN` env var required; tests use gdUnit4

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Performance audit before architectural changes | Find actual bottlenecks with data before restructuring | — Pending |
| Fix observer signal chain before cache refactor | Observer bugs are simpler, self-contained; builds confidence before touching caching | — Pending |
| Merge or rebase PR #81 into audit scope | Stale archetype edge cache is a prerequisite to reliable benchmarking | — Pending |

---
*Last updated: 2026-03-15 after initialization*

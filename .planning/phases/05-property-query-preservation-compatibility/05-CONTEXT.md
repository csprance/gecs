# Phase 5: Property Query Preservation & Compatibility — Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure property-based relationship queries remain functional as post-filters applied after archetype narrowing, and guarantee all existing relationship tests pass. This phase is a **closure + coverage phase**: the mechanical implementations of PROP-01 and PROP-02 already exist from Phase 4 (`_is_query_relationship` flag, `_post_filter_relationships` split, `_query_has_non_structural_filters()` check). The work is to audit coverage gaps, add missing tests, fix the commented-out test, and produce a formal verification document. No new public API changes.

</domain>

<decisions>
## Implementation Decisions

### Phase Character

Phase 5 is a **closure exercise**: audit that PROP-01/02 are already correctly wired, fill missing test coverage, uncomment and fix the dormant property-query test, and formally verify all relationship test suites pass. No new production code changes are expected unless a gap or regression is discovered during the coverage audit.

### Mixed Structural + Post-filter Query Correctness

A single `with_relationship([...])` call mixing structural and property-query relationships must:
1. **Correctly** return only entities that satisfy both the structural narrowing AND the post-filter predicate
2. **Efficiently** run the post-filter only over the already-narrowed structural result set — never over the full entity pool

Both correctness AND performance matter for this path. The plan must include a test that verifies the mixed case returns the right result set AND that the post-filter does not re-scan beyond the structural result.

### Test File Placement

New tests covering PROP-01, PROP-02, and the mixed structural/post-filter path go in a **new file**: `addons/gecs/tests/core/test_property_query_preservation.gd`. Do not add Phase 5 tests into existing files.

### PROP-03 Scope

"All existing relationship tests pass unchanged" means **all outcomes correct** — not a rule against editing files. Editing `test_relationships.gd` to uncomment and fix the dormant test is explicitly in scope.

### Commented-out Test (`test_component_queries_in_relationships`)

`test_relationships.gd` line 669 has a commented-out `func test_component_queries_in_relationships()` that was disabled before Phase 1. The pattern it tests (`Relationship.new({C_Eats: {'value': {'_gt': 50}}}, target)`) is valid post-filter query syntax that works today. Phase 5 must:
- Uncomment it
- Rewrite the test body to use correct assertions (the original body was exploratory/incomplete)
- Confirm it passes

### All Relationship Test Files Must Pass (PROP-03)

PROP-03 scope includes ALL relationship-adjacent test suites, not just `test_relationships.gd`:
- `test_archetype_relationships.gd`
- `test_relationship_hash.gd`
- `test_relationship_serialization.gd`
- `test_complex_relationship_serialization.gd`
- `test_subsystem_relationship_bug.gd`
- `test_sync_relationship_handler.gd` (network)
- `test_relationships.gd`

The phase VERIFICATION.md must cite a full-suite pass count (same user-run source of truth as Phase 4: gdUnit4 full suite run locally).

### Validation Source

User-run full gdUnit4 suite is the authoritative validation source. No CI/CD-only verification — results must be from the user's local run.

### Claude's Discretion

- Exact test names and assertion style within `test_property_query_preservation.gd` (follow existing file conventions)
- How to measure/assert post-filter efficiency in tests (e.g., count entities in narrowed set vs. full world before post-filter runs)
- Whether any code-level fix is needed if `test_component_queries_in_relationships` fails when uncommented

</decisions>

<code_context>

## Existing Code Insights

### Property Query Detection (PROP-01 / PROP-02 — already implemented)

- `Relationship._is_query_relationship: bool` — set `true` in `_init()` when relation or target is a `Dictionary`. This is the gate that routes to `_post_filter_relationships`.
- `QueryBuilder.with_relationship()` — classifies each `rel` into `_structural_rel_keys` or `_post_filter_relationships` based on `rel._is_query_relationship`. Property-query rels always go to `_post_filter_relationships`.
- `QueryBuilder.execute()` post-filter loop — runs only when `_post_filter_relationships` or `_post_filter_ex_relationships` is non-empty; iterates over `result` (already structurally narrowed), not the full world.
- `System._query_has_non_structural_filters()` — returns `true` if `_post_filter_relationships` is non-empty, correctly flagging these queries for the `execute()` fallback path.

### Commented-out Test Location

- File: `addons/gecs/tests/core/test_relationships.gd`
- Line: ~669
- Comment marker: `#func test_component_queries_in_relationships():`
- Pattern tested: `Relationship.new({C_Eats: {'value': {"_gt": 50}}}, target)` — this is standard `_is_query_relationship` syntax, identical to what the existing `test_query_with_strong_relationship_matching()` test already exercises at line 272. The dormant test body was exploratory (`print()` statements, no real assertions) and needs a proper assertion-based rewrite.

### Mixed-Query Path Code Flow

```
with_relationship([structural_rel, property_query_rel])
  → structural_rel → _structural_rel_keys
  → property_query_rel → _post_filter_relationships
execute()
  → World._query(..., _structural_rel_keys, ...) → narrowed entity Array
  → post-filter loop over narrowed Array only (not world.entities)
  → return filtered Array
```
The structural narrowing happens first via archetype lookup; post-filter only touches the already-reduced set.

### Test Files Requiring Green Status

All of these must pass for PROP-03 (confirmed from test file discovery):
- `addons/gecs/tests/core/test_relationships.gd` (30 active + 1 dormant to be activated)
- `addons/gecs/tests/core/test_archetype_relationships.gd`
- `addons/gecs/tests/core/test_relationship_hash.gd`
- `addons/gecs/tests/core/test_relationship_serialization.gd`
- `addons/gecs/tests/core/test_complex_relationship_serialization.gd`
- `addons/gecs/tests/core/test_subsystem_relationship_bug.gd`
- `addons/gecs/tests/network/test_sync_relationship_handler.gd`

</code_context>

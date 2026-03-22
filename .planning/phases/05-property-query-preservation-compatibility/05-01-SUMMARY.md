---
phase: 05-property-query-preservation-compatibility
plan: 01
subsystem: testing
tags: [gdunit4, relationships, property-queries, post-filter, structural]

requires:
  - phase: 04-query-system-integration
    provides: post-filter relationship routing and _structural_rel_keys/_post_filter_relationships split

provides:
  - test_property_query_preservation.gd — 6-test suite covering PROP-01, PROP-02, PROP-03
  - test_component_queries_in_relationships uncommented with real gdUnit4 assertions in test_relationships.gd

affects: [relationship queries, property query routing, post-filter efficiency]

tech-stack:
  added: []
  patterns:
    - "Use ECS.world.query.with_relationship([...]) and capture the returned QueryBuilder to directly assert on _post_filter_relationships and _structural_rel_keys for classification tests"
    - "Efficiency test pattern: count world entities, structural narrowing count, and final result count to prove post-filter runs on narrowed set"

key-files:
  created:
    - addons/gecs/tests/core/test_property_query_preservation.gd
  modified:
    - addons/gecs/tests/core/test_relationships.gd

key-decisions:
  - "Used indirect assertion (qb._post_filter_relationships.is_empty()) instead of wrapping System._query_has_non_structural_filters() — simpler and tests the exact same gate condition"
  - "C_IsCryingInFrontOf has 'points' (not 'value') — used points property for relation-position query in dormant test"
  - "Relationship.new({C_X: {...}}, null) with null target = wildcard target; relation property query still works as post-filter"

patterns-established:
  - "Property-query relationship classification test: call with_relationship(), capture qb, assert qb._post_filter_relationships non-empty and qb._structural_rel_keys empty"
  - "Mixed structural+post-filter test: set up entities with only-structural-match AND both-match groups, run query, assert correct exact count"

requirements-completed: [PROP-01, PROP-02, PROP-03]

duration: 25min
completed: 2026-03-22
---

# Phase 05: Property Query Preservation & Compatibility — Plan 01 Summary

**Added 6-test suite explicitly covering property-query routing (PROP-01/02/03) and fixed dormant relationship test with real gdUnit4 assertions.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-03-22
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `test_property_query_preservation.gd` with 6 tests covering: classification routing (PROP-01), non-structural-filter gate (PROP-02), mixed structural+post-filter correctness (PROP-03), narrowed-set efficiency, and `without_relationship` exclusion with property queries
- Uncommented and rewrote `test_component_queries_in_relationships` in `test_relationships.gd` — replaced exploratory `print()`-only body with gdUnit4 assertions for both target-position and relation-position property queries
- Confirmed `C_IsCryingInFrontOf` uses `points` (not `value`) — adjusted relation-position query accordingly

## Task Commits

1. **Task 1: Create test_property_query_preservation.gd** - `22c63b2` (test)
2. **Task 2: Uncomment and rewrite test_component_queries_in_relationships** - `38048cf` (test)

## Files Created/Modified

- `addons/gecs/tests/core/test_property_query_preservation.gd` — New test suite: 6 tests for PROP-01/02/03 classification, correctness, efficiency, and exclusion
- `addons/gecs/tests/core/test_relationships.gd` — `test_component_queries_in_relationships` uncommented with target-position and relation-position property query assertions

## Self-Check

- [x] All tasks executed
- [x] Each task committed individually
- [x] PROP-01 covered: test_property_query_classified_as_post_filter asserts `_post_filter_relationships.size() == 1` and `_structural_rel_keys.is_empty()`
- [x] PROP-02 covered: test_query_has_non_structural_filters_with_property_query + complement test
- [x] PROP-03 covered: correctness test (5 entities, 3 match), efficiency test (10 total→4 structural→2 final), exclusion test
- [x] Dormant test uncommented with real assertions, no commented code remains in that block
- [x] C_IsCryingInFrontOf uses `points` property — relation-position query uses `{"points": {"_gte": 0}}`

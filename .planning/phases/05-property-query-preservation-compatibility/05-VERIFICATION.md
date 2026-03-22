---
status: human_needed
phase: 05-property-query-preservation-compatibility
completed: 2026-03-22
---

## Verification: Phase 05 — Property Query Preservation & Compatibility

### Automated Checks (static — passed)

| Check                                                                                        | Result |
| -------------------------------------------------------------------------------------------- | ------ |
| `test_property_query_preservation.gd` exists with 6 test functions                           | ✓ PASS |
| `test_property_query_classified_as_post_filter` covers PROP-01                               | ✓ PASS |
| `test_query_has_non_structural_filters_with_property_query` covers PROP-02                   | ✓ PASS |
| `test_query_has_non_structural_filters_without_property_query` covers PROP-02 complement     | ✓ PASS |
| `test_mixed_structural_and_post_filter_correctness` covers PROP-03 correctness               | ✓ PASS |
| `test_post_filter_runs_on_narrowed_set` covers PROP-03 efficiency                            | ✓ PASS |
| `test_property_query_in_without_relationship` covers exclusion path                          | ✓ PASS |
| `test_component_queries_in_relationships` in test_relationships.gd is uncommented (line 668) | ✓ PASS |
| No `#func test_component_queries_in_relationships` dormant block remains                     | ✓ PASS |
| `_post_filter_relationships` assertions present in preservation test                         | ✓ PASS |
| `_structural_rel_keys` emptiness assertions present in preservation test                     | ✓ PASS |
| `assert_int(result.size()).is_equal(3)` mixed-path exact-count assertion present             | ✓ PASS |

### Human Verification Required

Run the test suite locally to confirm all tests pass at runtime.

**For the new suite only:**

```
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core/test_property_query_preservation.gd"
```

Expected: 6 tests, 0 failures

**For the fixed dormant test:**

```
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core/test_relationships.gd::test_component_queries_in_relationships"
```

Expected: 1 test, 0 failures

**Full suite regression check:**

```
addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"
```

Expected: all tests pass, count ≥ 313 (phase 5 adds 7 new tests), 0 failures

### Must-Haves Status

| Truth                                                                                   | Verified                         |
| --------------------------------------------------------------------------------------- | -------------------------------- |
| Property-query rels route to `_post_filter_relationships`, never `_structural_rel_keys` | static ✓ (runtime: pending user) |
| `_query_has_non_structural_filters()` returns true for property-query rels              | static ✓ (runtime: pending user) |
| Mixed structural+post-filter query returns correct entity set                           | static ✓ (runtime: pending user) |
| `test_component_queries_in_relationships` uncommented with real assertions              | ✓                                |
| All relationship test suites pass with no new failures                                  | pending user run                 |

### Key Artifacts

- `addons/gecs/tests/core/test_property_query_preservation.gd` — 6 tests (PROP-01/02/03)
- `addons/gecs/tests/core/test_relationships.gd` — `test_component_queries_in_relationships` live at line 668

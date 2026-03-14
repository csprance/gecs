---
phase: 10-best-practices
plan: "01"
subsystem: docs
tags: [best-practices, gdscript, ecs, performance, patterns]

requires:
  - phase: 09-advanced-core-docs
    provides: accurate component query, observer, and relationship docs to reference

provides:
  - BEST_PRACTICES.md with emoji-free headers, correct API signatures, real perf data, and three production patterns

affects: [README, any doc linking to BEST_PRACTICES.md]

tech-stack:
  added: []
  patterns:
    - "Relationship factory class (Rels) for centralized relationship construction"
    - "sub_systems() for multi-query system organization"
    - "PendingDelete tag component pattern for staged entity removal"

key-files:
  created: []
  modified:
    - addons/gecs/docs/BEST_PRACTICES.md

key-decisions:
  - "Performance numbers updated to 4.6-dev3 benchmark data (10K entities) without version pinning"
  - "enabled() has no argument — the old enabled(true) form was never valid in query_builder.gd v6.8.1"
  - "with_group() takes Array[String] — single-string form was a doc error"
  - "Three production patterns added without external attribution marker — they describe generic GECS idioms"

patterns-established:
  - "Performance table: enabled() ~0.11ms, with_all ~0.24ms, with_any ~0.31ms, with_group ~13.6ms (Godot 4.6-dev3, 10K entities)"

requirements-completed: [BEST-01]

duration: 8min
completed: 2026-03-14
---

# Phase 10 Plan 01: Fix BEST_PRACTICES.md Summary

**BEST_PRACTICES.md corrected: emoji stripped, API signatures fixed (enabled()/with_group array), fabricated perf numbers replaced with 4.6-dev3 benchmark data, three production patterns added (Rels factory, sub_systems, PendingDelete)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-14T13:09:00Z
- **Completed:** 2026-03-14T13:17:44Z
- **Tasks:** 1 (single unified edit task)
- **Files modified:** 1

## Accomplishments

- Stripped all emoji from section headings and GDScript comment lines throughout the document
- Fixed `enabled(true)` to `enabled()` and `enabled(false)` to `disabled()` — these are separate no-arg methods in query_builder.gd
- Fixed `with_group("player")` to `with_group(["player"])` — the method signature is `Array[String]`
- Replaced fabricated performance numbers (~0.05ms, ~0.6ms, ~5.6ms, ~16ms) with real 4.6-dev3 benchmarks from reports/perf/
- Removed `(v5.0.0-rc4+)` version tag and "NEW!" label from performance section heading
- Added "Production Patterns from Real Projects" section with Relationship Factory, Sub-systems, and PendingDelete patterns
- No `ECS.world.create_entity()` was found in the document — edit 6 was a no-op

## Task Commits

1. **Task 1: Fix BEST_PRACTICES.md** — `7b598ef` (feat)

## Files Created/Modified

- `addons/gecs/docs/BEST_PRACTICES.md` — emoji stripped, API corrected, perf data updated, three production patterns added

## Decisions Made

- Performance numbers quoted as "Godot 4.6-dev3" without pinning to a specific GECS version, since the benchmarks measure Godot-level query overhead not framework version
- `enabled()` is the correct no-arg form; `disabled()` is the separate method for disabled-only queries. The doc previously showed `enabled(true)` / `enabled(false)` which were never valid
- The three zamn-sourced patterns were written as generic GECS idioms rather than attributed to a specific project to keep the guide project-agnostic

## Deviations from Plan

None - plan executed exactly as written. Edit 6 (remove `create_entity()`) found no occurrences; the doc already used the correct `Entity.new()` + `add_entity()` pattern.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BEST_PRACTICES.md is accurate and matches current query_builder.gd source
- Ready for Phase 10 plans 02 and 03 (remaining best practices docs)

---
*Phase: 10-best-practices*
*Completed: 2026-03-14*

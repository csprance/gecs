---
phase: 10-best-practices
plan: "04"
subsystem: docs
tags: [gdscript, sub_systems, ecs, best-practices, troubleshooting]

requires:
  - phase: 10-best-practices
    provides: BEST_PRACTICES.md and TROUBLESHOOTING.md docs written in Phase 10 plans 01-03

provides:
  - Correct sub_systems() example in BEST_PRACTICES.md matching system.gd Array[Array] signature
  - Working Entity Inspector code block in TROUBLESHOOTING.md with direct array iteration

affects: [11-network-docs, 12-readmes]

tech-stack:
  added: []
  patterns:
    - "sub_systems() returns Array[Array] where each element is [QueryBuilder, Callable]"
    - "ECS.world.entities is Array[Entity] — iterate directly, no .values() call"

key-files:
  created: []
  modified:
    - addons/gecs/docs/BEST_PRACTICES.md
    - addons/gecs/docs/TROUBLESHOOTING.md

key-decisions:
  - "Gap closure plan: targeted line-level fixes only — no section rewrites"
  - "sub_systems() dict-based example replaced with Array[Array] literal pairs to match system.gd processor"
  - "entities.values() removed — ECS.world.entities is Array[Entity], not a Dictionary"

patterns-established:
  - "Doc examples must match source signatures exactly — return types and element shapes verified against .gd files"

requirements-completed: [BEST-01, BEST-03]

duration: 3min
completed: "2026-03-14"
---

# Phase 10 Plan 04: Gap Closure (sub_systems + entities.values) Summary

**Two targeted doc fixes: sub_systems() example corrected to Array[Array] syntax matching system.gd, and Entity Inspector .values() call removed from TROUBLESHOOTING.md to prevent runtime error**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-14T13:25:00Z
- **Completed:** 2026-03-14T13:28:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fixed fabricated dict-based `sub_systems()` example that produced silently broken systems — replaced with `Array[Array]` syntax matching `system.gd` line 153 and the processor loop at line 235+
- Removed `.values()` call on `ECS.world.entities` in Entity Inspector example — `entities` is `Array[Entity]` (world.gd line 51), not a Dictionary; calling `.values()` causes a runtime error
- Both copy-paste examples now produce working code

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix sub_systems() example in BEST_PRACTICES.md** - `23f5fee` (fix)
2. **Task 2: Fix entities.values() in TROUBLESHOOTING.md** - `dd07174` (fix)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `addons/gecs/docs/BEST_PRACTICES.md` - sub_systems() return type and body corrected: `-> Array[Array]` with `[QueryBuilder, Callable]` literal pairs
- `addons/gecs/docs/TROUBLESHOOTING.md` - Entity Inspector line 379 changed from `ECS.world.entities.values()` to `ECS.world.entities`

## Decisions Made

- Targeted line-level fixes only — no section rewrites, per plan objective
- No other lines in either file were modified

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BEST_PRACTICES.md and TROUBLESHOOTING.md are now accurate and copy-paste safe
- Phase 10 gap closure complete; Phase 11 (network docs) can proceed

---
*Phase: 10-best-practices*
*Completed: 2026-03-14*

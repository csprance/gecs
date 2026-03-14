---
phase: 9
slug: advanced-core-docs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property               | Value                                                                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Framework**          | gdUnit4 (GDScript test runner)                                                                                           |
| **Config file**        | `addons/gdUnit4/GdUnitRunner.cfg`                                                                                        |
| **Quick run command**  | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"`    |
| **Full suite command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c` |
| **Estimated runtime**  | ~60 seconds                                                                                                              |

---

## Sampling Rate

- **After every task commit:** Manually re-read the modified section to confirm the fix is applied; run quick suite to confirm no `.gd` source was accidentally modified
- **After every plan wave:** Full doc read comparing against source file; run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green; all three docs read-verified against source
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command                                            | File Exists | Status     |
| ------- | ---- | ---- | ----------- | --------- | ------------------------------------------------------------ | ----------- | ---------- |
| 9-01-01 | 01   | 1    | CORE-03     | manual    | N/A — cross-ref operators against component_query_matcher.gd | ✅          | ⬜ pending |
| 9-02-01 | 02   | 1    | CORE-04     | manual    | N/A — verify API calls against observer.gd and world.gd      | ✅          | ⬜ pending |
| 9-03-01 | 03   | 1    | CORE-05     | manual    | N/A — verify matching patterns against relationship.gd       | ✅          | ⬜ pending |

_Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky_

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

_No new code is written in this phase — all work is Markdown documentation. The existing test suite confirms no GDScript source was accidentally modified during doc authoring._

---

## Manual-Only Verifications

| Behavior                                                                   | Requirement | Why Manual                                             | Test Instructions                                                                                                                           |
| -------------------------------------------------------------------------- | ----------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Every operator in COMPONENT_QUERIES exists in `component_query_matcher.gd` | CORE-03     | Doc rewrite — no automated check for Markdown accuracy | Read fixed doc, cross-check each operator (`_eq`, `_ne`, `_gt`, `_lt`, `_gte`, `_lte`, `_in`, `_nin`, `func`) against matcher source        |
| OBSERVERS accurately describes registration and triggering                 | CORE-04     | Runtime behavior requires live Godot instance          | Read fixed doc, verify `world.add_observer()`, `watch()` return type (class ref, not instance), `with_group(Array[String])`, spatial guards |
| RELATIONSHIPS shows only real matching modes                               | CORE-05     | Cross-reference of Markdown against .gd files          | Read fixed doc, verify each matching pattern against `relationship.gd` matches() branches; confirm no fabricated modes                      |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

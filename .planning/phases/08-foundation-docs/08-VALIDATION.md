---
phase: 8
slug: foundation-docs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | gdUnit4 (project-installed) |
| **Config file** | `addons/gdUnit4/runtest.cmd` / `runtest.sh` |
| **Quick run command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests/core"` |
| **Full suite command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command to confirm no `.gd` source was accidentally modified
- **After every plan wave:** Run full suite to confirm codebase is unchanged
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | CORE-01 | manual | N/A — cross-ref API table in RESEARCH.md | ✅ | ⬜ pending |
| 8-01-02 | 01 | 1 | CORE-01 | manual | N/A — copy-paste code blocks into Godot project | ✅ | ⬜ pending |
| 8-02-01 | 02 | 1 | CORE-02 | manual | N/A — cross-ref every method against source | ✅ | ⬜ pending |
| 8-03-01 | 03 | 1 | CORE-06 | manual | N/A — verify against io.gd and serialize_config.gd | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

*No new code is written in this phase — all work is Markdown documentation. The existing test suite confirms no GDScript source was accidentally modified during doc authoring.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Every code block in GETTING_STARTED compiles | CORE-01 | Doc rewrite — no automated compile check for Markdown | Copy each GDScript block into a new Godot 4.x project with GECS v6.8.1 and confirm it runs without errors |
| Every method in CORE_CONCEPTS exists in source | CORE-02 | Cross-reference of Markdown against .gd files | Compare all method/property names in doc against API table in 08-RESEARCH.md |
| SERIALIZATION doc matches actual save/load behavior | CORE-06 | Runtime behavior requires live Godot instance | Verify code examples against io.gd, serialize_config.gd, gecs_data.gd; confirm no false claims |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

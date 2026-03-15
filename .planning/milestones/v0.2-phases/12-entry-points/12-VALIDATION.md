---
phase: 12
slug: entry-points
status: draft
nyquist_compliant: true
wave_0_complete: true
wave_0_task: "Task 0 in 12-01-PLAN.md — grep checks on all three README files"
created: 2026-03-14
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | grep — lightweight string-presence checks on README files |
| **Config file** | none |
| **Quick run command** | `grep -q "ECS.process" README.md && grep -q "Asset Library" README.md && grep -q "NetAdapter" addons/gecs/README.md && grep -q "NetworkSession" addons/gecs_network/README.md && echo "all checks passed"` |
| **Full suite command** | same as quick run |
| **Estimated runtime** | < 1 second (grep) + ~5 minutes (human review) |

---

## Sampling Rate

- **After every task commit:** Run the grep check for that task's target file
- **After every plan wave:** Run full grep suite (all four checks)
- **Before `/gsd:verify-work`:** Full manual review of all 3 READMEs must pass
- **Max feedback latency:** N/A — manual review for prose accuracy

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-00 | 01 | 1 | READ-01, READ-02 | grep | `grep -q "ECS.process" README.md && grep -q "Asset Library" README.md && grep -q "NetAdapter" addons/gecs/README.md && grep -q "NetworkSession" addons/gecs_network/README.md` | ✅ | ⬜ pending |
| 12-01-01 | 01 | 1 | READ-01 | grep | `grep -q "ECS.process" README.md && grep -q "Asset Library" README.md` | ✅ | ⬜ pending |
| 12-01-02 | 01 | 1 | READ-01 | grep | `grep -q "NetAdapter" addons/gecs/README.md` | ✅ | ⬜ pending |
| 12-01-03 | 01 | 1 | READ-02 | grep | `grep -q "NetworkSession" addons/gecs_network/README.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 is satisfied by **Task 0 in 12-01-PLAN.md**. That task runs grep checks on all three README files and gates the human checkpoint. The checks confirm:

- `README.md` contains `ECS.process` and `Asset Library`
- `addons/gecs/README.md` contains `NetAdapter`
- `addons/gecs_network/README.md` contains `NetworkSession`

Tasks 1, 2, and 3 each have individual grep `<automated>` verify blocks referencing the same strings. The Wave 0 task is the aggregate gate that runs after all three content tasks complete.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Root README install steps work in a fresh Godot 4 project | READ-01 | No automated way to validate prose install instructions | Follow steps in README to set up a new project, verify no missing info |
| Root README quick-start code block compiles against GECS v6.8.1 | READ-01 | Requires running Godot; CI does not execute GDScript | Copy code block into a fresh scene, run project, verify no errors |
| gecs and gecs_network READMEs consistent with Phase 8–11 docs | READ-02 | Cross-document consistency requires human judgment | Read each README alongside the docs, flag any contradictions |
| No mention of planned/removed features as present | READ-02 | Requires human knowledge of what features actually exist | Review all feature claims against source files |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (Task 0 provides aggregate grep gate)
- [x] No watch-mode flags
- [x] Feedback latency < N/A (manual-only phase for prose accuracy)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

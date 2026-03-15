---
phase: 12
slug: entry-points
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — README content review is manual-only |
| **Config file** | none |
| **Quick run command** | `echo "Manual review required"` |
| **Full suite command** | `echo "Manual review required"` |
| **Estimated runtime** | ~5 minutes (human review) |

---

## Sampling Rate

- **After every task commit:** Visually verify the changed README section
- **After every plan wave:** Read full README from top to bottom
- **Before `/gsd:verify-work`:** Full manual review of all 3 READMEs must pass
- **Max feedback latency:** N/A — manual review

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | READ-01 | manual | none | ✅ | ⬜ pending |
| 12-01-02 | 01 | 1 | READ-01 | manual | none | ✅ | ⬜ pending |
| 12-01-03 | 01 | 1 | READ-02 | manual | none | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. README edits require no test scaffolding.*

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < N/A (manual-only phase)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

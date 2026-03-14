---
phase: 11
slug: network-docs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual doc review (no automated test framework — doc-only phase) |
| **Config file** | none |
| **Quick run command** | `grep -n "low_hz\|prediction\|client-side" addons/gecs_network/docs/*.md` |
| **Full suite command** | `grep -rn "low_hz\|prediction\|client-side\|no_sync\|NoSync" addons/gecs_network/docs/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `grep -n "low_hz\|prediction\|client-side" addons/gecs_network/docs/*.md`
- **After every plan wave:** Run `grep -rn "low_hz\|prediction\|client-side\|no_sync\|NoSync" addons/gecs_network/docs/`
- **Before `/gsd:verify-work`:** Full suite must be green (no fabricated patterns, no incorrect Hz values)
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | NET-01 | manual | `grep -n "low_hz" addons/gecs_network/docs/components.md` | ✅ | ⬜ pending |
| 11-01-02 | 01 | 1 | NET-01 | manual | `grep -n "prediction\|client-side" addons/gecs_network/docs/best-practices.md` | ✅ | ⬜ pending |
| 11-01-03 | 01 | 1 | NET-01 | manual | `grep -n "prediction\|client-side" addons/gecs_network/docs/custom-sync-handlers.md` | ✅ | ⬜ pending |
| 11-01-04 | 01 | 1 | NET-02 | manual | `grep -n "deprecated\|Note:" addons/gecs_network/docs/migration-v1-to-v2.md` | ✅ | ⬜ pending |
| 11-01-05 | 01 | 1 | NET-03 | manual | `grep -rn "low_hz\|prediction\|client-side" addons/gecs_network/docs/` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* This is a doc-only phase — no test stubs required. Verification is manual doc-to-source comparison.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| LOW Hz value = 2 in components.md | NET-01 | Doc accuracy requires human reading | Open `components.md`, find Hz tier table, verify LOW = 2 Hz matches `cn_net_sync.gd` source |
| Prediction framing stripped from best-practices.md | NET-01 | Content correctness requires human judgment | Open `best-practices.md`, confirm "client prediction" framing removed, LOCAL pattern kept |
| Prediction framing reframed in custom-sync-handlers.md | NET-01 | Content correctness requires human judgment | Open `custom-sync-handlers.md`, confirm "server correction blending" framing replaces "client-side prediction" |
| Migration guide has deprecated notice only | NET-02 | Doc accuracy requires human review | Open `migration-v1-to-v2.md`, confirm deprecated notice at top, no other changes |
| All remaining 7 docs verified accurate | NET-03 | Full doc audit requires human reading | Check each doc for undocumented API calls or fabricated patterns |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

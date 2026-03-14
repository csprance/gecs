# Requirements: GECS v0.2 — Documentation Overhaul

**Defined:** 2026-03-13
**Core Value:** Developers can build ECS games in Godot with a framework that stays out of their way — clean APIs, honest docs, and patterns that actually work in real projects.

## v1 Requirements

### Core Docs (CORE) — addons/gecs/docs/

- [x] **CORE-01**: Developer can follow GETTING_STARTED end-to-end without hitting code that doesn't compile or APIs that don't exist
- [x] **CORE-02**: CORE_CONCEPTS accurately reflects the real ECS singleton, World, Entity, Component, System APIs — no invented methods
- [ ] **CORE-03**: COMPONENT_QUERIES matches the actual QueryBuilder syntax (with_all, with_any, with_none, with_relationship, with_group)
- [ ] **CORE-04**: OBSERVERS accurately describes the observer/reactive system as it works in actual source code
- [ ] **CORE-05**: RELATIONSHIPS doc is accurate — all examples use real API, no fabricated matching modes
- [x] **CORE-06**: SERIALIZATION verified against actual code or clearly marked as removed/changed

### Best Practices (BEST)

- [x] **BEST-01**: BEST_PRACTICES.md rewritten using patterns mined from zamn's actual systems and components — no fabricated examples
- [x] **BEST-02**: PERFORMANCE_OPTIMIZATION verified against actual benchmark data — no invented numbers or fake profiling results
- [x] **BEST-03**: TROUBLESHOOTING reflects real failure modes that users actually hit — verified against GECS source and test suite

### Network Docs (NET) — addons/gecs_network/docs/

- [ ] **NET-01**: All 8 network docs verified accurate against actual gecs_network v1.0.0 source code
- [ ] **NET-02**: Network best-practices doc uses real patterns — no AI-hallucinated networking advice
- [ ] **NET-03**: All example code in network docs compiles and matches the v1.0.0 API

### Entry Points (READ)

- [ ] **READ-01**: Root README.md rewritten as clean, accurate project homepage — correct install steps, real quick-start code
- [ ] **READ-02**: GECS addon README and network addon README consistent with rewritten docs

## v2 Requirements

### Supplementary

- **SUPP-01**: Interactive examples / tutorial project demonstrating all core concepts
- **SUPP-02**: Video walkthroughs linked from docs
- **SUPP-03**: API reference auto-generated from GDScript docstrings

## Out of Scope

| Feature | Reason |
|---------|--------|
| New GECS features or API changes | v0.2 is docs only — no .gd file changes |
| New tutorials / video content | Out of scope for this milestone |
| Docstring coverage on all .gd files | Useful but separate effort from user-facing docs |
| Translations | English-first |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 8 | Complete |
| CORE-02 | Phase 8 | Complete |
| CORE-03 | Phase 8 | Pending |
| CORE-04 | Phase 9 | Pending |
| CORE-05 | Phase 9 | Pending |
| CORE-06 | Phase 8 | Complete |
| BEST-01 | Phase 10 | Complete |
| BEST-02 | Phase 10 | Complete |
| BEST-03 | Phase 10 | Complete |
| NET-01 | Phase 11 | Pending |
| NET-02 | Phase 11 | Pending |
| NET-03 | Phase 11 | Pending |
| READ-01 | Phase 12 | Pending |
| READ-02 | Phase 12 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 after initial definition*

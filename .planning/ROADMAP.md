# Roadmap: GECS Networking v2

## Milestones

- ✅ **v0.1 GECS Networking v2** — Phases 1–7 (shipped 2026-03-13)
- **v0.2 Documentation Overhaul** — Phases 8–12 (active)

## Phases

<details>
<summary>✅ v0.1 GECS Networking v2 (Phases 1–7) — SHIPPED 2026-03-13</summary>

- [x] Phase 1: Foundation and Entity Lifecycle (4/4 plans) — completed 2026-03-09
- [x] Phase 2: Component Property Sync (4/4 plans) — completed 2026-03-09
- [x] Phase 3: Authority Model and Native Transform Sync (4/4 plans) — completed 2026-03-10
- [x] Phase 4: Relationship Sync (3/3 plans) — completed 2026-03-11
- [x] Phase 5: Reconciliation and Custom Sync (3/3 plans) — completed 2026-03-12
- [x] Phase 6: Cleanup, Documentation, and v1→v2 Migration (4/4 plans) — completed 2026-03-12
- [x] Phase 7: NetworkSession Node (4/4 plans) — completed 2026-03-13

Full archive: `.planning/milestones/v0.1-ROADMAP.md`

</details>

### v0.2 Documentation Overhaul

- [ ] **Phase 8: Foundation Docs** - GETTING_STARTED, CORE_CONCEPTS, and SERIALIZATION verified and rewritten
- [ ] **Phase 9: Advanced Core Docs** - COMPONENT_QUERIES, OBSERVERS, and RELATIONSHIPS verified and rewritten
- [ ] **Phase 10: Best Practices** - BEST_PRACTICES rebuilt from zamn, PERFORMANCE_OPTIMIZATION verified, TROUBLESHOOTING rewritten
- [ ] **Phase 11: Network Docs** - All gecs_network/docs/ verified against v1.0.0 source
- [ ] **Phase 12: Entry Points** - Root README and both addon READMEs rewritten

## Phase Details

### Phase 8: Foundation Docs
**Goal**: New developers can follow GETTING_STARTED end-to-end, understand the core ECS model, and trust that every API shown in the first three docs they encounter actually exists
**Depends on**: Nothing (first phase of v0.2)
**Requirements**: CORE-01, CORE-02, CORE-06
**Success Criteria** (what must be TRUE):
  1. A developer following GETTING_STARTED can copy-paste every code block and it compiles against GECS v6.8.1 without modification
  2. CORE_CONCEPTS lists only real methods and properties — every method name is verifiable against the actual `.gd` source files
  3. SERIALIZATION either demonstrates working serialization code or clearly states the feature's current state with no false claims
  4. No doc in this phase mentions a class, method, or property that does not exist in the current codebase
**Plans**: 3 plans

Plans:
- [ ] 08-01-PLAN.md — Rewrite GETTING_STARTED.md (full rewrite, emoji-free, verified API only)
- [ ] 08-02-PLAN.md — Fix CORE_CONCEPTS.md (targeted edit: undeclared variables, with_group type, cmd intro)
- [ ] 08-03-PLAN.md — Fix SERIALIZATION.md (remove false limitation, fix version, add GECSSerializeConfig)

### Phase 9: Advanced Core Docs
**Goal**: Developers can use COMPONENT_QUERIES, OBSERVERS, and RELATIONSHIPS docs as accurate references — every query syntax, observer hook, and relationship matching mode shown is real
**Depends on**: Phase 8
**Requirements**: CORE-03, CORE-04, CORE-05
**Success Criteria** (what must be TRUE):
  1. All QueryBuilder methods shown in COMPONENT_QUERIES (with_all, with_any, with_none, with_relationship, with_group) match the actual QueryBuilder source signatures
  2. OBSERVERS accurately describes how observers are registered and triggered — a developer reading it can implement a reactive system without consulting the source code
  3. RELATIONSHIPS shows only real relationship matching modes — no fabricated component query syntax or invented matching behaviors
  4. Every code example in all three docs produces no errors when loaded in a project using GECS v6.8.1
**Plans**: TBD

### Phase 10: Best Practices
**Goal**: Developers receive honest guidance on patterns, performance, and troubleshooting — every example comes from real code, every number is real, every failure mode was actually observed
**Depends on**: Phase 9
**Requirements**: BEST-01, BEST-02, BEST-03
**Success Criteria** (what must be TRUE):
  1. BEST_PRACTICES.md contains at least three patterns extracted from zamn's actual systems or components, each attributed to that source
  2. PERFORMANCE_OPTIMIZATION contains no invented benchmark numbers — any figures shown are either sourced from actual gdUnit4 performance test output or removed
  3. TROUBLESHOOTING describes failure modes that are reproducible from the GECS test suite or observable in the source — no invented error scenarios
  4. A developer hitting a real GECS issue (e.g., query returning no results, observer not firing) can find and apply a correct fix using TROUBLESHOOTING alone
**Plans**: TBD

### Phase 11: Network Docs
**Goal**: All gecs_network documentation accurately reflects the v1.0.0 API — no outdated method names, no fabricated RPC patterns, no docs that contradict the source
**Depends on**: Phase 10
**Requirements**: NET-01, NET-02, NET-03
**Success Criteria** (what must be TRUE):
  1. All 8 network docs have been read line-by-line against the gecs_network v1.0.0 source, with each discrepancy corrected or removed
  2. Every code example in every network doc compiles against the v1.0.0 API — no method calls to non-existent functions
  3. The network best-practices doc contains only patterns that are implementable with the actual v1.0.0 API (no invented prediction patterns, no undocumented hooks)
  4. The v1→v2 migration guide accurately reflects the real API differences between the old and new versions
**Plans**: TBD

### Phase 12: Entry Points
**Goal**: The root README and both addon READMEs serve as accurate first impressions — install steps work, quick-start code runs, and the reader gets a truthful picture of what GECS and GECS Network actually do
**Depends on**: Phase 11
**Requirements**: READ-01, READ-02
**Success Criteria** (what must be TRUE):
  1. A developer following the root README install steps can set up GECS in a new Godot 4 project without additional research
  2. The root README quick-start code block compiles and runs against GECS v6.8.1
  3. The gecs addon README and the gecs_network addon README are consistent with the rewritten docs from Phases 8–11 — no contradictions between README and doc content
  4. Each README accurately describes only features that exist in the current release — no mention of planned or removed features as present
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation and Entity Lifecycle | v0.1 | 4/4 | Complete | 2026-03-09 |
| 2. Component Property Sync | v0.1 | 4/4 | Complete | 2026-03-09 |
| 3. Authority Model and Native Transform Sync | v0.1 | 4/4 | Complete | 2026-03-10 |
| 4. Relationship Sync | v0.1 | 3/3 | Complete | 2026-03-11 |
| 5. Reconciliation and Custom Sync | v0.1 | 3/3 | Complete | 2026-03-12 |
| 6. Cleanup, Documentation, v1→v2 Migration | v0.1 | 4/4 | Complete | 2026-03-12 |
| 7. NetworkSession Node | v0.1 | 4/4 | Complete | 2026-03-13 |
| 8. Foundation Docs | v0.2 | 0/3 | Not started | - |
| 9. Advanced Core Docs | v0.2 | 0/? | Not started | - |
| 10. Best Practices | v0.2 | 0/? | Not started | - |
| 11. Network Docs | v0.2 | 0/? | Not started | - |
| 12. Entry Points | v0.2 | 0/? | Not started | - |

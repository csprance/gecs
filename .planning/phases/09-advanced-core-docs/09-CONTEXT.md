# Phase 9: Advanced Core Docs - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify and fix the three "advanced" docs that follow Phase 8's foundation docs:

- `addons/gecs/docs/COMPONENT_QUERIES.md`
- `addons/gecs/docs/OBSERVERS.md`
- `addons/gecs/docs/RELATIONSHIPS.md`

Goal: every query operator, observer hook, and relationship matching mode shown is real and matches the actual source code in GECS v6.8.1. No other docs are in scope.

</domain>

<decisions>
## Implementation Decisions

### Tone & style (carried from Phase 8)

- Strip all emojis from headers and body text (📋, 🎯, 🎮, 🔗, 🔧 are all present)
- No lengthy intro paragraphs — lead with content immediately
- No version stamp at the top
- Keep blockquote callout boxes (`> **Note:** ...`), no emoji inside them
- No trailing "By the end of this guide..." preamble
- Prefer minimal code examples — just enough to show the API works

### Rewrite depth

- Use per-doc judgment: light/surgical edit where mostly accurate, full rewrite where broken
- RELATIONSHIPS.md is 893 lines — preserve its structure and breadth, do a targeted accuracy pass removing fabricated matching modes or invented features rather than a full rewrite
- Rewrites may add sections if they close clear accuracy gaps

### COMPONENT_QUERIES scope

- Keep the doc focused on property-based filtering only — the `{ComponentClass: {property: {_gte: val}}}` dict syntax within `with_all` / `with_any`
- Do NOT expand scope to cover `with_group`, `with_relationship`, `without_relationship`, or `with_reverse_relationship` — those are covered in CORE_CONCEPTS and RELATIONSHIPS
- Operators (`_eq`, `_ne`, `_gt`, `_lt`, `_gte`, `_lte`, `_in`, `_nin`) are a real feature — verified in source docstrings and query_builder.gd post-structural filtering code

### OBSERVERS spatial assumptions

- Existing doc uses `entity.global_transform` and `entity.global_position` throughout (5+ locations) — assumes Entity is a Node3D
- Same issue as Phase 8 GETTING_STARTED: Entity extends Node, not Node3D
- Resolution: replace spatial examples with non-spatial alternatives (e.g., UI-style observer updating a Label, or a component-sync observer using plain data), OR add explicit `# Requires entity to be Node3D` guard comments
- Claude's discretion on which approach fits better per example

### Observer registration

- Observers are registered via `world.add_observer(observer)` — a separate method from `world.add_system()`
- `world.add_observers([array])` for batch registration
- Both methods are real and verified in world.gd (lines 820, 837)
- The doc must show the correct API — research phase should verify what the existing doc shows

### RELATIONSHIPS accuracy

- RELATIONSHIPS.md is the riskiest doc — it describes complex matching modes that may include fabricated behavior
- The success criteria explicitly call out: "no fabricated component query syntax or invented matching behaviors"
- Research phase must verify every matching mode shown in the doc against actual source (relationship.gd, query_builder.gd)
- Real verified features (from source docstrings): type matching, component query matching (`{C_Damage: {'amount': {"_gt": 50}}}` as relation arg), target property matching, limited removal
- Anything not present in source docstrings or query_builder.gd implementation should be removed or marked as unverified

### Claude's Discretion

- Which specific non-spatial examples to use in OBSERVERS (replace `global_transform` patterns)
- Section ordering within each doc
- Cross-linking strategy between the three docs and back to CORE_CONCEPTS
- Whether `with_reverse_relationship` gets a brief mention in RELATIONSHIPS or is covered only in CORE_CONCEPTS

</decisions>

<code_context>

## Existing Code Insights

### Reusable Assets

- `addons/gecs/ecs/query_builder.gd` — All methods: `with_all`, `with_any`, `with_none`, `with_relationship`, `without_relationship`, `with_reverse_relationship`, `with_group([Array[String]])`, `without_group`, `iterate`, `execute_one`, `execute`
- `addons/gecs/ecs/observer.gd` — `match() -> QueryBuilder` (optional), `watch() -> Resource` (required), `on_component_added(entity, component)`, `on_component_removed(entity, component)`, `on_component_changed(entity, component, property, new_value, old_value)`
- `addons/gecs/ecs/relationship.gd` — `Relationship.new(relation, target)`, `matches(other)`, `valid()`
- `addons/gecs/ecs/world.gd` — `add_observer(Observer)`, `add_observers(Array)`, `remove_observer(Observer)`

### Established Patterns

- `with_group` takes `Array[String]`, not a plain `String` — same fix needed here as Phase 8 (if COMPONENT_QUERIES doc shows it)
- Component query syntax is the `{ComponentClass: {property: {operator: value}}}` dict inside `with_all` or `with_any` args — operators are real (`_eq`, `_ne`, `_gt`, `_lt`, `_gte`, `_lte`, `_in`, `_nin`)
- Observer registration: `world.add_observer(observer_node)` — NOT `add_system()`
- Entity extends Node — spatial properties require entity to actually be Node3D/Node2D

### Integration Points

- COMPONENT_QUERIES → RELATIONSHIPS (link: "component queries work in relationship matching too")
- OBSERVERS → CORE_CONCEPTS (link: "see Systems section for comparison")
- RELATIONSHIPS → COMPONENT_QUERIES (link: "compound matching uses same operator syntax")
- All three in `addons/gecs/docs/` — relative links work

</code_context>

<specifics>
## Specific Ideas

No specific "I want it like X" references — user did not select areas for discussion.
All decisions above derived from Phase 8 context carryover and codebase scouting.

</specifics>

<deferred>
## Deferred Ideas

None — scope stayed within Phase 9 boundary.

</deferred>

---

_Phase: 09-advanced-core-docs_
_Context gathered: 2026-03-13_

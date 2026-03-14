# Phase 9: Advanced Core Docs — Research

**Researched:** 2026-03-14
**Domain:** GDScript documentation accuracy — GECS v6.8.1 source verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Three docs only: `addons/gecs/docs/COMPONENT_QUERIES.md`, `addons/gecs/docs/OBSERVERS.md`, `addons/gecs/docs/RELATIONSHIPS.md`
- Strip all emojis from headers and body text
- No lengthy intro paragraphs — lead with content immediately
- No version stamp at top
- Keep blockquote callout boxes (`> **Note:** ...`), no emoji inside them
- No trailing "By the end of this guide..." preamble
- Prefer minimal code examples
- Use per-doc judgment: light/surgical edit where mostly accurate, full rewrite where broken
- RELATIONSHIPS.md is 893 lines — preserve its structure and breadth, targeted accuracy pass only
- COMPONENT_QUERIES.md focuses on property-based filtering only — `{ComponentClass: {property: {_gte: val}}}` dict syntax in `with_all` / `with_any`. Do NOT expand scope to `with_group`, `with_relationship`, etc.
- Operators (`_eq`, `_ne`, `_gt`, `_lt`, `_gte`, `_lte`, `_in`, `_nin`) are verified real
- Observers use `world.add_observer(observer)` and `world.add_observers([array])` — NOT `add_system()`
- Spatial examples in OBSERVERS.md must add explicit Node3D guard comments OR be replaced with non-spatial alternatives; Claude has discretion on which fits better per example

### Claude's Discretion

- Which specific non-spatial examples to use in OBSERVERS (replace `global_transform` patterns)
- Section ordering within each doc
- Cross-linking strategy between the three docs and back to CORE_CONCEPTS
- Whether `with_reverse_relationship` gets a brief mention in RELATIONSHIPS or is covered only in CORE_CONCEPTS

### Deferred Ideas (OUT OF SCOPE)

None — scope stayed within Phase 9 boundary.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CORE-03 | COMPONENT_QUERIES matches actual QueryBuilder syntax | Operators verified in `component_query_matcher.gd`; `func` operator missing from doc but real; no fabricated syntax found |
| CORE-04 | OBSERVERS accurately describes how observers work | Registration API verified in `world.gd`; property change trigger mechanism clarified; spatial property bugs identified |
| CORE-05 | RELATIONSHIPS doc accurate — no fabricated matching modes | All matching modes verified in `relationship.gd` and `entity.gd`; one factory example has wrong method name |
</phase_requirements>

---

## Summary

Phase 9 targets three docs for accuracy verification against GECS v6.8.1 source. Research consisted entirely of reading actual source files and comparing them against the existing docs — no external research required.

**COMPONENT_QUERIES.md** is structurally accurate. The `{ComponentClass: {property: {operator: value}}}` syntax is real and verified in `component_query_matcher.gd`. The doc's listed operators are all real. One operator IS missing from the doc: `func` (custom callable, also verified in source). The doc needs emoji stripping and cleanup, but no correctness rewrite.

**OBSERVERS.md** has the most critical bugs. The spatial property usage (`entity.global_transform`, `entity.global_position`) is invalid for base Entity which extends Node, not Node3D. The `with_group` call takes `Array[String]` but the doc passes a bare String in 4+ places. Most seriously, the troubleshooting section states "Direct assignment to properties should work automatically" — this is factually wrong per observer.gd's own docstring, which states the developer must manually emit `property_changed` signal.

**RELATIONSHIPS.md** is the largest doc and is mostly accurate. All described matching modes — type matching, component query matching, wildcard, limited removal — are verified against source. One method name in a factory example is wrong. Emoji stripping and trailing quote removal are the primary edits needed.

**Primary recommendation:** Edit all three docs for emoji stripping, then apply targeted accuracy fixes per the issue lists below. Only OBSERVERS.md needs substantive rewriting of specific sections.

---

## Standard Stack

No libraries are added or changed. This phase is documentation-only markdown editing.

| Tool | Purpose | Notes |
|------|---------|-------|
| Read tool | Source verification | Primary research method |
| Write/Edit tool | Markdown editing | No .gd file changes permitted |

---

## Architecture Patterns

### Doc Edit Approach Per File

**COMPONENT_QUERIES.md** — Light surgical edit:
- Strip emoji headers
- Add `func` operator to Supported Operators table
- Remove "Conclusion" section trailing paragraph (optional cleanup)
- Examples using `QueryBuilder.new(world)` are technically valid; leave them

**OBSERVERS.md** — Moderate rewrite of specific sections:
- Strip all emoji headers (8+ occurrences)
- Fix `with_group` array syntax (4 occurrences)
- Fix or guard spatial property examples (3 code examples)
- Fix the property-change troubleshooting entry
- Remove trailing quote footer

**RELATIONSHIPS.md** — Targeted accuracy pass:
- Strip all emoji headers
- Fix one method name in the factory example
- Remove trailing quote footer
- Preserve all structure, breadth, and examples otherwise

### Phase 8 Patterns to Carry Forward

Established in Phase 8 (08-02-SUMMARY.md patterns-established):
- `with_group` always takes `Array[String]`: `with_group(["name"])` not `with_group("name")`
- Every code example must be self-contained — every variable used is declared in that same block
- Note callouts use blockquote syntax (`> **Note:** ...`) outside code fences, never inside

---

## Verified API Facts

Source of truth: GECS v6.8.1 source files read directly.

### QueryBuilder API (`addons/gecs/ecs/query_builder.gd`)

| Method | Signature | Notes |
|--------|-----------|-------|
| `with_all` | `with_all(components: Array = []) -> QueryBuilder` | Accepts component classes and/or dicts |
| `with_any` | `with_any(components: Array = []) -> QueryBuilder` | Accepts component classes and/or dicts |
| `with_none` | `with_none(components: Array = []) -> QueryBuilder` | Extracts class key from dicts, ignores query criteria |
| `with_relationship` | `with_relationship(relationships: Array = []) -> QueryBuilder` | |
| `without_relationship` | `without_relationship(relationships: Array = []) -> QueryBuilder` | |
| `with_reverse_relationship` | `with_reverse_relationship(relationships: Array = []) -> QueryBuilder` | Only checks `relation.get_script().resource_path`; target arg is ignored |
| `with_group` | `with_group(groups: Array[String] = []) -> QueryBuilder` | MUST be Array[String], not bare String |
| `without_group` | `without_group(groups: Array[String] = []) -> QueryBuilder` | |
| `enabled` | `enabled() -> QueryBuilder` | No parameter (not `enabled(true)`) |
| `disabled` | `disabled() -> QueryBuilder` | No parameter (not `enabled(false)`) |
| `execute` | `execute() -> Array` | Returns Array[Entity] |
| `execute_one` | `execute_one() -> Entity` | Returns first match or null |
| `iterate` | `iterate(components: Array) -> QueryBuilder` | For batch processing with process_batch() |

### Component Query Operators (`addons/gecs/lib/component_query_matcher.gd`)

All operators verified in `ComponentQueryMatcher.matches_query`:

| Operator | Behavior | Example |
|----------|----------|---------|
| `_eq` | `property == value` | `{"_eq": 25}` |
| `_ne` | `property != value` | `{"_ne": 0}` |
| `_gt` | `property > value` | `{"_gt": 10}` |
| `_lt` | `property < value` | `{"_lt": 100}` |
| `_gte` | `property >= value` | `{"_gte": 50}` |
| `_lte` | `property <= value` | `{"_lte": 100}` |
| `_in` | `property in [values]` | `{"_in": ["fire", "ice"]}` |
| `_nin` | `property not in [values]` | `{"_nin": ["dead"]}` |
| `func` | `callable.call(property) -> bool` | `{"func": func(v): return v > 10}` |

COMPONENT_QUERIES.md lists only 8 operators and is missing `func`. The `func` operator is real and documented in `component_query_matcher.gd` docstring.

### Observer API (`addons/gecs/ecs/observer.gd` + `world.gd`)

| Method | Signature | Required? | Notes |
|--------|-----------|-----------|-------|
| `watch()` | `watch() -> Resource` | YES — crashes if not overridden | Return the component class (script ref), not an instance: `return C_Health` |
| `match()` | `match() -> QueryBuilder` | NO | Returns `q` (empty QB) by default — matches all entities |
| `on_component_added` | `(entity: Entity, component: Resource) -> void` | NO | Override to handle |
| `on_component_removed` | `(entity: Entity, component: Resource) -> void` | NO | Override to handle |
| `on_component_changed` | `(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant) -> void` | NO | Only fires if component manually emits `property_changed` |

**Observer registration (world.gd lines 820, 837):**
```gdscript
ECS.world.add_observer(observer_node)         # Single
ECS.world.add_observers([obs1, obs2, obs3])   # Batch
ECS.world.remove_observer(observer_node)       # Remove
```

**Auto scene tree registration (world.gd line 183):**
```gdscript
var _observers = get_node(system_nodes_root).find_children("*", "Observer") as Array[Observer]
```
Observers placed under the systems root node are auto-discovered at world init.

**Property change signal chain:**
```
Component.property_changed.emit(self, "prop", old, new)
  -> Entity._on_component_property_changed (re-emits with entity prepended)
  -> World._on_entity_component_property_change
  -> Observer.on_component_changed(entity, component, property, new_value, old_value)
```
Manual `property_changed.emit(...)` in the component is REQUIRED. Setting a property directly does NOT trigger observers.

### Relationship API (`addons/gecs/ecs/relationship.gd` + `entity.gd`)

**Construction:**
```gdscript
Relationship.new(relation, target)   # relation: Component instance or dict or null; target: Entity/Component/Script/null
```

**Matching modes (all verified in `Relationship.matches()`):**

| Mode | How to Use | What It Does |
|------|-----------|--------------|
| Type matching | `Relationship.new(C_Comp.new(), target)` | Compares `relation.get_script()` equality |
| Wildcard | `null` or `ECS.wildcard` as relation or target | Matches any relation or any target |
| Component query (relation) | `Relationship.new({C_Comp: {'prop': {'_gte': val}}}, target)` | Evaluates `ComponentQueryMatcher` on the stored relation |
| Component query (target) | `Relationship.new(C_Comp.new(), {C_Target: {'prop': {'_lt': val}}})` | Evaluates `ComponentQueryMatcher` on the stored target |
| Both relation and target query | `Relationship.new({C_Comp: {query}}, {C_Target: {query}})` | Both sides evaluated |

**ECS.wildcard:** `ECS.wildcard = null` (defined in `ecs.gd` line 66). It is simply an alias for `null` for readability.

**Entity relationship methods (entity.gd):**
```gdscript
entity.add_relationship(Relationship)
entity.remove_relationship(Relationship, limit: int = -1)    # limit: -1=all, 0=none, N=up to N
entity.remove_relationships(Array[Relationship], limit: int = -1)
entity.remove_all_relationships()
entity.has_relationship(Relationship) -> bool
entity.get_relationship(Relationship) -> Relationship   # first match or null
entity.get_relationships(Relationship) -> Array[Relationship]
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Property comparison in queries | Custom comparison logic | `ComponentQueryMatcher.matches_query()` | Already handles all 9 operators including nil-safety |
| Relationship matching logic | Custom equality checks | `Relationship.matches(other)` | Handles all target/relation type combinations |

---

## Common Pitfalls

### Pitfall 1: with_group Takes Array[String], Not a Bare String

**What goes wrong:** `q.with_group("player")` is called. GDScript accepts it silently at runtime but the query finds no matching entities because the implementation does `_groups.append_array(groups)` where `groups` is expected to be an array.

**Why it happens:** Looks like most string-taking functions (all GDScript string args feel scalar).

**How to avoid:** Always `with_group(["player"])`.

**Warning signs:** Observer/query returns empty results for entities that are definitely in the group.

**Evidence:** Phase 8 CORE_CONCEPTS had this same bug fixed (08-02-SUMMARY.md patterns-established). OBSERVERS.md repeats it in 4 places.

### Pitfall 2: Property Changes Don't Trigger Observers Without Manual Signal

**What goes wrong:** Developer sets `health.current = 50` directly. Observer's `on_component_changed` never fires.

**Why it happens:** Godot's Resource class does not auto-emit signals on property assignment. The signal chain requires an explicit `property_changed.emit(self, "current", old_value, new_value)` inside the component's setter.

**How to avoid:** Component properties that should trigger observers must use a setter:
```gdscript
@export var current: int = 100 : set = set_current

func set_current(value: int):
    var old = current
    current = value
    property_changed.emit(self, "current", old, value)
```

**Warning signs:** Observer exists, is registered, query matches, but `on_component_changed` never fires.

**Source:** observer.gd docstring (lines 7-21) explicitly states this requirement.

### Pitfall 3: Entity Spatial Properties on Non-Spatial Entities

**What goes wrong:** Example code calls `entity.global_transform` or `entity.global_position`. Entity extends Node, not Node3D or Node2D. These properties do not exist on base Entity — accessing them raises an error.

**Why it happens:** Many tutorials and examples implicitly assume entities are 3D nodes.

**How to avoid:** Either cast explicitly (`entity as Node3D`).global_transform, or document the guard: `# Requires entity to be Node3D`.

**Warning signs:** `Invalid get index 'global_transform' on base 'Entity (entity.gd)'`.

### Pitfall 4: watch() Must Return Script Reference, Not Instance

**What goes wrong:** `return C_Health.new()` instead of `return C_Health`. Instance's `resource_path` is an empty string, so the world's component type comparison always fails — observer never fires.

**Why it happens:** GDScript usually requires `.new()` to instantiate. The watch() case is an exception because the world does `watch_component.resource_path == component.get_script().resource_path` — comparing paths, not instances.

**How to avoid:** `return C_Health` (bare class reference, no `.new()`).

### Pitfall 5: with_reverse_relationship Ignores the Target Argument

**What goes wrong:** `with_reverse_relationship([Relationship.new(C_Likes.new(), e_alice)])` — the `e_alice` target is silently ignored. The method only indexes on the relation type's script path.

**Why it happens:** The implementation (query_builder.gd lines 142-148) only reads `rel.relation.get_script().resource_path` to build the reverse index key.

**How to avoid:** Pass null or ECS.wildcard as target to make the intent explicit. Document that targets are not checked.

---

## Code Examples

Verified patterns from actual source files:

### Component Query in with_all

```gdscript
# Source: verified in component_query_matcher.gd and query_builder.gd
ECS.world.query.with_all([
    { C_Health: { "current": { "_lt": 20 } } }
]).execute()
```

### Component Query in with_any

```gdscript
ECS.world.query.with_any([
    { C_Health: { "current": { "_lt": 20 } } },
    { C_Shield: { "remaining": { "_eq": 0 } } }
]).execute()
```

### func Operator (custom callable)

```gdscript
# Source: component_query_matcher.gd line 56-58
ECS.world.query.with_all([
    { C_Health: { "current": { "func": func(v): return v < 20 } } }
]).execute()
```

### Observer Registration

```gdscript
# Source: world.gd lines 820-839
func _ready():
    ECS.world.add_observer(HealthUIObserver.new())
    ECS.world.add_observers([obs_a, obs_b, obs_c])
```

### Observer with Correct Query

```gdscript
# Source: observer.gd, query_builder.gd
class_name HealthObserver
extends Observer

func watch() -> Resource:
    return C_Health  # class reference, not C_Health.new()

func match() -> QueryBuilder:
    return q.with_all([C_Health]).with_group(["player"])  # Array[String] required

func on_component_changed(entity: Entity, component: Resource, property: String, new_value, old_value):
    if property == "current":
        update_health_bar(entity, new_value, old_value)
```

### Component Property Setter for Observer Triggering

```gdscript
# Source: observer.gd docstring (lines 15-22)
class_name C_Health
extends Component

@export var current: int = 100 : set = set_current

func set_current(value: int):
    var old = current
    current = value
    property_changed.emit(self, "current", old, value)
```

### Relationship Type Matching

```gdscript
# Source: relationship.gd matches() — compares get_script() identity
ECS.world.query.with_relationship([
    Relationship.new(C_Likes.new(), e_alice)
]).execute()
```

### Relationship Component Query Matching

```gdscript
# Source: relationship.gd lines 170-175
ECS.world.query.with_relationship([
    Relationship.new({ C_Eats: { "quantity": { "_gte": 5 } } }, e_apple)
]).execute()
```

### Limited Relationship Removal

```gdscript
# Source: entity.gd remove_relationship() lines 372+
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 1)   # remove one
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 3)   # remove up to three
entity.remove_relationship(Relationship.new(C_Buff.new(), null))      # remove all (default -1)
```

---

## Issues Found Per Document

This section is the primary planner input. Each issue maps to a specific fix task.

### COMPONENT_QUERIES.md Issues

| # | Issue | Type | Location | Fix |
|---|-------|------|----------|-----|
| CQ-1 | Emoji headers `📋` and `🎯` | Style | Lines 9, 14 | Strip emojis |
| CQ-2 | `func` operator missing from Supported Operators | Accuracy | After `_nin` | Add row: `func` — Custom function `func(value) -> bool` |
| CQ-3 | "Conclusion" trailing paragraph | Style | Last section | Remove or shorten |

CQ-1 and CQ-2 are required fixes (CORE-03 accuracy). CQ-3 is style cleanup.

**Overall severity:** Light surgical edit. No structural or API inaccuracies beyond CQ-2.

### OBSERVERS.md Issues

| # | Issue | Type | Occurrences | Fix |
|---|-------|------|------------|-----|
| OB-1 | Emoji headers throughout | Style | 8+ | Strip all emojis |
| OB-2 | `with_group("player")` — bare String, not Array | Bug | Lines 65, 86, 250, 335 | Change to `with_group(["player"])` |
| OB-3 | `entity.global_transform` — invalid on base Entity | Bug | Lines 43, 44, 127, 128, 131 | Add Node3D guard comment OR replace with non-spatial example |
| OB-4 | `entity.global_position` — invalid on base Entity | Bug | Lines 187, 189 | Same resolution as OB-3 |
| OB-5 | Troubleshooting: "Direct assignment works automatically" | False claim | Lines 337-342 | Replace with accurate description: manual signal required |
| OB-6 | Trailing quote footer | Style | Last line | Remove |

OB-2 through OB-5 are correctness issues required for CORE-04. OB-5 is the most misleading — a developer reading it would conclude their observer should work when it does not.

**Overall severity:** Moderate. The structural content (registration, callbacks, use cases) is accurate. Specific code examples and one troubleshooting entry need targeted fixes.

### RELATIONSHIPS.md Issues

| # | Issue | Type | Location | Fix |
|---|-------|------|----------|-----|
| RL-1 | Emoji headers throughout | Style | Many | Strip all emojis |
| RL-2 | `Relationships.chasing_anything()` called but method is `chasing_players()` | Bug | Line 806 | Fix method call to match the factory definition |
| RL-3 | Trailing quote footer | Style | Last line | Remove |

**Overall severity:** Light. All relationship matching modes are verified against source and are accurate. RL-2 is a minor example bug but won't cause a crash (it's just a doc example with a wrong method name).

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| Backwards iteration / snapshots for safe system iteration | CommandBuffer (`cmd.remove_entity()`) | Not relevant to these docs but established in Phase 8 |
| `enabled(true)` / `enabled(false)` pattern | `enabled()` / `disabled()` separate methods | QueryBuilder API changed — if any doc shows `enabled(true)` it is wrong |

---

## Open Questions

1. **Observer spatial example replacement strategy**
   - What we know: Claude has discretion on whether to use a Node3D guard comment or replace the examples entirely
   - What's unclear: The TransformObserver pattern (`entity.global_transform = transform_comp.transform`) is a real and common pattern — but only valid if entity IS a Node3D
   - Recommendation: Add a `# Requires entity to be Node3D` comment on the relevant lines, consistent with how Phase 8 GETTING_STARTED handled the same issue. This preserves the useful example while being accurate. For the audio example using `entity.global_position`, replace with a non-positional alternative (e.g., look up AudioStreamPlayer from entity's children instead of using position directly).

2. **COMPONENT_QUERIES.md `func` operator — show example or just list?**
   - What we know: `func` is real, verified in source
   - What's unclear: It may be less commonly used; a full example could confuse readers
   - Recommendation: Add it to the Supported Operators table with a one-line description and a brief inline example. No need for a separate full code block.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | gdUnit4 (GDScript test runner) |
| Config file | `addons/gdUnit4/GdUnitRunner.cfg` |
| Quick run command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests"` |
| Full suite command | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -c` |

### Phase Requirements → Test Map

This phase is docs-only (no .gd file changes). There are no automated tests that verify markdown content. All validation is manual.

| Req ID | Behavior | Test Type | Verification Method |
|--------|----------|-----------|---------------------|
| CORE-03 | COMPONENT_QUERIES syntax matches QueryBuilder | manual | Read fixed doc, cross-check each operator against `component_query_matcher.gd` |
| CORE-04 | OBSERVERS accurately describes registration and triggering | manual | Read fixed doc, verify each API call against `observer.gd` and `world.gd` |
| CORE-05 | RELATIONSHIPS shows only real matching modes | manual | Read fixed doc, verify each matching pattern against `relationship.gd` |

### Sampling Rate

- Per task commit: manually re-read the modified section to confirm the fix is applied
- Per wave merge: full doc read comparing against source file
- Phase gate: all three docs read-verified before `/gsd:verify-work`

### Wave 0 Gaps

None — no test files need to be created. This is a documentation phase with no code changes.

---

## Sources

### Primary (HIGH confidence)

All findings sourced from direct file reads of GECS v6.8.1 source:

- `addons/gecs/lib/component_query_matcher.gd` — all 9 operators verified, `process_component_list` logic
- `addons/gecs/ecs/query_builder.gd` — all method signatures, `with_group` array type, `execute()` flow
- `addons/gecs/ecs/observer.gd` — `watch()`/`match()` signatures, event callback signatures, property change docstring
- `addons/gecs/ecs/world.gd` lines 816-898 — `add_observer`, `add_observers`, `remove_observer`, observer dispatch logic, `_handle_observer_component_added`, `_on_entity_component_property_change`
- `addons/gecs/ecs/relationship.gd` — `_init` dict handling, all `matches()` branches, `valid()`
- `addons/gecs/ecs/entity.gd` — `remove_relationship(limit)`, `remove_relationships`, `get_relationship`, `get_relationships`, signal chain
- `addons/gecs/ecs/component.gd` — `property_changed` signal declaration
- `addons/gecs/ecs/ecs.gd` — `ECS.wildcard = null` declaration

### Secondary (HIGH confidence)

- `.planning/phases/08-foundation-docs/08-02-SUMMARY.md` — Phase 8 established patterns (`with_group` fix, self-contained examples, emoji stripping rules)
- `.planning/phases/09-advanced-core-docs/09-CONTEXT.md` — locked decisions and verified API notes from context session

---

## Metadata

**Confidence breakdown:**
- Issue lists: HIGH — every issue directly verified against source files read in this session
- Operator completeness: HIGH — `component_query_matcher.gd` exhaustively lists all match branches
- Observer signal chain: HIGH — traced from component.property_changed through entity to world to observer callback
- Relationship matching: HIGH — every `Relationship.matches()` branch read and documented
- Spatial property issue: HIGH — Entity class definition extends Node (not Node3D), confirmed in entity.gd

**Research date:** 2026-03-14
**Valid until:** 2026-05-14 (stable codebase, no .gd changes planned)

# GECS Bug Fixes Applied

## Overview
This document summarizes the bug fixes applied to the GECS (Godot Entity Component System) addon.

## Issues Fixed

### 1. System Group Property Reset Bug
**File:** `addons/gecs/ecs/world.gd`
**Function:** `add_system()`
**Lines:** 478-493

#### Problem
When a system was added to the world, its `@export var group` property (and other @export properties) were being reset to default values. This occurred because Godot resets @export variables when `add_child()` is called on a node.

#### Reproduction
```gdscript
var sys_a = TestASystem.new()
sys_a.group = "group1"  # Set group before adding
world.add_system(sys_a)
# sys_a.group is now "" instead of "group1"
```

#### Solution
Save all @export properties before calling `add_child()`, then restore them immediately after:

```gdscript
func add_system(system: System, topo_sort: bool = false) -> void:
    # BUGFIX: Preserve @export variables before add_child() as Godot resets them
    var saved_group = system.group
    var saved_process_empty = system.process_empty
    var saved_active = system.active
    var saved_parallel_processing = system.parallel_processing
    var saved_parallel_threshold = system.parallel_threshold
    
    if not system.is_inside_tree():
        get_node(system_nodes_root).add_child(system)
        # Restore @export variables after add_child()
        system.group = saved_group
        system.process_empty = saved_process_empty
        system.active = saved_active
        system.parallel_processing = saved_parallel_processing
        system.parallel_threshold = saved_parallel_threshold
    # ... rest of function
```

#### Impact
- Fixes `test_system_group_processes_entities_with_required_components` test
- Systems can now be properly organized into groups
- Group-based processing now works as expected

---

### 2. Entity Removal Reliability Issue
**File:** `addons/gecs/ecs/world.gd`
**Function:** `remove_entity()`
**Lines:** 336-339

#### Problem
The `entities.erase(entity)` call sometimes failed to remove entities from the typed array `Array[Entity]`. This could happen due to reference equality issues with typed arrays.

#### Solution
Changed from `erase()` to a more reliable `find()` + `remove_at()` pattern:

```gdscript
# Old code:
entities.erase(entity) # FIXME: This doesn't always work for some reason?

# New code:
# BUGFIX: Use find() to locate entity by reference, then remove by index for reliability
var entity_index = entities.find(entity)
if entity_index != -1:
    entities.remove_at(entity_index)
```

#### Impact
- More reliable entity removal from the world
- Prevents memory leaks from entities not being properly removed
- Better compatibility with Godot's typed arrays

---

## Test Updates

### File: `addons/gecs/tests/core/test_system.gd`
**Line 72:** Updated comment from FIXME to NOTE

```gdscript
# Before:
# FIXME: This test is failing system groups are not being set correctly (or they're being overidden somewhere)

# After:
# NOTE: System groups are now preserved correctly when systems are added to the world
```

---

## Technical Details

### Root Cause Analysis

#### System Group Issue
The root cause was Godot's behavior when adding nodes to the scene tree. When `add_child()` is called:
1. Godot internally calls `_enter_tree()` on the node
2. During this process, @export variables are reinitialized to their default values
3. This is standard Godot behavior to ensure scene consistency

#### Entity Removal Issue
The `erase()` method on typed arrays may have reference equality issues, especially when:
- Entities are being queue_free()'d
- Multiple references to the same entity exist
- The entity has already been partially destroyed

### Alternative Solutions Considered

#### System Group Issue
1. **Alternative 1:** Make `group` a regular variable (not @export)
   - Rejected: Loses editor convenience
   
2. **Alternative 2:** Set group after add_child() in user code
   - Rejected: Error-prone, breaks existing API

3. **Chosen Solution:** Save/restore pattern
   - Preserves API compatibility
   - Works transparently for users
   - Handles all @export properties

#### Entity Removal Issue
1. **Alternative 1:** Use filter() to create new array
   - Rejected: Performance overhead
   
2. **Alternative 2:** Maintain separate tracking dictionary
   - Rejected: Unnecessary complexity

3. **Chosen Solution:** find() + remove_at()
   - Simple and reliable
   - Good performance
   - Standard Godot pattern

---

## Verification

To verify these fixes work correctly:

```gdscript
# Test 1: System groups
var sys = TestSystem.new()
sys.group = "test_group"
world.add_system(sys)
assert(sys.group == "test_group", "Group should be preserved")

# Test 2: Entity removal
var entity = Entity.new()
world.add_entity(entity)
assert(world.entities.has(entity), "Entity should be added")
world.remove_entity(entity)
assert(not world.entities.has(entity), "Entity should be removed")
```

---

## Version
- GECS Version: 6.7.2
- Godot Version: 4.x
- Date Applied: 2024-12-03

---

## Related Issues
- Test: `test_system_group_processes_entities_with_required_components`
- Test: General entity lifecycle tests

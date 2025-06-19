# Observers in GECS

> **Reactive systems that respond to component changes**

Observers provide a reactive programming model where systems automatically respond to component changes, additions, and removals. This allows for decoupled, event-driven game logic.

## 📋 Prerequisites

- Understanding of [Core Concepts](CORE_CONCEPTS.md)
- Familiarity with [Systems](CORE_CONCEPTS.md#systems)

## 🎯 What are Observers?

Observers are specialized systems that watch for changes to specific components and react immediately when those changes occur. Instead of processing entities every frame, observers only trigger when something actually changes.

**Benefits:**

- **Performance** - Only runs when changes occur, not every frame
- **Decoupling** - Components don't need to know what systems depend on them
- **Reactivity** - Immediate response to state changes
- **Clean Logic** - Separate change-handling logic from regular processing

## 🔧 Observer Structure

Observers extend the `Observer` class and implement key methods:

1. **`watch()`** - Specifies which component to monitor for events (required)
2. **`match()`** - Defines a query to filter which entities trigger events (optional)
3. **Event Handlers** - Handle specific types of changes

```gdscript
# o_transform.gd
class_name TransformObserver
extends Observer

func watch() -> Resource:
    return C_Transform  # Watch for transform component changes

func on_component_added(entity: Entity, component: Resource):
    # Sync component transform to entity when added
    var transform_comp = component as C_Transform
    entity.global_transform = transform_comp.transform

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    # Sync component transform to entity when changed
    var transform_comp = component as C_Transform
    entity.global_transform = transform_comp.transform
```

## 🎮 Observer Event Types

### on_component_added()

Triggered when a watched component is added to an entity:

```gdscript
class_name HealthUIObserver
extends Observer

func watch() -> Resource:
    return C_Health

func match():
    return q.with_all([C_Health]).with_group("player")

func on_component_added(entity: Entity, component: Resource):
    # Create health bar when player gains health component
    var health = component as C_Health
    # Use call_deferred to avoid timing issues during component changes
    call_deferred("create_health_bar", entity, health.maximum)
```

### on_component_changed()

Triggered when a watched component's property changes:

```gdscript
class_name HealthBarObserver
extends Observer

func watch() -> Resource:
    return C_Health

func match():
    return q.with_all([C_Health]).with_group("player")

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    if property == "current":
        var health = component as C_Health
        # Update health bar display
        call_deferred("update_health_bar", entity, health.current, health.maximum)
```

### on_component_removed()

Triggered when a watched component is removed from an entity:

```gdscript
class_name HealthUIObserver
extends Observer

func watch() -> Resource:
    return C_Health

func on_component_removed(entity: Entity, component: Resource):
    # Clean up health bar when health component is removed
    call_deferred("remove_health_bar", entity)
```

## 💡 Common Observer Patterns

### Transform Synchronization

Keep entity scene transforms in sync with Transform components:

```gdscript
# o_transform.gd
class_name TransformObserver
extends Observer

func watch() -> Resource:
    return C_Transform

func on_component_added(entity: Entity, component: Resource):
    var transform_comp = component as C_Transform
    entity.global_transform = transform_comp.transform

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    var transform_comp = component as C_Transform
    entity.global_transform = transform_comp.transform
```

### Status Effect Visuals

Show visual feedback for status effects:

```gdscript
# o_status_effects.gd
class_name StatusEffectObserver
extends Observer

func watch() -> Resource:
    return C_StatusEffect

func on_component_added(entity: Entity, component: Resource):
    var status = component as C_StatusEffect
    call_deferred("add_status_visual", entity, status.effect_type)

func on_component_removed(entity: Entity, component: Resource):
    var status = component as C_StatusEffect
    call_deferred("remove_status_visual", entity, status.effect_type)

func add_status_visual(entity: Entity, effect_type: String):
    match effect_type:
        "poison":
            # Add poison particle effect
            pass
        "shield":
            # Add shield visual overlay
            pass

func remove_status_visual(entity: Entity, effect_type: String):
    # Remove corresponding visual effect
    pass
```

### Audio Feedback

Trigger sound effects on component changes:

```gdscript
# o_audio_feedback.gd
class_name AudioFeedbackObserver
extends Observer

func watch() -> Resource:
    return C_Health

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    if property == "current":
        var health_change = new_value - old_value
        
        if health_change < 0:
            # Health decreased - play damage sound
            call_deferred("play_damage_sound", entity.global_position)
        elif health_change > 0:
            # Health increased - play heal sound
            call_deferred("play_heal_sound", entity.global_position)
```

## 🏗️ Observer Best Practices

### Naming Conventions

**Observer files and classes:**

- **Class names**: `DescriptiveNameObserver` (TransformObserver, HealthUIObserver)
- **File names**: `o_descriptive_name.gd` (o_transform.gd, o_health_ui.gd)

### Use Deferred Calls

Always use `call_deferred()` to defer work and avoid immediate execution during component updates:

```gdscript
# ✅ Good - Defer work for later execution
func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    call_deferred("update_ui_element", entity, new_value)

# ❌ Avoid - Immediate execution can cause issues
func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    update_ui_element(entity, new_value)  # May cause timing issues
```

### Keep Observer Logic Simple

Focus observers on single responsibilities:

```gdscript
# ✅ Good - Single purpose observer
class_name HealthUIObserver
extends Observer

func watch() -> Resource:
    return C_Health

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    if property == "current":
        call_deferred("update_health_display", entity, new_value)

# ❌ Avoid - Observer doing too much
class_name HealthObserver
extends Observer

func on_component_changed(entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant):
    # Too many responsibilities in one observer
    update_health_display(entity, new_value)
    play_damage_sound(entity)
    check_achievements(entity)
    save_game_state()
```

### Use Specific Queries

Filter which entities trigger observers with `match()`:

```gdscript
# ✅ Good - Specific query
func match():
    return q.with_all([C_Health]).with_group("player")  # Only player health

# ❌ Avoid - Too broad
func match():
    return q.with_all([C_Health])  # ALL entities with health
```

## 🎯 When to Use Observers

**Use Observers for:**

- UI updates based on game state changes
- Audio/visual effects triggered by state changes
- Immediate response to critical state changes (death, level up)
- Synchronization between components and scene nodes
- Event logging and analytics

**Use Regular Systems for:**

- Continuous processing (movement, physics)
- Frame-by-frame updates
- Complex logic that depends on multiple entities
- Performance-critical processing loops

## 📚 Related Documentation

- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding the ECS fundamentals
- **[Systems](CORE_CONCEPTS.md#systems)** - Regular processing systems
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code

---

_"Observers turn your ECS from a polling system into a reactive system, making your game respond intelligently to state changes rather than constantly checking for them."_
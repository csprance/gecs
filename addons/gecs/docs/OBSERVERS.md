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

Observers extend the `Observer` class and implement three key methods:

1. **`watch()`** - Specifies which component to monitor for events
2. **`match()`** - Defines a query to filter which entities trigger events
3. **Event Handlers** - Handle specific types of changes

```gdscript
# o_health_ui_updater.gd
class_name HealthUIUpdater
extends Observer

func watch():
    return C_Health  # Watch for health component changes

func match():
    return q.with_all([C_Health, C_Player])  # Only for player entities

func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    # Called when health values change
    update_health_bar(entity, new_value)

func on_added(entity: Entity, component: Component):
    # Called when health component is added
    create_health_bar(entity)

func on_removed(entity: Entity, component: Component):
    # Called when health component is removed
    destroy_health_bar(entity)
```

## 🎮 Observer Event Types

### on_changed()

Triggered when a watched component's property changes:

```gdscript
class_name DamageEffectObserver
extends Observer

func watch():
    return C_Health

func match():
    return q.with_all([C_Health, C_Sprite])

func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    if property == "current" and new_value < old_value:
        # Health decreased - show damage effect
        var damage_amount = old_value - new_value
        show_damage_number(entity, damage_amount)
        flash_red(entity)
```

### on_added()

Triggered when a watched component is added to an entity:

```gdscript
class_name StatusEffectObserver
extends Observer

func watch():
    return C_StatusEffect

func match():
    return q.with_all([C_StatusEffect])

func on_added(entity: Entity, component: Component):
    var status = component as C_StatusEffect
    match status.effect_type:
        "poison":
            add_poison_visual(entity)
        "speed_boost":
            add_speed_particles(entity)
        "shield":
            add_shield_overlay(entity)
```

### on_removed()

Triggered when a watched component is removed from an entity:

```gdscript
class_name StatusEffectObserver
extends Observer

func watch():
    return C_StatusEffect

func match():
    return q.with_all([C_Sprite])  # Entities that can show visual effects

func on_removed(entity: Entity, component: Component):
    var status = component as C_StatusEffect
    match status.effect_type:
        "poison":
            remove_poison_visual(entity)
        "speed_boost":
            remove_speed_particles(entity)
        "shield":
            remove_shield_overlay(entity)
```

## 💡 Common Observer Patterns

### UI Synchronization

Keep UI elements synchronized with game state:

```gdscript
# o_inventory_ui.gd
class_name InventoryUIObserver
extends Observer

func watch():
    return C_Inventory

func match():
    return q.with_all([C_Inventory, C_Player])

func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    match property:
        "items":
            refresh_inventory_display()
        "selected_item":
            highlight_selected_item(new_value)
        "gold":
            update_gold_display(new_value)

func on_added(entity: Entity, component: Component):
    create_inventory_ui()

func on_removed(entity: Entity, component: Component):
    destroy_inventory_ui()
```

### Sound and Visual Effects

Trigger audio/visual feedback on state changes:

```gdscript
# o_audio_feedback.gd
class_name AudioFeedbackObserver
extends Observer

func watch():
    return C_Health

func match():
    return q.with_all([C_Health])

func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    if property == "current":
        if new_value <= 0:
            AudioManager.play("death_sound")
            ParticleManager.play_death_effect(entity.position)
        elif new_value < old_value:
            AudioManager.play("damage_sound")
        elif new_value > old_value:
            AudioManager.play("heal_sound")
```

## 🏗️ Observer Best Practices

### Naming Conventions

**Observer files and classes:**

- **Class names**: `DescriptiveNameObserver` (HealthUIObserver, DamageEffectObserver)
- **File names**: `o_descriptive_name.gd` (o_health_ui.gd, o_damage_effect.gd)

### Performance Considerations

**Keep Observer Logic Light:**

```gdscript
# ✅ Good - Light observer logic
func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    # Queue the work for later processing
    UIUpdateQueue.queue_health_update(entity, new_value)

# ❌ Avoid - Heavy processing in observer
func on_changed(entity: Entity, component: Component, property: String, old_value, new_value):
    # This could cause frame drops
    recalculate_entire_ui()
    rebuild_complex_display()
    save_game_state()
```

**Use Specific Queries:**

```gdscript
# ✅ Good - Specific query
func match():
    return q.with_all([C_Health, C_Player])  # Only player health changes

# ❌ Avoid - Overly broad query
func match():
    return q.with_all([C_Health])  # Triggers for ALL entities with health
```

## 🎯 When to Use Observers

**Use Observers for:**

- UI updates based on game state
- Audio/visual effects triggered by changes
- Achievement/statistics tracking
- State synchronization between components
- Immediate response to critical state changes

**Use Regular Systems for:**

- Continuous processing (movement, physics)
- Frame-by-frame updates
- Complex logic that depends on multiple entities
- Performance-critical processing

## 📚 Related Documentation

- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding the ECS fundamentals
- **[Systems](CORE_CONCEPTS.md#systems)** - Regular processing systems
- **[Best Practices](BEST_PRACTICES.md)** - Write maintainable ECS code

---

_"Observers turn your ECS from a polling system into a reactive system, making your game respond intelligently to state changes rather than constantly checking for them."_

# Observers

Observers respond to events on specific components of entities. When a watched component fires an event, the system is triggered.

## Overview

1. watch(): Specifies which component to monitor for events.
2. match(): Defines a query (using QueryBuilder) to filter entities with watched components
3. Event Handler Functions: Handles logic after a change is detected.

By combining these methods, you can focus on specific entities and properties to react immediately to changes (e.g., updating UI, syncing states).

## Example Usage

1. Inherit from Observer and override methods:
   - watch(): return MyComponent
    - This is the component we want to watch
   - match(): return q.with_all([MyOtherComponent])
    - Any entity must match this query or none of the events will be fired
   - on_changed(entity, component, property, old_value, new_value):
     - Fired anytime the component being watched is changed on an Entity
   - on_added(entity, component):
     - Fires anytime a component being watched is added to an Entity
   - on_removed(entity, component):
     - Fires when an component being watched is removed from an Entity
2. Add your Observer(s) to the world. Any modifications to the watched component property on an entity that matches the query will call the event handlers

Use observers to decouple logic and ensure your game/app can quickly respond whenever component data changes.

# Actions
> A way to dispatch actions from 'outside' the ECS framework

## Introduction
Actions are a way to dispatch logic from inside or outside the ECS framework. Since Godot is not an ECS specific engine, 
we're essentially slapping on ECS over the top. Thanks to this hybrid approach we can used godot for it's strengths (scene tree,
servers, nodes, editor), and ECS (data oriented design) for it's strength. 

Actions can be one of the tools used to help bridge that gap, or serve as a general purpose abstraction of a "Thing" that happens somewhere. 

Actions extend from the base type Resource. Which gives us the advantage of being able to create components or nodes that have an Action
as an @export variable and now we can pick and choose our action and modify any metadata as needed which is made available in 
the action through the `meta` variable.

Actions consist of two parts:
- A function that runs the logic making up the action. 
- A query that determines if the entities passed in should have the action run on them

This keeps actions reusable and composable because we can combine actions together in different ways with the same entities and have 
actions run on some entities and not others. 

## Types of actions
It often makes sense to break down specific types of actions into their own specific classes (or action types) for ease of use and
to explicitly type the parameters

The following classes extend Action:

### Area Actions
Area Actions get called on Component Areas. When you enter or exit an Area it runs an action on the entity that has entered/exited that area. The action is only performed on the entity if it matches the Query return in the query() method

### Interactions
Interactions get called by the InteractablesSystem and are called when an interactable has a group of interactors interacting with it. 
We call the run_interaction function

### Inventory Actions
Inventory Actions are called by the InventoryUtils.use_inventory item. They run an action based on the item being used and the player using it
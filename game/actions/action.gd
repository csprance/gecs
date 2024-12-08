## Actions are two parts and are similar to systems
## The first part is the query. This query runs on the entities passed into it and then passes the entities that match the query to the execute function
## This way you can create reusable actions that can be used in multiple places and only operate on specific entities.
## actions don't need to operate on any entities and if you pass in an empty array it will just run the execute function with no entities
class_name Action
extends Resource


## Meta Data for the Action
@export var meta = {
    'name': 'Default Action',
    'description': 'This is the default action that is executed when no other action is assigned',
}

## The query that the provided entities must match against to process
## Any entity that matches it will be processed any that don't will be ignored
func query() -> QueryBuilder:
    return ECS.world.query


## Always Override this with your own. This is what the action does or when it's run what does it execute
func _action(entities: Array) -> void:
    Loggie.warn('Default Action executed. You Should Probably Replace this!!')


## Call this if you're running the action from somewhere
func run_action(entities: Array = [], _meta=null) -> void:
    if _meta:
        meta.assign(_meta)
    Loggie.info('Running Action: ', meta)
    _action(query().matches(entities)) 
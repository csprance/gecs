class_name Utils

## Synchronize a Transform component with the position from the entity (node2d)
## This is usually run from _ready to sync node and component transforms together
## This is the opposite of [method Utils.sync_from_transform]
static func sync_transform(entity: Entity):
    var trs: C_Transform = entity.get_component(C_Transform)
    if trs:
        trs.position = entity.position
        trs.rotation = entity.rotation
        trs.scale = entity.scale


## Synchronize a transfrorm from the component to the entity
## This is the opposite of [method Utils.sync_transform]
static func sync_from_transform(entity: Entity):
    var trs: C_Transform = entity.get_component(C_Transform)
    entity.position = trs.position
    entity.rotation = trs.rotation
    entity.scale = trs.scale


## Python like all function. Goes through an array and if any of the values are nothing it's false
## Otherwise it's true if every value is something
static func all(arr: Array) -> bool:
    for element in arr:
        if not element:
            return false
    return true


## An event entity is an entity with the event component and other components attached to it that describe an event[br]
## Systems should clean up the event entity after processing the event
## [param components] - An array of extra components to attach to the event entity
static func create_ecs_event(extra_components = []):
    var entity = Entity.new()
    ECS.world.add_entity(entity)
    entity.add_components([C_Event.new()] + extra_components)


## A common pattern is to add components to a query result. This allows that
static func add_components_to_query_results(query: QueryBuilder, components: Array[Component]):
    var entities = query.execute()
    for entity in entities:
        entity.add_components(components)


## Add components to all the active balls
static func add_components_to_active_balls(components: Array[Component]):
    add_components_to_query_results(
        ECS.world.query.with_all([C_ActiveBall]),
        components
    )


## Add components to all the active paddles
static func add_components_to_active_paddles(components: Array[Component]):
    add_components_to_query_results(
        ECS.world.query.with_all([C_ActivePaddle]),
        components
    )

static func get_active_balls() -> Array:
    return ECS.world.query.with_all([C_ActiveBall]).execute()

static func get_active_paddles() -> Array:
    return ECS.world.query.with_all([C_ActivePaddle]).execute()

class_name StaticQuery
extends Resource

var meta = {}

func query() -> QueryBuilder:
    return ECS.world.query

func matches(entities: Array[Entity]) -> bool:
    return Utils.all(query().matches(entities))
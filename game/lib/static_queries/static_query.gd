class_name StaticQuery
extends Resource

@export var with_all: Array[Component] = []
@export var with_any: Array[Component] = []
@export var with_none: Array[Component] = []

@export var with_relationship: Array[Relationship] = []
@export var without_relationship: Array[Relationship] = []


var query:
    get:
        return QueryBuilder.new(ECS.world).with_all(with_all).with_any(with_any).with_none(with_none).with_relationship(with_relationship).without_relationship(without_relationship)
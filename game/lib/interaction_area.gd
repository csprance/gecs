class_name InteractionArea
extends Area3D

@export var parent: Entity

@export var can_interact_query: Array[StaticQuery]


func _ready():
    # Connect the area_entered signal to the parent entity
    body_shape_entered.connect(_on_area_entered)
    body_shape_exited.connect(_on_area_exited)
    

func _on_area_entered(body_id: int, body: Object, body_shape: int, area_shape: int) -> void:
    if body is Entity:
        var query: QueryBuilder = ECS.world.query
        # Combine all static queries
        for static_query in can_interact_query:
            query.combine(static_query.query())
        # Check if the body matches the query
        if not query.matches([body]).is_empty():
            body.add_relationship(Relationship.new(C_CanInteractWith.new(), parent))

func _on_area_exited(body_id: int, body: Object, body_shape: int, area_shape: int) -> void:
    body.remove_relationship(Relationship.new(C_CanInteractWith.new(), parent))
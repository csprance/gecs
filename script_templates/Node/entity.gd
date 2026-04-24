# meta-description: An Entity represents a "Thing" in your game world. It is a container for components.
@tool
class_name _CLASS_
extends Entity

# Entities are containers + GLUE between the scene tree and the ECS world.
# Rule for what lives here vs. in a C_* component:
#   Glue (here)       : scene-tree child handles (NavigationAgent3D, AnimationPlayer,
#                       CollisionShape3D, camera anchors). Doesn't change at runtime,
#                       no system queries by it, Resource can't serialize it.
#   Component (C_*)   : pure data (numbers, vectors, enums), anything systems filter
#                       on via with_all/with_none, anything that swaps at runtime.
# If removing the field would break no system's QUERY → glue. Otherwise → component.
#
# Example glue field (uncomment if applicable):
# @onready var nav_agent: NavigationAgent3D = get_node_or_null(^"NavigationAgent3D")


# func on_ready() -> void:
# 	# we may want to sync the component transform to the node transform?
# 	pass


# func on_destroy() -> void:
#     pass

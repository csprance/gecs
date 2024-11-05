## Component
##
## A Component serves as a data container within the ECS (Entity Component System) framework.
## It holds specific data related to an entity but does not contain any behavior or logic.
## Components are designed to be lightweight and easily attachable to entities to define their properties.
##
## Example:
##     extends Node2D
##
##     ## Position Component.
##     ##
##     ## Holds the position data for an entity.
##     @export var position: Vector2 = Vector2.ZERO
##
##     ## Velocity Component.
##     ##
##     ## Holds the velocity data for an entity.
##     @export var velocity: Vector2 = Vector2.ZERO
@icon('res://addons/qt_ecs/assets/component.svg')
class_name Component
extends Resource

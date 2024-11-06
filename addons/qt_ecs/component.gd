## A Component serves as a data container within the [_ECS] ([Entity] [Component] [System]) framework.
##
## A [Component] holds specific data related to an [Entity] but does not contain any behavior or logic.[br]
## Components are designed to be lightweight and easily attachable to [Entity]s to define their properties.[br]
##[br]
## [b]Example:[/b]
##[codeblock]
##  ## Velocity Component.
##  ##
##  ## Holds the velocity data for an entity.
##  class_name VelocityComponent
##  extends Node2D
##
##  @export var velocity: Vector2 = Vector2.ZERO
##[/codeblock]    
@icon('res://addons/qt_ecs/assets/component.svg')
class_name Component
extends Resource

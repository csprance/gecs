## WorldManager (Autoload Singleton)
## This sits at the top and allows you access to
## The current world so you always have access to it
extends Node

var current_world: World = null

func set_current_world(world: World):
    current_world = world

func get_current_world() -> World:
    return current_world

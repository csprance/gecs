## WorldManager (Autoload Singleton)
## This sits at the top and allows you access to
## The current world so you always have access to it
extends Node

## The Current active World Instance
var world: World:
	get:
		return world
	set(value):
		world = value

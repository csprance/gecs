@tool
class_name Locator3D
extends Node3D

## Should we always show the locator in the game?
@export var draw_in_game: = false

func _process(_delta: float) -> void:
    if not visible:
        return
    if draw_in_game or Engine.is_editor_hint() or visible:
        pass
        # DebugDraw3D.draw_gizmo(global_transform, DebugDraw3D.empty_color, true)

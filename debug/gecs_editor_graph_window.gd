@tool
## One floating graph window of the GECS debugger tab: a [GECSEditorGraphPanel]
## with its own watch set, depth and "Show live" toggle.
##
## The tab opens one per "Open graph" (any number can be open at once) and
## routes [code]gecs:graph_state[/code] payloads to the window whose
## [member graph_id] matches. Closing the window drops its watch in the game.
class_name GECSEditorGraphWindow
extends Window

const DEFAULT_SIZE := Vector2i(960, 640)
const MIN_SIZE := Vector2i(480, 320)
const TITLE_NAMES := 3

## Id shared with the game-side stepper (GECSStepper.graphs key).
var graph_id := 0
var panel: GECSEditorGraphPanel


func _init(id: int = 0) -> void:
	graph_id = id
	title = "GECS Graph"
	size = DEFAULT_SIZE
	min_size = MIN_SIZE
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	wrap_controls = false
	panel = GECSEditorGraphPanel.new()
	panel.graph_id = id
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)


## Apply a payload for this graph and name the window after its watched entities.
func apply_graph(step_id: int, payload: Dictionary) -> void:
	panel.apply_graph(step_id, payload)
	title = title_for(payload)


static func title_for(payload: Dictionary) -> String:
	var names: Array = []
	for node in payload.get("nodes", []):
		if node.get("kind", "") == "entity" and bool(node.get("watched", false)):
			names.append(str(node.get("name", "")))
	if names.is_empty():
		return "GECS Graph"
	var text := "GECS Graph: " + ", ".join(names.slice(0, TITLE_NAMES))
	if names.size() > TITLE_NAMES:
		text += " +%d" % (names.size() - TITLE_NAMES)
	return text

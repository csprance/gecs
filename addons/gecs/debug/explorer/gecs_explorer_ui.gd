@tool
extends RefCounted
## Explorer-only visual language. Never mutates the editor's shared theme.
const BACKGROUND := Color("141b24")
const SURFACE := Color("1c2632")
const INSET := Color("17202b")
const BORDER := Color("304153")
const TEXT := Color("e8eff6")
const MUTED := Color("95a8bd")
const ACCENT := Color("74dfc5")
const WARNING := Color("f2c57b")
const ERROR := Color("ff9b9b")

static func scale() -> float:
	return EditorInterface.get_editor_scale() if Engine.is_editor_hint() else float(ProjectSettings.get_setting("gecs/explorer_preview_scale", 1.0))

static func px(value: float) -> int:
	return roundi(value * scale())

static func style(color: Color, padding := 12, radius := 8, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(px(radius))
	box.set_content_margin_all(px(padding))
	if border.a > 0:
		box.border_color = border
		box.set_border_width_all(px(1))
	return box

static func action_style(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := style(color, 4, 4, border)
	box.content_margin_left = px(8)
	box.content_margin_right = px(8)
	return box

static func make_theme() -> Theme:
	var theme := Theme.new()
	if Engine.is_editor_hint():
		var editor_theme := EditorInterface.get_editor_theme()
		if editor_theme != null: theme.merge_with(editor_theme)
	theme.default_font_size = px(14)
	for type in ["Label", "Button", "MenuButton", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "Tree", "ItemList", "PopupMenu", "TabBar", "TabContainer", "RichTextLabel"]:
		theme.set_font_size("font_size", type, px(14))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_disabled_color", type, Color("617387"))
	for type in ["HBoxContainer", "VBoxContainer", "HFlowContainer"]:
		theme.set_constant("separation", type, px(6))
		theme.set_constant("h_separation", type, px(6))
		theme.set_constant("v_separation", type, px(6))
	for type in ["SplitContainer", "HSplitContainer", "VSplitContainer"]:
		theme.set_constant("separation", type, px(12))
		theme.set_constant("autohide", type, 0)
	for type in ["Button", "MenuButton", "OptionButton"]:
		theme.set_stylebox("normal", type, action_style(Color("222e3a")))
		theme.set_stylebox("hover", type, action_style(Color("33485a")))
		theme.set_stylebox("pressed", type, action_style(Color("31574f"), ACCENT.darkened(0.45)))
		theme.set_stylebox("disabled", type, action_style(Color.TRANSPARENT))
		theme.set_stylebox("focus", type, style(Color.TRANSPARENT, 0, 5, ACCENT))
	for type in ["Button", "MenuButton", "OptionButton", "CheckBox", "CheckButton"]: theme.set_font_size("font_size", type, px(13))
	theme.set_type_variation("ExplorerQuiet", "Button")
	theme.set_stylebox("normal", "ExplorerQuiet", action_style(Color.TRANSPARENT))
	theme.set_type_variation("ExplorerPrimary", "Button")
	theme.set_stylebox("normal", "ExplorerPrimary", action_style(ACCENT))
	theme.set_stylebox("hover", "ExplorerPrimary", action_style(ACCENT.lightened(0.12)))
	theme.set_stylebox("pressed", "ExplorerPrimary", action_style(ACCENT.darkened(0.15)))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: theme.set_color(state, "ExplorerPrimary", BACKGROUND)
	for type in ["LineEdit", "TextEdit", "CodeEdit"]:
		theme.set_stylebox("normal", type, style(INSET, 6, 4, BORDER))
		theme.set_stylebox("focus", type, style(INSET, 6, 4, ACCENT.darkened(0.3)))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_placeholder_color", type, MUTED)
	for type in ["Tree", "ItemList"]:
		theme.set_stylebox("panel", type, style(INSET, 6, 6))
		theme.set_stylebox("selected", type, style(Color("284c48"), 4, 4))
		theme.set_stylebox("selected_focus", type, style(Color("2c5a52"), 4, 4))
		theme.set_stylebox("cursor", type, style(Color.TRANSPARENT, 0, 4, ACCENT.darkened(0.35)))
		theme.set_constant("v_separation", type, px(5))
		theme.set_constant("h_separation", type, px(6))
	theme.set_stylebox("title_button_normal", "Tree", style(SURFACE, 5, 0))
	theme.set_stylebox("title_button_hover", "Tree", style(Color("293b4c"), 5, 0))
	theme.set_color("title_button_color", "Tree", MUTED)
	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, style(Color("2a403f"), 7, 5))
		theme.set_stylebox("tab_unselected", type, style(Color.TRANSPARENT, 7, 5))
		theme.set_stylebox("tab_hovered", type, style(SURFACE, 7, 5))
		theme.set_color("font_selected_color", type, ACCENT)
		theme.set_color("font_unselected_color", type, MUTED)
	theme.set_stylebox("panel", "TabContainer", style(Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("panel", "PopupPanel", style(SURFACE, 16, 8, BORDER))
	theme.set_stylebox("panel", "PopupMenu", style(SURFACE, 8, 6, BORDER))
	return theme

static func label(parent: Node, text: String, size := 14, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", px(size))
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

static func hint(parent: Node, text: String) -> Label:
	var node := label(parent, text, 12, MUTED)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func heading(parent: Node, title: String, help := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", px(3))
	row.add_child(text)
	label(text, title, 16)
	if help != "": hint(text, help)
	return row

static func card(parent: Node, title := "", help := "", expand := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(SURFACE, 10, 6, BORDER))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand: panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	if title != "": heading(body, title, help)
	return body

static func button(parent: Node, text: String, callback: Callable, primary := false, help := "") -> Button:
	var node := Button.new()
	node.text = text
	node.tooltip_text = help
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.theme_type_variation = "ExplorerPrimary" if primary else "ExplorerQuiet"
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

static func menu(parent: Node, title: String, labels: Array, actions: Array) -> MenuButton:
	var node := MenuButton.new()
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.text = title
	parent.add_child(node)
	for text in labels: node.get_popup().add_item(text)
	node.get_popup().id_pressed.connect(func(index: int): actions[index].call())
	return node

static func field(parent: Node, title: String, control: Control, help := "") -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", px(5))
	parent.add_child(column)
	label(column, title, 12, MUTED)
	column.add_child(control)
	if help != "": hint(column, help)

## Select the row under the pointer before exposing its contextual actions.
static func context_menu(tree: Tree, actions: Callable) -> void:
	tree.allow_rmb_select = true
	var popup := PopupMenu.new()
	tree.add_child(popup)
	var callbacks: Array = []
	popup.id_pressed.connect(func(index: int):
		if index >= 0 and index < callbacks.size(): callbacks[index].call()
	)
	tree.item_mouse_selected.connect(func(position: Vector2, button: int):
		if button != MOUSE_BUTTON_RIGHT: return
		popup.clear()
		callbacks.clear()
		var items: Dictionary = actions.call()
		for title in items:
			popup.add_item(title)
			callbacks.append(items[title])
		if callbacks.is_empty(): return
		popup.position = Vector2i(tree.get_screen_position() + position)
		popup.popup()
	)

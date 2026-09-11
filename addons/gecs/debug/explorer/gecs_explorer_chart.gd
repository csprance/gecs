@tool
class_name GECSExplorerChart
extends Control
## Bounded sampled property series. Samples are observations, not causal traces.
const UI = preload("res://addons/gecs/debug/explorer/gecs_explorer_ui.gd")
var values: Array = []
var state_transitions := false
var duration := 0.0
var caption := "Property samples"
var sample_times: Array = []
var line_color := UI.ACCENT
var axis_width := 32.0
var axis_decimals := 2
var constant_padding := 1.0
var minimum_axis_value: Variant = null
var right_label := "now"
var empty_text := "Waiting for samples · step or resume ECS."
var show_hover := false
var _hover_index := -1


func _ready() -> void:
	custom_minimum_size = Vector2(UI.px(210), UI.px(165))
	mouse_exited.connect(func():
		_hover_index = -1
		queue_redraw()
	)

func set_samples(samples: Array, component: int, property: String) -> void:
	values.clear()
	sample_times.clear()
	for sample in samples:
		sample_times.append(sample.time)
		var point: Variant = null
		for comp in sample.data.get("components", []):
			if comp.iid != component: continue
			for field in comp.fields:
				if field.name == property: point = GECSExplorerCodec.decode(field.value)
		values.append(point)
	duration = (float(samples[-1].time) - float(samples[0].time)) / 1000.0 if samples.size() > 1 else 0.0
	caption = property.capitalize()
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := UI.px(12)
	draw_string(font, Vector2(0, UI.px(16)), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x, font_size, UI.TEXT)
	var channels: Array = [[], [], [], []]
	for value in values:
		var components: Array = []
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT: components = [float(value)]
			TYPE_VECTOR2, TYPE_VECTOR2I: components = [float(value.x), float(value.y)]
			TYPE_VECTOR3, TYPE_VECTOR3I: components = [float(value.x), float(value.y), float(value.z)]
			TYPE_VECTOR4, TYPE_VECTOR4I: components = [float(value.x), float(value.y), float(value.z), float(value.w)]
		for i in 4: channels[i].append(components[i] if i < components.size() else null)
	var low := INF
	var high := -INF
	for channel in channels:
		for value in channel:
			if value != null and is_finite(value):
				low = minf(low, value)
				high = maxf(high, value)
	if low == INF:
		draw_string(font, Vector2(0, UI.px(50)), empty_text, HORIZONTAL_ALIGNMENT_LEFT, size.x, font_size, UI.MUTED)
		return
	if is_equal_approx(low, high):
		var padding := maxf(absf(low) * 0.05, constant_padding)
		low -= padding
		high += padding
	if minimum_axis_value != null: low = maxf(low, float(minimum_axis_value))
	var span := maxf(high - low, 0.001)
	var colors := [line_color, Color("97baff"), UI.WARNING, Color("d5a5ee")]
	var plot := Rect2(Vector2(UI.px(axis_width), UI.px(32)), Vector2(maxf(10, size.x - UI.px(axis_width + 2)), maxf(10, size.y - UI.px(75))))
	for i in 3:
		var y := plot.position.y + plot.size.y * float(i) / 2
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), UI.BORDER, 1.0)
		var tick := high - (high - low) * float(i) / 2
		draw_string(font, Vector2(0, y + UI.px(4)), String.num(tick, axis_decimals), HORIZONTAL_ALIGNMENT_LEFT, UI.px(axis_width - 2), UI.px(10), UI.MUTED)
	for c in 4:
		var previous: Variant = null
		for i in channels[c].size():
			var value: Variant = channels[c][i]
			if value == null or not is_finite(value):
				previous = null
				continue
			var point := Vector2(plot.position.x + _sample_fraction(i) * plot.size.x, plot.end.y - (value - low) / span * plot.size.y)
			if previous != null:
				if state_transitions:
					var corner := Vector2(point.x, previous.y)
					draw_line(previous, corner, colors[c], 2.0)
					draw_line(corner, point, colors[c], 2.0)
				else: draw_line(previous, point, colors[c], 2.0, true)
			if values.size() == 1 or (show_hover and i == _hover_index): draw_circle(point, UI.px(3), colors[c])
			previous = point
	if show_hover and _hover_index >= 0 and _hover_index < values.size():
		var x := plot.position.x + _sample_fraction(_hover_index) * plot.size.x
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), UI.MUTED, 1.0)
	draw_string(font, Vector2(plot.position.x, size.y - UI.px(16)), "−%.1fs" % duration, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(10), UI.MUTED)
	draw_string(font, Vector2(size.x - UI.px(40), size.y - UI.px(16)), right_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(10), UI.MUTED)
	if not values.is_empty() and typeof(values[-1]) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I]:
		for c in 4:
			if channels[c].any(func(value): return value != null): draw_string(font, Vector2(UI.px(40 + c * 30), size.y), ["x", "y", "z", "w"][c], HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(10), colors[c])

func _sample_fraction(index: int) -> float:
	if sample_times.size() == values.size() and sample_times.size() > 1:
		var span := float(sample_times.back()) - float(sample_times.front())
		if span > 0: return (float(sample_times[index]) - float(sample_times.front())) / span
	return float(index) / maxi(1, values.size() - 1)

func _index_at(position: Vector2) -> int:
	if values.is_empty(): return -1
	var fraction := clampf((position.x - UI.px(axis_width)) / maxf(1, size.x - UI.px(axis_width + 2)), 0, 1)
	var nearest := 0
	var distance := INF
	for i in values.size():
		var next := absf(_sample_fraction(i) - fraction)
		if next < distance:
			distance = next
			nearest = i
	return nearest

func _gui_input(event: InputEvent) -> void:
	if show_hover and event is InputEventMouseMotion:
		_hover_index = _index_at(event.position)
		queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	if not show_hover: return tooltip_text
	var index := _index_at(at_position)
	if index < 0: return "No samples yet"
	return "%s · %.2fs before latest sample" % [str(values[index]) if values[index] != null else "Not measured", (1.0 - _sample_fraction(index)) * duration]

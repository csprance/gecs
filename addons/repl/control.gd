@tool
extends Control

@onready var command_input := %InputLineEdit
@onready var command_output := %OutputRichLabel
@onready var path_dialog := $PathFileDialog

@onready var _env := ReplEnv.new()
@onready var _parser := ReplParser.new()
@onready var _history:Array[String] = []
@onready var _index:int = -1


func _ready():
	command_output.add_text('>>> ')
	command_input.grab_focus()


func _on_tree_exited():
	_history = []
	_index = -1


func evaluate_from_input():
	command_output.add_text(command_input.text + '\n')
	if command_input.text != '':
		var result = _parser.evaluate(command_input.text, _env)
		command_output.add_text(str(result[1]) + '\n')
		# if no history, add the line
		if len(_history) == 0:
			_history.append(command_input.text)
		# if the line doesn't match the last record, add it
		elif _history[len(_history) - 1] != command_input.text:
			_history.append(command_input.text)
		_index = -1
		command_input.clear()
	command_output.add_text('>>> ')
	command_output.scroll_to_line(command_output.get_line_count())


func shift_input_stack(input:LineEdit, stack:Array[String], direction:int) -> void:
	# index: the position from the back of stack
	# direction: +/- 1 to go up/down the stack
	
	# if we have text and it isn't on the stack, and we're at the bottom, add it
	if input.text.length() > 0 and _index < 0:
		stack.insert(_index, input.text)
		_index += 1
	
	_index += direction
	
	if _index < 0:
		input.text = ''
	elif _index > len(stack) - 1:
		# already at the top
		pass
	else:
		var length = len(stack)
		var read_index = length - _index - 1
		input.text = stack[read_index]
	
	_index = clamp(_index, -1, len(stack) - 1)
	

func _on_input_line_edit_gui_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			evaluate_from_input()
		elif event.pressed and event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
		elif event.pressed and event.keycode == KEY_UP:
			shift_input_stack(command_input, _history, +1)
		elif event.pressed and event.keycode == KEY_DOWN:
			shift_input_stack(command_input, _history, -1)


func _on_eval_button_pressed():
	evaluate_from_input()


func _on_path_button_pressed():
	path_dialog.popup_centered(Vector2i(400, 600))


func _on_path_file_dialog_file_selected(path):
	paste_path(path)


func _on_path_file_dialog_dir_selected(dir):
	paste_path(dir)


func paste_path(path):
	command_input.insert_text_at_caret(path)
	command_input.grab_focus()

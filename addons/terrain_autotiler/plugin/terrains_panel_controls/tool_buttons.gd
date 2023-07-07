@tool
extends Control

# TODO: If/when this PR is merged, can set editor shortcuts dynamically
# rather than just setting them to defaults: https://github.com/godotengine/godot/pull/58585

const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

@onready var draw_button: Button = %DrawButton
@onready var line_button: Button = %LineButton
@onready var rect_button: Button = %RectButton
@onready var bucket_button: Button = %BucketButton
@onready var picker_button: Button = %PickerButton
@onready var lock_button: Button = %LockButton



@onready var _paint_tool_buttons := {
	Context.PaintTool.DRAW : draw_button,
	Context.PaintTool.LINE: line_button,
	Context.PaintTool.RECT: rect_button,
	Context.PaintTool.BUCKET: bucket_button,
}

@onready var _input_mode_buttons := {
	Context.InputMode.PAINT: [
		draw_button,
		line_button,
		rect_button,
		bucket_button,
	],
	Context.InputMode.PICKER: [
		picker_button,
	],
	Context.InputMode.LOCK: [
		lock_button,
	],
}


var context : Context

func setup(p_context : Context) -> void:
	context = p_context

	if not is_inside_tree():
		await tree_entered

	for paint_tool in _paint_tool_buttons:
		var button : Button = _paint_tool_buttons[paint_tool]
		button.pressed.connect(
			_on_paint_tool_button_pressed.bind(paint_tool)
		)

	# start in paint mode as default, using last used tool
	context.set_current_input_mode(Context.InputMode.PAINT)
	_select_last_paint_tool()

	context.current_input_mode_changed.connect(_on_current_input_mode_changed)


func _select_last_paint_tool() -> void:
	var last_paint_tool : Context.PaintTool = context.settings.get_value(
			Context.Settings.LAST_PAINT_TOOL
		)
	var last_paint_button : Button = _paint_tool_buttons[last_paint_tool]
	last_paint_button.set_pressed_no_signal(true)
	context.set_current_paint_tool(last_paint_tool)


func _on_current_input_mode_changed(p_input_mode : Context.InputMode) -> void:
	for input_mode in _input_mode_buttons:
		if input_mode == p_input_mode:
			continue
		for button in _input_mode_buttons[input_mode]:
			button.set_pressed_no_signal(false)

	if p_input_mode == Context.InputMode.PAINT:
		_select_last_paint_tool()



func _on_paint_tool_button_pressed(p_paint_tool : Context.PaintTool) -> void:
	_paint_tool_buttons[p_paint_tool].set_pressed_no_signal(true)

	context.set_current_paint_tool(p_paint_tool)
	context.settings.set_value(
		Context.Settings.LAST_PAINT_TOOL,
		p_paint_tool,
	)
	# change input mode after settings, so that will not select previous
	# paint tool
	context.set_current_input_mode(Context.InputMode.PAINT)




func _on_picker_button_toggled(button_pressed: bool) -> void:
	if button_pressed:
		context.set_current_input_mode(Context.InputMode.PICKER)
	else:
		context.set_current_input_mode(Context.InputMode.PAINT)


func _on_lock_button_toggled(button_pressed: bool) -> void:
	if button_pressed:
		context.set_current_input_mode(Context.InputMode.LOCK)
	else:
		context.set_current_input_mode(Context.InputMode.PAINT)

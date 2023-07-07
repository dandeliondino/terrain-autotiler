@tool
extends Control

const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

var context : Context


@onready var autotiler_button: Button = %AutotilerButton

@onready var debug_separator: VSeparator = %DebugSeparator

@onready var debug_button: Button = %DebugButton
@onready var error_button: Button = %ErrorButton

var status_error_icon : Texture2D
var status_warning_icon : Texture2D
var status_ok_icon : Texture2D
var status_none_icon : Texture2D

#var error_icon_width : int

var panel : StyleBoxFlat
var panel_pressed : StyleBoxFlat

func setup(p_context : Context) -> void:
	context = p_context

	var replace_gui : bool = context.settings.get_value(Context.Settings.REPLACE_TERRAIN_GUI)
	autotiler_button.set_pressed_no_signal(replace_gui)
	autotiler_button.toggled.connect(_on_replace_gui_check_button_toggled)


	var show_debug : bool = context.settings.get_value(Context.Settings.SHOW_DEBUG_PANEL)
	debug_button.set_pressed_no_signal(show_debug)
	context.toggle_debug_panel_requested.emit(show_debug)

	status_error_icon = get_theme_icon("StatusError", "EditorIcons")
	status_warning_icon = get_theme_icon("StatusWarning", "EditorIcons")
	status_ok_icon = get_theme_icon("StatusSuccess", "EditorIcons")
#	error_icon_width = status_error_icon.get_size().x
#	error_button.custom_minimum_size = Vector2i(error_icon_width, 0)
	error_button.icon = null


	context.current_update_result_changed.connect(_on_current_update_result_changed)

	panel_pressed = get_theme_stylebox("pressed", "EditorLogFilterButton").duplicate()
	panel_pressed.content_margin_top = 5
	panel_pressed.content_margin_bottom = 5

	panel = panel_pressed.duplicate()
	panel.border_color = panel.bg_color

	_update_pressed_state()



func _update_pressed_state() -> void:
	var pressed := autotiler_button.button_pressed
	if pressed:
		set("theme_override_styles/panel", panel_pressed)
		debug_button.show()
		debug_separator.show()
	else:
		set("theme_override_styles/panel", panel)
		debug_button.hide()
		debug_separator.hide()
		error_button.hide()




func _update_error_button(result : UpdateResult) -> void:
	if not result:
		error_button.hide()
		return
	error_button.show()

	if not result.cell_errors.is_empty():
		error_button.icon = status_error_icon
		if result.cell_warnings.is_empty():
			error_button.tooltip_text = "%s errors. Open debug panel for details." % result.cell_errors.size()
		else:
			error_button.tooltip_text = "%s errors and %s warnings. Open debug panel for details." % [result.cell_errors.size(), result.cell_warnings.size()]
	elif not result.cell_warnings.is_empty():
		error_button.icon = status_warning_icon
		error_button.tooltip_text = "%s warnings. Open debug panel for details." % result.cell_warnings.size()
	else:
		error_button.icon = status_ok_icon
		error_button.tooltip_text = "No errors or warnings"



func _on_current_update_result_changed(p_update_result : UpdateResult) -> void:
	_update_error_button(p_update_result)



func _on_replace_gui_check_button_toggled(p_button_pressed : bool) -> void:
	context.settings.set_value(Context.Settings.REPLACE_TERRAIN_GUI, p_button_pressed)
	_update_pressed_state()


func _on_update_button_pressed() -> void:
	context.actions.update_layer()


func _on_debug_button_toggled(button_pressed: bool) -> void:
	context.toggle_debug_panel_requested.emit(button_pressed)
	context.settings.set_value(Context.Settings.SHOW_DEBUG_PANEL, button_pressed)


@tool
extends Control

const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

@onready var connect_button: Button = %ConnectButton
@onready var path_button: Button = %PathButton


var context : Context

func setup(p_context : Context) -> void:
	context = p_context

	var button_group := ButtonGroup.new()
	connect_button.button_group = button_group
	path_button.button_group = button_group

	var paint_mode : Context.PaintMode = context.settings.get_value(
		Context.Settings.PAINT_MODE
	)
	context.set_current_paint_mode(paint_mode)
	connect_button.set_pressed(
		paint_mode == Context.PaintMode.CONNECT
	)
	path_button.set_pressed_no_signal(
		paint_mode == Context.PaintMode.PATH
	)


func _on_path_button_pressed() -> void:
	context.set_current_paint_mode(Context.PaintMode.PATH)
	context.settings.set_value(Context.Settings.PAINT_MODE, Context.PaintMode.PATH)

func _on_connect_button_pressed() -> void:
	context.set_current_paint_mode(Context.PaintMode.CONNECT)
	context.settings.set_value(Context.Settings.PAINT_MODE, Context.PaintMode.CONNECT)

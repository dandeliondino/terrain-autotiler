@tool
extends Control

const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

var context : Context

@onready var coords_label: Label = %CoordsLabel
@onready var tool_label: Label = %ToolLabel


func setup(p_context : Context) -> void:
	context = p_context
	context.current_cell_changed.connect(_on_current_cell_changed)
	context.current_input_mode_changed.connect(_on_current_input_mode_changed)
	context.current_terrain_changed.connect(_on_current_terrain_changed)
	context.overlay_update_requested.connect(_on_overlay_update_requested)

	tool_label.text = ""
	coords_label.text = ""

	set(
		"theme_override_constants/margin_left",
		context.editor_interface.get_editor_scale() * 16,
	)
	set(
		"theme_override_constants/margin_bottom",
		context.editor_interface.get_editor_scale() * 8,
	)

	coords_label.set(
		"theme_override_colors/font_color",
		get_theme_color("highlighted_font_color", "Editor")
	)
	tool_label.set(
		"theme_override_colors/font_color",
		get_theme_color("highlighted_font_color", "Editor")
	)

	_update_tool_text(context.get_current_input_mode())


func _update_tool_text(p_input_mode : Context.InputMode) -> void:
	if not context.terrains_panel.is_visible_in_tree():
		hide()
		return
	if not context.has_current_terrain_set():
		hide()
		return

	show()

	var tool_text := ""

	match p_input_mode:
		Context.InputMode.PAINT:
			var terrain := context.get_current_terrain()
			if terrain == Autotiler.EMPTY_TERRAIN:
				tool_text = "Erase\nLeft-click to erase"
			elif context.get_current_tile_map() && context.get_current_tile_map().tile_set:
				var terrain_set := context.get_current_terrain_set()
				var terrains_data := context.get_current_terrains_data()
				if not terrains_data:
					return
				var terrain_name : String = terrains_data.terrain_names[terrain]
				tool_text = "Paint %s\nLeft-click to paint\nRight-click to erase" % terrain_name
		Context.InputMode.PICKER:
			tool_text = "Picker\nLeft-click to pick a tile's terrain\nRight-click to exit"
		Context.InputMode.LOCK:
			tool_text = "Lock\nLeft-click to lock\nRight-click to unlock"
		Context.InputMode.DEBUG:
			tool_text = "Debug\nLeft-click to inspect cell\nRight-click to exit"

	tool_label.text = tool_text
	tool_label.visible = true



func _on_current_input_mode_changed(p_input_mode : Context.InputMode) -> void:
	_update_tool_text(p_input_mode)



func _on_current_cell_changed(p_coords : Vector2i) -> void:
	if p_coords == Context.INVALID_CELL:
		coords_label.hide()
		return

	coords_label.text = str(p_coords)
	coords_label.show()


func _on_current_terrain_changed(_p_terrain : int) -> void:
	_update_tool_text(context.get_current_input_mode())


func _on_overlay_update_requested() -> void:
	_update_tool_text(context.get_current_input_mode())



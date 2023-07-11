@tool
extends EditorPlugin



const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")
const ViewportDraw := preload("res://addons/terrain_autotiler/plugin/viewport_draw.gd")
const ViewportInput := preload("res://addons/terrain_autotiler/plugin/viewport_input.gd")
const TileSetInspectorPlugin := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/tile_set_inspector_plugin.gd")


var context := Context.new()
var viewport_draw := ViewportDraw.new()
var viewport_input := ViewportInput.new()
var tile_set_inspector_plugin := TileSetInspectorPlugin.new()



# -----------------------------------
# VIRTUAL FUNCTIONS
# -----------------------------------

func _enter_tree() -> void:
#	print("\n\n----------\n_enter_tree()")
	context.editor_interface = get_editor_interface()

	# update overlays to remove drawing of current cell
	# when mouse leaves main screen
	context.overlay_update_requested.connect(update_overlays)

	context.actions.setup(context, get_undo_redo())

	populate_editor_references()

	add_terrains_controls()

	context.settings.setting_changed.connect(_on_setting_changed)
	load_settings()

	add_inspector_plugin(tile_set_inspector_plugin)

#	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)

	reselect_current_tilemap.call_deferred()




#func _on_scene_changed(_arg) -> void:
#	prints("_on_scene_changed", _arg)
#	context.set_current_tile_map(null)


func _on_scene_closed(_arg) -> void:
#	print("_on_scene_closed")
	context.set_current_tile_map(null)


func _exit_tree() -> void:
	replace_terrain_gui = false
	tile_set_inspector_plugin.clean_up()
	remove_inspector_plugin(tile_set_inspector_plugin)

	restore_editor_terrain_gui()
	remove_terrains_controls()


func _get_window_layout(configuration: ConfigFile) -> void:
	context.settings.save_config(configuration)



func _handles(object: Object) -> bool:
	if not object is TileMap and not object is TileSet:
#		print("_handles(): not object is TileMap - %s" % object)
		context.set_current_tile_map(null)
		return false

#	print("_handles(): object is TileMap or TileSet - %s" % object)
	if object is TileMap:
		context.set_current_tile_map(object)
	elif object is TileSet:
		context.set_current_tile_map(get_first_connected_object_by_class(ed_tile_map_editor, "TileMap"))

	show_bottom_tile_map_editor.call_deferred()
	return true


# sometimes when you select a tilemap, the editor opens the tileset editor instead
# this waits until the editor is done opening the tileset, and re-opens the tilemap
# sometimes there's a quick flash, but overall far less annoying
func show_bottom_tile_map_editor() -> void:
	await get_tree().create_timer(0.1).timeout
	make_bottom_panel_item_visible(ed_tile_map_editor)



func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not replace_terrain_gui:
		return false
	if not terrains_panel.is_visible_in_tree():
		return false
	if not context.has_current_terrain_set():
		return false

	if event is InputEventShortcut:
#		prints("shortcut", event)
		return false
	if event is InputEventKey:
#		prints("key", event)
		return false

	viewport_input._forward_canvas_gui_input(event)
	update_overlays()
	return true



func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if not replace_terrain_gui:
		return
	if not terrains_panel.is_visible_in_tree():
		return

	var tile_map := context.get_current_tile_map()
	if not tile_map or not tile_map.tile_set:
		return
	if not context.has_current_terrain_set():
		return

	viewport_draw._forward_canvas_draw_over_viewport(viewport_control)



# -----------------------------------
# SETTINGS
# -----------------------------------

func load_settings() -> void:
	replace_terrain_gui = context.settings.get_value(Context.Settings.REPLACE_TERRAIN_GUI)
#	print("load_settings(): replace_terrain_gui=%s" % replace_terrain_gui)



func _on_setting_changed(p_setting : StringName, p_value : Variant) -> void:
	if p_setting == Context.Settings.REPLACE_TERRAIN_GUI:
		replace_terrain_gui = p_value

	queue_save_layout()



# -----------------------------------
# EDITOR CONTROLS
# -----------------------------------
const INVALID_TAB_IDX := -1

var ed_tile_map_editor : Node
var ed_tool_buttons_container : Control
var ed_terrains_panel : Control
var ed_layer_option_button : OptionButton
var ed_canvas_item_editor_viewport : Node


func populate_editor_references() -> void:
	ed_tile_map_editor = get_editor_interface().get_base_control().find_children("*", "TileMapEditor", true, false)[0]
	var hflow_container : Node = ed_tile_map_editor.find_children("*", "HFlowContainer", false, false)[0]

	ed_tool_buttons_container = hflow_container.find_children("*", "HBoxContainer", false, false)[1]
	ed_terrains_panel = ed_tile_map_editor.find_child("Terrains", false, false)
	ed_terrains_panel.visibility_changed.connect(_on_ed_terrains_panel_visibility_changed)

	ed_layer_option_button = hflow_container.find_children("*", "OptionButton", false, false)[0]
	context.set_layer_option_button(ed_layer_option_button)

	context.ed_tab_bar = hflow_container.find_children("*", "TabBar", false, false)[0]
	context.ed_terrain_tab_idx = context.ed_tab_bar.tab_count - 1
	context.ed_tab_bar.tab_changed.connect(_on_ed_tab_changed)

	context.ed_no_tileset_label = ed_tile_map_editor.find_children("*", "Label", false, false)[0]

	ed_canvas_item_editor_viewport = get_editor_interface().get_base_control().find_children("*", "CanvasItemEditorViewport", true, false)[0]


func _on_ed_tab_changed(_tab : int) -> void:
#	print("\n\n_on_ed_tab_changed()")
	update_terrain_tab()


func _on_ed_terrains_panel_visibility_changed() -> void:
#	print("_on_ed_terrains_panel_visibility_changed()")
	if not replace_terrain_gui:
		return
	if not ed_terrains_panel.is_visible_in_tree():
		return
	ed_terrains_panel.visible = false
#	print("_on_ed_terrains_panel_visibility_changed() -> update_panel_display()")
	terrains_panel.update_panel_display()


# re-open current tile map to trigger _handles()
# and receive _forward_canvas_gui_input()
func reselect_current_tilemap() -> void:
#	print("reselect_current_tilemap()")
	var current_tile_map := get_first_connected_object_by_class(ed_tile_map_editor, "TileMap")
	context.set_current_tile_map(current_tile_map)
	if not current_tile_map:
		return

	if not get_editor_interface().get_selection().get_selected_nodes().has(current_tile_map):
		return

	context.editor_interface.edit_node(current_tile_map)


func get_first_connected_object_by_class(p_object : Object, p_class_name : String) -> Object:
	var objects := []
	for connection in p_object.get_incoming_connections():
		var connected_object = connection["signal"].get_object()
		if connected_object.is_class(p_class_name):
			objects.append(connected_object)
	if !objects.size():
		return null
	return objects[0]



# --------------------------------
# 	TERRAIN TAB UI
# --------------------------------
const AutotilerButtons := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/autotiler_buttons.gd")
const AutotilerButtonsControl := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/autotiler_buttons.tscn")
const ToolButtons := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/tool_buttons.gd")
const ToolButtonsControl := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/tool_buttons.tscn")
const TerrainsPanel := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/terrains_panel.gd")
const TerrainsPanelControl := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/terrains_panel.tscn")
const InfoLabel := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/info_label.gd")
const InfoLabelControl := preload("res://addons/terrain_autotiler/plugin/terrains_panel_controls/info_label.tscn")

var autotiler_buttons : AutotilerButtons
var tool_buttons : ToolButtons
var terrains_panel : TerrainsPanel
var info_label : InfoLabel

var replace_terrain_gui := false :
	set(value):
		replace_terrain_gui = value
		if value:
			replace_editor_terrain_gui()
		else:
			restore_editor_terrain_gui()


func add_terrains_controls() -> void:
	autotiler_buttons = AutotilerButtonsControl.instantiate()
	ed_layer_option_button.get_parent().get_child(ed_layer_option_button.get_index()-1).add_sibling(autotiler_buttons)
	autotiler_buttons.setup(context)

	tool_buttons = ToolButtonsControl.instantiate()
	ed_tool_buttons_container.add_sibling(tool_buttons)
	tool_buttons.setup(context)

	terrains_panel = TerrainsPanelControl.instantiate()
	ed_tile_map_editor.add_child(terrains_panel)
	context.terrains_panel = terrains_panel
	terrains_panel.setup(context)
	terrains_panel.visible = false
	terrains_panel.visibility_changed.connect(context.emit_signal.bind("overlay_update_requested"))
#	terrains_panel.visibility_changed.connect(update_terrain_tab)

	terrains_panel.add_child(viewport_input)
	viewport_input.setup(context, ed_canvas_item_editor_viewport)

	terrains_panel.add_child(viewport_draw)
	viewport_draw.setup(context)

	info_label = InfoLabelControl.instantiate()
	ed_canvas_item_editor_viewport.get_parent().add_child(info_label)
	info_label.setup(context)


func remove_terrains_controls() -> void:
	autotiler_buttons.queue_free()
	tool_buttons.queue_free()
	terrains_panel.queue_free()
	info_label.queue_free()


func update_terrain_tab() -> void:
#	print("update_terrain_tab")
	if context.is_terrain_tab_active():
#		print("update_terrain_tab: active")
		autotiler_buttons.visible = true
		if replace_terrain_gui:
			tool_buttons.visible = true
			info_label.visible = true
			ed_terrains_panel.visible = false
			toggle_editor_buttons(false)
#			terrains_panel.update_panel_display()
	else:
#		print("update_terrain_tab: inactive")
		autotiler_buttons.visible = false
		tool_buttons.visible = false
		terrains_panel.visible = false
		info_label.visible = false
		toggle_editor_buttons(true)


func replace_editor_terrain_gui() -> void:
	ed_terrains_panel.visible = false
	update_terrain_tab()
#	print("replace_editor_terrain_gui() -> terrains_panel.update_panel_display()")
	terrains_panel.update_panel_display()


func restore_editor_terrain_gui() -> void:
	if context.is_terrain_tab_active():
#		print("terrain tab is active, setting ed_terrains_panel visible to true")
		ed_terrains_panel.visible = true
	tool_buttons.visible = false
	terrains_panel.visible = false
	info_label.visible = false
	toggle_editor_buttons(true)
	update_overlays()


func toggle_editor_buttons(value : bool) -> void:
	var first_button_pressed := false
	for button in ed_tool_buttons_container.find_children("*", "Button", true, false):
		button.visible = value
		if value && not first_button_pressed:
			button.button_pressed = true
			first_button_pressed = true
		elif not value:
			button.button_pressed = false










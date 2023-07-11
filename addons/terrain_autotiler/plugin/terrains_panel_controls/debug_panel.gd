@tool
extends Control

const DEFAULT_TEXT := "No information available."

# Tabs
const TERRAINS := 0
const RESULTS := 1
const CELL_LOG := 2

# Menu items
const ENABLE_CELL_LOGGING := 0
const BUG_REPORT := 1

const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")

var context : Context

@onready var tab_bar: TabBar = %TabBar
@onready var debug_overlay_button: Button = %DebugOverlayButton
@onready var menu_button: MenuButton = %MenuButton
@onready var menu_popup : PopupMenu = menu_button.get_popup()

@onready var results_label: RichTextLabel = %ResultsLabel
@onready var cell_label: RichTextLabel = %CellLabel
@onready var terrains_label: RichTextLabel = %TerrainsLabel

@onready var terrains_container: ScrollContainer = %TerrainsContainer
@onready var results_container: ScrollContainer = %ResultsContainer
@onready var cells_container: ScrollContainer = %CellsContainer

@onready var transitions_button: Button = %TransitionsButton

@onready var log_panel: Control = %LogPanel



@onready var tab_containers := {
	TERRAINS : terrains_container,
	RESULTS : results_container,
	CELL_LOG : cells_container,
}


func setup(p_context : Context) -> void:
	context = p_context

	var cell_logging_idx := menu_popup.get_item_index(ENABLE_CELL_LOGGING)
	var cell_logging_enabled := context.is_cell_logging_enabled()
	menu_popup.set_item_checked(cell_logging_idx, cell_logging_enabled)

	var bug_report_idx := menu_popup.get_item_index(BUG_REPORT)
	menu_popup.set_item_icon(bug_report_idx, get_theme_icon("ExternalLink", "EditorIcons"))


	results_label.add_theme_font_override("normal_font", get_theme_font("font", "CodeEdit"))
	cell_label.add_theme_font_override("normal_font", get_theme_font("font", "CodeEdit"))
	terrains_label.add_theme_font_override("normal_font", get_theme_font("font", "CodeEdit"))

	context.current_terrain_set_changed.connect(_on_current_terrain_set_changed)
	context.current_update_result_changed.connect(_on_current_update_result_changed)
	context.current_debug_cell_changed.connect(_on_current_debug_cell_changed)
	context.current_input_mode_changed.connect(_on_current_input_mode_changed)

	visibility_changed.connect(_on_visibility_changed)

	menu_popup.id_pressed.connect(_on_menu_popup_id_pressed)

	_reset_cell_log()
	_update_results(null)

	set("theme_override_styles/panel", get_theme_stylebox("bg_selected", "EditorProperty"))
	log_panel.set("theme_override_styles/panel", get_theme_stylebox("Content", "EditorStyles"))


func _show_tab(p_idx : int) -> void:
	tab_bar.current_tab = p_idx
	for idx in tab_containers:
		var container : Control = tab_containers[idx]
		if idx == p_idx:
			container.show()
		else:
			container.hide()


# -------------------
#	TERRAINS TAB
# -------------------

func _update_terrains(p_terrain_set : int, p_show_transitions := false) -> void:
#	print("update_terrains called with %s" % p_terrain_set)
	terrains_label.clear()
	transitions_button.hide()

	if not is_visible_in_tree():
		return

	if p_terrain_set == Autotiler.NULL_TERRAIN_SET:
		return
	var autotiler := context.get_current_autotiler()
	if not autotiler:
		return

	_show_tab(TERRAINS)
	var terrains_data := autotiler._get_terrains_data(p_terrain_set)
	if not terrains_data:
		return

	if not p_show_transitions:
		transitions_button.show()

	terrains_label.append_text(terrains_data.get_debug_text(p_show_transitions))



func _on_transitions_button_pressed() -> void:
	_update_terrains(context.get_current_terrain_set(), true)





func _update_results(p_update_result : UpdateResult) -> void:
	results_label.clear()
	_reset_cell_log()

	if not is_visible_in_tree():
		return

	if not p_update_result:
		tab_bar.set_tab_hidden(RESULTS, true)
		return

	tab_bar.set_tab_hidden(RESULTS, false)
	_show_tab(RESULTS)

	results_label.append_text(p_update_result.get_tiles_updater_timer_text())

	if context.is_cell_logging_enabled():
		results_label.append_text(p_update_result.get_stats_text())
	results_label.append_text(p_update_result.get_errors_text())
#	tab_container.current_tab = results_tab
#	tab_container.set_tab_hidden(cell_tab, true)


func _show_cell_log(p_coords : Vector2i) -> void:

	_show_tab(CELL_LOG)

	cell_label.clear()

	var current_result := context.get_current_update_result()

	var texts := current_result.get_cell_log_texts(p_coords)
	if texts.is_empty():
		cell_label.append_text(DEFAULT_TEXT)
		return

	var type_text : String = current_result.get_cell_pattern_type_text(p_coords)
	var idx : int = current_result.cell_update_indexes[p_coords]

	tab_bar.set_tab_title(CELL_LOG, "#%s: %s" % [idx, p_coords])

	cell_label.append_text("%s: %s (update #%s)" % [str(p_coords), type_text, idx])
	for text in current_result.get_cell_log_texts(p_coords):
		cell_label.append_text("\n")
		cell_label.append_text(text)


func _reset_cell_log() -> void:
	if not context.is_cell_logging_enabled() or \
		not context.has_update_result():

		tab_bar.set_tab_hidden(CELL_LOG, true)
		debug_overlay_button.hide()
		return

	debug_overlay_button.show()
	tab_bar.set_tab_hidden(CELL_LOG, false)
	tab_bar.set_tab_title(CELL_LOG, "(?,?)")
	cell_label.clear()
	cell_label.append_text("Open the debug overlay by clicking the magnifying glass (above).\n\nThen select a cell to view its log.")


func _on_visibility_changed() -> void:
	_update_terrains(context.get_current_terrain_set())
	_update_results(context.get_current_update_result())


func _on_current_terrain_set_changed(p_terrain_set : int) -> void:
#	prints("_on_current_terrain_set_changed", p_terrain_set)
	_update_terrains(p_terrain_set)


func _on_current_update_result_changed(p_update_result : UpdateResult) -> void:
	_update_results(p_update_result)


func _on_debug_overlay_button_toggled(button_pressed: bool) -> void:
	if button_pressed:
		context.set_current_input_mode(Context.InputMode.DEBUG)
	else:
		context.set_current_input_mode(Context.InputMode.PAINT)


func _on_current_debug_cell_changed(p_coords : Vector2i) -> void:
	_show_cell_log(p_coords)


func _on_tab_bar_tab_changed(tab: int) -> void:
	_show_tab(tab)


func _on_menu_popup_id_pressed(p_id : int) -> void:
	var idx := menu_popup.get_item_index(p_id)
	if p_id == ENABLE_CELL_LOGGING:
		var cell_logging_enabled := context.is_cell_logging_enabled()
		menu_popup.set_item_checked(idx, not cell_logging_enabled)
		context.settings.set_value(Context.Settings.ENABLE_CELL_LOGGING, not cell_logging_enabled)
	elif p_id == BUG_REPORT:
		var url := "https://github.com/dandeliondino/terrain-autotiler/issues"
		OS.shell_open(url)


func _on_current_input_mode_changed(p_input_mode : Context.InputMode) -> void:
	if p_input_mode != Context.InputMode.DEBUG:
		debug_overlay_button.set_pressed_no_signal(false)




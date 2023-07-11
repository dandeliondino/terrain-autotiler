extends RefCounted

signal overlay_update_requested


const Actions := preload("res://addons/terrain_autotiler/plugin/actions.gd")
const Settings := preload("res://addons/terrain_autotiler/plugin/settings.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")

# ----------------------------------------------
# PUBLIC REFERENCES
# ----------------------------------------------

var actions := Actions.new()
var settings := Settings.new()

var editor_interface : EditorInterface

var terrains_panel : Control

var ed_tab_bar : Control
var ed_terrain_tab_idx : int

var ed_no_tileset_label : Label


func is_terrain_tab_active() -> bool:
	return ed_tab_bar.current_tab == ed_terrain_tab_idx

# ----------------------------------------------
# CURRENT TILE MAP
# ----------------------------------------------

signal current_tile_map_changed(tile_map)
signal current_tile_set_changed(tile_set)

var _current_tile_map : TileMap
var _current_tile_set : TileSet

func set_current_tile_map(p_tile_map : TileMap) -> void:
#	print("set_current_tile_map() - p_tile_map = %s" % p_tile_map)
	if _current_tile_map == null && p_tile_map == null:
		return

	if is_instance_valid(_current_tile_map) && p_tile_map == _current_tile_map:
		return

	if is_instance_valid(_current_tile_map) && _current_tile_map.changed.is_connected(_update_current_tile_set):
		_current_tile_map.changed.disconnect(_update_current_tile_set)


	_current_tile_map = p_tile_map
#	print("context :: _current_tile_map -> %s" % p_tile_map)

	clear_current_terrain_set()
	clear_current_terrain()
	_clear_current_autotiler()
	_update_current_tile_set()
	if is_instance_valid(_current_tile_map) && not _current_tile_map.changed.is_connected(_update_current_tile_set):
		_current_tile_map.changed.connect(_update_current_tile_set)

	current_tile_map_changed.emit(_current_tile_map)
	overlay_update_requested.emit()


func _update_current_tile_set() -> void:
	if is_instance_valid(_current_tile_map) && _current_tile_set == _current_tile_map.tile_set:
		return
	if not is_instance_valid(_current_tile_map):
		_current_tile_set = null
	else:
		_current_tile_set = _current_tile_map.tile_set
	clear_current_terrains_data()
	current_tile_set_changed.emit(_current_tile_set)


func get_current_tile_map() -> TileMap:
	return _current_tile_map

func get_current_tile_set() -> TileSet:
	return _current_tile_set


# ----------------------------------------------
# 	CURRENT AUTOTILER
# ----------------------------------------------

var _current_autotiler : Autotiler

# called by terrains data panel
func update_current_autotiler() -> void:
	clear_current_terrains_data()
	clear_current_update_result()

	if not _current_tile_map or not _current_tile_map.tile_set:
		_current_autotiler = null
	else:
		_current_autotiler = Autotiler.new(_current_tile_map)
#	print("update_current_autotiler() -> %s" % _current_autotiler)


func _clear_current_autotiler() -> void:
#	print("_clear_current_autotiler()")
	_current_autotiler = null
	clear_current_terrains_data()
	clear_current_update_result()


func get_current_autotiler() -> Autotiler:
	return _current_autotiler




# ----------------------------------------------
# CURRENT LAYER
# ----------------------------------------------
# OptionButtons don't send signals when the selected item is updated via script
# so it is unreliable to monitor the layer option button for a selected signal.
# Therefore, get_current_layer() gets the layer straight from the editor control
# whenever it is needed.

var _layer_option_button : OptionButton

func set_layer_option_button(p_layer_option_button : OptionButton) -> void:
	_layer_option_button = p_layer_option_button


func get_current_layer() -> int:
	return _layer_option_button.get_selected_id()


# ----------------------------------------------
# CURRENT CELL
# ----------------------------------------------

signal current_cell_changed(coords)
#signal input_exited_tilemap

const INVALID_CELL := Vector2i(-999,-999)

var _current_cell := INVALID_CELL

# returns true if changed, otherwise false
func set_current_cell(p_coords : Vector2i) -> bool:
	if _current_cell == p_coords:
		return false
	_current_cell = p_coords
	current_cell_changed.emit(p_coords)
	return true


# input_exited_tilemap avoids duplicate checks in other scripts
# to see if new cell is valid
func clear_current_cell() -> void:
	_current_cell = INVALID_CELL
	current_cell_changed.emit(INVALID_CELL)
#	input_exited_tilemap.emit()
	overlay_update_requested.emit()


func get_current_cell() -> Vector2i:
	return _current_cell


func has_current_cell() -> bool:
	return _current_cell != INVALID_CELL



# ----------------------------------------------
# SELECTED CELLS
# ----------------------------------------------

var _selected_cells : Array[Vector2i]


func add_selected_cell(p_coords : Vector2i) -> void:
	if _selected_cells.has(p_coords):
		return
	_selected_cells.append(p_coords)


func set_selected_cells(p_cells : Array[Vector2i]) -> void:
	_selected_cells = p_cells


func get_selected_cells() -> Array[Vector2i]:
	return _selected_cells


func clear_selected_cells() -> void:
	_selected_cells.clear()


func has_selected_cells() -> bool:
	return not _selected_cells.is_empty()



# ----------------------------------------------
# CURRENT TERRAIN SET AND TERRAINS DATA
# ----------------------------------------------

signal current_terrain_set_changed(terrain_set)

var _current_terrain_set := Autotiler.NULL_TERRAIN_SET
var _current_terrains_data : TerrainsData = null


func set_current_terrain_set(p_terrain_set : int) -> void:
#	print("set_current_terrain_set() - %s" % p_terrain_set)
	if p_terrain_set == _current_terrain_set:
#		print("p_terrain_set == _current_terrain_set, returning")
		return
	_current_terrain_set = p_terrain_set
	if _current_terrain_set == Autotiler.NULL_TERRAIN_SET:
		_current_terrains_data = null
	elif not get_current_autotiler():
#		print("set_current_terrain_set() - not get_current_autotiler() - _current_terrains_data = null")
		_current_terrains_data = null
	else:
		_current_terrains_data = get_current_autotiler()._get_terrains_data(p_terrain_set)
#		print("set_current_terrain_set() - _current_terrains_data -> %s" % _current_terrains_data)
	current_terrain_set_changed.emit(p_terrain_set)


func get_current_terrain_set() -> int:
	return _current_terrain_set


func has_current_terrain_set() -> bool:
	return _current_terrain_set != Autotiler.NULL_TERRAIN_SET


func clear_current_terrain_set() -> void:
	_current_terrain_set = Autotiler.NULL_TERRAIN_SET
	clear_current_terrains_data()
	clear_current_terrain()


func get_current_terrains_data() -> TerrainsData:
	return _current_terrains_data


func clear_current_terrains_data() -> void:
#	print("clear_current_terrains_data()")
	_current_terrains_data = null


# ----------------------------------------------
# CURRENT TERRAIN
# ----------------------------------------------

signal terrain_change_requested(terrain_set, terrain)
signal current_terrain_changed(terrain)

var _current_terrain := Autotiler.NULL_TERRAIN

# should be called by terrains panel only
# if other objects want to change the terrain,
# they should use signal terrain_change_requested
func set_current_terrain(p_terrain : int) -> void:
	if p_terrain == _current_terrain:
		return
	_current_terrain = p_terrain
	current_terrain_changed.emit(p_terrain)


func get_current_terrain() -> int:
	return _current_terrain


func has_current_terrain() -> bool:
	return _current_terrain != Autotiler.NULL_TERRAIN


func clear_current_terrain() -> void:
	_current_terrain = Autotiler.NULL_TERRAIN



# ----------------------------------------------
# INPUT MODE
# ----------------------------------------------

signal current_input_mode_changed(input_mode)

enum InputMode {
	NONE,
	PAINT,
	PICKER,
	LOCK,
	DEBUG,
}

var _current_input_mode := InputMode.NONE

func set_current_input_mode(p_input_mode : InputMode) -> void:
	if p_input_mode == _current_input_mode:
		return
	_current_input_mode = p_input_mode
	reset_input()
	current_input_mode_changed.emit(p_input_mode)
	overlay_update_requested.emit()


func get_current_input_mode() -> InputMode:
	return _current_input_mode


func reset_input() -> void:
	clear_selected_cells()
	clear_current_button_index()
	set_mouse_pressed(false)


# ----------------------------------------------
# PAINT TOOLS
# ----------------------------------------------

signal current_paint_tool_changed(paint_tool)

enum PaintTool {
	NONE,
	DRAW,
	LINE,
	RECT,
	BUCKET,
}

const PaintToolNames := {
	PaintTool.DRAW: "Draw",
	PaintTool.LINE: "Line",
	PaintTool.RECT: "Rect",
	PaintTool.BUCKET: "Bucket",
}

var _current_paint_tool := PaintTool.DRAW

func set_current_paint_tool(p_paint_tool : PaintTool) -> void:
	if p_paint_tool == _current_paint_tool:
		return
	_current_paint_tool = p_paint_tool
	reset_input()
	current_paint_tool_changed.emit(p_paint_tool)

func get_current_paint_tool() -> PaintTool:
	return _current_paint_tool

func get_current_paint_tool_name() -> String:
	return PaintToolNames.get(_current_paint_tool, "")


# ----------------------------------------------
# PAINT MODES
# ----------------------------------------------

enum PaintMode {
	CONNECT,
	PATH,
}

var _current_paint_mode : PaintMode

func set_current_paint_mode(p_value : PaintMode) -> void:
	_current_paint_mode = p_value


func get_current_paint_mode() -> PaintMode:
	return _current_paint_mode





# ----------------------------------------------
# MOUSE STATES
# ----------------------------------------------
# will be set to none when mouse exits main screen

var _mouse_pressed := false

func set_mouse_pressed(p_value : bool) -> void:
	_mouse_pressed = p_value

func is_mouse_pressed() -> bool:
	return _mouse_pressed



var _current_button_index : MouseButton

func set_current_button_index(p_button_index : MouseButton) -> void:
	_current_button_index = p_button_index


func get_current_button_index() -> MouseButton:
	return _current_button_index

# default to left mouse button
func clear_current_button_index() -> void:
	_current_button_index = MOUSE_BUTTON_LEFT



# ----------------------------------------------
#  GET CELL TERRAIN
# ----------------------------------------------

const TERRAIN_SET := &"TERRAIN_SET"
const TERRAIN := &"TERRAIN"


# will return a dict with both terrain_set and terrain = NULL values
# if it contains a non-terrain cell
# will return EMPTY_TERRAIN if the cell is empty (no guaranteed return value for terrain_set)
# and the terrain set and terrain if the cell has a terrain
func get_cell_terrain_dict(p_coords : Vector2i) -> Dictionary:
	var dict := {
		TERRAIN_SET: Autotiler.NULL_TERRAIN_SET,
		TERRAIN: Autotiler.NULL_TERRAIN,
	}

	var layer := get_current_layer()
	var tile_map := get_current_tile_map()

	if not tile_map:
		return dict

	const INVALID_SOURCE := -1
	var has_tile := (tile_map.get_cell_source_id(layer, p_coords) != INVALID_SOURCE)
	var tile_data := tile_map.get_cell_tile_data(layer, p_coords)

	# this should ignore non-atlas tiles
	if has_tile and not tile_data:
		return dict

	# this should identify empty tiles
	if not tile_data:
		dict[TERRAIN] = Autotiler.EMPTY_TERRAIN
		return dict

	# -1 is the default value as well as empty value
	# but if the cell is empty, it shouldn't have a TileData
	# so this cell likely has a non-terrain tile in it, so we'll return the dict
	# with null values
	const UNASSIGNED := -1
	if tile_data.terrain_set == UNASSIGNED or tile_data.terrain == UNASSIGNED:
		return dict

	dict[TERRAIN_SET] = tile_data.terrain_set
	dict[TERRAIN] = tile_data.terrain

	return dict



# ----------------------------------------------
#  DEBUG : UpdateResult
# ----------------------------------------------

signal toggle_debug_panel_requested(value)

signal current_update_result_changed(update_result)

const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")

var _current_update_result : UpdateResult


func set_current_update_result(p_update_result : UpdateResult) -> void:
	_current_update_result = p_update_result
	current_update_result_changed.emit(p_update_result)


func get_current_update_result() -> UpdateResult:
	return _current_update_result


func clear_current_update_result() -> void:
	set_current_update_result(null)


func has_update_result() -> bool:
	return _current_update_result != null

# ----------------------------------------------
#  DEBUG : Cell Logs
# ----------------------------------------------

signal current_debug_cell_changed(coords)

var _current_debug_cell : Vector2i


func is_cell_logging_enabled() -> bool:
	return settings.get_value(Settings.ENABLE_CELL_LOGGING)


func set_current_debug_cell(p_coords : Vector2i) -> void:
	_current_debug_cell = p_coords
	current_debug_cell_changed.emit(p_coords)


func get_current_debug_cell() -> Vector2i:
	return _current_debug_cell


func clear_current_debug_cell() -> void:
	_current_debug_cell = INVALID_CELL
	current_debug_cell_changed.emit(INVALID_CELL)

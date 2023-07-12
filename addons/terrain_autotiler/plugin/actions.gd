extends RefCounted

const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")
const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

var context : Context
var undo_redo : EditorUndoRedoManager


func setup(p_context : Context, p_undo_redo : EditorUndoRedoManager) -> void:
	context = p_context
	undo_redo = p_undo_redo


func update_layer() -> void:
	var layer := context.get_current_layer()
	var tile_map := context.get_current_tile_map()
	var autotiler := context.get_current_autotiler()
	autotiler._cell_logging = context.is_cell_logging_enabled()
	autotiler.update_terrain_tiles(layer)


	context.set_current_update_result(autotiler._last_update_result)

	undo_redo.create_action("Terrain Autotiler: Update %s / layer %s" % [tile_map.name, layer], UndoRedo.MERGE_DISABLE, tile_map)
	undo_redo.add_do_method(self, "_place_cell_tiles", tile_map, layer, autotiler._last_update_result.cell_tiles_after)
	undo_redo.add_undo_method(self, "_place_cell_tiles", tile_map, layer, autotiler._last_update_result.cell_tiles_before)
	undo_redo.commit_action(false)


var _draw_cell_tiles_before := {}
var _draw_cell_tiles_after := {}


func start_draw_selection() -> void:
	var autotiler := context.get_current_autotiler()
	paint_selection(false)
	_draw_cell_tiles_before = autotiler._last_update_result.cell_tiles_before
	_draw_cell_tiles_after = autotiler._last_update_result.cell_tiles_after



func continue_draw_selection() -> void:
	paint_selection(false)
	var autotiler := context.get_current_autotiler()
	var current_result_before := autotiler._last_update_result.cell_tiles_before
	var current_result_after := autotiler._last_update_result.cell_tiles_after
	for coords in current_result_before:
		if not _draw_cell_tiles_before.has(coords):
			_draw_cell_tiles_before[coords] = current_result_before[coords]
		_draw_cell_tiles_after[coords] = current_result_after[coords]


func finish_draw_selection() -> void:
	var layer := context.get_current_layer()
	var tile_map := context.get_current_tile_map()

	var terrain : int
	if context.get_current_button_index() == MOUSE_BUTTON_RIGHT:
		terrain = Autotiler.EMPTY_TERRAIN
	else:
		terrain = context.get_current_terrain()
	var terrain_name : String = context.get_current_terrains_data().terrain_names[terrain]
	var paint_tool := context.get_current_paint_tool_name()

	undo_redo.create_action(
		"Terrain Autotiler: Paint %s (%s)" % [terrain_name, paint_tool],
		UndoRedo.MERGE_DISABLE,
		tile_map,
	)
	undo_redo.add_do_method(
		self,
		"_place_cell_tiles",
		tile_map,
		layer,
		_draw_cell_tiles_after.duplicate(),
	)
	undo_redo.add_undo_method(
		self,
		"_place_cell_tiles",
		tile_map,
		layer,
		_draw_cell_tiles_before.duplicate(),
	)
	undo_redo.commit_action(false)
	_draw_cell_tiles_before.clear()
	_draw_cell_tiles_after.clear()


func paint_selection(p_create_undo_redo := true) -> void:
	var terrain : int
	if context.get_current_button_index() == MOUSE_BUTTON_RIGHT:
		terrain = Autotiler.EMPTY_TERRAIN
	else:
		terrain = context.get_current_terrain()

	var terrain_set := context.get_current_terrain_set()
	var paint_mode := context.get_current_paint_mode()

	var cells := context.get_selected_cells()
	var layer := context.get_current_layer()
	var tile_map := context.get_current_tile_map()
	var autotiler := context.get_current_autotiler()
	autotiler._cell_logging = context.is_cell_logging_enabled()

	if paint_mode == Context.PaintMode.CONNECT:
		autotiler.set_cells_terrain_connect(
			layer,
			cells,
			terrain_set,
			terrain,
		)
	else:
		autotiler.set_cells_terrain_path(
			layer,
			cells,
			terrain_set,
			terrain,
		)

	context.set_current_update_result(autotiler._last_update_result)

	if not p_create_undo_redo:
		return

	var paint_tool := context.get_current_paint_tool_name()
	var terrain_name : String = context.get_current_terrains_data().terrain_names[terrain]

	undo_redo.create_action(
		"Terrain Autotiler: Paint %s (%s)" % [terrain_name, paint_tool],
		UndoRedo.MERGE_DISABLE,
		tile_map,
	)
	undo_redo.add_do_method(
		self,
		"_place_cell_tiles",
		tile_map,
		layer,
		autotiler._last_update_result.cell_tiles_after,
	)
	undo_redo.add_undo_method(
		self,
		"_place_cell_tiles",
		tile_map,
		layer,
		autotiler._last_update_result.cell_tiles_before,
	)
	undo_redo.commit_action(false)





func lock_selection() -> void:
	var lock := (context.get_current_button_index() == MOUSE_BUTTON_LEFT)
	var tile_map := context.get_current_tile_map()
	var layer := context.get_current_layer()
	var cells := context.get_selected_cells()

	var action_name : String
	if lock:
		action_name = "Terrain Autotiler: Lock cells"
	else:
		action_name = "Terrain Autotiler: Unlock cells"

#	print("Current button: %s" % context.get_current_button_index())
#	print("Lock selection: %s" % lock)


	undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_DISABLE,
		tile_map,
	)
	undo_redo.add_do_method(
		Autotiler,
		"set_cells_locked",
		tile_map,
		layer,
		cells,
		lock,
	)
	undo_redo.add_undo_method(
		Autotiler,
		"set_cells_locked",
		tile_map,
		layer,
		cells,
		not lock,
	)
	undo_redo.commit_action(true)



func _place_cell_tiles(p_tile_map : TileMap, p_layer : int, p_cell_tiles : Dictionary) -> void:
	for coords in p_cell_tiles:
		var tile_location : TileLocation = p_cell_tiles[coords]
		if not tile_location:
			p_tile_map.erase_cell(p_layer, coords)
			continue

		p_tile_map.set_cell(
			p_layer,
			coords,
			tile_location.source_id,
			tile_location.atlas_coords,
			tile_location.alternative_tile_id,
		)











